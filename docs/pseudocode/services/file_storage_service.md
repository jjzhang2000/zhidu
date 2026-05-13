# FileStorageService - 文件存储服务

## 概述

文件系统操作服务，提供 JSON/文本文件的读写、文件删除等通用存储操作。

## 源文件

`lib/services/file_storage_service.dart`

## 类定义

### FileStorageService

单例模式服务。

```dart
class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();
  factory FileStorageService() => _instance;
  FileStorageService._internal();
  
  final _log = LogService();
}
```

## 方法列表

### writeJson(String filePath, Map<String, dynamic> data) → Future<bool>

将 Map 数据编码为 JSON 并写入文件。

```
参数:
  filePath: 目标文件路径
  data:     要写入的 Map 数据

返回:
  true:  写入成功
  false: 写入失败（异常）

处理流程:
  1. jsonEncode(data) 编码
  2. File(filePath).writeAsString(encoded)
  3. 异常时记录日志并返回 false
```

### readJson(String filePath) → Future<Map<String, dynamic>?>

从 JSON 文件读取并解码为 Map。

```
参数:
  filePath: JSON 文件路径

返回:
  成功: Map<String, dynamic> 对象
  文件不存在: null
  解码失败: null

处理流程:
  1. 检查文件是否存在 → 不存在返回 null
  2. 读取文件内容
  3. jsonDecode(content) 解码
  4. 返回 Map 或 null
```

### writeText(String filePath, String content) → Future<bool>

写文本内容到文件。

### readText(String filePath) → Future<String?>

读文本文件内容。文件不存在返回 null。

### deleteFile(String filePath) → Future<bool>

删除指定文件。

### deleteDirectory(String dirPath) → Future<bool>

递归删除指定目录及其所有内容。

### fileExists(String filePath) → Future<bool>

检查文件是否存在。

## 使用场景

| 操作 | 调用方 | 存储内容 |
|------|--------|----------|
| `writeJson` | SettingsService | `settings.json` |
| `writeJson` | BookService | `books.json`, `metadata.json` |
| `writeText` | SummaryService | 章节摘要 `.md` 文件 |
| `writeText` | TranslationService | 章节译文 `.html` 文件 |
| `readText` | SummaryService | 读取已有摘要 |
| `deleteFile` | BookService | 删除书籍文件和相关摘要 |
| `deleteDirectory` | BookService | 删除整个书籍目录 |

## 依赖

- `dart:convert`: JSON 编解码
- `dart:io`: 文件/Directory 操作
- `LogService`: 日志记录