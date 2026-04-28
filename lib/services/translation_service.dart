/// 翻译服务（简化版）
///
/// 负责管理文档翻译的完整流程：
/// 1. 直接翻译HTML内容（保留HTML标签）
/// 2. 流式显示（实时逐字显示翻译过程）

import '../services/log_service.dart';
import '../services/ai_service.dart';

/// 翻译服务（单例模式）
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final _log = LogService();
  final _aiService = AIService();

  // ==================== 翻译方法 ====================

  /// 翻译EPUB内容（直接翻译HTML，保留HTML标签）
  ///
  /// 参数：
  /// - [htmlContent]: EPUB章节的HTML内容
  /// - [sourceLang]: 源语言代码
  /// - [targetLang]: 目标语言代码
  /// - [chapterTitle]: 章节标题（可选）
  /// - [onProgress]: 进度回调（当前译文内容）
  ///
  /// 返回：完整的HTML格式译文
  Future<String> translateEpubContent(
    String htmlContent, {
    required String sourceLang,
    required String targetLang,
    String? chapterTitle,
    Function(String)? onProgress,
  }) async {
    _log.d('TranslationService', '开始翻译EPUB内容，HTML长度: ${htmlContent.length}');

    return _translateWithStreaming(
      htmlContent,
      sourceLang: sourceLang,
      targetLang: targetLang,
      chapterTitle: chapterTitle,
      onProgress: onProgress,
    );
  }

  /// 流式翻译（核心方法）
  ///
  /// 整章调用AI翻译，实时返回流式内容
  Future<String> _translateWithStreaming(
    String content, {
    required String sourceLang,
    required String targetLang,
    String? chapterTitle,
    Function(String)? onProgress,
  }) async {
    _log.d('TranslationService', '开始流式翻译，内容长度: ${content.length}');

    if (!_aiService.isConfigured) {
      _log.w('TranslationService', 'AI服务未配置，无法翻译');
      return '';
    }

    final buffer = StringBuffer();
    int chunkCount = 0;

    await for (final chunk in _aiService.translateHtmlStream(
      content,
      chapterTitle: chapterTitle,
      sourceLang: sourceLang,
      targetLang: targetLang,
    )) {
      buffer.write(chunk);
      chunkCount++;

      // 前3个chunk输出日志
      if (chunkCount <= 3) {
        _log.d('TranslationService', 'Chunk $chunkCount: $chunk');
      }

      // 实时回调，让UI显示流式内容
      if (onProgress != null) {
        onProgress(buffer.toString());
      }
    }

    final result = buffer.toString();
    _log.d('TranslationService', '翻译完成，译文长度: ${result.length}, chunk数: $chunkCount');
    return result;
  }
}
