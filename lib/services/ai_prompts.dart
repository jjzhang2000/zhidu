import '../l10n/app_localizations.dart';

/// AI提示词模板类
class AiPrompts {
  static String getLanguageInstruction(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'IMPORTANT: Respond in English.';
      case 'ja':
        return 'IMPORTANT: Respond in Japanese (日本語).';
      case 'zh':
      default:
        return 'IMPORTANT: Respond in Chinese (简体中文).';
    }
  }

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

  static String chapterSummary({
    required AppLocalizations loc,
    String? chapterTitle,
    required String content,
  }) {
    return loc.promptChapterSummary(chapterTitle ?? '', content);
  }

  static String translateHtml({
    required String content,
    required String sourceLang,
    required String targetLang,
    String? chapterTitle,
  }) {
    final t = _langName(targetLang);

    if (targetLang == 'ja') {
      return '''以下のHTMLコンテンツを **$t** に翻訳してください。

${chapterTitle != '' ? '章タイトル：$chapterTitle\n' : ''}HTML原文：
$content

**重要：翻訳ルール**
1. **すべてのテキストを $t に統一して翻訳**
2. **すべてのHTMLタグを厳密に保持**：タグ名、属性、ネスト関係、順序を完全に変更しないこと
3. **タグ内のプレーンテキストのみを翻訳**し、タグ名、属性値、URL、コード内容は翻訳しないこと
4. 技術用語は原文のまま保持可能
5. **コードブロック（`<code>` または `<pre>` タグ内の内容）は一切翻訳せず、エスケープ処理も行わないこと**
6. **`<code>` と `<pre>` 内の内容はそのまま出力し、バックスラッシュを追加・削除しないこと**
7. **入力に `%%ZHIDU_CODE_BLOCK_N%%`（Nは数字）というプレースホルダーが含まれる場合があります。これはコードブロックのマーカーです。そのまま保持し、翻訳・解釈・変更しないでください**
8. 説明、注釈、追加コンテンツを一切追加しないこと
9. 翻訳後のHTMLのみを直接出力すること
''';
    }

    if (targetLang == 'zh') {
      return '''请将以下 HTML 内容翻译为 **$t**。

${chapterTitle != '' ? '章节标题：$chapterTitle\n' : ''}HTML原文：
$content

**重要：翻译规则**
1. **所有文本必须统一翻译为 $t**，无论原文是哪种语言，输出中只允许出现 $t
2. **严格保留所有 HTML 标签**：标签的名称、属性、嵌套关系、顺序完全不变
3. **只翻译标签内的纯文本**，不翻译标签名、属性值、URL、代码内容
4. 技术术语可以保留原文
5. **代码块（`<code>` 或 `<pre>` 标签内的内容）完全不需要翻译，也不要进行任何转义处理**
6. **对于 `<code>` 和 `<pre>` 中的内容，原样输出，不要添加或移除任何反斜杠**
7. **输入中可能包含占位符 `%%ZHIDU_CODE_BLOCK_N%%`（N为数字），这些是代码块的标记，原样保留即可，不要翻译、解释或修改**
8. 不要添加任何解释、注释或额外内容
9. 直接输出翻译后的 HTML
''';
    }

    return '''Please translate the following HTML content to **$t**.

${chapterTitle != '' ? 'Chapter title: $chapterTitle\n' : ''}HTML source:
$content

**IMPORTANT: Translation Rules**
1. **ALL text must be translated to $t**, regardless of the source language. The output should contain ONLY $t text (except for technical terms)
2. **Strictly preserve ALL HTML tags**: tag names, attributes, nesting, and order must remain completely unchanged
3. **Only translate the text content inside tags**, do not translate tag names, attribute values, URLs, or code
4. Technical terms can remain in original
5. **Code blocks (content inside `<code>` or `<pre>` tags) should NOT be translated at all, and do NOT perform any escape processing**
6. **For content in `<code>` and `<pre>`, output exactly as-is, do NOT add or remove any backslashes**
7. **The input may contain placeholders `%%ZHIDU_CODE_BLOCK_N%%` (where N is a number), these are markers for code blocks - keep them as-is, do NOT translate, interpret, or modify them**
8. Do NOT add any explanations, notes, or extra content
9. Output ONLY the translated HTML
''';
  }

  static String _langName(String code) {
    switch (code) {
      case 'zh':
        return '中文';
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      default:
        return code;
    }
  }
}
