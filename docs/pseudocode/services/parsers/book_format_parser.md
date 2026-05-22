# BookFormatParser + FormatRegistry — 伪代码文档

## 概述

**文件**: `lib/services/parsers/book_format_parser.dart`
**用途**: 书籍格式解析器统一接口 + 格式注册表，元数据解析和内容解析归口到一组解析器
**模式**: 策略模式 + 注册表模式

---

## BookMetadata 模型

```
class BookMetadata
  final String title
  final String author
  final int totalChapters
  final String? coverPath
  final String? language
```

仅包含导入时需要的轻量信息，不包含章节内容。

---

## 接口定义

```
abstract class BookFormatParser
  Future<BookMetadata?> parseMetadata(String filePath, String bookId)
  Future<List<Chapter>> getChapters(String filePath)
  Future<Chapter> getChapterContent(String filePath, Chapter chapter)
```

| 方法 | 用途 |
|------|------|
| `parseMetadata` | 轻量解析：标题、作者、封面、章节数、语言 |
| `getChapters` | 提取章节列表（含 index、title、location、level） |
| `getChapterContent` | 提取指定章节的完整 HTML 内容 |

### 实现类

| 类 | 格式 |
|----|------|
| EpubParser | EPUB |
| PdfParser | PDF |

---

## 注册表

```
class FormatRegistry
  static Map<String, BookFormatParser> _parsers = {}

  static void register(extension, parser)
    _parsers[extension.toLowerCase()] = parser

  static BookFormatParser? getParser(extension)
    return _parsers[extension.toLowerCase()]

  static bool isSupported(extension)
    return _parsers.containsKey(extension.toLowerCase())

  static List<String> getSupportedFormats()
    return _parsers.keys.toList()

  static void clear()
    _parsers.clear()
```

---

## 使用流程

```
main.dart
  → FormatRegistry.register('.epub', EpubParser())
  → FormatRegistry.register('.pdf', PdfParser())

BookService.importBookFromPath()
  → parser = FormatRegistry.getParser(extension)
  → metadata = parser.parseMetadata(filePath, bookId)
  → 构建 Book 对象

BookScreen / ChapterScreen / SummaryService
  → parser = FormatRegistry.getParser('.epub')
  → parser.getChapters(filePath)
  → parser.getChapterContent(filePath, chapter)
```

---

## 调用关系

| 方法 | 调用方 |
|------|--------|
| `parseMetadata` | BookService.importBookFromPath() |
| `getChapters` | BookService, BookScreen, ChapterScreen, SummaryService |
| `getChapterContent` | ChapterScreen, SummaryService |

---

## 扩展新格式

1. 创建实现 `BookFormatParser` 的解析器类
2. 在 main.dart 中调用 `FormatRegistry.register('.ext', Parser())`
