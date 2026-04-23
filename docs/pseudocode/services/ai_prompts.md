# AiPrompts - AI 提示词模板伪代码文档

## 概述

AiPrompts 是一个静态类，提供用于 AI 服务的提示词模板。支持书籍摘要和章节摘要的生成，支持多语言输出控制。

---

## 类结构

```pseudocode
CLASS AiPrompts:
    // 所有方法均为静态方法
    // 无实例属性
    // 无构造函数（纯静态类）
```

---

## 方法伪代码

### getLanguageInstruction() - 获取语言指令

```pseudocode
PUBLIC STATIC METHOD getLanguageInstruction(mode: String, manualLanguage: String? = null) -> String:
    SWITCH mode:
        CASE 'book':
            // 根据书籍内容语言输出
            RETURN 'IMPORTANT: Respond in the SAME LANGUAGE as the book content. 
                    Detect the language from the provided text and use that same 
                    language for your summary. Examples: English book → English, 
                    Chinese book → Chinese, Japanese book → Japanese, 
                    French book → French, German book → German. 
                    DO NOT use English if the book is not in English.'
        
        CASE 'system':
            // 根据系统语言设置输出
            RETURN 'Respond according to the system language setting.'
        
        CASE 'manual':
            // 手动指定语言
            SWITCH manualLanguage:
                CASE 'zh':
                    RETURN 'IMPORTANT: Respond in Chinese (简体中文).'
                CASE 'en':
                    RETURN 'IMPORTANT: Respond in English.'
                CASE 'ja':
                    RETURN 'IMPORTANT: Respond in Japanese (日本語).'
                DEFAULT:
                    RETURN 'Respond in the language specified by the system.'
        
        DEFAULT:
            RETURN 'Respond according to the system language setting.'
```

**语言模式说明:**

| 模式 | 说明 | 使用场景 |
|------|------|----------|
| book | 自动检测书籍语言 | 多语言书籍，保持原文语言 |
| system | 使用系统语言设置 | 用户界面语言偏好 |
| manual | 手动指定语言 | 用户明确指定输出语言 |

---

### bookSummaryFromPreface() - 基于前言生成书籍摘要提示词

```pseudocode
PUBLIC STATIC METHOD bookSummaryFromPreface(
    title: String,
    author: String,
    prefaceContent: String,
    totalChapters: int? = null,
    languageInstruction: String? = null
) -> String:
    // 检查是否要求英文输出
    isEnglish = languageInstruction != null AND
                (languageInstruction.contains('Respond in English.') OR
                 languageInstruction.contains('IMPORTANT: Respond in English.'))
    
    // 如果要求英文，使用英文模板
    IF isEnglish:
        RETURN _englishBookSummaryFromPreface(title, author, prefaceContent, totalChapters)
    
    // 中文提示词模板
    RETURN '''
    {languageInstruction != null ? '【语言要求】{languageInstruction}\n\n' : ''}
    请根据以下前言/序言内容，为书籍生成一份内容介绍，使用 Markdown 格式输出。
    
    书籍信息：
    - 书名：{title}
    - 作者：{author}
    {totalChapters != null ? '- 章节数：{totalChapters}' : ''}
    
    前言/序言内容：
    {prefaceContent}
    
    要求：
    1. **长度：400-600 字**（约 200-300 英文单词）- 这是严格要求
       - 不要超过 700 字
       - 不要少于 300 字
    2. 按内容分段输出，使用 Markdown 标题（##）和段落组织，便于阅读
    3. 基于前言/序言内容提炼书籍主题和核心内容
    4. 必须包含本书的适用读者人群或技术要求
    5. 使用 Markdown 格式输出，可以包含标题、列表、粗体等格式
    6. 输出结构：
       - `## 内容简介` - 书籍内容概览
       - `## 核心主题` - 主要主题和关键思想
       - `## 适合读者` - 谁应该阅读此书以及需要什么前置知识
    
    **重要**：不要输出占位符文本如"（内容概述）"。基于前言生成实际的摘要内容。
    '''
```

**提示词结构分析:**

```
┌─────────────────────────────────────────────────────────────┐
│           bookSummaryFromPreface() 提示词结构                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 语言要求（可选）                                         │
│      └─ 【语言要求】{languageInstruction}                    │
│                                                             │
│  2. 任务描述                                                 │
│      └─ 请根据前言/序言内容生成内容介绍                       │
│                                                             │
│  3. 书籍信息                                                 │
│      ├─ 书名                                                │
│      ├─ 作者                                                │
│      └─ 章节数（可选）                                       │
│                                                             │
│  4. 输入内容                                                 │
│      └─ 前言/序言完整文本                                    │
│                                                             │
│  5. 输出要求                                                 │
│      ├─ 长度限制（400-600字）                                │
│      ├─ 格式要求（Markdown）                                 │
│      ├─ 内容要求（主题、读者）                               │
│      └─ 结构要求（三个章节）                                 │
│                                                             │
│  6. 禁止事项                                                 │
│      └─ 不要输出占位符文本                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### _englishBookSummaryFromPreface() - 英文前言摘要模板

```pseudocode
PRIVATE STATIC METHOD _englishBookSummaryFromPreface(
    title: String,
    author: String,
    prefaceContent: String,
    totalChapters: int? = null
) -> String:
    RETURN '''
    Please generate a content introduction for the book based on the 
    following preface/foreword content, output in Markdown format.
    
    Book information:
    - Title: {title}
    - Author: {author}
    {totalChapters != null ? '- Chapters: {totalChapters}' : ''}
    
    Preface/Foreword content:
    {prefaceContent}
    
    Requirements:
    1. **Length: 400-600 words** - this is strict
       - Do NOT exceed 700 words
       - Do NOT write less than 300 words
    2. Output in sections using Markdown headers (##)
    3. Distill the book's theme and core content
    4. Must include the target audience or technical requirements
    5. Output in Markdown format
    6. Structure your response as:
       - `## Content Summary`
       - `## Core Themes`
       - `## Target Audience`
    
    **IMPORTANT**: DO NOT output placeholder text. 
    Generate actual summary content based on the preface.
    '''
```

---

### bookSummary() - 基于章节摘要生成全书摘要提示词

```pseudocode
PUBLIC STATIC METHOD bookSummary(
    title: String,
    author: String,
    chapterSummaries: String,
    totalChapters: int? = null,
    languageInstruction: String? = null
) -> String:
    // 检查是否要求英文输出
    isEnglish = languageInstruction != null AND
                (languageInstruction.contains('Respond in English.') OR
                 languageInstruction.contains('IMPORTANT: Respond in English.'))
    
    IF isEnglish:
        RETURN _englishBookSummary(title, author, chapterSummaries, totalChapters)
    
    // 中文提示词模板
    RETURN '''
    {languageInstruction != null ? '【语言要求】{languageInstruction}\n\n' : ''}
    请根据以下各章节摘要，为全书生成一份完整的书籍摘要，使用 Markdown 格式输出。
    
    书籍信息：
    - 书名：{title}
    - 作者：{author}
    {totalChapters != null ? '- 章节数：{totalChapters}' : ''}
    
    各章节摘要：
    {chapterSummaries}
    
    要求：
    1. **长度：400-600 字** - 这是严格要求
    2. 按内容分段输出，使用 Markdown 标题（##）
    3. 综合各章节内容，提炼全书核心观点和知识体系
    4. 必须包含本书的适用读者人群或技术要求
    5. 输出结构：
       - `## 内容简介` - 全书内容概览
       - `## 核心主题` - 全书核心主题
       - `## 关键要点` - 最重要的 3-5 个概念要点
       - `## 适合读者` - 谁应该阅读此书
    
    **重要**：不要输出占位符文本。基于章节摘要生成实际的摘要内容。
    '''
```

---

### _englishBookSummary() - 英文全书摘要模板

```pseudocode
PRIVATE STATIC METHOD _englishBookSummary(
    title: String,
    author: String,
    chapterSummaries: String,
    totalChapters: int? = null
) -> String:
    RETURN '''
    Please generate a complete book summary based on the following 
    chapter summaries, output in Markdown format.
    
    Book information:
    - Title: {title}
    - Author: {author}
    {totalChapters != null ? '- Chapters: {totalChapters}' : ''}
    
    Chapter summaries:
    {chapterSummaries}
    
    Requirements:
    1. **Length: 400-600 words** - this is strict
    2. Output in sections using Markdown headers (##)
    3. Synthesize chapter content to distill core ideas
    4. Must include the target audience
    5. Structure your response as:
       - `## Content Summary`
       - `## Core Themes`
       - `## Key Points` - 3-5 bullet points
       - `## Target Audience`
    
    **IMPORTANT**: DO NOT output placeholder text.
    '''
```

---

### chapterSummary() - 章节摘要提示词

```pseudocode
PUBLIC STATIC METHOD chapterSummary(
    chapterTitle: String? = null,
    content: String,
    languageInstruction: String? = null
) -> String:
    // 检查是否要求英文输出
    isEnglish = languageInstruction != null AND
                (languageInstruction.contains('Respond in English.') OR
                 languageInstruction.contains('IMPORTANT: Respond in English.'))
    
    IF isEnglish:
        RETURN _englishChapterSummary(chapterTitle, content)
    
    // 中文提示词模板
    RETURN '''
    {languageInstruction != null ? '【语言要求】{languageInstruction}\n\n' : ''}
    请对以下书籍章节内容进行全面分析，**首先提取章节的真实标题**，然后生成摘要。
    
    {chapterTitle != null ? '原始章节标识：{chapterTitle}（可能不准确，请根据内容判断真实标题）\n' : ''}
    章节内容：
    {content}
    
    要求：
    1. **第一行必须输出章节的真实标题**，格式为：`## [真实标题]`
       - **必须保留章节编号**（如"第 X 章"、"Chapter X"、"X."等）
       - 标题格式示例："## 第 1 章 数据结构与算法基础"
       - 如果原始标识包含编号，保留编号并提取完整标题
    2. 标题行之后空一行，然后输出摘要正文
    3. **摘要长度：200-300 字** - 这是严格要求
       - 不要超过 350 字
       - 不要少于 150 字
    4. 摘要正文使用 Markdown 标题（##）和段落组织
    5. 使用通俗易懂的语言，保持客观中立
    6. 输出结构：
       - 以 `## [标题]` 开始
       - 然后是 `## 核心内容` 部分
       - 然后是 `## 关键要点`，包含 3-5 个要点
       - 最后是 `## 总结` 部分
    
    **重要**：不要输出占位符文本。基于章节内容生成实际的摘要内容。
    '''
```

**章节摘要提示词结构:**

```
┌─────────────────────────────────────────────────────────────┐
│              chapterSummary() 提示词结构                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 语言要求（可选）                                         │
│                                                             │
│  2. 任务描述                                                 │
│      └─ 分析章节内容，提取真实标题，生成摘要                  │
│                                                             │
│  3. 原始章节标识（可选）                                      │
│      └─ 提示 AI 可能不准确，需根据内容判断                   │
│                                                             │
│  4. 章节内容                                                 │
│      └─ 完整章节文本                                        │
│                                                             │
│  5. 标题提取要求                                             │
│      ├─ 第一行必须是真实标题                                 │
│      ├─ 必须保留章节编号                                     │
│      └─ 格式示例                                            │
│                                                             │
│  6. 摘要要求                                                 │
│      ├─ 长度限制（200-300字）                                │
│      ├─ 格式要求（Markdown）                                 │
│      └─ 结构要求（四个部分）                                 │
│                                                             │
│  7. 禁止事项                                                 │
│      └─ 不要输出占位符文本                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### _englishChapterSummary() - 英文章节摘要模板

```pseudocode
PRIVATE STATIC METHOD _englishChapterSummary(
    chapterTitle: String? = null,
    content: String
) -> String:
    RETURN '''
    Please analyze the following book chapter content comprehensively, 
    **first extract the real chapter title**, then generate a summary.
    
    {chapterTitle != null ? 'Original chapter identifier: {chapterTitle} (may not be accurate)\n' : ''}
    Chapter content:
    {content}
    
    Requirements:
    1. **The first line must output the real chapter title**
       - **Must preserve chapter numbering** (e.g., "Chapter X")
       - Title format examples: "## Chapter 1: Data Structures"
    2. After the title line, leave a blank line
    3. **Summary length: 200-300 words** - this is strict
    4. Use Markdown headers (##) for organization
    5. Structure your response as:
       - Start with `## [title]`
       - Then `## Core Content`
       - Then `## Key Points` with 3-5 bullet points
       - End with `## Summary`
    
    **IMPORTANT**: DO NOT output placeholder text.
    '''
```

---

## 提示词设计原则

### 1. 明确的长度限制

```pseudocode
// 使用严格的字数限制，避免 AI 输出过长或过短
"**长度：400-600 字** - 这是严格要求"
"- 不要超过 700 字"
"- 不要少于 300 字"
```

### 2. 结构化输出要求

```pseudocode
// 明确指定输出结构，便于解析和展示
"输出结构：
 - `## 内容简介`
 - `## 核心主题`
 - `## 适合读者`"
```

### 3. 禁止占位符

```pseudocode
// 防止 AI 输出无意义的占位符文本
"**重要**：不要输出占位符文本如"（内容概述）""
```

### 4. 语言控制

```pseudocode
// 使用 IMPORTANT 标记强化语言要求
"IMPORTANT: Respond in Chinese (简体中文)."
```

### 5. 标题提取

```pseudocode
// 章节摘要要求 AI 首先提取真实标题
"**第一行必须输出章节的真实标题**"
"必须保留章节编号"
```

---

## 输出格式示例

### 书籍摘要输出

```markdown
## 内容简介

本书系统介绍了软件设计模式的核心概念和实践方法...

## 核心主题

设计模式分为三大类：创建型、结构型、行为型...

## 适合读者

适合有一定编程基础的软件开发人员，需要了解面向对象编程的基本概念...
```

### 章节摘要输出

```markdown
## 第 1 章 设计模式概述

## 核心内容

本章介绍了设计模式的基本概念和历史背景...

## 关键要点

- 设计模式是可复用的解决方案
- 分为三大类：创建型、结构型、行为型
- 有助于提高代码质量和可维护性

## 总结

设计模式是软件工程的重要工具，理解其基本概念是后续学习的基础。
```

---

## 多语言支持

### 支持的语言

| 语言代码 | 语言名称 | 指令文本 |
|----------|----------|----------|
| zh | 简体中文 | IMPORTANT: Respond in Chinese (简体中文). |
| en | English | IMPORTANT: Respond in English. |
| ja | 日本語 | IMPORTANT: Respond in Japanese (日本語). |
| ko | 한국어 | IMPORTANT: Respond in Korean (한국어). |
| fr | Français | IMPORTANT: Respond in French (Français). |
| de | Deutsch | IMPORTANT: Respond in German (Deutsch). |
| ru | Русский | IMPORTANT: Respond in Russian (Русский). |
| es | Español | IMPORTANT: Respond in Spanish (Español). |

---

## 使用示例

### 生成章节摘要

```pseudocode
// 获取语言指令
languageInstruction = AiPrompts.getLanguageInstruction('book')

// 构建提示词
prompt = AiPrompts.chapterSummary(
    chapterTitle: '第1章',
    content: chapterContent,
    languageInstruction: languageInstruction
)

// 调用 AI
summary = await AIService()._callAI(prompt, systemMessage: languageInstruction)
```

### 生成书籍摘要

```pseudocode
// 基于前言生成
prompt = AiPrompts.bookSummaryFromPreface(
    title: '设计模式',
    author: 'GoF',
    prefaceContent: prefaceText,
    totalChapters: 25,
    languageInstruction: 'IMPORTANT: Respond in Chinese.'
)

// 基于章节摘要生成
prompt = AiPrompts.bookSummary(
    title: '设计模式',
    author: 'GoF',
    chapterSummaries: allChapterSummaries,
    totalChapters: 25,
    languageInstruction: 'IMPORTANT: Respond in Chinese.'
)
```

---

## 错误处理

提示词模板本身不涉及错误处理，但需要注意:

1. **内容过长**: AI 可能截断输入内容
2. **语言检测失败**: 'book' 模式可能无法准确检测语言
3. **格式不符**: AI 可能不遵循 Markdown 格式要求

---

## 性能考量

### 提示词长度

```
章节摘要提示词: ~500 字符
书籍摘要提示词: ~600 字符
```

### Token 消耗估算

```
提示词模板: ~100-150 tokens
章节内容: 根据实际长度
AI 输出: ~200-300 tokens (摘要)
```

---

## 测试支持

```pseudocode
// 测试提示词生成
TEST AiPrompts:
    // 测试语言指令
    instruction = AiPrompts.getLanguageInstruction('zh')
    ASSERT instruction.contains('Chinese')
    
    // 测试章节摘要提示词
    prompt = AiPrompts.chapterSummary(
        chapterTitle: 'Test',
        content: 'Test content',
        languageInstruction: instruction
    )
    ASSERT prompt.contains('Test content')
    ASSERT prompt.contains('章节标题')
    
    // 测试书籍摘要提示词
    prompt = AiPrompts.bookSummaryFromPreface(
        title: 'Test Book',
        author: 'Test Author',
        prefaceContent: 'Test preface'
    )
    ASSERT prompt.contains('Test Book')
    ASSERT prompt.contains('Test Author')
```