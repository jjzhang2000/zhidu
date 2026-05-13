# StorageConfig - 存储路径配置

## 概述

统一管理应用的存储路径配置，提供获取各目录和文件路径的静态方法。

## 源文件

`lib/services/storage_config.dart`

## 类定义

### StorageConfig

纯静态方法工具类，无实例。

```dart
class StorageConfig {
  // 无实例字段，所有方法为 static
}
```

## 方法列表

### getAppDirectory() → Future<Directory>

获取应用根目录（Documents 下的 zhidu 目录）。

```
路径规则:
  Windows: C:\Users\{username}\Documents\zhidu\
  macOS:   /Users/{username}/Documents/zhidu/
  Android: /storage/emulated/0/Documents/zhidu/ 或应用私有目录
  iOS:     /var/mobile/.../Documents/zhidu/

如果目录不存在，自动创建。
```

### getBooksDirectory() → Future<Directory>

获取书籍存储目录。

```
路径: {appDir}/books/
```

### getBookDirectory(String bookId) → Future<Directory>

获取指定书籍的存储目录。

```
路径: {booksDir}/{bookId}/
```

### getSettingsFilePath() → Future<String>

获取设置文件路径。

```
路径: {appDir}/settings.json
```

### getBooksIndexFilePath() → Future<String>

获取书籍索引文件路径。

```
路径: {appDir}/books.json
```

### getBookMetadataPath(String bookId) → Future<String>

获取书籍元数据文件路径。

```
路径: {booksDir}/{bookId}/metadata.json
```

### getCoverSavePath(String bookId, String mimeType) → Future<String>

获取封面保存路径。

```
根据 MIME 类型确定扩展名:
  image/png  → cover.png
  image/jpeg → cover.jpg

路径: {booksDir}/{bookId}/cover.{ext}
```

### getSummarySavePath(String bookId, String language) → Future<String>

获取全书摘要保存路径。

```
格式: {booksDir}/{bookId}/summary-{lang}.md
示例: summary-zh.md
```

### getChapterSummarySavePath(String bookId, int chapterIndex, String language) → Future<String>

获取章节摘要保存路径。

```
格式: {booksDir}/{bookId}/chapter-{index:3d}-{lang}.md
示例: chapter-003-zh.md
```

### getTranslationSavePath(String bookId, int chapterIndex, String language) → Future<String>

获取章节译文保存路径。

```
格式: {booksDir}/{bookId}/chapter-{index:3d}-{lang}.html
示例: chapter-003-en.html
```

### getAllBookDirs() → Future<List<Directory>>

获取所有书籍目录列表。

```
遍历: {booksDir} 下的所有子目录
```

### getPlatformDocumentsDir() → Future<Directory>

获取平台文档目录。

```
平台:
  Android: /storage/emulated/0/Documents/
  其他:    path_provider 返回的文档目录
```

## 路径约定

| 类型 | 命名格式 | 示例 |
|------|----------|------|
| 应用根目录 | `Documents/zhidu/` | `C:\Users\...\Documents\zhidu\` |
| 书籍索引 | `books.json` | |
| 设置文件 | `settings.json` | |
| 书籍目录 | `books/{bookId}/` | `books/a1b2c3d4/` |
| 元数据 | `metadata.json` | |
| 全书摘要 | `summary-{lang}.md` | `summary-zh.md` |
| 章节摘要 | `chapter-{index:3d}-{lang}.md` | `chapter-003-zh.md` |
| 章节译文 | `chapter-{index:3d}-{lang}.html` | `chapter-003-en.html` |
| 封面 | `cover.{ext}` | `cover.png`, `cover.jpg` |

## 依赖

- `path_provider`: 获取平台文档目录
- `path`: 路径拼接
- `dart:io`: 文件/目录操作