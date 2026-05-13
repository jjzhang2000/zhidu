# PdfService - PDF 文件解析服务

## 概述

PDF 文件解析服务，负责 PDF 文件的导入、元数据提取、章节检测、封面渲染和内容读取。

## 源文件

`lib/services/pdf_service.dart`

## 类定义

### PdfService

单例模式服务，使用 `pdfrx` 库进行 PDF 解析。

```dart
class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();
  
  final _uuid = const Uuid();
  final _log = LogService();
}
```

### 辅助模型

#### PdfChapter

```dart
class PdfChapter {
  final int index;       // 章节索引 (0-based)
  final String title;    // 章节标题（如"第一章"）
  final int startPage;   // 起始页码 (1-based)
  final int endPage;     // 结束页码 (1-based)
}
```

#### PdfPageContent

```dart
class PdfPageContent {
  final int pageNumber;  // 页码 (1-based)
  final String content;  // 页面文本内容
}
```

## 方法列表

### parsePdfFile(String filePath) → Future<Book?>

解析 PDF 文件并创建 Book 对象。

```
参数:
  filePath: PDF 文件的完整路径

返回:
  成功: Book 对象
  失败: null

处理流程:
  1. PdfDocument.openFile(filePath) 打开 PDF
  2. 获取总页数
  3. 从文件名提取标题
  4. _detectChapters() 检测章节结构
  5. _extractCover() 渲染第一页为封面图片
  6. OpfReaderService.readFromSameDirectory() 读取 OPF 元数据
     → 合并 OPF 元数据（优先覆盖标题、作者、语言等）
  7. 创建 Book(format: BookFormat.pdf)
  8. document.dispose() 释放资源
```

### _detectChapters(PdfDocument document) → Future<List<PdfChapter>>

检测 PDF 中的章节结构（核心算法）。

```
算法:
  1. 遍历所有页面，提取文本内容
  2. 使用正则匹配章节标题模式：
     - 第[一二三四五六七八九十百]+章   (中文数字章节)
     - 第\d+章                         (数字章节)
     - Chapter\s+\d+                   (英文Chapter)
     - CHAPTER\s+\d+                   (英文CHAPTER)
     - ^\d+\.\s+[A-Za-z]              (数字点号格式)
     - ^[A-Z][a-z]+\s+\d+             (英文单词+数字)
  3. 根据匹配位置确定章节边界
  4. 创建 PdfChapter 列表（含标题、页码范围）
```

### _extractCover(PdfDocument document, String bookId) → Future<String?>

渲染 PDF 第一页为封面图片。

```
处理流程:
  1. 获取第一页（如无页面则返回 null）
  2. 计算渲染尺寸（宽度 600px，高度等比缩放）
  3. firstPage.render() 渲染页面
  4. 像素格式处理（BGRA8888 / RGBA8888）
  5. 编码为 PNG 格式
  6. 保存到 StorageConfig.getCoverSavePath()
  7. 返回封面路径
```

### getChapterPages(String filePath, int chapterIndex) → Future<List<PdfPageContent>>

获取指定章节的所有页面内容。

### getChapterPageRange(String filePath, int chapterIndex) → Future<List<int>>

获取指定章节的页码范围（1-based）。

### getPageContent(String filePath, int pageNumber) → Future<PdfPageContent>

获取指定页面内容。

## 章节检测正则模式

| 优先级 | 模式 | 匹配示例 |
|--------|------|----------|
| 1 | `第[一二三四五六七八九十百]+章` | 第一章、第十章、第一百二十章 |
| 2 | `第\d+章` | 第1章、第23章 |
| 3 | `Chapter\s+\d+` | Chapter 1, Chapter 23 |
| 4 | `CHAPTER\s+\d+` | CHAPTER 1 |
| 5 | `^\d+\.\s+[A-Za-z]` | 1. Introduction |
| 6 | `^[A-Z][a-z]+\s+\d+` | Part 1 |

## 封面渲染技术细节

- **渲染库**: pdfrx 的 `page.render()`
- **目标尺寸**: 宽度 600px，高度等比
- **像素格式**: 支持 BGRA8888 和 RGBA8888
- **背景色**: 白色（避免透明背景）
- **输出格式**: PNG
- **保存位置**: `books/{bookId}/cover.png`

## 数据流

```
PDF 文件
    ↓
PdfService.parsePdfFile()
    ↓
PdfDocument.openFile()  → PdfDocument 对象
    ↓
_detectChapters()       → List<PdfChapter>
_extractCover()         → cover.png 路径
OpfReaderService.readFromSameDirectory() → OpfMetadata (可选)
    ↓
合并 OPF 元数据
    ↓
Book(format: BookFormat.pdf)
```

## 依赖

- `pdfrx`: PDF 渲染和文本提取
- `OpfReaderService`: 外部 OPF 元数据读取
- `LogService`: 日志
- `StorageConfig`: 封面存储路径
- `Book` / `BookFormat`: 数据模型
- `uuid`: UUID 生成
- `image`: PNG 编码
- `dart:ui`: 像素格式处理