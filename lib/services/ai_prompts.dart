import '../l10n/app_localizations.dart';

/// AI 提示词模板
///
/// 所有方法接收 [AppLocalizations] 实例，将提示词文本委托给 l10n 框架，
/// 使提示词语言与 AI 输出语言自动保持一致。
class AiPrompts {
  /// 基于前言/序言内容生成全书摘要提示词
  ///
  /// [totalChapters] 可选，传入时会在提示词中附带"章节数：N"信息。
  static String bookSummaryFromPreface({
    required AppLocalizations loc,
    required String title,
    required String author,
    required String prefaceContent,
    int? totalChapters,
  }) {
    final chaptersLine = totalChapters != null
        ? '- ${loc.promptBookChaptersLabel}$totalChapters'
        : '';
    return loc.promptPrefaceSummary(title, author, prefaceContent, chaptersLine);
  }

  /// 基于章节摘要汇总生成全书摘要提示词
  ///
  /// [totalChapters] 可选，传入时会在提示词中附带"章节数：N"信息。
  static String bookSummary({
    required AppLocalizations loc,
    required String title,
    required String author,
    required String chapterSummaries,
    int? totalChapters,
  }) {
    final chaptersLine = totalChapters != null
        ? '- ${loc.promptBookChaptersLabel}$totalChapters'
        : '';
    return loc.promptBookSummary(title, author, chapterSummaries, chaptersLine);
  }

  /// 生成章节摘要提示词
  ///
  /// [chapterTitle] 可选，传入时会作为原始章节标识供 AI 参考提取真实标题。
  static String chapterSummary({
    required AppLocalizations loc,
    String? chapterTitle,
    required String content,
  }) {
    return loc.promptChapterSummary(chapterTitle ?? '', content);
  }

  /// 生成 HTML 内容翻译提示词
  ///
  /// [chapterTitle] 可选，传入时会随 HTML 原文一起提供给 AI。
  static String translateHtml({
    required AppLocalizations loc,
    required String content,
    String? chapterTitle,
  }) {
    return loc.promptTranslateHtml(content, chapterTitle ?? '');
  }
}
