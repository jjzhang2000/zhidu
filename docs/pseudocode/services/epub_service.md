# EpubService - EPUB 文件解析服务

## 概述

EPUB 文件解析服务，负责 EPUB 文件的导入、元数据提取、章节标题计数、封面提取。是 `BookService.importBook()` 的核心解析组件。

## 源文件

`lib/services/epub_service.dart`

## 类定义

### EpubService

单例模式服务。

```dart
class EpubService {
  static final EpubService _instance = EpubService._internal();
  factory EpubService() => _instance;
  EpubService._internal();
  
  final _log = LogService();
}
```

## 方法列表

### parseEpubFile(String filePath, String bookId) → Future<Book?>

解析 EPUB 文件并创建 Book 对象。

```
参数:
  filePath: EPUB 文件的完整路径
  bookId: 书籍唯一标识符（由 BookService 生成）

返回:
  成功: Book 对象（含元数据、章节计数、封面）
  失败: null

处理流程:
  1. EpubReader.readBook() 解析 EPUB
     → 提取 title, author, chapterTitles
  2. 解析失败时回退到 archive 方案
     → _parseContainerXml() → _parseOpfFile() → _parseNavigationFile()
  3. 标题回退: _extractTitleFromPath()
  4. _extractCover() 提取封面（EpubReader → archive 回退）
  5. 创建并返回 Book 对象
```

### _extractChapterTitles(List<EpubChapter> chapters) → List<String>

从 EpubChapter 树中提取章节标题列表（递归遍历 subChapters）。

### _extractTextFromHtml(String html) → String

从 HTML 字符串中去除 script/style 标签、HTML 标签、实体，返回纯文本。

### _extractTitleFromPath(String filePath) → String

从文件路径提取标题（去除扩展名，替换 _/- 为空格）。

### _parseContainerXml(Archive archive) → Map<String, String>?

解析 META-INF/container.xml，提取 OPF 文件路径。

### _parseOpfFile(Archive archive) → Map<String, String?>?

解析 OPF 文件，提取 title 和 author。

### _parseNavigationFile(Archive archive) → List<String>

解析 NCX/NAV 导航文件，提取章节标题列表。

### _extractCover(Uint8List bytes, String bookId) → Future<String?>

提取 EPUB 封面（EpubReader 主路径 → archive 回退）。

### _extractCoverFromArchive(Uint8List bytes, String bookId) → Future<String?>

从 archive 中按模式匹配提取封面图片。

## 数据流

```
EPUB 文件
    ↓
EpubService.parseEpubFile(filePath, bookId)
    ↓
EpubReader.readBook()  → title, author, chapters
    ↓ (失败回退)
_parseContainerXml() → _parseOpfFile() → _parseNavigationFile()
    ↓
_extractCover() → cover.jpg/png 路径
    ↓
Book 对象（id=bookId, title, author, totalChapters, coverPath）
```

## 依赖

- `epub_plus`: EPUB 解析核心库
- `archive`: ZIP 解压（回退方案）
- `xml`: XML 解析（container.xml/OPF/NCX）
- `path`: 文件名提取
- `LogService`: 日志
- `StorageConfig`: 封面存储路径
- `Book` / `BookFormat`: 数据模型
