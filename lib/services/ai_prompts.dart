/// AI提示词模板类
///
/// 提供用于AI服务的提示词模板，支持书籍摘要和章节摘要的生成。
/// 所有方法均为静态方法，直接通过类名调用。
///
/// 使用示例：
/// ```dart
/// final prompt = AiPrompts.chapterSummary(
///   chapterTitle: '第1章',
///   content: chapterContent,
///   languageInstruction: AiPrompts.getLanguageInstruction('manual', 'zh'),
/// );
/// ```
class AiPrompts {
  /// 获取语言指令
  ///
  /// 根据语言输出模式生成相应的语言指令，用于控制AI输出语言。
  ///
  /// 参数：
  /// - [mode]: 语言模式，可选值：
  ///   - 'auto_book': 根据书籍内容的语言输出
  ///   - 'system': 根据系统语言设置输出
  ///   - 'manual': 手动指定语言（需配合manualLanguage参数）
  /// - [manualLanguage]: 手动指定的语言代码（仅在mode='manual'时使用）
  ///   - 'zh': 中文
  ///   - 'en': 英文
  ///   - 'ja': 日文
  ///
  /// 返回：
  /// - 对应模式的语言指令字符串
  static String getLanguageInstruction(String mode, {String? manualLanguage, String? systemLanguage}) {
    switch (mode) {
      case 'book':
        return 'IMPORTANT: Respond in the SAME LANGUAGE as the book content. Detect the language from the provided text and use that same language for your summary. Examples: English book → English, Chinese book → Chinese, Japanese book → Japanese, French book → French, German book → German. DO NOT use English if the book is not in English.';
      case 'system':
        // 根据实际系统语言生成具体指令
        switch (systemLanguage) {
          case 'zh':
            return 'IMPORTANT: Respond in Chinese (简体中文).';
          case 'en':
            return 'IMPORTANT: Respond in English.';
          case 'ja':
            return 'IMPORTANT: Respond in Japanese (日本語).';
          default:
            return 'IMPORTANT: Respond in Chinese (简体中文). This is based on the system language setting.';
        }
      case 'manual':
        switch (manualLanguage) {
          case 'zh':
            return 'IMPORTANT: Respond in Chinese (简体中文).';
          case 'en':
            return 'IMPORTANT: Respond in English.';
          case 'ja':
            return 'IMPORTANT: Respond in Japanese (日本語).';
          default:
            return 'Respond in the language specified by the system.';
        }
      default:
        return 'IMPORTANT: Respond in Chinese (简体中文).';
    }
  }

  /// 根据前言/序言生成书籍摘要提示词
  ///
  /// 当用户首次导入书籍时，系统会提取前言或序言内容，
  /// 使用此提示词让AI生成书籍的内容介绍。
  /// 这可以帮助用户快速了解书籍主题和适用人群。
  ///
  /// 参数：
  /// - [title]: 书籍标题
  /// - [author]: 作者姓名
  /// - [prefaceContent]: 前言或序言的完整文本内容
  /// - [totalChapters]: 书籍总章节数（可选）
  /// - [languageInstruction]: 语言指令（可选），建议使用[getLanguageInstruction]生成
  ///
  /// 返回：
  /// - 格式化的AI提示词字符串，要求AI生成800-900字的Markdown格式摘要
  static String bookSummaryFromPreface({
    required String title,
    required String author,
    required String prefaceContent,
    int? totalChapters,
    String? languageInstruction,
  }) {
    // 检查语言指令是否明确要求英文
    // 重要：这里需要更精确地检测是否要求使用英文，而不是检测指令中是否包含'ENGLISH'这个词
    final isEnglish = languageInstruction != null &&
        (languageInstruction.contains('Respond in English.') ||
            languageInstruction.contains('IMPORTANT: Respond in English.'));

    if (isEnglish) {
      return _englishBookSummaryFromPreface(
        title: title,
        author: author,
        prefaceContent: prefaceContent,
        totalChapters: totalChapters,
      );
    }

    // 中文提示词模板 - 使用修正后的字数和格式
    return '''
${languageInstruction != null ? '【语言要求】$languageInstruction\n\n' : ''}请根据以下前言/序言内容，为书籍生成一份内容介绍，使用 Markdown 格式输出。

书籍信息：
- 书名：$title
- 作者：$author
${totalChapters != null ? '- 章节数：$totalChapters' : ''}

前言/序言内容：
$prefaceContent

要求：
1. **长度：400-600 字**（约 200-300 英文单词）- 这是严格要求
   - 不要超过 700 字
   - 不要少于 300 字
2. 按内容分段输出，使用 Markdown 标题（##）和段落组织，便于阅读
3. 基于前言/序言内容提炼书籍主题和核心内容
4. 必须包含本书的适用读者人群或技术要求（如需要的基础知识、前置技能等）
5. 使用 Markdown 格式输出，可以包含标题、列表、粗体等格式
6. 输出结构：
   - `## 内容简介` - 书籍内容概览
   - `## 核心主题` - 主要主题和关键思想，用段落描述
   - `## 适合读者` - 谁应该阅读此书以及需要什么前置知识

**重要**：不要输出占位符文本如"（内容概述）"或"（核心内容描述）"。基于前言生成实际的摘要内容。
''';
  }

  /// 英文基于前言的书籍摘要提示词模板
  static String _englishBookSummaryFromPreface({
    required String title,
    required String author,
    required String prefaceContent,
    int? totalChapters,
  }) {
    return '''
Please generate a content introduction for the book based on the following preface/foreword content, output in Markdown format.

Book information:
- Title: $title
- Author: $author
${totalChapters != null ? '- Chapters: $totalChapters' : ''}

Preface/Foreword content:
$prefaceContent

Requirements:
1. **Length: 400-600 words** (approximately 800-900 Chinese characters) - this is strict
   - Do NOT exceed 700 words
   - Do NOT write less than 300 words
2. Output in sections using Markdown headers (##) and paragraphs for easy reading
3. Distill the book's theme and core content based on the preface/foreword
4. Must include the target audience or technical requirements (e.g., required background knowledge, prerequisites)
5. Output in Markdown format, can include headers, lists, bold text, etc.
6. Structure your response as:
   - `## Content Summary` - Overview of the book's content
   - `## Core Themes` - Main themes and key ideas, described in paragraphs  
   - `## Target Audience` - Who should read this book and what prerequisites are needed

**IMPORTANT**: DO NOT output placeholder text like "(Content overview)" or "(Core content description)". Generate actual summary content based on the preface.
''';
  }

  /// 根据章节摘要生成全书摘要提示词
  ///
  /// 当用户完成多个章节的阅读和摘要生成后，
  /// 使用此提示词让AI整合所有章节摘要，生成全书的综合摘要。
  /// 这提供了比单独的前言摘要更完整、更详细的书籍概览。
  ///
  /// 参数：
  /// - [title]: 书籍标题
  /// - [author]: 作者姓名
  /// - [chapterSummaries]: 已生成的所有章节摘要的合并文本
  /// - [totalChapters]: 书籍总章节数（可选）
  /// - [languageInstruction]: 语言指令（可选），建议使用[getLanguageInstruction]生成
  ///
  /// 返回：
  /// - 格式化的AI提示词字符串，要求AI生成800-900字的Markdown格式全书摘要
  static String bookSummary({
    required String title,
    required String author,
    required String chapterSummaries,
    int? totalChapters,
    String? languageInstruction,
  }) {
    // 检查语言指令是否明确要求英文
    // 重要：这里需要更精确地检测是否要求使用英文，而不是检测指令中是否包含'ENGLISH'这个词
    final isEnglish = languageInstruction != null &&
        (languageInstruction.contains('Respond in English.') ||
            languageInstruction.contains('IMPORTANT: Respond in English.'));

    if (isEnglish) {
      return _englishBookSummary(
        title: title,
        author: author,
        chapterSummaries: chapterSummaries,
        totalChapters: totalChapters,
      );
    }

    // 中文提示词模板 - 使用修正后的字数和格式
    return '''
${languageInstruction != null ? '【语言要求】$languageInstruction\n\n' : ''}请根据以下各章节摘要，为全书生成一份完整的书籍摘要，使用 Markdown 格式输出。

书籍信息：
- 书名：$title
- 作者：$author
${totalChapters != null ? '- 章节数：$totalChapters' : ''}

各章节摘要：
$chapterSummaries

要求：
1. **长度：400-600 字**（约 200-300 英文单词）- 这是严格要求
   - 不要超过 700 字
   - 不要少于 300 字
2. 按内容分段输出，使用 Markdown 标题（##）和段落组织，便于阅读
3. 综合各章节内容，提炼全书核心观点和知识体系
4. 必须包含本书的适用读者人群或技术要求（如需要的基础知识、前置技能等）
5. 使用 Markdown 格式输出，可以包含标题、列表、粗体等格式
6. 输出结构：
   - `## 内容简介` - 全书内容概览
   - `## 核心主题` - 全书核心主题，用段落描述
   - `## 关键要点` - 最重要的 3-5 个概念要点
   - `## 适合读者` - 谁应该阅读此书以及需要什么前置知识

**重要**：不要输出占位符文本如"（全书内容概述）"或"（核心主题）"。基于章节摘要生成实际的摘要内容。
''';
  }

  /// 英文基于章节的书籍摘要提示词模板
  static String _englishBookSummary({
    required String title,
    required String author,
    required String chapterSummaries,
    int? totalChapters,
  }) {
    return '''
Please generate a complete book summary based on the following chapter summaries, output in Markdown format.

Book information:
- Title: $title
- Author: $author
${totalChapters != null ? '- Chapters: $totalChapters' : ''}

Chapter summaries:
$chapterSummaries

Requirements:
1. **Length: 400-600 words** (approximately 800-900 Chinese characters) - this is strict
   - Do NOT exceed 700 words  
   - Do NOT write less than 300 words
2. Output in sections using Markdown headers (##) and paragraphs for easy reading
3. Synthesize chapter content to distill the book's core ideas and knowledge system
4. Must include the target audience or technical requirements (e.g., required background knowledge, prerequisites)
5. Output in Markdown format, can include headers, lists, bold text, etc.
6. Structure your response as:
   - `## Content Summary` - Overview of the book's content
   - `## Core Themes` - Main themes and key ideas, described in paragraphs
   - `## Key Points` - 3-5 bullet points of the most important concepts
   - `## Target Audience` - Who should read this book and what prerequisites are needed

**IMPORTANT**: DO NOT output placeholder text like "(Book content overview)" or "(Core themes)". Generate actual summary content based on the chapter summaries.
''';
  }

  /// 生成 HTML 翻译提示词
  ///
  /// 直接翻译 HTML 内容，要求 AI 保留所有 HTML 标签，
  /// 仅翻译标签内的文本内容。
  ///
  /// 参数：
  /// - [content]: HTML 格式的原文
  /// - [sourceLang]: 源语言代码
  /// - [targetLang]: 目标语言代码
  /// - [chapterTitle]: 章节标题（可选）
  ///
  /// 返回：格式化的 AI 提示词
  static String translateHtml({
    required String content,
    required String sourceLang,
    required String targetLang,
    String? chapterTitle,
  }) {
    final sourceLangName = _getLanguageName(sourceLang);
    final targetLangName = _getLanguageName(targetLang);
    final isEnglishOutput = targetLang == 'en';

    if (isEnglishOutput) {
      return _englishTranslateHtml(
        content: content,
        sourceLang: sourceLangName,
        chapterTitle: chapterTitle,
      );
    }

    return '''
请将以下 HTML 内容翻译为 **$targetLangName**。

${chapterTitle != null ? '章节标题：$chapterTitle\n' : ''}HTML原文：
$content

**重要：翻译规则**
1. **所有文本必须统一翻译为 $targetLangName**，无论原文是哪种语言（日文、英文、俄文等），输出中只允许出现 $targetLangName
2. **严格保留所有 HTML 标签**：标签的名称、属性、嵌套关系、顺序完全不变
3. **只翻译标签内的纯文本**，不翻译标签名、属性值、URL、代码内容
4. 技术术语（编程语言名称、API名、框架名、类名、方法名等）可以保留原文
5. **代码块（`<code>` 或 `<pre>` 标签内的内容）完全不需要翻译，也不要进行任何转义处理**
6. **对于 `<code>` 和 `<pre>` 中的内容，原样输出，不要添加或移除任何反斜杠**
7. **输入中可能包含占位符 `%%ZHIDU_CODE_BLOCK_N%%`（N为数字），这些是代码块的标记，原样保留即可，不要翻译、解释或修改**
8. 不要添加任何解释、注释或额外内容
9. 直接输出翻译后的 HTML

示例：
输入：
<h2><strong>重要概念</strong></h2>
<p>这是一个包含<strong>粗体</strong>和<em>斜体</em>的段落。</p>
<p>代码示例：<code>int x = 5;</code></p>

输出（翻译后）：
<h2><strong>Important Concept</strong></h2>
<p>This is a paragraph containing <strong>bold</strong> and <em>italic</em> text.</p>
<p>Code example: <code>int x = 5;</code></p>
''';
  }

  static String _englishTranslateHtml({
    required String content,
    required String sourceLang,
    String? chapterTitle,
  }) {
    return '''
Please translate the following HTML content to **English**.

${chapterTitle != null ? 'Chapter title: $chapterTitle\n' : ''}HTML source:
$content

**IMPORTANT: Translation Rules**
1. **ALL text must be translated to English**, regardless of the source language (Japanese, Chinese, Russian, etc.). The output should contain ONLY English text (except for technical terms)
2. **Strictly preserve ALL HTML tags**: tag names, attributes, nesting, and order must remain completely unchanged
3. **Only translate the text content inside tags**, do not translate tag names, attribute values, URLs, or code
4. Technical terms (programming language names, API names, framework names, class names, method names, etc.) can remain in original
5. **Code blocks (content inside `<code>` or `<pre>` tags) should NOT be translated at all, and do NOT perform any escape processing**
6. **For content in `<code>` and `<pre>`, output exactly as-is, do NOT add or remove any backslashes**
7. **The input may contain placeholders `%%ZHIDU_CODE_BLOCK_N%%` (where N is a number), these are markers for code blocks - keep them as-is, do NOT translate, interpret, or modify them**
8. Do NOT add any explanations, notes, or extra content
9. Output ONLY the translated HTML

Example:
Input:
<h2><strong>重要概念</strong></h2>
<p>这是一个包含<strong>粗体</strong>和<em>斜体</em>的段落。</p>
<p>代码示例：<code>int x = 5;</code></p>

Output (translated):
<h2><strong>Important Concept</strong></h2>
<p>This is a paragraph containing <strong>bold</strong> and <em>italic</em> text.</p>
<p>Code example: <code>int x = 5;</code></p>
''';
  }

  /// 获取语言名称
  static String _getLanguageName(String code) {
    switch (code) {
      case 'zh':
        return '中文';
      case 'en':
        return '英文';
      case 'ja':
        return '日文';
      case 'ko':
        return '韩文';
      case 'fr':
        return '法文';
      case 'de':
        return '德文';
      case 'ru':
        return '俄文';
      case 'es':
        return '西班牙文';
      default:
        return code;
    }
  }

  /// 生成章节摘要提示词
  ///
  /// 用于为单个章节生成详细的摘要。
  /// 此提示词会要求AI首先识别章节的真实标题（可能不同于EPUB目录中的标识），
  /// 然后生成结构化的摘要内容。
  ///
  /// 参数：
  /// - [chapterTitle]: 原始章节标识/标题（可选，可能不准确）
  /// - [content]: 章节的完整文本内容
  /// - [languageInstruction]: 语言指令（可选），建议使用[getLanguageInstruction]生成
  ///
  /// 返回：
  /// - 格式化的AI提示词字符串，要求AI生成500-600字的Markdown格式章节摘要
  ///
  /// 注意：
  /// - AI会优先根据内容判断章节的真实标题，而非依赖传入的标识
  /// - 摘要格式要求保留章节编号（如"第X章"、"Chapter X"等）
  static String chapterSummary({
    String? chapterTitle,
    required String content,
    String? languageInstruction,
  }) {
    // 如果语言指令明确要求英文，使用英文提示词模板
    final isEnglish = languageInstruction != null &&
        (languageInstruction.contains('Respond in English.') ||
            languageInstruction.contains('IMPORTANT: Respond in English.'));

    if (isEnglish) {
      return _englishChapterSummary(
          chapterTitle: chapterTitle, content: content);
    }

    // 中文提示词模板 - 使用修正后的字数和格式
    return '''
${languageInstruction != null ? '【语言要求】$languageInstruction\n\n' : ''}请对以下书籍章节内容进行全面分析，**首先提取章节的真实标题**，然后生成摘要。

${chapterTitle != null ? '原始章节标识：$chapterTitle（可能不准确，请根据内容判断真实标题）\n' : ''}章节内容：
$content

要求：
1. **第一行必须输出章节的真实标题**，格式为：`## [真实标题]`
   - **必须保留章节编号**（如"第 X 章"、"Chapter X"、"X."等）
   - 标题格式示例："## 第 1 章 数据结构与算法基础"、"## Chapter 1: Introduction"、"## 1. 基础概念"
   - 如果原始标识包含编号，保留编号并提取完整标题
   - 如果内容无明显标题，请根据内容提炼概括性标题（仍需包含编号）
2. 标题行之后空一行，然后输出摘要正文
3. **摘要长度：200-300 字**（约 100-150 英文单词）- 这是严格要求
   - 不要超过 350 字
   - 不要少于 150 字
   - 重点关注要点，保持简洁
4. 摘要正文使用 Markdown 标题（##）和段落组织，便于阅读
5. 使用通俗易懂的语言，保持客观中立
6. 输出结构：
   - 以 `## [标题]` 开始（只显示标题，不显示"章节标题："这类字样）
   - 然后是 `## 核心内容` 部分，包含主要要点
   - 然后是 `## 关键要点`，包含 3-5 个要点
   - 最后是 `## 总结` 部分

**重要**：不要输出占位符文本如"（主要内容概述）"或"（章节总结）"。基于章节内容生成实际的摘要内容。
''';
  }

  /// 英文章节摘要提示词模板
  static String _englishChapterSummary({
    String? chapterTitle,
    required String content,
  }) {
    return '''
Please analyze the following book chapter content comprehensively, **first extract the real chapter title**, then generate a summary.

${chapterTitle != null ? 'Original chapter identifier: $chapterTitle (may not be accurate, please judge the real title based on the content)\n' : ''}Chapter content:
$content

Requirements:
1. **The first line must output the real chapter title**, format: `## [Real Title]`
   - **Must preserve chapter numbering** (e.g., "Chapter X", "Part X", "X." etc.)
   - Title format examples: "## Chapter 1: Data Structures and Algorithms", "## Chapter 1: Introduction", "## 1. Basic Concepts"
   - If the original identifier contains numbering, preserve the numbering and extract the full title
   - If there is no obvious title in the content, distill a summary title based on the content (still needs to include numbering)
2. After the title line, leave a blank line, then output the summary text
3. **Summary length: 200-300 words** (approximately 400-600 Chinese characters) - this is strict
   - Do NOT exceed 350 words
   - Do NOT write less than 150 words
   - Focus on key points, be concise
4. Summary text should use Markdown headers (##) and paragraphs for easy reading
5. Use accessible language, maintain objectivity and neutrality
6. Structure your response as:
   - Start with `## [title]` (only show the title, not "Chapter Title:" prefix)
   - Then `## Core Content` section with main points
   - Then `## Key Points` with 3-5 bullet points
   - End with `## Summary` section

**IMPORTANT**: DO NOT output placeholder text like "(Main content overview)" or "(Chapter summary)". Generate actual summary content based on the chapter.
''';
  }
}
