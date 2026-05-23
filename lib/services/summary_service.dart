/// 摘要服务
///
/// 负责管理章节摘要和全书摘要的生成、存储、读取和删除。
/// 支持并发控制，防止同一章节被重复生成摘要。

import 'dart:async';

import 'package:path/path.dart' as p;

import '../models/chapter.dart';
import '../models/book.dart';
import 'file_storage_service.dart';
import 'log_service.dart';
import 'book_service.dart';
import 'ai_service.dart';
import 'settings_service.dart';
import 'parsers/book_format_parser.dart';
import 'storage_config.dart';

/// 信号量类，用于控制并发数
class Semaphore {
  final int _maxPermits;
  int _availablePermits;
  final List<Completer<void>> _waitingQueue = [];

  Semaphore(this._maxPermits) : _availablePermits = _maxPermits;

  /// 获取一个许可，如果没有可用许可则等待
  Future<void> acquire() async {
    if (_availablePermits > 0) {
      _availablePermits--;
      return;
    }

    final completer = Completer<void>();
    _waitingQueue.add(completer);
    return completer.future;
  }

  /// 释放一个许可
  void release() {
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeAt(0);
      completer.complete();
    } else {
      _availablePermits++;
    }
  }
}

/// 摘要管理服务（单例模式）
///
/// 提供摘要的CRUD操作和AI生成功能。
/// 所有摘要以文件形式存储在应用目录中。
class SummaryService {
  /// 单例实例
  static final SummaryService _instance = SummaryService._internal();

  /// 工厂构造函数，返回单例实例
  factory SummaryService() => _instance;

  /// 私有构造函数
  SummaryService._internal();

  /// AI服务，用于调用大模型生成摘要
  final _aiService = AIService();

  /// 书籍服务，用于更新章节标题等元数据
  final _bookService = BookService();

  /// 日志服务
  final _log = LogService();

  /// 文件存储服务，用于读写摘要文件
  final _fileStorage = FileStorageService();

  /// 并发AI请求信号量，限制同时进行的AI请求总数
  /// 防止用户快速切换章节时同时发起过多AI请求导致性能问题
  /// 本地模型（ollama/lmstudio）设为1，云端模型设为3
  late Semaphore _concurrentRequestSemaphore;

  /// 流式内容回调映射表
  /// Key: {bookId}_{language}，支持同一本书不同语言同时生成
  final Map<String, Function(String)> _streamingCallbacks = {};

  /// 注册全书摘要流式回调
  void registerBookStreamingCallback(String bookId, String language, Function(String) callback) {
    final key = '${bookId}_$language';
    _streamingCallbacks[key] = callback;
    _log.d('SummaryService', '注册全书摘要流式回调: $key, 当前回调数: ${_streamingCallbacks.length}');
  }

  /// 取消全书摘要流式回调
  void unregisterBookStreamingCallback(String bookId, String language) {
    _streamingCallbacks.remove('${bookId}_$language');
    _log.d('SummaryService', '取消全书摘要流式回调: $bookId [$language]');
  }

  /// 章节摘要流式回调映射表
  /// Key: {bookId}_{chapterIndex}_{language}
  final Map<String, Function(String)> _chapterCallbacks = {};

  /// 注册章节摘要流式回调
  void registerChapterCallback(String bookId, int chapterIndex, Function(String) callback) {
    _chapterCallbacks['${bookId}_$chapterIndex'] = callback;
  }

  /// 取消章节摘要流式回调
  void unregisterChapterCallback(String bookId, int chapterIndex) {
    _chapterCallbacks.remove('${bookId}_$chapterIndex');
  }

  void _notifyChapterContent(String bookId, int chapterIndex, String content) {
    _chapterCallbacks['${bookId}_$chapterIndex']?.call(content);
  }

  /// 章节译文流式回调映射表
  final Map<String, Function(String)> _translationCallbacks = {};

  /// 注册章节译文流式回调
  void registerTranslationCallback(String bookId, int chapterIndex, Function(String) callback) {
    _translationCallbacks['${bookId}_$chapterIndex'] = callback;
  }

  /// 取消章节译文流式回调
  void unregisterTranslationCallback(String bookId, int chapterIndex) {
    _translationCallbacks.remove('${bookId}_$chapterIndex');
  }

  void _notifyTranslationContent(String bookId, int chapterIndex, String content) {
    _translationCallbacks['${bookId}_$chapterIndex']?.call(content);
  }

  /// 触发全书摘要流式内容更新
  void _notifyBookStreamingContent(String bookId, String language, String content) {
    final key = '${bookId}_$language';
    final callback = _streamingCallbacks[key];
    if (callback != null) {
      _log.d('SummaryService', '触发流式回调: $key, 内容长度: ${content.length}');
      callback(content);
    } else {
      _log.w('SummaryService', '未找到流式回调: $key');
    }
  }

  // ==================== 并发控制相关 ====================

  /// 正在生成摘要的章节标识集合
  ///
  /// Key格式：`{bookId}_{chapterIndex}`
  final Set<String> _generatingKeys = {};

  /// 生成章节的唯一标识键
  String _key(String bookId, int chapterIndex) => '${bookId}_$chapterIndex';

  // ==================== 初始化 ====================

  /// 初始化服务
  ///
  /// 文件存储模式下无需初始化，仅打印日志。
  Future<void> init() async {
    _initSemaphore();
    SettingsService().aiSettings.addListener(_onAiSettingsChanged);
    _log.d('SummaryService', '初始化完成');
  }

  void _onAiSettingsChanged() {
    _initSemaphore();
  }

  /// 根据AI提供商初始化信号量
  /// 本地模型（ollama/lmstudio）设为1，云端模型设为3
  void _initSemaphore() {
    final provider = _aiService.currentProvider;
    final isLocal = provider == 'ollama' || provider == 'lmstudio';
    _concurrentRequestSemaphore = Semaphore(isLocal ? 1 : 3);
    _log.d('SummaryService', '并发限制初始化：provider=$provider, maxConcurrency=${isLocal ? 1 : 3}');
  }

  /// 清理资源，移除监听器
  void dispose() {
    SettingsService().aiSettings.removeListener(_onAiSettingsChanged);
  }

  // ==================== 单章节摘要操作 ====================

  /// 获取指定章节的摘要
  Future<Chapter?> getSummary(String bookId, int chapterIndex, {String language = 'zh'}) async {
    try {
      final filePath =
          await StorageConfig.getChapterSummaryPath(bookId, chapterIndex, language: language);
      final content = await _fileStorage.readText(filePath);

      if (content == null || content.isEmpty) {
        return null;
      }

      final chapter = Chapter(
        bookId: bookId,
        index: chapterIndex,
        title: '',
        location: ChapterLocation(),
        objectiveSummary: content,
      );

      return chapter;
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'getSummary 失败', e, stackTrace);
      return null;
    }
  }

  /// 保存章节摘要
  Future<void> saveSummary(Chapter chapter, {String language = 'zh'}) async {
    try {
      final filePath = await StorageConfig.getChapterSummaryPath(
          chapter.bookId, chapter.index, language: language);
      final content = chapter.objectiveSummary;
      if (content != null) {
        await _fileStorage.writeText(filePath, content);
      }
      _log.d(
          'SummaryService', '摘要已保存: ${chapter.bookId}_${chapter.index}_$language');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'saveSummary 失败', e, stackTrace);
    }
  }

  // ==================== 全书摘要操作 ====================

  /// 获取全书摘要
  Future<String?> getBookSummary(String bookId, {String language = 'zh'}) async {
    try {
      final filePath = await StorageConfig.getBookSummaryPath(bookId, language: language);
      return await _fileStorage.readText(filePath);
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'getBookSummary 失败: $bookId', e, stackTrace);
      return null;
    }
  }

  /// 保存全书摘要
  ///
  /// 全书摘要以独立的 Markdown 文件存储（summary-zh.md），
  /// 不再同时写入 metadata.json 的 aiIntroduction 字段，避免重复存储。
  Future<void> saveBookSummary(String bookId, String summary, {String language = 'zh'}) async {
    try {
      final filePath = await StorageConfig.getBookSummaryPath(bookId, language: language);
      await _fileStorage.writeText(filePath, summary);
      _log.d('SummaryService', '书籍摘要已保存: $bookId, language: $language');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'saveBookSummary 失败: $bookId', e, stackTrace);
    }
  }

  // ==================== 摘要生成 ====================

  /// 生成单个章节的摘要（带并发控制）
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [chapterTitle]：章节原标题（用于AI提示词）
  /// - [content]：章节正文内容
  /// - [onContentUpdate]：内容更新回调函数（可选，用于实时反馈）
  ///
  /// 返回：`true` 表示生成成功，`false` 表示失败或重复请求
  Future<bool> generateSingleSummary(
    String bookId,
    int chapterIndex,
    String chapterTitle,
    String content, {
    Function(String)? onContentUpdate,  // 实时内容更新回调
    String language = 'zh',  // 语言代码
  }) async {
    final key = _key(bookId, chapterIndex);

    // 并发控制：检查是否正在生成
    if (_generatingKeys.contains(key)) {
      _log.d('SummaryService', '摘要生成中，跳过重复请求: $key');
      return false;
    }

    // 获取并发AI请求许可
    await _concurrentRequestSemaphore.acquire();

    // 标记为"生成中"
    _generatingKeys.add(key);

    try {
      // 调用AI流式生成摘要（内部使用流式方法）
      final stream = _aiService.generateFullChapterSummaryStream(
        content,
        chapterTitle: chapterTitle,
        bookId: bookId,
        language: language,
      );

      String accumulatedContent = '';

      await for (final chunk in stream) {
        accumulatedContent += chunk;

        if (onContentUpdate != null) {
          onContentUpdate(accumulatedContent);
        }
        _notifyChapterContent(bookId, chapterIndex, accumulatedContent);
      }

      // 生成完成，处理最终内容
      if (accumulatedContent.isNotEmpty) {
        final extractedTitle = extractTitleFromSummary(accumulatedContent);
        final cleanSummary = removeTitleLineFromSummary(accumulatedContent);

        final chapterSummary = Chapter(
          bookId: bookId,
          index: chapterIndex,
          title: extractedTitle ?? chapterTitle,
          location: ChapterLocation(),
          objectiveSummary: cleanSummary,
        );

        await saveSummary(chapterSummary, language: language);
        return true;
      } else {
        _log.w('SummaryService', 'AI返回空摘要: $key');
        return false;
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '生成摘要失败: $key', e, stackTrace);
      return false;
    } finally {
      // 清理并发控制标记
      _generatingKeys.remove(key);
      // 释放并发AI请求许可
      _concurrentRequestSemaphore.release();
    }
  }

  /// 确保章节摘要存在（加载已有或触发生成）
  ///
  /// 先检查已缓存的摘要，存在则直接返回。
  /// 否则通过 [generateSingleSummary] 流式生成，
  /// 期间通过注册的章节回调实时推送内容。
  Future<Chapter?> ensureChapterSummary(
    String bookId,
    int chapterIndex,
    String content,
    String chapterTitle, {
    String language = 'zh',
  }) async {
    final existing = await getSummary(bookId, chapterIndex, language: language);
    if (existing != null) return existing;

    await generateSingleSummary(
      bookId, chapterIndex, chapterTitle, content,
      language: language,
    );

    return await getSummary(bookId, chapterIndex, language: language);
  }

  /// 为整本书生成摘要（主入口）
  Future<void> generateSummariesForBook(
    Book book,
    List<Chapter> chapters, {
    String language = 'zh',
  }) async {
    try {
      if (chapters.isEmpty) {
        _log.w('SummaryService', '章节列表为空: ${book.title}');
        return;
      }

      _log.d('SummaryService', '使用已有的 ${chapters.length} 个章节，语言: $language');

      final extension = book.format == BookFormat.epub ? '.epub' : '.pdf';
      final parser = FormatRegistry.getParser(extension);

      if (parser == null) {
        _log.w('SummaryService', '不支持的格式: ${book.format}');
        return;
      }

      if (book.format == BookFormat.epub) {
        await _generateChapterSummaries(book, chapters, parser, language: language);
        await _generateBookSummaryFromChapters(book, chapters, language: language);
      } else {
        await _generateChapterSummaries(book, chapters, parser, language: language);
        await _generateBookSummaryFromChapters(book, chapters, language: language);
      }

      _log.info('SummaryService', '书籍摘要生成完成: ${book.title}');
    } catch (e, stackTrace) {
      _log.e('SummaryService', '生成书籍摘要失败: ${book.title}', e, stackTrace);
    }
  }

  /// 生成章节摘要（只为顶层章节生成）
  Future<void> _generateChapterSummaries(
    Book book,
    List<Chapter> chapters,
    dynamic parser, {
    String language = 'zh',
  }) async {
    // 只为顶层章节（level==0）生成摘要
    final topLevelChapters = chapters.where((c) => c.level == 0).toList();

    // 创建一个队列来管理并发任务
    final futures = <Future<void>>[];
    final semaphore = Semaphore(3); // 最多3个并发任务

    for (final chapter in topLevelChapters) {
      // chapter.index 是专门为顶层章节计算的索引
      final chapterIndex = chapter.index;
      if (chapterIndex < 0) continue; // 跳过无效index

      // 跳过已有摘要的章节
      final existingSummary = await getSummary(book.id, chapterIndex, language: language);
      if (existingSummary != null) {
        continue;
      }

      // 创建并发任务
      final future = _processChapterConcurrently(
        book,
        chapter,
        chapterIndex,
        parser,
        semaphore,
        language,
      );

      futures.add(future);
    }

    // 等待所有任务完成
    await Future.wait(futures);
  }

  /// 并发处理单个章节摘要生成
  Future<void> _processChapterConcurrently(
    Book book,
    Chapter chapter,
    int chapterIndex,
    dynamic parser,
    Semaphore semaphore,
    String language,
  ) async {
    // 等待信号量许可
    await semaphore.acquire();

    try {
      // 获取章节内容并生成摘要
      final updatedChapter = await parser.getChapterContent(book.filePath, chapter);
      final chapterContent = updatedChapter.htmlContent;

      if (chapterContent != null && chapterContent.isNotEmpty) {
        await generateSingleSummary(
          book.id,
          chapterIndex,
          chapter.title,
          chapterContent,
          language: language,
        );
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '处理章节 $chapterIndex 时出错', e, stackTrace);
    } finally {
      // 释放信号量许可
      semaphore.release();
    }
  }

  /// 从章节摘要生成全书摘要
  Future<void> _generateBookSummaryFromChapters(
    Book book,
    List<Chapter> chapters, {
    String language = 'zh',
  }) async {
    try {
      // 检查是否已有本书当前语言的摘要
      final existingSummary = await getBookSummary(book.id, language: language);
      if (existingSummary != null && existingSummary.isNotEmpty) {
        _log.d('SummaryService', '已有全书摘要[$language]，跳过: ${book.title}');
        return;
      }

      // 收集所有章节摘要和少量实际内容用于语言检测
      final chapterSummaries = <String>[];
      final contentSamples = <String>[];

      for (int i = 0; i < chapters.length && i < 30; i++) {
        final summary = await getSummary(book.id, i, language: language);
        if (summary != null && summary.objectiveSummary != null && summary.objectiveSummary!.isNotEmpty) {
          // 截取前400字保持摘要完整性
          final shortSummary = summary.objectiveSummary!.length > 400
              ? summary.objectiveSummary!.substring(0, 400)
              : summary.objectiveSummary!;
          chapterSummaries.add('第${i + 1}章：$shortSummary...');
        }

        // 同时获取原始内容样本用于语言检测
        if (contentSamples.length < 3) {
          // 仅取前3个样本避免内容过长
          try {
            final parser = FormatRegistry.getParser(p.extension(book.filePath));
            if (parser != null) {
              final chapterContent =
                  await parser.getChapterContent(book.filePath, chapters[i]);
              if (chapterContent.htmlContent != null &&
                  chapterContent.htmlContent!.isNotEmpty) {
                // 取取前300个字符作为语言检测样本
                final content = chapterContent.htmlContent!;
                final sampleLength =
                    content.length > 300 ? 300 : content.length;
                contentSamples.add(
                    '第${i + 1}章内容样本：${content.substring(0, sampleLength)}');
              }
            }
          } catch (e) {
            _log.w('SummaryService', '获取第${i + 1}章内容样本用于语言检测失败: $e');
          }
        }
      }

      if (chapterSummaries.isEmpty) {
        _log.w('SummaryService', '没有章节摘要，无法生成全书摘要: ${book.title}');
        return;
      }

      // 生成全书摘要
      String combinedContent = chapterSummaries.join('\n\n');

      // 如果有内容样本，添加到摘要内容中用于语言检测
      if (contentSamples.isNotEmpty) {
        combinedContent +=
            '\n\n参考内容样本（用于语言识别）：\n${contentSamples.join('\n\n')}';
      }

      // 生成全书摘要（使用流式方法）
      final stream = _aiService.generateBookSummaryStream(
        title: book.title,
        author: book.author,
        chapterSummaries: combinedContent,
        totalChapters: chapters.length,
        bookId: book.id,
        language: language,
      );

      String accumulatedContent = '';

      await for (final chunk in stream) {
        accumulatedContent += chunk;
        _notifyBookStreamingContent(book.id, language, accumulatedContent);
      }

      if (accumulatedContent.isNotEmpty) {
        await saveBookSummary(book.id, accumulatedContent, language: language);
        _log.info('SummaryService', '全书摘要生成成功: ${book.title} [$language]');
      } else {
        _log.w('SummaryService', 'AI返回空的全书摘要: ${book.title}');
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '从章节摘要生成全书摘要失败: ${book.title}', e, stackTrace);
    }
  }

  // ==================== 译文管理 ====================

  /// 获取指定章节的译文
  Future<String?> getTranslation(
      String bookId, int chapterIndex, String targetLang) async {
    try {
      final filePath = await StorageConfig.getChapterTranslationPath(
          bookId, chapterIndex, targetLang);
      final content = await _fileStorage.readText(filePath);
      return content;
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'getTranslation 失败: $bookId chapter $chapterIndex to $targetLang', e, stackTrace);
      return null;
    }
  }

  /// 保存章节译文
  Future<void> saveTranslation(
      String bookId, int chapterIndex, String targetLang, String content) async {
    try {
      final filePath = await StorageConfig.getChapterTranslationPath(
          bookId, chapterIndex, targetLang);
      await _fileStorage.writeText(filePath, content);
      _log.d('SummaryService', '译文已保存: ${bookId}_${chapterIndex}_$targetLang');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'saveTranslation 失败', e, stackTrace);
    }
  }

  /// 译文生成中标记集合
  final Set<String> _generatingTranslationKeys = {};

  /// 流式生成章节译文（格式保留）
  Future<bool> generateTranslationStream({
    required String bookId,
    required int chapterIndex,
    required String content,
    String? chapterTitle,
    required String sourceLang,
    required String targetLang,
    String? bookFormat,
    Function(String)? onContentUpdate,
  }) async {
    final key = '${bookId}_${chapterIndex}_$targetLang';

    // 防止重复生成
    if (_generatingTranslationKeys.contains(key)) {
      _log.d('SummaryService', '译文生成中，跳过重复请求: $key');
      return false;
    }

    _generatingTranslationKeys.add(key);

    try {
      final translatedContent = await _aiService.translateContent(
        content,
        sourceLang: sourceLang,
        targetLang: targetLang,
        chapterTitle: chapterTitle,
        onProgress: (currentTranslation) {
          if (onContentUpdate != null) {
            onContentUpdate(currentTranslation);
          }
          _notifyTranslationContent(bookId, chapterIndex, currentTranslation);
        },
      );

      if (translatedContent.isNotEmpty) {
        await saveTranslation(bookId, chapterIndex, targetLang, translatedContent);
        _log.info('SummaryService', '译文生成成功: $key');
        return true;
      } else {
        _log.w('SummaryService', 'AI返回空译文: $key');
        return false;
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '流式生成译文失败: $key', e, stackTrace);
      return false;
    } finally {
      _generatingTranslationKeys.remove(key);
    }
  }

  /// 确保章节译文存在（加载缓存或触发生成）
  Future<String?> ensureChapterTranslation({
    required String bookId,
    required int chapterIndex,
    required String content,
    String? chapterTitle,
    required String sourceLang,
    required String targetLang,
    String? bookFormat,
  }) async {
    final existing = await getTranslation(bookId, chapterIndex, targetLang);
    if (existing != null && existing.isNotEmpty) return existing;

    await generateTranslationStream(
      bookId: bookId,
      chapterIndex: chapterIndex,
      content: content,
      chapterTitle: chapterTitle,
      sourceLang: sourceLang,
      targetLang: targetLang,
      bookFormat: bookFormat,
    );

    return await getTranslation(bookId, chapterIndex, targetLang);
  }

  // ==================== 标题提取工具方法 ====================

  /// 从摘要内容中提取章节标题
  String? extractTitleFromSummary(String summary) {
    final lines = summary.split('\n');
    if (lines.isEmpty) return null;

    final firstLine = lines[0].trim();
    // 匹配格式：## 章节标题：xxx 或 ## 章节标题:xxx
    final titlePattern = RegExp(r'^##\s*章节标题[：:]\s*(.+)$');
    final match = titlePattern.firstMatch(firstLine);

    if (match != null) {
      final title = match.group(1)?.trim() ?? '';

      // 验证标题有效性
      // 1. 不能为空
      if (title.isEmpty || title.length > 50) {
        return null;
      }

      // 2. 不能包含Markdown格式符号
      if (title.contains('#') || title.contains('**') || title.contains('*')) {
        return null;
      }

      return title;
    }

    return null;
  }

  /// 从摘要内容中移除标题行
  String removeTitleLineFromSummary(String summary) {
    final lines = summary.split('\n');
    if (lines.isEmpty) return summary;

    final firstLine = lines[0].trim();
    // 匹配格式：## 章节标题：xxx 或 ## 第X章：xxx 或 ## 前言 等章节标题格式
    final titlePattern = RegExp(r'^##\s*(章节标题[：:]\s*.+|第[一二三四五六七八九十0-9]+章[：:]\s*.+|前言|序言|引言|序|跋|后记|附录.*)$');

    if (titlePattern.hasMatch(firstLine)) {
      // 如果第二行是空行，跳过前两行
      if (lines.length > 1 && lines[1].trim().isEmpty) {
        return lines.skip(2).join('\n').trim();
      }
      // 否则只跳过第一行
      return lines.skip(1).join('\n').trim();
    }

    return summary;
  }
}
