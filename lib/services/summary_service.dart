/// 摘要服务
///
/// 负责管理章节摘要和全书摘要的生成、存储、读取和删除。
/// 支持并发控制，防止同一章节被重复生成摘要。
///
/// ## 摘要存储结构
/// - 章节摘要：存储为Markdown文件，路径为 `{bookId}/chapter-{index}.md`
/// - 全书摘要：存储为Markdown文件，路径为 `{bookId}/book-summary.md`
///
/// ## 摘要生成流程
/// 1. 用户进入书籍详情页（BookScreen）后，调用 [generateSummariesForBook] 开始生成
/// 2. 根据书籍格式选择不同的生成策略：
///    - EPUB：先生成全书摘要（基于目录），再生成章节摘要
///    - PDF：先生成章节摘要，再基于章节摘要生成全书摘要
/// 3. AI生成摘要后，提取章节标题并保存
///
/// ## 并发控制
/// 使用 [_generatingKeys] 和 [_generatingFutures] 防止同一章节被重复生成：
/// - [_generatingKeys]：记录正在生成的章节（用于快速检查）
/// - [_generatingFutures]：存储生成中的Future（用于等待完成）

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/chapter_summary.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/chapter_location.dart';
import 'file_storage_service.dart';
import 'log_service.dart';
import 'book_service.dart';
import 'ai_service.dart';
import 'parsers/format_registry.dart';
import 'storage_config.dart';
import 'translation_service.dart';

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
  /// 最大并发数设置为3，可根据需要调整
  final _concurrentRequestSemaphore = Semaphore(3);

  /// 流式内容回调映射表
  /// Key: chapter key (格式: bookId_chapterIndex)
  /// Value: 回调函数
  final Map<String, Function(String)> _streamingCallbacks = {};

  /// 全书摘要流式内容回调
  /// Key: bookId
  /// Value: 回调函数
  final Map<String, Function(String)> _bookStreamingCallbacks = {};

  /// 全书摘要生成中标记
  final Set<String> _generatingBookSummaryKeys = {};

  /// 已完成但尚未处理的章节key集合
  /// 用于防止重复处理
  final Set<String> _completedKeys = {};

  /// 注册流式内容回调
  ///
  /// 当章节开始生成摘要时，UI 可以调用此方法注册回调，
  /// 这样流式内容更新时会自动通知 UI
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [callback]：内容更新回调函数
  void registerStreamingCallback(
    String bookId,
    int chapterIndex,
    Function(String) callback,
  ) {
    final key = _key(bookId, chapterIndex);
    _streamingCallbacks[key] = callback;
    _log.d('SummaryService', '注册章节流式回调: $key');
  }

  /// 取消流式内容回调
  void unregisterStreamingCallback(String bookId, int chapterIndex) {
    final key = _key(bookId, chapterIndex);
    _streamingCallbacks.remove(key);
    _log.d('SummaryService', '取消章节流式回调: $key');
  }

  /// 触发流式内容更新
  void _notifyStreamingContent(String bookId, int chapterIndex, String content) {
    final key = _key(bookId, chapterIndex);
    final callback = _streamingCallbacks[key];
    if (callback != null) {
      callback(content);
    }
  }

  /// 注册全书摘要流式内容回调
  void registerBookStreamingCallback(String bookId, Function(String) callback) {
    _bookStreamingCallbacks[bookId] = callback;
    _generatingBookSummaryKeys.add(bookId);
    _log.d('SummaryService', '注册全书摘要流式回调: $bookId');
  }

  /// 取消全书摘要流式内容回调
  void unregisterBookStreamingCallback(String bookId) {
    _bookStreamingCallbacks.remove(bookId);
    _generatingBookSummaryKeys.remove(bookId);
    _log.d('SummaryService', '取消全书摘要流式回调: $bookId');
  }

  /// 触发全书摘要流式内容更新
  void _notifyBookStreamingContent(String bookId, String content) {
    final callback = _bookStreamingCallbacks[bookId];
    if (callback != null) {
      callback(content);
    }
  }

  /// 检查全书摘要是否正在生成
  bool isGeneratingBookSummary(String bookId) {
    return _generatingBookSummaryKeys.contains(bookId);
  }

  // ==================== 并发控制相关 ====================

  /// 正在生成摘要的章节标识集合
  ///
  /// 用于快速判断某个章节是否正在生成摘要。
  /// Key格式：`{bookId}_{chapterIndex}`
  ///
  /// 示例：
  /// ```dart
  /// // bookId为"abc123"，章节索引为5
  /// _generatingKeys.contains("abc123_5") // true表示正在生成
  /// ```
  final Set<String> _generatingKeys = {};

  /// 正在生成摘要的Future映射表
  ///
  /// 存储每个章节生成任务的Future对象。
  /// 当其他地方调用同一个章节的生成时，可以复用这个Future，
  /// 避免重复调用AI接口。
  ///
  /// Key格式：`{bookId}_{chapterIndex}`
  final Map<String, Future<void>> _generatingFutures = {};

  /// 生成章节的唯一标识键
  ///
  /// 将书籍ID和章节索引组合成唯一键，用于并发控制。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引（从0开始）
  ///
  /// 返回：格式为 `{bookId}_{chapterIndex}` 的字符串
  String _key(String bookId, int chapterIndex) => '${bookId}_$chapterIndex';

  /// 检查指定章节是否正在生成摘要
  ///
  /// 用于UI层显示加载状态，防止用户重复点击。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  ///
  /// 返回：`true` 表示正在生成，`false` 表示未生成
  bool isGenerating(String bookId, int chapterIndex) {
    return _generatingKeys.contains(_key(bookId, chapterIndex));
  }

  /// 获取正在生成的Future对象
  ///
  /// 用于等待正在进行的生成任务完成。
  /// 当用户点击同一个章节时，可以复用已有的生成任务。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  ///
  /// 返回：正在生成的Future，如果没有则返回null
  Future<void>? getGeneratingFuture(String bookId, int chapterIndex) {
    return _generatingFutures[_key(bookId, chapterIndex)];
  }

  // ==================== 初始化 ====================

  /// 初始化服务
  ///
  /// 文件存储模式下无需初始化，仅打印日志。
  Future<void> init() async {
    _log.d('SummaryService', '文件存储模式，无需初始化');
  }

  // ==================== 单章节摘要操作 ====================

  /// 获取指定章节的摘要
  ///
  /// 从文件系统读取摘要内容，返回ChapterSummary对象。
  /// 如果摘要不存在或读取失败，返回null。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  ///
  /// 返回：章节摘要对象，不存在则返回null
  ///
  /// 文件路径：`{应用目录}/books/{bookId}/chapter-{index}.md`
  Future<ChapterSummary?> getSummary(String bookId, int chapterIndex, {String language = 'zh'}) async {
    _log.v('SummaryService',
        'getSummary 开始执行, bookId: $bookId, chapterIndex: $chapterIndex, language: $language');

    try {
      final filePath =
          await StorageConfig.getChapterSummaryPath(bookId, chapterIndex, language: language);
      final content = await _fileStorage.readText(filePath);

      if (content == null || content.isEmpty) {
        _log.v('SummaryService', 'getSummary 加载完成, result: 空');
        return null;
      }

      final summary = ChapterSummary(
        bookId: bookId,
        chapterIndex: chapterIndex,
        chapterTitle: '', // 章节标题在读取时会从章节列表获取
        objectiveSummary: content,
        aiInsight: '',
        keyPoints: [],
        createdAt: DateTime.now(),
      );

      _log.v('SummaryService', 'getSummary 加载完成, result: 有内容');
      return summary;
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'getSummary 失败', e, stackTrace);
      return null;
    }
  }

  /// 保存章节摘要
  ///
  /// 将摘要内容写入Markdown文件。
  /// 只保存objectiveSummary字段（客观摘要内容）。
  ///
  /// 参数：
  /// - [summary]：要保存的章节摘要对象
  ///
  /// 文件路径：`{应用目录}/books/{bookId}/chapter-{index}.md`
  Future<void> saveSummary(ChapterSummary summary, {String language = 'zh'}) async {
    try {
      final filePath = await StorageConfig.getChapterSummaryPath(
          summary.bookId, summary.chapterIndex, language: language);
      await _fileStorage.writeText(filePath, summary.objectiveSummary);
      _log.d(
          'SummaryService', '摘要已保存: ${summary.bookId}_${summary.chapterIndex}_$language');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'saveSummary 失败', e, stackTrace);
    }
  }

  /// 删除指定章节的摘要
  ///
  /// 从文件系统删除摘要文件。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [language]：语言代码（如 'zh', 'en', 'ja'），默认为 'zh'
  Future<void> deleteSummary(String bookId, int chapterIndex, {String language = 'zh'}) async {
    try {
      final filePath =
          await StorageConfig.getChapterSummaryPath(bookId, chapterIndex, language: language);
      await _fileStorage.deleteFile(filePath);
      _log.d('SummaryService', '摘要已删除: ${bookId}_${chapterIndex}_$language');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'deleteSummary 失败', e, stackTrace);
    }
  }

  // ==================== 批量摘要操作 ====================

  /// 获取指定书籍的所有章节摘要
  ///
  /// 遍历书籍目录下的所有章节摘要文件，返回摘要列表。
  /// 结果按章节索引排序。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  ///
  /// 返回：章节摘要列表，按章节索引升序排列
  ///
  /// 文件匹配规则：`Summary-*.md`（如Summary-000-zh.md, Summary-001-en.md）
  Future<List<ChapterSummary>> getSummariesForBook(String bookId) async {
    try {
      final bookDir = await StorageConfig.getBookDirectory(bookId);
      final files =
          await _fileStorage.listFiles(bookDir.path, extension: '.md');

      final summaries = <ChapterSummary>[];

      for (final file in files) {
        final filename = p.basename(file.path);
        if (filename.startsWith('Summary-') && filename.endsWith('.md')) {
          final indexStr = filename.substring(8, 11);
          final index = int.tryParse(indexStr);
          if (index != null) {
            final content = await _fileStorage.readText(file.path);
            if (content != null && content.isNotEmpty) {
              final lastModified = await file.lastModified();
              summaries.add(ChapterSummary(
                bookId: bookId,
                chapterIndex: index,
                chapterTitle: '',
                objectiveSummary: content,
                aiInsight: '',
                keyPoints: [],
                createdAt: lastModified,
              ));
            }
          }
        }
      }

      // 按章节索引排序
      summaries.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
      return summaries;
    } catch (e, stackTrace) {
      _log.e(
          'SummaryService', 'getSummariesForBook 失败: $bookId', e, stackTrace);
      return [];
    }
  }

  // ==================== 全书摘要操作 ====================

  /// 获取全书摘要
  ///
  /// 从文件读取全书摘要内容。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  ///
  /// 返回：全书摘要文本，不存在则返回null
  ///
  /// 文件路径：`{应用目录}/books/{bookId}/book-summary.md`
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
  /// 将全书摘要写入文件，并同步更新书籍元数据中的aiIntroduction字段。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [summary]：全书摘要文本
  /// - [language]：语言代码（如 'zh', 'en', 'ja'），默认为 'zh'
  ///
  /// 副作用：更新BookService中对应书籍的aiIntroduction字段
  Future<void> saveBookSummary(String bookId, String summary, {String language = 'zh'}) async {
    try {
      final filePath = await StorageConfig.getBookSummaryPath(bookId, language: language);
      await _fileStorage.writeText(filePath, summary);
      _log.d('SummaryService', '书籍摘要已保存: $bookId, language: $language');

      // 同时更新书籍元数据中的aiIntroduction
      final book = _bookService.getBookById(bookId);
      if (book != null) {
        final updatedBook = book.copyWith(aiIntroduction: summary);
        await _bookService.updateBook(updatedBook);
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'saveBookSummary 失败: $bookId', e, stackTrace);
    }
  }

  // ==================== 摘要生成 ====================

  /// 生成单个章节的摘要（带并发控制）
  ///
  /// 这是生成章节摘要的核心方法，实现了并发控制机制：
  /// 1. 检查是否正在生成，如果是则返回false（拒绝重复请求）
  /// 2. 将章节标识加入[_generatingKeys]标记为"生成中"
  /// 3. 创建Completer并存入[_generatingFutures]，允许其他调用者等待
  /// 4. 调用AI流式生成摘要（内部使用流式方法以支持实时回调）
  /// 5. 实时更新内容到回调函数（如果提供）
  /// 6. 提取章节标题并更新书籍元数据
  /// 7. 保存摘要内容
  /// 8. 清理并发控制标记
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [chapterTitle]：章节原标题（用于AI提示词）
  /// - [content]：章节正文内容
  /// - [onContentUpdate]：内容更新回调函数（可选，用于实时反馈）
  ///
  /// 返回：`true` 表示生成成功，`false` 表示失败或重复请求
  ///
  /// ## 并发控制流程图
  /// ```
  /// 用户点击生成
  ///     ↓
  /// isGenerating检查 → 正在生成 → 返回false
  ///     ↓ 未生成
  /// 加入_generatingKeys
  ///     ↓
  /// 创建Completer并加入_generatingFutures
  ///     ↓
  /// 调用AI流式生成摘要（内部实现）
  ///     ↓
  /// 实时更新内容 → onContentUpdate回调（如果有）
  ///     ↓
  /// 提取标题 → 更新章节标题
  ///     ↓
  /// 保存摘要文件
  ///     ↓
  /// complete()完成Completer
  ///     ↓
  /// 从_generatingKeys和_generatingFutures移除
  /// ```
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

    // 创建Completer用于其他调用者等待
    final completer = Completer<void>();
    _generatingFutures[key] = completer.future;

    try {
      _log.d('SummaryService', '开始生成摘要: $key, language: $language');

      // 调用AI流式生成摘要（内部使用流式方法）
      final stream = _aiService.generateFullChapterSummaryStream(
        content,
        chapterTitle: chapterTitle,
        bookId: bookId,
      );

      String accumulatedContent = '';

      await for (final chunk in stream) {
        accumulatedContent += chunk;

        // 触发流式内容更新（同时调用回调和广播）
        if (onContentUpdate != null) {
          onContentUpdate(accumulatedContent);
        }
        _notifyStreamingContent(bookId, chapterIndex, accumulatedContent);
      }

      // 生成完成，处理最终内容
      if (accumulatedContent.isNotEmpty) {
        // 提取AI返回的章节标题
        final extractedTitle = extractTitleFromSummary(accumulatedContent);
        final cleanSummary = removeTitleLineFromSummary(accumulatedContent);

        // 如果提取到有效标题，更新书籍元数据
        if (extractedTitle != null && extractedTitle.isNotEmpty) {
          await _bookService.updateChapterTitle(
              bookId, chapterIndex, extractedTitle);
          _log.d('SummaryService', '提取并更新章节标题: $extractedTitle');
        }

        // 构建并保存摘要对象
        final chapterSummary = ChapterSummary(
          bookId: bookId,
          chapterIndex: chapterIndex,
          chapterTitle: extractedTitle ?? chapterTitle,
          objectiveSummary: cleanSummary,
          aiInsight: '',
          keyPoints: [],
          createdAt: DateTime.now(),
        );

        await saveSummary(chapterSummary, language: language);
        _log.info('SummaryService', '摘要生成成功: $key, language: $language');
        completer.complete();
        return true;
      } else {
        _log.w('SummaryService', 'AI返回空摘要: $key');
        completer.complete(); // 空摘要时不视为错误
        return false;
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '生成摘要失败: $key', e, stackTrace);
      completer.completeError(e);
      return false;
    } finally {
      // 清理并发控制标记
      _generatingKeys.remove(key);
      _generatingFutures.remove(key);
      // 释放并发AI请求许可
      _concurrentRequestSemaphore.release();
    }
  }

  /// 生成单个章节的摘要（流式，带并发控制）
  ///
  /// 这是生成章节摘要的流式方法，实现了实时反馈机制：
  /// 1. 检查是否正在生成，如果是则返回false（拒绝重复请求）
  /// 2. 将章节标识加入[_generatingKeys]标记为"生成中"
  /// 3. 创建Completer并存入[_generatingFutures]，允许其他调用者等待
  /// 4. 调用AI流式生成摘要
  /// 5. 实时更新内容到回调函数
  /// 6. 提取章节标题并更新书籍元数据
  /// 7. 保存摘要内容
  /// 8. 清理并发控制标记
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [chapterTitle]：章节原标题（用于AI提示词）
  /// - [content]：章节正文内容
  /// - [onContentUpdate]：内容更新回调函数（实时反馈用）
  ///
  /// 返回：`true` 表示生成成功，`false` 表示失败或重复请求
  ///
  /// ## 流式生成流程图
  /// ```
  /// 用户点击生成
  ///     ↓
  /// isGenerating检查 → 正在生成 → 返回false
  ///     ↓ 未生成
  /// 加入_generatingKeys
  ///     ↓
  /// 创建Completer并加入_generatingFutures
  ///     ↓
  /// 调用AI流式生成摘要
  ///     ↓
  /// 实时更新内容 → onContentUpdate回调
  ///     ↓
  /// 提取标题 → 更新章节标题
  ///     ↓
  /// 保存摘要文件
  ///     ↓
  /// complete()完成Completer
  ///     ↓
  /// 从_generatingKeys和_generatingFutures移除
  /// ```
  Future<bool> generateSingleSummaryStream(
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

    // 创建Completer用于其他调用者等待
    final completer = Completer<void>();
    _generatingFutures[key] = completer.future;

    try {
      _log.d('SummaryService', '开始流式生成摘要: $key, language: $language');

      // 调用AI流式生成摘要
      final stream = _aiService.generateFullChapterSummaryStream(
        content,
        chapterTitle: chapterTitle,
        bookId: bookId,
      );

      String accumulatedContent = '';

      await for (final chunk in stream) {
        accumulatedContent += chunk;

        // 立即通过回调函数更新内容，让UI层处理频率控制
        if (onContentUpdate != null) {
          onContentUpdate(accumulatedContent);
        }
      }

      // 生成完成，处理最终内容
      if (accumulatedContent.isNotEmpty) {
        // 提取AI返回的章节标题
        final extractedTitle = extractTitleFromSummary(accumulatedContent);
        final cleanSummary = removeTitleLineFromSummary(accumulatedContent);

        // 如果提取到有效标题，更新书籍元数据
        if (extractedTitle != null && extractedTitle.isNotEmpty) {
          await _bookService.updateChapterTitle(
              bookId, chapterIndex, extractedTitle);
          _log.d('SummaryService', '提取并更新章节标题: $extractedTitle');
        }

        // 构建并保存摘要对象
        final chapterSummary = ChapterSummary(
          bookId: bookId,
          chapterIndex: chapterIndex,
          chapterTitle: extractedTitle ?? chapterTitle,
          objectiveSummary: cleanSummary,
          aiInsight: '',
          keyPoints: [],
          createdAt: DateTime.now(),
        );

        await saveSummary(chapterSummary, language: language);
        _log.info('SummaryService', '流式摘要生成成功: $key, language: $language');
        completer.complete();
        return true;
      } else {
        _log.w('SummaryService', 'AI返回空摘要: $key');
        completer.complete(); // 空摘要时不视为错误
        return false;
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '流式生成摘要失败: $key', e, stackTrace);
      completer.completeError(e);
      return false;
    } finally {
      // 清理并发控制标记
      _generatingKeys.remove(key);
      _generatingFutures.remove(key);
      // 释放并发AI请求许可
      _concurrentRequestSemaphore.release();
    }
  }

  /// 为整本书生成摘要（主入口）
  ///
  /// 根据书籍格式选择不同的生成策略：
  /// - **EPUB格式**：有完整的目录结构，先生成全书摘要（基于目录），
  ///   再生成各章节摘要
  /// - **PDF格式**：通常没有目录结构，先生成章节摘要，
  ///   再基于章节摘要生成全书摘要
  ///
  /// 参数：
  /// - [book]：书籍对象
  ///
  /// ## 生成流程图
  /// ```
  /// EPUB格式：
  ///   解析EPUB → 获取章节列表 → 生成全书摘要(基于目录) → 生成章节摘要
  ///
  /// PDF格式：
  ///   解析PDF → 获取章节列表 → 生成章节摘要 → 生成全书摘要(基于章节摘要)
  /// ```
  Future<void> generateSummariesForBook(Book book) async {
    _log.d('SummaryService', '开始为书籍生成摘要: ${book.title}');

    try {
      // 使用FormatRegistry获取解析器
      final extension = book.format == BookFormat.epub ? '.epub' : '.pdf';
      final parser = FormatRegistry.getParser(extension);

      if (parser == null) {
        _log.w('SummaryService', '不支持的格式: ${book.format}');
        return;
      }

      // 获取章节列表
      final chapters = await parser.getChapters(book.filePath);
      _log.d('SummaryService', '获取到 ${chapters.length} 个章节');

      if (book.format == BookFormat.epub) {
        // EPUB文件：先生成全书摘要，再生成章节摘要
        _log.d('SummaryService', 'EPUB格式：先生成全书摘要');
        await _generateBookSummaryFromPreface(book, chapters, parser);

        // 再生成章节摘要
        await _generateChapterSummaries(book, chapters, parser);
      } else {
        // PDF文件：先生成章节摘要，再用章节摘要生成全书摘要
        _log.d('SummaryService', 'PDF格式：先生成章节摘要');
        await _generateChapterSummaries(book, chapters, parser);

        // 最后用章节摘要生成全书摘要
        await _generateBookSummaryFromChapters(book, chapters);
      }

      _log.info('SummaryService', '书籍摘要生成完成: ${book.title}');
    } catch (e, stackTrace) {
      _log.e('SummaryService', '生成书籍摘要失败: ${book.title}', e, stackTrace);
    }
  }

  /// 生成章节摘要（只为顶层章节生成）
  ///
  /// 并发处理所有顶层章节（level==0），为每个章节：
  /// 1. 检查是否已有摘要，有则跳过
  /// 2. 获取章节内容
  /// 3. 调用[generateSingleSummary]生成摘要
  ///
  /// 参数：
  /// - [book]：书籍对象
  /// - [chapters]：章节列表
  /// - [parser]：文件解析器（EPUB或PDF）
  ///
  /// 注意：只为顶层章节生成摘要，子章节（level>0）不单独生成
  /// 并发控制：最多3个并发任务同时进行AI摘要生成
  Future<void> _generateChapterSummaries(
    Book book,
    List<Chapter> chapters,
    dynamic parser,
  ) async {
    // 只为顶层章节（level==0）生成摘要
    final topLevelChapters = chapters.where((c) => c.level == 0).toList();
    _log.d('SummaryService', '开始生成章节摘要: 顶层章节 ${topLevelChapters.length} 章');

    // 创建一个队列来管理并发任务
    final futures = <Future<void>>[];
    final semaphore = Semaphore(3); // 最多3个并发任务

    for (final chapter in topLevelChapters) {
      // chapter.index 是专门为顶层章节计算的索引
      final chapterIndex = chapter.index;
      if (chapterIndex < 0) continue; // 跳过无效index

      // 跳过已有摘要的章节
      final existingSummary = await getSummary(book.id, chapterIndex, language: 'zh');
      if (existingSummary != null) {
        _log.d('SummaryService', '章节 $chapterIndex 已有摘要，跳过');
        continue;
      }

      // 创建并发任务
      final future = _processChapterConcurrently(
        book,
        chapter,
        chapterIndex,
        parser,
        semaphore,
      );

      futures.add(future);
    }

    // 等待所有任务完成
    await Future.wait(futures);
    _log.d('SummaryService', '所有章节摘要生成完成');
  }

  /// 并发处理单个章节摘要生成
  ///
  /// 使用信号量控制并发数，确保最多只有3个AI请求同时进行
  Future<void> _processChapterConcurrently(
    Book book,
    Chapter chapter,
    int chapterIndex,
    dynamic parser,
    Semaphore semaphore,
  ) async {
    // 等待信号量许可
    await semaphore.acquire();

    try {
      // 获取章节内容并生成摘要
      final content = await parser.getChapterContent(book.filePath, chapter);
      final chapterContent = content.htmlContent;

      if (chapterContent != null && chapterContent.isNotEmpty) {
        await generateSingleSummary(
          book.id,
          chapterIndex,
          chapter.title,
          chapterContent,
          language: 'zh',
        );
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '处理章节 $chapterIndex 时出错', e, stackTrace);
    } finally {
      // 释放信号量许可
      semaphore.release();
    }
  }

  /// 从前言/目录生成全书摘要（用于EPUB等有目录结构的文件）
  ///
  /// EPUB文件通常有完整的目录结构，可以基于目录信息生成全书摘要。
  /// 收集前20章的标题，调用AI生成全书概览。
  ///
  /// 参数：
  /// - [book]：书籍对象
  /// - [chapters]：章节列表
  /// - [parser]：文件解析器
  ///
  /// 生成内容示例：
  /// ```
  /// 本书目录结构：
  ///
  /// 第1章：引言
  /// 第2章：基础概念
  /// ...
  /// 第20章：进阶应用
  /// ... 等共 50 章
  /// ```
  Future<void> _generateBookSummaryFromPreface(
    Book book,
    List<Chapter> chapters,
    dynamic parser,
  ) async {
    _log.d('SummaryService', '从前言/目录生成全书摘要: ${book.title}');

    try {
      // 检查是否已有全书摘要
      final existingSummary = await getBookSummary(book.id);
      if (existingSummary != null && existingSummary.isNotEmpty) {
        _log.d('SummaryService', '已有全书摘要，跳过: ${book.title}');
        return;
      }

      // 收集目录信息和少量实际内容用于语言检测
      final prefaceContent = StringBuffer();
      prefaceContent.writeln('本书目录结构：\n');

      for (int i = 0; i < chapters.length && i < 20; i++) {
        prefaceContent.writeln('第${i + 1}章：${chapters[i].title}');
      }

      if (chapters.length > 20) {
        prefaceContent.writeln('... 等共 ${chapters.length} 章');
      }

      // 添加少量实际内容用于语言检测
      if (chapters.isNotEmpty) {
        try {
          // 获取第一章的部分内容用于语言检测
          final firstChapter = chapters[0];
          final chapterContent =
              await parser.getChapterContent(book.filePath, firstChapter);
          final contentSample = chapterContent.htmlContent;

          if (contentSample != null && contentSample.isNotEmpty) {
            // 取取前500个字符作为语言检测样本
            final sampleLength =
                contentSample.length > 500 ? 500 : contentSample.length;
            prefaceContent.writeln(
                '\n\n第一章内容样本（用于语言识别）：\n${contentSample.substring(0, sampleLength)}');
          }
        } catch (e) {
          _log.w('SummaryService', '获取第一章内容用于语言检测失败: $e');
          // 如果获取内容失败，使用原方法继续
        }
      }

      // 生成全书摘要（使用流式方法）
      final stream = _aiService.generateBookSummaryFromPrefaceStream(
        title: book.title,
        author: book.author,
        prefaceContent: prefaceContent.toString(),
        totalChapters: chapters.length,
        bookId: book.id,
      );

      String accumulatedContent = '';

      await for (final chunk in stream) {
        accumulatedContent += chunk;
        // 触发流式内容更新
        _notifyBookStreamingContent(book.id, accumulatedContent);
      }

      if (accumulatedContent.isNotEmpty) {
        await saveBookSummary(book.id, accumulatedContent, language: 'zh');
        _log.info('SummaryService', '全书摘要生成成功: ${book.title}');
      } else {
        _log.w('SummaryService', 'AI返回空的全书摘要: ${book.title}');
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '从前言生成全书摘要失败: ${book.title}', e, stackTrace);
    }
  }

  /// 从章节摘要生成全书摘要（用于PDF等无目录结构的文件）
  ///
  /// PDF文件通常没有结构化的目录，需要先读取各章节摘要，
  /// 再基于章节摘要内容生成全书概览。
  /// 最多使用前10章的摘要（每章截取前200字）。
  ///
  /// 参数：
  /// - [book]：书籍对象
  /// - [chapters]：章节列表
  ///
  /// 生成内容示例：
  /// ```
  /// 第1章：本章介绍了...（摘要前200字）...
  ///
  /// 第2章：本章讨论了...（摘要前200字）...
  /// ...
  /// ```
  Future<void> _generateBookSummaryFromChapters(
    Book book,
    List<Chapter> chapters,
  ) async {
    _log.d('SummaryService', '从章节摘要生成全书摘要: ${book.title}');

    try {
      // 检查是否已有全书摘要
      final existingSummary = await getBookSummary(book.id);
      if (existingSummary != null && existingSummary.isNotEmpty) {
        _log.d('SummaryService', '已有全书摘要，跳过: ${book.title}');
        return;
      }

      // 收集所有章节摘要和少量实际内容用于语言检测
      final chapterSummaries = <String>[];
      final contentSamples = <String>[];

      for (int i = 0; i < chapters.length && i < 10; i++) {
        final summary = await getSummary(book.id, i, language: 'zh');
        if (summary != null && summary.objectiveSummary.isNotEmpty) {
          // 截取前200字避免内容过长
          final shortSummary = summary.objectiveSummary.length > 200
              ? summary.objectiveSummary.substring(0, 200)
              : summary.objectiveSummary;
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
      );

      String accumulatedContent = '';

      await for (final chunk in stream) {
        accumulatedContent += chunk;
        // 触发流式内容更新
        _notifyBookStreamingContent(book.id, accumulatedContent);
      }

      if (accumulatedContent.isNotEmpty) {
        await saveBookSummary(book.id, accumulatedContent, language: 'zh');
        _log.info('SummaryService', '全书摘要生成成功: ${book.title}');
      } else {
        _log.w('SummaryService', 'AI返回空的全书摘要: ${book.title}');
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '从章节摘要生成全书摘要失败: ${book.title}', e, stackTrace);
    }
  }

  // ==================== 导出相关 ====================

  /// 获取所有书籍的所有摘要（用于导出）
  ///
  /// 遍历应用目录下的所有书籍目录，收集所有章节摘要。
  ///
  /// 返回：所有章节摘要的列表
  Future<List<ChapterSummary>> getAllSummaries() async {
    final allSummaries = <ChapterSummary>[];

    // 遍历所有书籍目录获取摘要
    final appDir = await StorageConfig.getAppDirectory();
    final booksDir = Directory('${appDir.path}/books');

    if (!await booksDir.exists()) {
      return [];
    }

    final bookDirs = await booksDir
        .list()
        .where((e) => e is Directory)
        .cast<Directory>()
        .toList();

    for (final bookDir in bookDirs) {
      final bookId = p.basename(bookDir.path);
      final summaries = await getSummariesForBook(bookId);
      allSummaries.addAll(summaries);
    }

    return allSummaries;
  }

  /// 删除书籍的所有摘要
  ///
  /// 注意：在文件存储模式下，BookService.deleteBook 已经删除了整个书籍目录，
  /// 所以这个方法实际上不需要执行任何操作。
  /// 保留此方法是为了兼容旧代码接口。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  Future<void> deleteAllSummariesForBook(String bookId) async {
    _log.d('SummaryService', '删除书籍所有摘要: $bookId');
    // 文件存储模式下，书籍目录的删除由BookService处理
    // 这里可以保留为兼容旧代码的接口
  }

  // ==================== 标题提取工具方法 ====================

  // ==================== 译文管理 ====================

  /// 获取指定章节的译文
  ///
  /// 从文件系统读取译文内容，返回译文字符串。
  /// 如果译文不存在或读取失败，返回null。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [targetLang]：目标语言代码（如 'en', 'zh', 'ja'）
  ///
  /// 返回：译文内容，不存在则返回null
  ///
  /// 文件路径：`{应用目录}/books/{bookId}/chapter-{index}-{targetLang}.md`
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
  ///
  /// 将译文内容写入Markdown文件。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [targetLang]：目标语言代码
  /// - [content]：译文内容
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

  /// 删除指定章节的译文
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [targetLang]：目标语言代码
  Future<void> deleteTranslation(
      String bookId, int chapterIndex, String targetLang) async {
    try {
      final filePath = await StorageConfig.getChapterTranslationPath(
          bookId, chapterIndex, targetLang);
      await _fileStorage.deleteFile(filePath);
      _log.d('SummaryService', '译文已删除: ${bookId}_${chapterIndex}_$targetLang');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'deleteTranslation 失败', e, stackTrace);
    }
  }

  /// 译文生成中标记集合
  final Set<String> _generatingTranslationKeys = {};

  /// 检查指定译文是否正在生成
  bool isTranslationGenerating(String bookId, int chapterIndex, String targetLang) {
    return _generatingTranslationKeys.contains('${bookId}_${chapterIndex}_$targetLang');
  }

  /// 流式生成章节译文（格式保留）
  ///
  /// 使用TranslationService进行格式保留的分段翻译：
  /// 1. 解析文档结构（EPUB/PDF）
  /// 2. 分段翻译，保留格式信息
  /// 3. 重组译文，还原原始结构
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [content]：章节正文内容（HTML或纯文本）
  /// - [chapterTitle]：章节标题
  /// - [sourceLang]：源语言代码
  /// - [targetLang]：目标语言代码
  /// - [bookFormat]：书籍格式（'epub' 或 'pdf'），用于选择对应的解析器
  /// - [onContentUpdate]：内容更新回调函数（用于流式显示）
  ///
  /// 返回：`true` 表示生成成功，`false` 表示失败
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
      _log.d('SummaryService', '开始流式生成译文（格式保留）: $key, format: $bookFormat');

      // 使用TranslationService进行格式保留翻译
      final translationService = TranslationService();
      String translatedContent;

      // 根据书籍格式选择对应的解析器
      if (bookFormat == 'epub') {
        // EPUB格式：直接翻译HTML
        translatedContent = await translationService.translateEpubContent(
          content,
          sourceLang: sourceLang,
          targetLang: targetLang,
          chapterTitle: chapterTitle,
          onProgress: (currentTranslation) {
            if (onContentUpdate != null) {
              onContentUpdate(currentTranslation);
            }
          },
        );
      } else {
        // PDF格式：PdfParser将纯文本包裹为<p>...</p>，直接翻译HTML
        translatedContent = await translationService.translateEpubContent(
          content,
          sourceLang: sourceLang,
          targetLang: targetLang,
          chapterTitle: chapterTitle,
          onProgress: (currentTranslation) {
            if (onContentUpdate != null) {
              onContentUpdate(currentTranslation);
            }
          },
        );
      }

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

  // ==================== 标题提取工具方法 ====================

  /// 从摘要内容中提取章节标题
  ///
  /// AI生成的摘要可能包含格式化的标题行，例如：
  /// ```
  /// ## 章节标题：真正的章节名
  ///
  /// 这是摘要正文...
  /// ```
  ///
  /// 此方法提取第一行中的标题文本。
  ///
  /// ## 提取规则
  /// 1. 检查第一行是否匹配模式 `## 章节标题[:：](.+)$`
  /// 2. 提取冒号后的标题文本
  /// 3. 验证标题有效性：
  ///    - 不能为空
  ///    - 长度不能超过50字符
  ///    - 不能包含Markdown格式符号（#、**、*）
  ///
  /// 参数：
  /// - [summary]：AI生成的摘要文本
  ///
  /// 返回：提取的标题文本，如果无效则返回null
  ///
  /// 示例：
  /// ```dart
  /// extractTitleFromSummary('## 章节标题：设计模式概述\n\n本章介绍...')
  /// // 返回: '设计模式概述'
  ///
  /// extractTitleFromSummary('## 章节标题：这是一个**很长**的标题包含格式')
  /// // 返回: null (包含格式符号)
  /// ```
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
  ///
  /// 当AI返回的摘要包含格式化的标题行时，需要将其移除后再保存，
  /// 因为章节标题应该从书籍元数据中获取，而不是存储在摘要文本中。
  ///
  /// ## 移除规则
  /// 1. 如果第一行匹配标题模式（## 章节标题：xxx 或 ## 第X章：xxx），移除第一行
  /// 2. 如果第二行是空行，也一并移除
  /// 3. 如果第一行不匹配，返回原文本
  ///
  /// 参数：
  /// - [summary]：原始摘要文本
  ///
  /// 返回：移除标题行后的摘要文本
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
