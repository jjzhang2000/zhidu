# StoragePathService - 存储路径管理服务

## 概述

管理用户可自定义的存储目录路径。支持通过文件选择器更改默认存储位置，提供书籍目录和备份目录的自定义设置。

## 源文件

`lib/services/storage_path_service.dart`

## 类定义

### StoragePathService

单例模式服务。

```dart
class StoragePathService {
  static final StoragePathService _instance = StoragePathService._internal();
  factory StoragePathService() => _instance;
  StoragePathService._internal();

  final _log = LogService();
  String? _customBooksDirectory;      // 自定义书籍目录
  String? _customBackupDirectory;     // 自定义备份目录
  bool _initialized = false;
}
```

## 核心属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `_customBooksDirectory` | `String?` | 自定义书籍目录路径，null=使用默认 |
| `_customBackupDirectory` | `String?` | 自定义备份目录路径，null=使用默认 |
| `_initialized` | `bool` | 是否已初始化 |

## 方法列表

### get booksDirectory → Future<Directory>

获取当前书籍目录（自定义优先，否则默认 `Documents/zhidu/books/`）。目录不存在时自动创建。

### get backupDirectory → Future<Directory>

获取当前备份目录（自定义优先，否则默认 `Documents/zhidu/backups/`）。目录不存在时自动创建。

### init() → Future<void>

初始化存储路径服务（从设置加载自定义路径）。

```
调用时机: 应用启动时
前置条件: SettingsService 已初始化
```

### setBooksDirectory(String? path)

设置自定义书籍目录。null 表示恢复默认。

### setBackupDirectory(String? path)

设置自定义备份目录。null 表示恢复默认。

### getBooksDirectoryPath() → Future<String>

获取当前书籍目录路径字符串（用于 UI 显示）。

### getBackupDirectoryPath() → Future<String>

获取当前备份目录路径字符串（用于 UI 显示）。

### resetBooksDirectory()

重置书籍目录为默认。

### get isUsingCustomBooksDirectory → bool

检查是否使用自定义书籍目录。

### getDefaultBooksDirectoryPath() → Future<String>

获取默认书籍目录路径字符串（用于对比显示）。

## 默认路径结构

```
Documents/zhidu/
├── books/              ← 默认书籍目录
│   └── {bookId}/
│       ├── metadata.json
│       ├── summary-zh.md
│       └── chapter-xxx-zh.md
├── backups/            ← 默认备份目录
│   └── {timestamp}/
├── settings.json
└── books.json
```

## 使用示例

```dart
final storagePath = StoragePathService();
await storagePath.init();

// 获取当前书籍目录
final booksDir = await storagePath.booksDirectory;

// 设置自定义路径
storagePath.setBooksDirectory('/custom/path/books');

// 获取路径用于 UI 显示
final bookPath = await storagePath.getBooksDirectoryPath();
```

## 依赖

- `StorageConfig`: 默认路径配置
- `LogService`: 日志
- `file_picker`: 文件/目录选择器
- `path`: 路径拼接