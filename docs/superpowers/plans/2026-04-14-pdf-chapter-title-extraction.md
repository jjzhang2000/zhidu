# PDF章节标题智能提取与更新 - 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在PDF书籍生成章节摘要时，让AI同步提取章节真实标题，实时更新显示在章节页面AppBar和全书目录中。

**Architecture:** 在Book模型新增chapterTitles字段存储章节标题映射；修改AI Prompt要求输出标题行；SummaryService解析AI输出提取标题并更新BookService；UI层优先显示元数据中的标题。

**Tech Stack:** Flutter, Dart, AI API (智谱/通义千问)

---

## 文件结构

| 文件 | 责任 | 改动类型 |
|------|------|----------|
| lib/models/book.dart | 章节标题存储 | 新增字段、修改方法 |
| lib/services/book_service.dart | 更新章节标题 | 新增方法 |
| lib/services/ai_prompts.dart | AI输出格式 | 修改prompt |
| lib/services/summary_service.dart | 标题解析与更新 | 新增逻辑 |
| lib/screens/book_detail_screen.dart | 章节列表显示 | 修改显示逻辑 |
| lib/screens/summary_screen.dart | AppBar标题显示 | 修改显示逻辑 |

---

### Task 1: Book模型新增chapterTitles字段

**Files:**
- Modify: `lib/models/book.dart`

- [ ] **Step 1: 在Book类中新增chapterTitles字段**

在第12行`final DateTime? lastReadAt;`后添加新字段：

```dart
final Map<int, String>? chapterTitles;
```

- [ ] **Step 2: 修改构造函数，添加chapterTitles参数**

修改`Book`构造函数，在`lastReadAt`参数后添加：

```dart
class Book {
  // ...
  Book({
    // ...
    this.lastReadAt,
    this.chapterTitles,
  });
```

- [ ] **Step 3: 修改copyWith方法**

在`copyWith`方法的参数列表和返回体中添加`chapterTitles`：

```dart
Book copyWith({
  // ...
  DateTime? lastReadAt,
  Map<int, String>? chapterTitles,
}) {
  return Book(
    // ...
    lastReadAt: lastReadAt ?? this.lastReadAt,
    chapterTitles: chapterTitles ?? this.chapterTitles,
  );
}
```

- [ ] **Step 4: 修改toJson方法**

在`toJson`方法的返回Map中添加`chapterTitles`：

```dart
Map<String, dynamic> toJson() {
  return {
    // ...
    'aiIntroduction': aiIntroduction,
    'chapterTitles': chapterTitles?.map((k, v) => MapEntry(k.toString(), v)),
  };
}
```

- [ ] **Step 5: 修改fromJson方法**

在`fromJson`方法中解析`chapterTitles`：

```dart
factory Book.fromJson(Map<String, dynamic> json) {
  final chapterTitlesRaw = json['chapterTitles'] as Map<String, dynamic>?;
  final chapterTitles = chapterTitlesRaw?.map(
    (k, v) => MapEntry(int.parse(k), v as String),
  );
  
  return Book(
    // ...
    aiIntroduction: json['aiIntroduction'],
    chapterTitles: chapterTitles,
  );
}
```

- [ ] **Step 6: 运行flutter analyze验证**

```bash
flutter analyze lib/models/book.dart
```

Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add lib/models/book.dart
git commit -m "feat: add chapterTitles field to Book model"
```

---

### Task 2: BookService新增updateChapterTitle方法

**Files:**
- Modify: `lib/services/book_service.dart`

- [ ] **Step 1: 在BookService类末尾添加updateChapterTitle方法**

在`searchBooks`方法后添加新方法：

```dart
Future<void> updateChapterTitle(
  String bookId,
  int chapterIndex,
  String title,
) async {
  _log.d('BookService', '更新章节标题: bookId=$bookId, index=$chapterIndex, title=$title');
  
  final book = getBookById(bookId);
  if (book == null) {
    _log.w('BookService', '书籍不存在: $bookId');
    return;
  }
  
  final updatedTitles = Map<int, String>.from(book.chapterTitles ?? {});
  updatedTitles[chapterIndex] = title;
  
  final updatedBook = book.copyWith(chapterTitles: updatedTitles);
  await updateBook(updatedBook);
  
  _log.d('BookService', '章节标题更新成功: $title');
}
```

- [ ] **Step 2: 运行flutter analyze验证**

```bash
flutter analyze lib/services/book_service.dart
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/book_service.dart
git commit -m "feat: add updateChapterTitle method to BookService"
```

---

### Task 3: AI Prompt修改

**Files:**
- Modify: `lib/services/ai_prompts.dart`

- [ ] **Step 1: 修改chapterSummary方法的prompt内容**

将`chapterSummary`方法中的prompt修改为：

```dart
static String chapterSummary({
  String? chapterTitle,
  required String content,
}) {
  return '''
请对以下书籍章节内容进行全面分析，**首先提取章节的真实标题**，然后生成摘要。

${chapterTitle != null ? '原始章节标识：$chapterTitle（可能不准确，请根据内容判断真实标题）\n' : ''}
章节内容：
$content

要求：
1. **第一行必须输出章节的真实标题**，格式为：`## 章节标题：[真实标题]`
   - 标题应简洁明了（不超过30字），反映章节核心主题
   - 如果原始标识准确，可以沿用
   - 如果内容无明显标题，请根据内容提炼概括性标题
2. 标题行之后空一行，然后输出摘要正文
3. 摘要长度应在500-600字左右
4. 摘要正文使用Markdown标题（##）和段落组织，便于阅读
5. 使用通俗易懂的语言，保持客观中立
6. 输出格式示例：
## 章节标题：数据结构与算法基础

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
```

- [ ] **Step 2: 运行flutter analyze验证**

```bash
flutter analyze lib/services/ai_prompts.dart
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/ai_prompts.dart
git commit -m "feat: update AI prompt to extract chapter title"
```

---

### Task 4: SummaryService标题解析与更新逻辑

**Files:**
- Modify: `lib/services/summary_service.dart`

- [ ] **Step 1: 在SummaryService类中添加_bookService实例**

在类定义开头，已有`_bookService`实例（第24行），无需添加。确认存在：
```dart
final _bookService = BookService();
```

- [ ] **Step 2: 在SummaryService类末尾添加extractTitleFromSummary方法**

在类的末尾添加标题提取方法：

```dart
String? extractTitleFromSummary(String summary) {
  final lines = summary.split('\n');
  if (lines.isEmpty) return null;
  
  final firstLine = lines[0].trim();
  final titlePattern = RegExp(r'^##\s*章节标题[：:]\s*(.+)$');
  final match = titlePattern.firstMatch(firstLine);
  
  if (match != null) {
    final title = match.group(1)?.trim() ?? '';
    
    if (title.isEmpty || title.length > 50) {
      return null;
    }
    
    if (title.contains('#') || title.contains('**') || title.contains('*')) {
      return null;
    }
    
    return title;
  }
  
  return null;
}

String removeTitleLineFromSummary(String summary) {
  final lines = summary.split('\n');
  if (lines.isEmpty) return summary;
  
  final firstLine = lines[0].trim();
  final titlePattern = RegExp(r'^##\s*章节标题[：:]\s*.+$');
  
  if (titlePattern.matches(firstLine)) {
    if (lines.length > 1 && lines[1].trim().isEmpty) {
      return lines.skip(2).join('\n').trim();
    }
    return lines.skip(1).join('\n').trim();
  }
  
  return summary;
}
```

- [ ] **Step 3: 修改generateSingleSummary方法，添加标题解析逻辑**

在`generateSingleSummary`方法的`if (summary != null && summary.isNotEmpty)`块中，修改为：

```dart
if (summary != null && summary.isNotEmpty) {
  final extractedTitle = extractTitleFromSummary(summary);
  final cleanSummary = removeTitleLineFromSummary(summary);
  
  if (extractedTitle != null && extractedTitle.isNotEmpty) {
    await _bookService.updateChapterTitle(bookId, chapterIndex, extractedTitle);
    _log.d('SummaryService', '提取并更新章节标题: $extractedTitle');
  }
  
  final chapterSummary = ChapterSummary(
    bookId: bookId,
    chapterIndex: chapterIndex,
    chapterTitle: extractedTitle ?? chapterTitle,
    objectiveSummary: cleanSummary,
    aiInsight: '',
    keyPoints: [],
    createdAt: DateTime.now(),
  );

  await saveSummary(chapterSummary);
  _log.info('SummaryService', '摘要生成成功: $key');
  completer.complete();
  return true;
}
```

- [ ] **Step 4: 运行flutter analyze验证**

```bash
flutter analyze lib/services/summary_service.dart
```

Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/services/summary_service.dart
git commit -m "feat: add title extraction logic to SummaryService"
```

---

### Task 5: BookDetailScreen显示逻辑修改

**Files:**
- Modify: `lib/screens/book_detail_screen.dart`

- [ ] **Step 1: 在_book定义后添加获取章节标题的方法**

在`_BookDetailScreenState`类中，在`_refreshBookIfNeeded`方法附近添加辅助方法：

```dart
String _getChapterTitle(int index, Chapter chapter) {
  final titles = _book.chapterTitles;
  if (titles != null && titles.containsKey(index)) {
    return titles[index]!;
  }
  return chapter.title;
}
```

- [ ] **Step 2: 修改_buildChapterList方法中的章节标题显示**

在`_buildChapterList`方法中，找到显示章节标题的Text widget（约第472-480行），修改为：

```dart
title: Text(
  _getChapterTitle(chapter.index, chapter),
  style: TextStyle(
    fontSize: 13 - chapter.level * 1,
    color: chapter.level > 0 ? Colors.grey[600] : null,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

- [ ] **Step 3: 运行flutter analyze验证**

```bash
flutter analyze lib/screens/book_detail_screen.dart
```

Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/screens/book_detail_screen.dart
git commit -m "feat: update chapter list to show extracted titles"
```

---

### Task 6: SummaryScreen显示逻辑修改

**Files:**
- Modify: `lib/screens/summary_screen.dart`

- [ ] **Step 1: 在_SummaryScreenState类中添加_getChapterTitle方法**

在类中添加辅助方法：

```dart
String _getChapterTitle(int index, String defaultTitle) {
  if (widget.book != null) {
    final titles = widget.book!.chapterTitles;
    if (titles != null && titles.containsKey(index)) {
      return titles[index]!;
    }
  }
  return defaultTitle;
}
```

- [ ] **Step 2: 修改AppBar的title显示**

在`build`方法中，找到AppBar的title Text（约第295-301行），修改为：

```dart
appBar: AppBar(
  title: Text(
    _getChapterTitle(widget.chapterIndex, widget.chapterTitle),
    style: const TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 16,
    ),
    overflow: TextOverflow.ellipsis,
  ),
  // ...
),
```

- [ ] **Step 3: 添加BookService实例**

在`_SummaryScreenState`类中，在已有`_summaryService`后添加`_bookService`：

```dart
final _bookService = BookService();
```

需要添加import（如果还没有）：
```dart
import '../services/book_service.dart';
```

- [ ] **Step 4: 修改_generateSummary方法，生成后刷新标题**

由于`generateSingleSummary`已移除标题行并更新到Book元数据，生成成功后需要从BookService获取最新标题。

修改`_generateSummary`方法：

```dart
Future<void> _generateSummary() async {
  if (_content.isEmpty) {
    setState(() {
      _error = '无法生成摘要：章节内容为空';
    });
    return;
  }

  setState(() {
    _isGenerating = true;
    _error = null;
  });

  try {
    final plainText = _extractTextContent(_content);

    final success = await _summaryService.generateSingleSummary(
      widget.bookId,
      widget.chapterIndex,
      _title,
      plainText,
    );

    if (!mounted) return;

    if (success) {
      final summary = await _summaryService.getSummary(
        widget.bookId,
        widget.chapterIndex,
      );
      
      final updatedBook = _bookService.getBookById(widget.bookId);
      if (updatedBook != null) {
        final newTitle = updatedBook.chapterTitles?[widget.chapterIndex];
        setState(() {
          _summary = summary;
          _title = newTitle ?? _title;
          _isGenerating = false;
        });
      } else {
        setState(() {
          _summary = summary;
          _isGenerating = false;
        });
      }
    } else {
      setState(() {
        _error = '生成摘要失败';
        _isGenerating = false;
      });
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _error = '生成摘要失败: $e';
      _isGenerating = false;
    });
  }
}
```

注意：这里需要重构整个`_generateSummary`方法，因为当前逻辑需要等待生成完成后再次读取摘要来提取标题。或者更简单的方式：让`generateSingleSummary`返回生成的摘要内容，这样可以直接解析。

查看当前`generateSingleSummary`返回的是`bool`，需要改为返回摘要内容或者通过其他方式获取。

更简单的方案：在`generateSingleSummary`完成后，重新调用`getSummary`获取摘要并解析标题。

- [ ] **Step 5: 运行flutter analyze验证**

```bash
flutter analyze lib/screens/summary_screen.dart
```

Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add lib/screens/summary_screen.dart
git commit -m "feat: update SummaryScreen to show extracted title in AppBar"
```

---

### Task 7: 最终验证与集成测试

**Files:**
- None (手动测试)

- [ ] **Step 1: 运行flutter analyze整体验证**

```bash
flutter analyze
```

Expected: No issues found

- [ ] **Step 2: 运行应用测试功能**

```bash
flutter run
```

手动测试流程：
1. 导入一本PDF书籍
2. 点击进入书籍详情页，查看章节列表显示占位符标题
3. 点击一个章节进入摘要页面，点击"生成摘要"
4. 观察AppBar标题是否实时更新为真实标题
5. 返回书籍详情页，查看章节列表标题是否更新

- [ ] **Step 3: 最终Commit（如果测试通过）**

```bash
git add -A
git commit -m "feat: complete PDF chapter title extraction feature"
```

---

## 自审清单

- [x] Spec coverage: 所有设计文档中的需求都有对应任务
- [x] Placeholder scan: 无placeholder，所有步骤有完整代码
- [x] Type consistency: `chapterTitles`字段类型一致，方法签名一致