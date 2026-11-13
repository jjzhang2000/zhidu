# AiPrompts - AI 提示词模板伪代码文档

## 概述

AiPrompts 是一个静态类，提供用于 AI 服务的提示词模板。所有提示词文本通过 `AppLocalizations`（l10n）进行国际化翻译，回复语言指令直接嵌入提示词文本首行，不再通过 `systemMessage` 传递。

---

## 类结构

```pseudocode
CLASS AiPrompts:
    // 所有方法均为静态方法
    // 无实例属性、无构造函数（纯静态类）
    // 依赖 AppLocalizations 获取本地化提示词模板
```

---

## 方法伪代码

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

以简体中文为例，`loc.promptChapterSummary()` 返回首行含 "请用中文回复。" 的完整模板文本。

章节标题名在不同语言文件中直接硬编码为对应语言：

| 语言 | 核心内容 | 关键要点 | 总结 |
|------|---------|---------|------|
| zh | 核心内容 | 关键要点 | 总结 |
| en | Core Content | Key Points | Summary |
| ja | 核心内容 | 重要ポイント | まとめ |

---

### translateHtml() - HTML 翻译提示词

```pseudocode
PUBLIC STATIC METHOD translateHtml(
    loc: AppLocalizations,
    content: String,
    chapterTitle: String? = null
) -> String:
    RETURN loc.promptTranslateHtml(content, chapterTitle ?? '')
```

`loc.promptTranslateHtml()` 在各语言实现中直接包含完整翻译提示词模板，首行同样包含回复语言指令。

---

## AppLocalizations l10n 结构

提示词相关 l10n key：

| Key | 类型 | 说明 |
|-----|------|------|
| `promptBookTitleLabel` | getter | 书名标签 |
| `promptBookAuthorLabel` | getter | 作者标签 |
| `promptBookChaptersLabel` | getter | 章节数标签 |
| `promptBookSummary` | 方法 | 全书摘要模板 |
| `promptPrefaceSummary` | 方法 | 前言摘要模板 |
| `promptChapterSummary` | 方法 | 章节摘要模板 |
| `promptTranslateHtml` | 方法 | HTML 翻译模板（新增） |

所有模板方法首行自带回复语言指令：中文 "请用中文回复。"、英文 "Please respond in English."、日语 "日本語で回答してください。"。

---

## 数据流

```
AIService.generateFullChapterSummaryStream()
    │
    ├─ outputLanguage = await _resolveOutputLanguage(...)
    │
    ├─ loc = _getPromptLoc(outputLanguage)
    │
    ├─ prompt = AiPrompts.chapterSummary(loc: loc, ...)
    │      → loc.promptChapterSummary(...)
    │      → 首行：请用中文回复。/Please respond in English./日本語で回答してください。
    │      → 提示词语言与 AI 输出语言一致
    │
    └─ _callAIStream(prompt)           ← 不再需要 systemMessage
```

**关键设计决策**：
- 回复语言指令 **直接嵌入 prompt 体首行**，不再作为 systemMessage 传递
- prompt 体通过 l10n 实现三语（zh/en/ja），提示词语言与 AI 输出语言一致
- `_callAIStream()` / `_callAI()` 不再接收 `systemMessage` 参数，消息列表仅含 `user` role

---

## 版本历史

- **2026-05-21**: 彻底消除 systemMessage — 删除 `getLanguageInstruction()`/`_outputInstruction()`/`_langName()` 三个方法；删除 `AiPrompts` 方法上 `outputLanguage` 参数；`translateHtml` 硬编码三语提示词迁移至 l10n 的 `promptTranslateHtml`；回复语言指令直接嵌入各 l10n 提示词模板首行
- **2026-05-20**: 提示词 l10n 化 — 全部提示词文本委托 AppLocalizations；删除 5 个死方法（~315行）；消除动态占位符；`getLanguageInstruction` 简化为 `(languageCode)`；ai_prompts.dart 457→128 行
