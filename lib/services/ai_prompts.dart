import '../l10n/app_localizations.dart';

/// AI 提示词模板
///
/// 所有方法接收 [AppLocalizations] 实例，将提示词文本委托给 l10n 框架，
/// 使提示词语言与 AI 输出语言自动保持一致。
class AiPrompts {
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
