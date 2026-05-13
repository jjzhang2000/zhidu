# OpfReaderService - OPF 元数据读取服务

## 概述

从 Calibre 生成的 `metadata.opf` 文件读取书籍元数据。支持从指定的 OPF 文件路径读取，或从书籍文件同目录下自动查找。

## 源文件

`lib/services/opf_reader_service.dart`

## 类定义

### OpfReaderService

纯静态方法服务，不含实例字段，所有方法通过类名直接调用。

```dart
class OpfReaderService {
  static final _log = LogService();
}
```

## 方法列表

### readFromOpfFile(String opfPath) → Future<OpfMetadata?>

从指定的 OPF 文件路径读取并解析元数据。

```
参数:
  opfPath: OPF 文件的完整路径

返回:
  成功: OpfMetadata 对象
  失败: null

处理流程:
  1. 检查文件是否存在
  2. 读取文件内容
  3. 调 _parseOpfContent 解析 XML
  4. 返回 OpfMetadata
```

### readFromSameDirectory(String bookFilePath) → Future<OpfMetadata?>

从书籍文件同目录下查找 `metadata.opf` 并解析。

```
参数:
  bookFilePath: 书籍文件（.epub/.pdf）的完整路径

返回:
  找到并解析成功: OpfMetadata 对象
  未找到或解析失败: null

处理流程:
  1. 获取书籍文件所在目录
  2. 拼接 metadata.opf 路径
  3. 检查文件是否存在
  4. 存在则调 readFromOpfFile()
```

### _parseOpfContent(String content) → OpfMetadata?

解析 OPF 文件XML内容，提取元数据字段。

```
解析字段:
  - dc:title    → title
  - dc:creator  → author（多个用逗号拼接）
  - dc:language → language
  - dc:publisher → publisher
  - dc:description → description
  - dc:subject  → subjects（列表）
  - meta[cover] → coverPath（需在 manifest 中查找对应项）

处理流程:
  1. XmlDocument.parse(content)
  2. 查找 metadata 元素
  3. 逐字段提取
  4. 封面需通过 meta[cover] → manifest item 关联
```

## 数据流

```
书籍目录/
├── 倚天屠龙记.epub
└── metadata.opf          ← Calibre 生成的元数据文件
      ↓
OpfReaderService.readFromSameDirectory(bookFilePath)
      ↓
_parseOpfContent(XML 内容)
      ↓
OpfMetadata { title, author, language, ... }
      ↓
合并到 Book / PdfService 解析结果中
```

## 依赖

- `xml` 包: XML 解析
- `path` 包: 路径拼接
- `OpfMetadata` 模型
- `LogService`: 日志记录