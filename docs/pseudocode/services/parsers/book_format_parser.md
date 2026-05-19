# BookFormatParser + FormatRegistry — 伪代码文档

## 概述

**文件**: `lib/services/parsers/book_format_parser.dart`
**用途**: 书籍格式解析器抽象接口 + 格式注册表
**模式**: 策略模式 + 注册表模式

---

## 接口定义

```
abstract class BookFormatParser
  Future<List<Chapter>> getChapters(String filePath)
  Future<Chapter> getChapterContent(String filePath, Chapter chapter)
  Future<String?> extractCover(String filePath)
```

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

BookScreen / ChapterScreen / SummaryService
  → parser = FormatRegistry.getParser('.epub')
  → parser.getChapters(filePath)
  → parser.getChapterContent(filePath, chapter)
```

---

## 调用关系

| 方法 | 调用方 |
|------|--------|
| `getChapters` | BookScreen, ChapterScreen, SummaryService |
| `getChapterContent` | ChapterScreen, SummaryService |
| `extractCover` | EpubService._extractCover(), PdfService._extractCover() |

---

## 扩展新格式

1. 创建实现 `BookFormatParser` 的解析器类
2. 在 main.dart 中调用 `FormatRegistry.register('.ext', Parser())`
