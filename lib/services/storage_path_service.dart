import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'storage_config.dart';
import 'log_service.dart';

/// 存储路径服务 - 管理用户可自定义的存储目录
///
/// 单例模式实现，提供书籍和备份目录的自定义设置功能。
/// 用户可以通过文件选择器更改默认存储位置。
///
/// 默认路径结构：
/// ```
/// Documents/zhidu/
/// ├── books/              # 书籍数据目录
/// │   └── {bookId}/
/// │       ├── metadata.json
/// │       ├── summary.md
/// │       └── chapter-xxx.md
/// └── backups/            # 备份目录
///     └── {timestamp}/
/// ```
///
/// 使用示例：
/// ```dart
/// final storagePath = StoragePathService();
/// await storagePath.init();
///
/// // 获取当前书籍目录
/// final booksDir = await storagePath.getBooksDirectory();
///
/// // 更改书籍存储位置
/// final newPath = await storagePath.pickBooksDirectory();
/// if (newPath != null) {
///   print('新的书籍目录: $newPath');
/// }
/// ```
class StoragePathService {
  /// 单例实例
  static final StoragePathService _instance = StoragePathService._internal();

  /// 工厂构造函数
  factory StoragePathService() => _instance;

  /// 私有命名构造函数
  StoragePathService._internal();

  /// 日志服务
  final _log = LogService();

  /// 自定义书籍目录路径（null表示使用默认路径）
  String? _customBooksDirectory;

  /// 自定义备份目录路径（null表示使用默认路径）
  String? _customBackupDirectory;

  /// 是否已初始化
  bool _initialized = false;

  /// 获取当前书籍目录
  ///
  /// 返回规则：
  /// - 如果用户设置了自定义路径，返回自定义路径
  /// - 否则返回默认路径 `Documents/zhidu/books/`
  ///
  /// 如果目录不存在，会自动创建（包括父目录）。
  ///
  /// Returns:
  ///   书籍存储目录 [Directory] 对象
  Future<Directory> get booksDirectory async {
    if (_customBooksDirectory != null) {
      final dir = Directory(_customBooksDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    // 返回默认路径
    final appDir = await StorageConfig.getAppDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir;
  }

  /// 获取当前备份目录
  ///
  /// 返回规则：
  /// - 如果用户设置了自定义路径，返回自定义路径
  /// - 否则返回默认路径 `Documents/zhidu/backups/`
  ///
  /// 如果目录不存在，会自动创建（包括父目录）。
  ///
  /// Returns:
  ///   备份存储目录 [Directory] 对象
  Future<Directory> get backupDirectory async {
    if (_customBackupDirectory != null) {
      final dir = Directory(_customBackupDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    // 返回默认路径
    final appDir = await StorageConfig.getAppDirectory();
    final backupDir = Directory(p.join(appDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 初始化存储路径服务
  ///
  /// 从持久化存储加载自定义路径设置。
  /// 应用在启动时调用，恢复用户的自定义设置。
  ///
  /// 注意：此服务需要SettingsService先初始化完成，
  /// 因为自定义路径设置存储在SettingsService中。
  Future<void> init() async {
    if (_initialized) return;

    _log.v('StoragePathService', 'init 开始执行');

    // 之前版本用于从SettingsService加载已保存的自定义路径
    // 现在由于移除了存储设置功能，此服务不再需要初始化

    _initialized = true;
    _log.v('StoragePathService', 'init 执行完成');
  }

  /// 设置自定义书籍目录
  ///
  /// 由SettingsService调用，当用户更改设置时更新。
  /// 传入null表示恢复使用默认路径。
  ///
  /// Parameters:
  ///   - [path]: 自定义目录路径，null表示使用默认
  void setBooksDirectory(String? path) {
    _customBooksDirectory = path;
    _log.d('StoragePathService', '书籍目录已设置: ${path ?? "默认路径"}');
  }

  /// 设置自定义备份目录
  ///
  /// 由SettingsService调用，当用户更改设置时更新。
  /// 传入null表示恢复使用默认路径。
  ///
  /// Parameters:
  ///   - [path]: 自定义目录路径，null表示使用默认
  void setBackupDirectory(String? path) {
    _customBackupDirectory = path;
    _log.d('StoragePathService', '备份目录已设置: ${path ?? "默认路径"}');
  }

  /// 获取当前书籍目录路径字符串
  ///
  /// 用于显示在设置界面中，让用户知道当前使用的路径。
  ///
  /// Returns:
  ///   书籍目录的完整路径字符串
  Future<String> getBooksDirectoryPath() async {
    final dir = await booksDirectory;
    return dir.path;
  }

  /// 获取当前备份目录路径字符串
  ///
  /// 用于显示在设置界面中，让用户知道当前使用的路径。
  ///
  /// Returns:
  ///   备份目录的完整路径字符串
  Future<String> getBackupDirectoryPath() async {
    final dir = await backupDirectory;
    return dir.path;
  }

  /// 重置书籍目录为默认值
  ///
  /// 清除自定义设置，恢复使用默认路径。
  void resetBooksDirectory() {
    _customBooksDirectory = null;
    _log.d('StoragePathService', '书籍目录已重置为默认');
  }

  /// 检查是否使用自定义书籍目录
  ///
  /// Returns:
  ///   true表示使用自定义路径，false表示使用默认路径
  bool get isUsingCustomBooksDirectory => _customBooksDirectory != null;

  /// 获取默认书籍目录路径（用于显示对比）
  ///
  /// Returns:
  ///   默认书籍目录的完整路径字符串
  Future<String> getDefaultBooksDirectoryPath() async {
    final appDir = await StorageConfig.getAppDirectory();
    return p.join(appDir.path, 'books');
  }
}