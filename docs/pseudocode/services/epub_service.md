# EpubService - EPUB 文件解析服务

## 概述

EPUB 文件解析服务，负责 EPUB 文件的导入、元数据提取、章节解析、封面提取。是 `BookService.importBook()` 的核心解析组件。

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
  
  final _uuid = const Uuid();
  final _log = LogService();
}
```

## 方法列表

### parseEpubFile(String filePath) → Future<Book?>

解析 EPUB 文件并创建 Book 对象。

```
参数:
  filePath: EPUB 文件的完整路径

返回:
  成功: Book 对象（含元数据、章节列表、封面）
  失败: null

处理流程:
  1. 使用 epub_plus 库读取 EPUB 文件 (EpubReader.readFromUri)
  2. 提取元数据（title, author）或从文件名回退
  3. 生成 bookId (UUID v4)
  4. 解析章节列表 (_extractChapters)
  5. 提取封面图片 (_extractCover)
  6. 读取同目录 metadata.opf (OpfReaderService)
     → 合并 OPF 元数据（优先覆盖）
  7. 创建 Book 对象
```

### _extractChapters(EpubBook epubBook) → Future<List<Chapter>>

从 EPUB 结构中提取章节列表。

```
处理流程:
  1. 尝试从 EPUB spine 或 toc 获取章节顺序
  2. 对每个章节项提取 title + href
  3. 构造 ChapterLocation 对象
  4. 生成唯一章节 ID
  5. 构建 Chapter 列表

支持:
  - 标准 ToC (Table of Contents)
  - NCX 导航文件
  - NAV HTML 导航文件
  - Spine 线性顺序（回退方案）
```

### _extractCover(EpubBook epubBook, String bookId) → Future<String?>

提取 EPUB 封面图片。

```
处理流程:
  1. 查找 EPUB 内部封面文件引用
  2. 读取封面图片数据
  3. 保存到 books/{bookId}/cover.{ext}
  4. 返回封面路径

回退:
  - 无内部封面时返回 null
```

### _fileNameToTitle(String filePath) → String

从文件路径提取标题（去除扩展名）。

### getChapterContent(String filePath, int chapterIndex) → Future<ChapterContent?>

获取指定章节的内容（HTML + 纯文本）。

```
参数:
  filePath: EPUB 文件路径
  chapterIndex: 章节索引

返回:
  ChapterContent { htmlContent, plainText }

处理流程:
  1. 打开 EPUB 文件
  2. 获取章节 HTML 文件路径
  3. 读取 HTML 内容
  4. 解析 HTML 提取纯文本（去除标签）
  5. 返回 ChapterContent
```

## 数据流

```
EPUB 文件
    ↓
EpubService.parseEpubFile()
    ↓
EpubReader.readFromUri()  → EpubBook 对象
    ↓
_extractChapters()         → List<Chapter>
_extractCover()            → cover.jpg/png 路径
OpfReaderService.readFromSameDirectory() → OpfMetadata
    ↓
合并 OPF 元数据
    ↓
Book 对象（含元数据 + 章节列表 + 封面路径）
```

## 依赖

- `epub_plus`: EPUB 解析核心库
- `OpfReaderService`: 外部 OPF 元数据读取
- `LogService`: 日志
- `StorageConfig`: 封面存储路径
- `Book` / `BookFormat` / `Chapter`: 数据模型
- `File`: 文件操作
- `uuid`: UUID 生成