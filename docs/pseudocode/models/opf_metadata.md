# OpfMetadata - OPF 元数据模型

## 概述

Calibre `metadata.opf` 文件的解析结果模型。用于在导入书籍时从同目录下的 OPF 文件获取更精确的元数据（标题、作者、语言、出版社、描述、主题、封面路径）。

## 源文件

`lib/models/opf_metadata.dart`

## 类定义

### OpfMetadata

```dart
class OpfMetadata {
  final String? title;        // 书名
  final String? author;       // 作者
  final String? language;     // 语言代码（如 zh, en, ja）
  final String? coverPath;    // 封面文件路径
  final String? publisher;    // 出版社
  final String? description;  // 书籍描述
  final List<String> subjects; // 主题/标签列表
}
```

## 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `title` | `String?` | 否 | 书籍标题 |
| `author` | `String?` | 否 | 作者名 |
| `language` | `String?` | 否 | 语言代码 |
| `coverPath` | `String?` | 否 | OPF 中引用的封面文件路径 |
| `publisher` | `String?` | 否 | 出版社 |
| `description` | `String?` | 否 | 书籍描述 |
| `subjects` | `List<String>` | 否 | 主题标签列表 |

## 数据来源

- 由 `OpfReaderService` 解析 `metadata.opf` 文件生成
- 在 EPUB/PDF 导入时，`EpubParser`/`PdfParser` 调用 `OpfReaderService.readFromSameDirectory()` 获取
- 解析结果的可空字段会优先覆盖解析器提取的默认元数据

## 使用场景

```dart
// 在导入书籍时读取 OPF 元数据
final opfMeta = await OpfReaderService.readFromSameDirectory(bookFilePath);
if (opfMeta != null) {
  book.title = opfMeta.title ?? book.title;
  book.author = opfMeta.author ?? book.author;
  book.language = opfMeta.language;
  book.publisher = opfMeta.publisher;
  book.description = opfMeta.description;
  book.subjects = opfMeta.subjects;
}
```

## 依赖关系

- **输出给**: Book 模型（合并 OPF 字段）
- **由谁创建**: OpfReaderService._parseOpfContent()
- **不依赖其他模型**