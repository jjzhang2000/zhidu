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
  static String getLanguageInstruction(String mode, {String? manualLanguage}) {
    switch (mode) {
      case 'book':
      case 'auto_book':
        return 'IMPORTANT: Detect the language of the book content first, then respond in THAT SAME language. If the book is in English, respond in English. If the book is in Chinese, respond in Chinese. DO NOT use the language of this prompt.';
      case 'system':
        return '根据系统语言设置，使用对应语言输出摘要。';
      case 'manual':
        switch (manualLanguage) {
          case 'zh':
            return '请用中文输出摘要。';
          case 'en':
            return 'Please respond in English for the summary.';
          case 'ja':
            return '摘要は日本語で出力してください。';
          default:
            return '根据系统语言设置，使用对应语言输出摘要。';
        }
      default:
        return '根据系统语言设置，使用对应语言输出摘要。';
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
    return '''
${languageInstruction != null ? '【语言要求】$languageInstruction\n\n' : ''}请根据以下前言/序言内容，为书籍生成一份内容介绍，使用 Markdown 格式输出。

书籍信息：
- 书名：$title
- 作者：$author
${totalChapters != null ? '- 章节数：$totalChapters' : ''}

前言/序言内容：
$prefaceContent

要求：
1. 介绍长度应在 800-900 字左右
2. 按内容分段输出，使用 Markdown 标题（##）和段落组织，便于阅读
3. 基于前言/序言内容提炼书籍主题和核心内容
4. 必须包含本书的适用读者人群或技术要求（如需要的基础知识、前置技能等）
5. 使用 Markdown 格式输出，可以包含标题、列表、粗体等格式
6. 输出格式示例：
## 内容简介
（内容概述）

## 核心主题
（核心内容分段描述）

## 适合读者
（读者人群或技术要求）
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
    return '''
${languageInstruction != null ? '【语言要求】$languageInstruction\n\n' : ''}请根据以下各章节摘要，为全书生成一份完整的书籍摘要，使用 Markdown 格式输出。

书籍信息：
- 书名：$title
- 作者：$author
${totalChapters != null ? '- 章节数：$totalChapters' : ''}

各章节摘要：
$chapterSummaries

要求：
1. 摘要长度应在 800-900 字左右
2. 按内容分段输出，使用 Markdown 标题（##）和段落组织，便于阅读
3. 综合各章节内容，提炼全书核心观点和知识体系
4. 必须包含本书的适用读者人群或技术要求（如需要的基础知识、前置技能等）
5. 使用 Markdown 格式输出，可以包含标题、列表、粗体等格式
6. 输出格式示例：
## 内容简介
（全书内容概述）

## 核心主题
（全书核心主题，分段描述）

## 关键要点
- 要点 1
- 要点 2
- 要点 3

## 适合读者
（读者人群或技术要求）
''';
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
    return '''
${languageInstruction != null ? '【语言要求】$languageInstruction\n\n' : ''}请对以下书籍章节内容进行全面分析，**首先提取章节的真实标题**，然后生成摘要。

${chapterTitle != null ? '原始章节标识：$chapterTitle（可能不准确，请根据内容判断真实标题）\n' : ''}章节内容：
$content

要求：
1. **第一行必须输出章节的真实标题**，格式为：`## 章节标题：[真实标题]`
   - **必须保留章节编号**（如"第 X 章"、"Chapter X"、"X."等）
   - 标题格式示例："第 1 章 数据结构与算法基础"、"Chapter 1: Introduction"、"1. 基础概念"
   - 如果原始标识包含编号，保留编号并提取完整标题
   - 如果内容无明显标题，请根据内容提炼概括性标题（仍需包含编号）
2. 标题行之后空一行，然后输出摘要正文
3. 摘要长度应在 500-600 字左右
4. 摘要正文使用 Markdown 标题（##）和段落组织，便于阅读
5. 使用通俗易懂的语言，保持客观中立
6. 输出格式示例：
## 章节标题：第 1 章 数据结构与算法基础

## 核心内容
（主要内容概述，分段描述）

## 关键要点
- 要点 1
- 要点 2
- 要点 3

## 总结
（章节总结与意义）
''';
  }
}
