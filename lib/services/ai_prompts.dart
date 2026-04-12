class AiPrompts {
  static String bookSummaryFromPreface({
    required String title,
    required String author,
    required String prefaceContent,
    int? totalChapters,
  }) {
    return '''
请根据以下前言/序言内容，为书籍生成一份内容介绍，使用Markdown格式输出。

书籍信息：
- 书名：$title
- 作者：$author
${totalChapters != null ? '- 章节数：$totalChapters' : ''}

前言/序言内容：
$prefaceContent

要求：
1. 介绍长度应在800-900字左右
2. 按内容分段输出，使用Markdown标题（##）和段落组织，便于阅读
3. 基于前言/序言内容提炼书籍主题和核心内容
4. 必须包含本书的适用读者人群或技术要求（如需要的基础知识、前置技能等）
5. 使用Markdown格式输出，可以包含标题、列表、粗体等格式
6. 输出格式示例：
## 内容简介
（内容概述）

## 核心主题
（核心内容分段描述）

## 适合读者
（读者人群或技术要求）
''';
  }

  static String bookSummary({
    required String title,
    required String author,
    required String chapterSummaries,
    int? totalChapters,
  }) {
    return '''
请根据以下各章节摘要，为全书生成一份完整的书籍摘要，使用Markdown格式输出。

书籍信息：
- 书名：$title
- 作者：$author
${totalChapters != null ? '- 章节数：$totalChapters' : ''}

各章节摘要：
$chapterSummaries

要求：
1. 摘要长度应在800-900字左右
2. 按内容分段输出，使用Markdown标题（##）和段落组织，便于阅读
3. 综合各章节内容，提炼全书核心观点和知识体系
4. 必须包含本书的适用读者人群或技术要求（如需要的基础知识、前置技能等）
5. 使用Markdown格式输出，可以包含标题、列表、粗体等格式
6. 输出格式示例：
## 内容简介
（全书内容概述）

## 核心主题
（全书核心主题，分段描述）

## 关键要点
- 要点1
- 要点2
- 要点3

## 适合读者
（读者人群或技术要求）
''';
  }

  static String chapterSummary({
    String? chapterTitle,
    required String content,
  }) {
    return '''
请对以下书籍章节内容进行全面分析，使用Markdown格式输出。

${chapterTitle != null ? '章节标题：$chapterTitle\n' : ''}
章节内容：
$content

要求：
1. 摘要长度应在800-900字左右
2. 按内容分段输出，使用Markdown标题（##）和段落组织，便于阅读
3. 使用通俗易懂的语言，保持客观中立
4. 使用Markdown格式输出，可以包含标题、列表、粗体等格式
5. 输出格式示例：
## 核心内容
（主要内容概述，分段描述）

## 关键要点
- 要点1
- 要点2
- 要点3

## 总结
（章节总结与意义）
''';
  }
}
