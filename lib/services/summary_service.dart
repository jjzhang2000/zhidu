// 缩写服务
//
// 负责章节缩写与译文的存储、读取。

import 'dart:convert';

import '../models/chapter.dart';
import 'file_storage_service.dart';
import 'log_service.dart';
import 'ai_service.dart';
import 'storage_config.dart';

/// 章节缩写管理服务（单例模式）
///
/// 提供章节缩写与译文的读取、存储，以及译文生成。
/// 缩写与译文以文件形式存储在应用目录中。
class SummaryService {
  /// 单例实例
  static final SummaryService _instance = SummaryService._internal();

  /// 工厂构造函数，返回单例实例
  factory SummaryService() => _instance;

  /// 私有构造函数
  SummaryService._internal();

  /// AI服务，用于调用大模型生成译文
  final _aiService = AIService();

  /// 日志服务
  final _log = LogService();

  /// 文件存储服务，用于读写缩写与译文文件
  final _fileStorage = FileStorageService();

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

  // ==================== 工具方法 ====================

  /// 从 HTML 中提取纯文本
  ///
  /// 移除 HTML 标签并解码常见 HTML 实体，供内容长度判断使用。
  String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .trim();
  }

  /// 判断章节正文是否超过「一页」内容（约 2000 字节），超过才需要缩写
  bool shouldAbbreviate(String plainText) {
    return utf8.encode(plainText).length >= 2000;
  }

  // ==================== 单章节缩写操作 ====================

  /// 获取指定章节的缩写
  Future<Chapter?> getChapterAbbreviation(String bookId, int chapterIndex, {String language = 'zh'}) async {
    try {
      final filePath =
          await StorageConfig.getChapterAbbreviationPath(bookId, chapterIndex, language: language);
      final content = await _fileStorage.readText(filePath);

      if (content == null || content.isEmpty) {
        return null;
      }

      // 清理可能残留的AI思考过程标签
      final cleanContent = removeThinkingProcess(content);

      return Chapter(
        bookId: bookId,
        index: chapterIndex,
        title: '',
        location: ChapterLocation(),
        abbreviation: cleanContent,
      );
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'getChapterAbbreviation 失败', e, stackTrace);
      return null;
    }
  }

  /// 保存章节缩写
  Future<void> saveChapterAbbreviation(Chapter chapter, {String language = 'zh'}) async {
    try {
      final filePath = await StorageConfig.getChapterAbbreviationPath(
          chapter.bookId, chapter.index, language: language);
      final content = chapter.abbreviation;
      if (content != null) {
        await _fileStorage.writeText(filePath, content);
      }
      _log.d(
          'SummaryService', '章节缩写已保存: ${chapter.bookId}_${chapter.index}_$language');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'saveChapterAbbreviation 失败', e, stackTrace);
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
    );

    return await getTranslation(bookId, chapterIndex, targetLang);
  }

  /// 从内容中移除 AI 思考过程标签
  ///
  /// 支持的格式：
  /// - `<thinking>...</thinking>`
  /// - `<think>...</think>`
  /// - 以代码块或空行结尾的思考块
  String removeThinkingProcess(String content) {
    // 移除 <thinking>...</thinking> 块
    final thinkingPattern = RegExp(r'<thinking>[\s\S]*?</thinking>', multiLine: true, dotAll: true);
    content = content.replaceAll(thinkingPattern, '').trim();

    // 移除 <think>...</think> 块
    final thinkPattern = RegExp(r'<think>[\s\S]*?</think>', multiLine: true, dotAll: true);
    content = content.replaceAll(thinkPattern, '').trim();

    // 处理未闭合的 <thinking> 或 <think> 标签（直到下一个空行或代码块结束）
    final lines = content.split('\n');
    if (lines.isNotEmpty && (lines[0].trim().startsWith('<thinking') || lines[0].trim().startsWith('<think'))) {
      int startIndex = 0;
      final unclosedPattern = RegExp(r'^```\s*$|^\s*$');
      int thinkEndIndex = -1;
      for (int i = 1; i < lines.length; i++) {
        if (unclosedPattern.hasMatch(lines[i].trim())) {
          thinkEndIndex = i;
          break;
        }
      }
      if (thinkEndIndex >= 0) {
        startIndex = thinkEndIndex + 1;
        while (startIndex < lines.length && lines[startIndex].trim().isEmpty) {
          startIndex++;
        }
      }
      if (startIndex > 0 && startIndex < lines.length) {
        content = lines.skip(startIndex).join('\n').trim();
      }
    }

    return content;
  }
}
