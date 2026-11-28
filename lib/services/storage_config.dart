import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 存储配置服务：统一管理应用文件路径，数据均位于 Documents/zhidu/
///
/// 目录结构：
/// ```
/// Documents/zhidu/
/// ├── books.json         # 书架索引
/// ├── settings.json      # 应用设置
/// ├── window_state.json  # 桌面窗口状态
/// └── books/{bookId}/    # 每本书：metadata.json、abbr-*.md、chapter-*.html、cover.*
/// ```
class StorageConfig {
  /// 应用数据根目录缓存
  ///
  /// 首次调用 [getAppDirectory] 后缓存，避免重复获取系统目录。
  static Directory? _appDir;

  /// 测试用：重置缓存状态
  @visibleForTesting
  static void resetForTest() {
    _appDir = null;
    _testBaseDir = null;
  }

  /// 测试用：设置测试基础目录（跳过path_provider）
  static Directory? _testBaseDir;

  @visibleForTesting
  static void setTestBaseDirectory(Directory dir) {
    _testBaseDir = dir;
  }

  /// 获取应用数据根目录 `Documents/zhidu/`，不存在时自动创建
  static Future<Directory> getAppDirectory() async {
    if (_appDir != null) return _appDir!;

    Directory docsDir;
    if (_testBaseDir != null) {
      docsDir = _testBaseDir!;
    } else {
      docsDir = await getApplicationDocumentsDirectory();
    }
    _appDir = Directory(p.join(docsDir.path, 'zhidu'));

    if (!await _appDir!.exists()) {
      await _appDir!.create(recursive: true);
    }

    return _appDir!;
  }

  /// 书籍索引文件 `Documents/zhidu/books.json` 的路径
  static Future<String> getBooksIndexPath() async {
    final appDir = await getAppDirectory();
    return p.join(appDir.path, 'books.json');
  }

  /// 书籍目录路径 `Documents/zhidu/books/{bookId}/`（不创建目录）
  ///
  /// 与 [getBookDirectory] 的区别仅为不创建目录，适用于删除等只需路径的场景。
  static Future<String> getBookDirectoryPath(String bookId) async {
    final appDir = await getAppDirectory();
    return p.join(appDir.path, 'books', bookId);
  }

  /// 书籍目录 `Documents/zhidu/books/{bookId}/`，不存在时自动创建
  static Future<Directory> getBookDirectory(String bookId) async {
    final bookDirPath = await getBookDirectoryPath(bookId);
    final bookDir = Directory(bookDirPath);

    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }

    return bookDir;
  }

  /// 书籍元数据文件 `Documents/zhidu/books/{bookId}/metadata.json` 的路径
  static Future<String> getBookMetadataPath(String bookId) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(bookDir.path, 'metadata.json');
  }

  /// 章节缩写文件 `abbr-{index}-{lang}.md` 的路径（索引 3 位补零）
  ///
  /// 例：第 1 章中文 → `abbr-001-zh.md`
  static Future<String> getChapterAbbreviationPath(
      String bookId, int chapterIndex, {String language = 'zh'}) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(
        bookDir.path, 'abbr-${chapterIndex.toString().padLeft(3, '0')}-$language.md');
  }

  /// 章节译文文件 `chapter-{index}-{lang}.html` 的路径（索引 3 位补零）
  ///
  /// 例：第 1 章英文译文 → `chapter-001-en.html`
  static Future<String> getChapterTranslationPath(
      String bookId, int chapterIndex, String targetLang) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(
        bookDir.path, 'chapter-${chapterIndex.toString().padLeft(3, '0')}-$targetLang.html');
  }

  /// 封面保存路径 `books/{bookId}/cover.{extension}`
  static Future<String> getCoverSavePath(String bookId, String extension) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(bookDir.path, 'cover.$extension');
  }
}
