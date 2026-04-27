# PDF章节标题智能提取与更新 - 设计文档

## 背景

PDF文档没有内嵌目录结构，现有实现使用正则表达式从页面开头检测章节标题，但检测结果可能是占位符（如"全文"、"第X章"），无法反映真实章节主题。

用户需要在生成章节摘要时，让AI同步提取每章的真实标题，并更新显示在章节页面的AppBar里。所有章节标题提取完成后，应更新全书目录显示。

## 需求

1. **标题来源**：两者结合（优先从章节开头正则提取，失败或不准确时让AI提取）
2. **更新时机**：实时更新（每次生成摘要时立即更新该章节标题）
3. **存储位置**：保存在书籍元数据中（Book对象新增字段）
4. **AI输出格式**：在摘要开头包含标题行（`## 章节标题：XXX`）

## 技术方案

### 方案选择：元数据驱动

在Book模型中新增`chapterTitles`字段，存储章节索引到标题的映射。标题作为书籍固有属性，与书籍元数据一起持久化。

### 数据模型修改

**文件**: `lib/models/book.dart`

新增字段：
```dart
final Map<int, String>? chapterTitles; // 章节索引 -> 标题
```

修改`copyWith()`、`toJson()`、`fromJson()`方法以支持新字段。

### AI Prompt修改

**文件**: `lib/services/ai_prompts.dart`

修改`chapterSummary()`方法，在prompt中增加标题提取要求：

```
请首先提取章节的真实标题，格式为：## 章节标题：[真实标题]
```

### SummaryService修改

**文件**: `lib/services/summary_service.dart`

在`generateSingleSummary()`方法中：
1. 解析AI返回内容，提取开头的标题行
2. 调用`BookService.updateChapterTitle()`更新元数据
3. 保存书籍元数据

新增方法：
- `extractTitleFromSummary(String summary)` - 从摘要开头提取标题
- `updateChapterTitle(String bookId, int index, String title)` - 更新章节标题

### BookService修改

**文件**: `lib/services/book_service.dart`

新增方法：
- `updateChapterTitle(String bookId, int chapterIndex, String title)` - 更新指定章节标题

### UI层修改

**文件**: `lib/screens/book_screen.dart`

- `_buildChapterList()`方法：显示章节时优先使用`book.chapterTitles?[index]`
- 监听书籍元数据变化，自动刷新章节列表

**文件**: `lib/screens/chapter_screen.dart`

- AppBar标题：优先使用`book.chapterTitles?[chapterIndex]`
- 监听书籍元数据变化，自动刷新标题

## 数据流程

```
PDF导入
    │
    ▼
PdfParser.getChapters()
    │ 正则检测初始标题（如"全文"、"第X章")
    │
    ▼
BookScreen显示占位符标题
    │
    ▼
用户点击章节 → ChapterScreen
    │
    ▼
生成摘要 → AI调用
    │ AI返回: ## 章节标题：真实标题
    │         ## 核心内容...（摘要）
    │
    ▼
解析标题 → 提取真实标题
    │
    ▼
BookService.updateChapterTitle()
    │ 更新book.chapterTitles[index]
    │
    ▼
保存书籍元数据 → UI实时刷新
```

## 实现要点

### AI输出解析

AI返回内容格式：
```
## 章节标题：真实标题

## 核心内容
（摘要正文）
```

解析逻辑：
1. 检查开头是否有`## 章节标题：`行
2. 提取冒号后的标题文本
3. 移除标题行后，剩余内容作为摘要保存

### 标题验证

为避免AI输出异常标题，增加以下验证：
- 标题长度不超过50字符
- 标题不含Markdown语法符号（如`#`、`**`）
- 标题为空或无效时，不更新，保持原占位符

### 实时更新机制

使用`BookService.updateBook()`触发元数据保存，UI层通过以下方式监听：
- `BookScreen`: 定时刷新机制（已有，每3秒刷新）
- `ChapterScreen`: 在`_generateSummary()`完成后主动刷新标题

## 影响范围

| 文件 | 改动类型 |
|------|----------|
| lib/models/book.dart | 新增字段 |
| lib/services/ai_prompts.dart | 修改prompt |
| lib/services/summary_service.dart | 新增标题解析逻辑 |
| lib/services/book_service.dart | 新增方法 |
| lib/screens/book_screen.dart | 显示逻辑修改 |
| lib/screens/chapter_screen.dart | 显示逻辑修改 |

## 兼容性

- EPUB书籍：不受影响，保持原有目录解析逻辑
- 已导入PDF书籍：`chapterTitles`字段为空，显示原有占位符标题；生成摘要后自动填充

## 测试要点

1. PDF导入后章节列表显示占位符标题
2. 生成摘要后AppBar标题实时更新
3. 生成摘要后书籍详情页章节列表标题实时更新
4. 多次生成同一章节摘要，标题不重复更新
5. AI返回异常标题时，保持原占位符