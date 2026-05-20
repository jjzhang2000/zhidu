# AiPrompts - AI 提示词模板伪代码文档

## 概述

AiPrompts 是一个静态类，提供用于 AI 服务的提示词模板。支持书籍摘要和章节摘要的生成。

提示词文本通过 `AppLocalizations`（l10n）进行国际化翻译，`languageInstruction` 不作为提示词体内容，
而只通过 `systemMessage` 参数传递给 AI。

---

## 类结构

```pseudocode
CLASS AiPrompts:
    // 所有方法均为静态方法
    // 无实例属性
    // 无构造函数（纯静态类）
    // 依赖 AppLocalizations 获取本地化标签
```

---

## 方法伪代码

### getLanguageInstruction() - 获取语言指令

生成 AI 输出的语言控制指令，只作为 `systemMessage` 使用，**不再嵌入 prompt 体**。

```pseudocode
PUBLIC STATIC METHOD getLanguageInstruction(languageCode: String) -> String:
    SWITCH languageCode:
        CASE 'zh':
            RETURN 'IMPORTANT: Respond in Chinese (简体中文).'
        CASE 'en':
            RETURN 'IMPORTANT: Respond in English.'
        CASE 'ja':
            RETURN 'IMPORTANT: Respond in Japanese (日本語).'
        DEFAULT:
            RETURN 'IMPORTANT: Respond in Chinese (简体中文).'
```

---

### bookSummaryFromPreface() - 基于前言生成书籍摘要提示词

```pseudocode
PUBLIC STATIC METHOD bookSummaryFromPreface(
    loc: AppLocalizations,
    title: String,
    author: String,
    prefaceContent: String,
    totalChapters: int? = null
) -> String:
    chaptersLine = totalChapters != null
        ? '- {loc.promptBookChaptersLabel}{totalChapters}'
        : ''

    RETURN loc.promptPrefaceSummary(title, author, prefaceContent, chaptersLine)
```

`loc.promptPrefaceSummary()` 在每个语言的实现中直接包含完整模板文本。
以简体中文为例，返回：

```
请根据以下前言/序言内容，为书籍生成一份内容介绍，使用 Markdown 格式输出。

书籍信息：
- 书名：{title}
- 作者：{author}
{chaptersLine}

前言/序言内容：
{prefaceContent}

要求：
1. **长度：400-600 字**
2. 按内容分段输出，使用 Markdown 标题（##）和段落组织
3. 基于前言/序言内容提炼书籍主题和核心内容
4. 必须包含本书的适用读者人群或技术要求
5. 使用 Markdown 格式输出
6. 输出结构：
   - `## 内容简介` - 书籍内容概览
   - `## 核心主题` - 主要主题和关键思想
   - `## 适合读者` - 谁应该阅读此书
```

---

### bookSummary() - 基于章节摘要生成全书摘要提示词

```pseudocode
PUBLIC STATIC METHOD bookSummary(
    loc: AppLocalizations,
    title: String,
    author: String,
    chapterSummaries: String,
    totalChapters: int? = null
) -> String:
    chaptersLine = totalChapters != null
        ? '- {loc.promptBookChaptersLabel}{totalChapters}'
        : ''

    RETURN loc.promptBookSummary(title, author, chapterSummaries, chaptersLine)
```

---

### chapterSummary() - 章节摘要提示词

```pseudocode
PUBLIC STATIC METHOD chapterSummary(
    loc: AppLocalizations,
    chapterTitle: String? = null,
    content: String
) -> String:
    RETURN loc.promptChapterSummary(
        chapterTitle ?? '',
        content
    )
```

以简体中文为例，`loc.promptChapterSummary()` 返回：

```
请对以下书籍章节内容进行全面分析，**首先提取章节的真实标题**，然后生成摘要。

{chapterTitle != '' ? '原始章节标识：{chapterTitle}\n' : ''}
章节内容：
{content}

要求：
1. **第一行必须输出章节的真实标题**
2. 标题行之后空一行，然后输出摘要正文
3. **摘要长度：200-300 字**
4. 使用 Markdown 标题（##）和段落组织
5. 输出结构：
   - 以 `## [标题]` 开始
   - 然后是 `## 核心内容` 部分
   - 然后是 `## 关键要点`，包含 3-5 个要点
   - 最后是 `## 总结` 部分
```

章节标题名在不同语言文件中直接硬编码为对应语言：

| 语言 | 核心内容 | 关键要点 | 总结 |
|------|---------|---------|------|
| zh | 核心内容 | 关键要点 | 总结 |
| en | Core Content | Key Points | Summary |
| ja | 核心内容 | 重要ポイント | まとめ |

---

### translateHtml() - HTML 翻译提示词

翻译提示词不通过 l10n，直接在 AiPrompts 内部按目标语言分支：

```pseudocode
PUBLIC STATIC METHOD translateHtml(
    content: String,
    sourceLang: String,
    targetLang: String,
    chapterTitle: String? = null
) -> String:
    t = _langName(targetLang)

    IF targetLang == 'ja':
        RETURN 日语翻译模板（含 $t 插值）
    IF targetLang == 'zh':
        RETURN 中文翻译模板（含 $t 插值）
    RETURN 英文翻译模板（含 $t 插值）
```

---

### _langName() - 语言名称

```pseudocode
PRIVATE STATIC METHOD _langName(code: String) -> String:
    SWITCH code:
        CASE 'zh': RETURN '中文'
        CASE 'en': RETURN 'English'
        CASE 'ja': RETURN '日本語'
        DEFAULT: RETURN code
```

---

## AppLocalizations l10n 结构

提示词相关 l10n key 仅保留 3 个静态标签 getter + 3 个内容模板方法：

| Key | 类型 | 说明 |
|-----|------|------|
| `promptBookTitleLabel` | getter | 书名标签：`书名：` / `Title: ` / `書名：` |
| `promptBookAuthorLabel` | getter | 作者标签：`作者：` / `Author: ` / `著者：` |
| `promptBookChaptersLabel` | getter | 章节数标签：`章节数：` / `Chapters: ` / `章数：` |
| `promptBookSummary` | 方法 | 全书摘要模板 |
| `promptPrefaceSummary` | 方法 | 前言摘要模板 |
| `promptChapterSummary` | 方法 | 章节摘要模板 |

所有模板方法只接受内容参数（title、author、content 等），不接受 `languageInstruction` 或语言名称等动态占位符。

---

## 数据流

```
AIService.generateFullChapterSummaryStream()
    │
    ├─ languageInstruction = AiPrompts.getLanguageInstruction('en')
    │      → 'IMPORTANT: Respond in English.'          ← systemMessage 用
    │
    ├─ loc = _getPromptLoc()                           ← 根据 UI 语言设置
    │
    ├─ prompt = AiPrompts.chapterSummary(loc: loc, ...)
    │      → loc.promptChapterSummary(...)              ← 纯内容模板（无语言前缀）
    │
    └─ _callAIStream(prompt, systemMessage: languageInstruction)
           → AI 通过 systemMessage 接收语言指令
```

**关键设计决策**：
- `languageInstruction` **只作为 systemMessage**，不嵌入 prompt 体
- prompt 体是纯内容模板，通过 l10n 实现三语（zh/en/ja）
- 模板中无动态占位符，每个语言文件的模板文本各自独立

---
