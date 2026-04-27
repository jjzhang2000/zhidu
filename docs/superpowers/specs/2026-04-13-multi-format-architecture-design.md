# 多格式电子书架构设计

## 概述

重构智读应用的书籍格式处理架构，实现阅读流程、AI生成流程与文件格式的完全解耦。通过统一的抽象接口，使EPUB、PDF、TXT、MOBI、AZW等格式都能以一致的方式与阅读器和AI服务交互。

## 设计原则

1. **统一章节抽象**：所有格式都映射为扁平化的章节列表
2. **接口隔离**：格式解析器通过标准接口与系统其他部分交互
3. **双格式内容**：AI处理使用纯文本，阅读渲染保留原格式
4. **向后兼容**：现有EPUB功能保持完整

## 核心数据模型

### Chapter（统一章节模型）

```dart
class Chapter {
  final String id;              // 持久化ID
  final int index;              // UI顺序索引（0, 1, 2...）
  final String title;
  final ChapterLocation location; // 在源文件中的位置
  
  Chapter({
    required this.id,
    required this.index,
    required this.title,
    required this.location,
  });
}
```

### ChapterLocation（章节位置）

```dart
class ChapterLocation {
  final String? href;           // EPUB: "chapter1.html"
  final int? startPage;         // PDF: 起始页码
  final int? endPage;           // PDF: 结束页码（可选）
  
  ChapterLocation({
    this.href,
    this.startPage,
    this.endPage,
  });
}
```

### ChapterContent（章节内容）

```dart
class ChapterContent {
  final String plainText;       // AI使用的纯文本
  final String? htmlContent;    // 阅读器使用（如有）
  
  ChapterContent({
    required this.plainText,
    this.htmlContent,
  });
}
```

### BookMetadata（书籍元数据）

```dart
class BookMetadata {
  final String title;
  final String author;
  final String? coverPath;
  final int totalChapters;
  final BookFormat format;
  
  BookMetadata({
    required this.title,
    required this.author,
    this.coverPath,
    required this.totalChapters,
    required this.format,
  });
}
```

## 格式解析器接口

```dart
abstract class BookFormatParser {
  /// 解析文件，提取元数据
  Future<BookMetadata> parse(String filePath);
  
  /// 获取章节列表（扁平化，只有一级）
  Future<List<Chapter>> getChapters(String filePath);
  
  /// 获取章节内容
  Future<ChapterContent> getChapterContent(String filePath, Chapter chapter);
  
  /// 提取封面（可选）
  Future<String?> extractCover(String filePath);
}
```

## 格式注册表

```dart
class FormatRegistry {
  static final Map<String, BookFormatParser> _parsers = {};
  
  static void register(String extension, BookFormatParser parser) {
    _parsers[extension.toLowerCase()] = parser;
  }
  
  static BookFormatParser? getParser(String extension) {
    return _parsers[extension.toLowerCase()];
  }
  
  static void initialize() {
    register('epub', EpubParser());
    register('pdf', PdfParser());
    register('txt', TxtParser());
    // 未来格式：register('mobi', MobiParser());
    // 未来格式：register('azw', AzwParser());
  }
}
```

## 各格式解析器实现

### EpubParser

```dart
class EpubParser implements BookFormatParser {
  @override
  Future<BookMetadata> parse(String filePath) async {
    // 解析EPUB文件，提取元数据
    // 提取封面（如有）
  }
  
  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    // 获取EPUB层级章节，但只返回第一级
    // 映射为统一的Chapter列表
  }
  
  @override
  Future<ChapterContent> getChapterContent(String filePath, Chapter chapter) async {
    // 根据href获取章节内容
    // 返回纯文本和HTML
  }
  
  @override
  Future<String?> extractCover(String filePath) async {
    // 提取EPUB封面图片
  }
}
```

### PdfParser

```dart
class PdfParser implements BookFormatParser {
  @override
  Future<BookMetadata> parse(String filePath) async {
    // 解析PDF文件，提取元数据
  }
  
  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    // 检测章节标题（使用正则表达式）
    // 将PDF页面范围映射为Chapter列表
  }
  
  @override
  Future<ChapterContent> getChapterContent(String filePath, Chapter chapter) async {
    // 根据页码范围获取文本内容
    // 返回纯文本（PDF转换为文本）
  }
  
  @override
  Future<String?> extractCover(String filePath) async {
    // PDF通常没有独立封面，返回null
    return null;
  }
}
```

### TxtParser（未来实现）

```dart
class TxtParser implements BookFormatParser {
  @override
  Future<BookMetadata> parse(String filePath) async {
    // 解析TXT文件（文件名作为标题）
  }
  
  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    // 按固定字数（如每5000字）或章节标题检测分割
    // 映射为Chapter列表
  }
  
  @override
  Future<ChapterContent> getChapterContent(String filePath, Chapter chapter) async {
    // 根据字节范围读取文本
    // 返回纯文本（无HTML）
  }
  
  @override
  Future<String?> extractCover(String filePath) async {
    // TXT无封面，返回null
    return null;
  }
}
```

## 架构流程

### 书籍导入流程

```
用户选择文件
    ↓
BookService.importBook()
    ↓
根据扩展名获取parser = FormatRegistry.getParser(extension)
    ↓
parser.parse(filePath) → BookMetadata
    ↓
保存到数据库
```

### 章节导航流程

```
用户点击书籍
    ↓
BookScreen加载
    ↓
parser = FormatRegistry.getParser(book.format)
    ↓
parser.getChapters(filePath) → List<Chapter>
    ↓
显示章节列表（扁平化）
```

### AI摘要生成流程

```
SummaryService.generateSummariesForBook(book)
    ↓
parser = FormatRegistry.getParser(book.format)
    ↓
chapters = parser.getChapters(filePath)
    ↓
for each chapter:
    content = parser.getChapterContent(filePath, chapter)
    aiService.generateSummary(content.plainText)
```

### 阅读流程

```
用户点击章节
    ↓
ReadingScreen加载
    ↓
parser = FormatRegistry.getParser(book.format)
    ↓
content = parser.getChapterContent(filePath, chapter)
    ↓
渲染：优先使用htmlContent，否则plainText
```

## 向后兼容性

### 现有EPUB功能保持

1. **层级章节处理**：EpubParser内部获取层级章节，但只返回第一级，与当前实际使用一致
2. **章节导航**：ChapterScreen不再需要 `level == 0` 过滤
3. **内容渲染**：EPUB的HTML内容通过 `htmlContent` 字段保留
4. **AI摘要**：统一使用 `plainText` 字段

### 数据迁移

- 数据库Book表已有format字段，无需修改
- 新架构下所有格式统一处理，无需数据迁移

## 未来格式扩展

新增格式只需：

1. 实现 `BookFormatParser` 接口
2. 在 `FormatRegistry.initialize()` 中注册
3. 无需修改阅读界面、AI服务、导航逻辑

## 实施步骤

1. 创建新的数据模型（Chapter, ChapterLocation, ChapterContent, BookMetadata）
2. 创建BookFormatParser接口
3. 创建FormatRegistry
4. 重构EpubService为EpubParser（保持功能不变）
5. 重构PdfService为PdfParser（适配新接口）
6. 修改BookService使用FormatRegistry
7. 修改SummaryService统一处理所有格式
8. 修改BookScreen和ChapterScreen使用新模型
9. 删除旧格式相关的硬编码逻辑

## 优势

1. **单一职责**：每个格式解析器只负责解析，不处理业务逻辑
2. **开闭原则**：新增格式无需修改现有代码
3. **测试友好**：每个解析器可独立测试
4. **代码复用**：阅读、AI、导航逻辑完全复用
5. **维护简单**：格式相关逻辑集中在一处