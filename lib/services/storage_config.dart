import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 存储配置服务 - 管理应用文件存储路径
///
/// 提供统一的文件存储路径管理，所有文件存储在 Documents/zhidu/ 目录下。
/// 采用单例模式，避免重复创建目录。
///
/// 目录结构：
/// ```
/// Documents/zhidu/
/// ├── books.json          # 书籍索引文件
/// └── books/
///     └── {bookId}/       # 每本书独立目录
///         ├── metadata.json      # 书籍元数据
///         ├── summary.md        # 书籍摘要
///         ├── chapter-001.md     # 章节摘要（按章节编号）
///         ├── chapter-002.md
///         └── cover.jpg/png     # 封面图片
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

  /// 获取应用数据根目录
  ///
  /// 返回应用专用存储目录 `Documents/zhidu/`。
  /// 如果目录不存在，会自动创建（包括父目录）。
  ///
  /// 示例路径：
  /// - Windows: `C:\Users\{username}\Documents\zhidu\`
  /// - macOS: `/Users/{username}/Documents/zhidu/`
  /// - Android: `/storage/emulated/0/Documents/zhidu/` 或应用私有目录
  /// - iOS: `/var/mobile/Containers/Data/Application/{uuid}/Documents/zhidu/`
  ///
  /// Returns:
  ///   应用数据根目录 [Directory] 对象
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

  /// 获取书籍索引文件路径
  ///
  /// 返回 `Documents/zhidu/books.json` 文件路径。
  /// 该文件存储所有书籍的简要索引信息，包括：
  /// - 书籍ID、标题、作者
  /// - 格式（EPUB/PDF）
  /// - 原始文件路径
  /// - 添加时间
  ///
  /// Returns:
  ///   索引文件的完整路径字符串
  static Future<String> getBooksIndexPath() async {
    final appDir = await getAppDirectory();
    return p.join(appDir.path, 'books.json');
  }

  /// 获取书籍目录
  ///
  /// 返回指定书籍的存储目录 `Documents/zhidu/books/{bookId}/`。
  /// 每本书都有独立的目录，存储其元数据、摘要和封面。
  /// 如果目录不存在，会自动创建。
  ///
  /// Parameters:
  ///   - [bookId]: 书籍唯一标识符
  ///
  /// Returns:
  ///   书籍目录 [Directory] 对象
  static Future<Directory> getBookDirectory(String bookId) async {
    final appDir = await getAppDirectory();
    final bookDir = Directory(p.join(appDir.path, 'books', bookId));

    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }

    return bookDir;
  }

  /// 获取书籍元数据文件路径
  ///
  /// 返回 `Documents/zhidu/books/{bookId}/metadata.json` 文件路径。
  /// 该文件存储书籍的完整元数据，包括：
  /// - 基本信息：ID、标题、作者、出版社、语言
  /// - 文件信息：格式、原始路径、文件大小
  /// - 阅读状态：当前章节、阅读进度
  /// - 时间戳：添加时间、最后阅读时间
  /// - 章节列表：章节标题、路径、索引
  ///
  /// Parameters:
  ///   - [bookId]: 书籍唯一标识符
  ///
  /// Returns:
  ///   元数据文件的完整路径字符串
  static Future<String> getBookMetadataPath(String bookId) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(bookDir.path, 'metadata.json');
  }

  /// 获取书籍摘要文件路径
  ///
  /// 返回 `Documents/zhidu/books/{bookId}/summary.md` 文件路径。
  /// 该文件存储全书级别的AI生成摘要，包括：
  /// - 核心主题和观点
  /// - 主要章节概要
  /// - 关键结论
  ///
  /// 使用Markdown格式存储，方便阅读和导出。
  ///
  /// Parameters:
  ///   - [bookId]: 书籍唯一标识符
  ///
  /// Returns:
  ///   摘要文件的完整路径字符串
  static Future<String> getBookSummaryPath(String bookId) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(bookDir.path, 'summary.md');
  }

  /// 获取章节摘要文件路径
  ///
  /// 返回 `Documents/zhidu/books/{bookId}/chapter-{index}.md` 文件路径。
  /// 章节索引使用3位数字零填充（如 001, 002, 012, 123）。
  /// 这确保文件按章节顺序正确排序。
  ///
  /// 示例：
  /// - 第1章: `chapter-001.md`
  /// - 第12章: `chapter-012.md`
  /// - 第123章: `chapter-123.md`
  ///
  /// Parameters:
  ///   - [bookId]: 书籍唯一标识符
  ///   - [chapterIndex]: 章节索引（从0或1开始，取决于书籍结构）
  ///
  /// Returns:
  ///   章节摘要文件的完整路径字符串
  static Future<String> getChapterSummaryPath(
      String bookId, int chapterIndex) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(
        bookDir.path, 'chapter-${chapterIndex.toString().padLeft(3, '0')}.md');
  }

  /// 获取封面文件路径
  ///
  /// 查找书籍的封面图片文件，支持 JPG 和 PNG 格式。
  /// 优先返回存在的文件路径，若都不存在则返回 null。
  ///
  /// 查找顺序：
  /// 1. `cover.jpg`
  /// 2. `cover.png`
  ///
  /// Parameters:
  ///   - [bookId]: 书籍唯一标识符
  ///
  /// Returns:
  ///   封面文件路径，若不存在则返回 null
  static Future<String?> getCoverPath(String bookId) async {
    final bookDir = await getBookDirectory(bookId);
    final jpgPath = p.join(bookDir.path, 'cover.jpg');
    final pngPath = p.join(bookDir.path, 'cover.png');

    if (await File(jpgPath).exists()) {
      return jpgPath;
    }
    if (await File(pngPath).exists()) {
      return pngPath;
    }
    return null;
  }

  /// 获取封面保存路径
  ///
  /// 根据 MIME 类型确定封面文件的扩展名。
  /// - `image/png` → `cover.png`
  /// - `image/jpeg` 或其他 → `cover.jpg`
  ///
  /// 用于从 EPUB 中提取封面时确定保存文件名。
  ///
  /// Parameters:
  ///   - [bookId]: 书籍唯一标识符
  ///   - [mimeType]: 图片的 MIME 类型（如 `image/jpeg`, `image/png`）
  ///
  /// Returns:
  ///   封面保存路径字符串
  static Future<String> getCoverSavePath(String bookId, String mimeType) async {
    final bookDir = await getBookDirectory(bookId);
    final extension = mimeType.contains('png') ? 'png' : 'jpg';
    return p.join(bookDir.path, 'cover.$extension');
  }
}
