import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'book_service.dart';
import 'log_service.dart';
import 'storage_config.dart';

/// 书库后台导入服务
///
/// 负责 Calibre 书库的后台导入与断点续传：
/// - 导入在后台异步执行，前台不显示进度
/// - 每导入 10 本或导入完成时通过 [refreshSignal] 通知首页刷新
/// - 进度持久化到本地文件，程序退出时保存，下次启动自动恢复
class LibraryImportService {
  LibraryImportService._internal();

  static final LibraryImportService _instance =
      LibraryImportService._internal();

  factory LibraryImportService() => _instance;

  final LogService _log = LogService();
  final BookService _bookService = BookService();

  /// 首页刷新信号：每导入 10 本或导入完成时 +1
  final ValueNotifier<int> refreshSignal = ValueNotifier<int>(0);

  /// 当前导入任务（null 表示无进行中的任务）
  LibraryImportTask? _currentTask;

  /// 是否正在导入
  bool get isImporting => _currentTask != null;

  /// 进度持久化文件名
  static const String _progressFileName = 'library_import_progress.json';

  /// 初始化：加载持久化进度，若有未完成任务则自动恢复
  Future<void> init() async {
    try {
      final progressPath = await _progressFilePath();
      final file = File(progressPath);
      if (!await file.exists()) return;

      final data = jsonDecode(await file.readAsString());
      final task = LibraryImportTask.fromJson(data as Map<String, dynamic>);
      if (task.pendingOpfFiles.isEmpty) {
        await _deleteProgress();
        return;
      }

      _currentTask = task;
      _log.info('LibraryImportService',
          '恢复导入任务: 剩余 ${task.pendingOpfFiles.length} 本');
      // 后台恢复，不阻塞启动流程
      _runImportLoop();
    } catch (e, stackTrace) {
      _log.e('LibraryImportService', '恢复导入任务失败', e, stackTrace);
    }
  }

  /// 启动书库后台导入
  Future<void> startImport(String libraryPath) async {
    if (_currentTask != null) {
      _log.w('LibraryImportService', '已有导入任务进行中，忽略新的导入请求');
      return;
    }

    final opfFiles = await _bookService.scanCalibreOpfFiles(libraryPath);
    if (opfFiles.isEmpty) {
      _log.info('LibraryImportService', '书库无书籍可导入: $libraryPath');
      return;
    }

    _currentTask = LibraryImportTask(
      libraryPath: libraryPath,
      pendingOpfFiles: opfFiles,
      importedCount: 0,
    );
    await _saveProgress();
    _log.info('LibraryImportService', '开始后台导入: ${opfFiles.length} 本');
    _runImportLoop();
  }

  /// 后台导入循环
  Future<void> _runImportLoop() async {
    final task = _currentTask;
    if (task == null) return;

    while (task.pendingOpfFiles.isNotEmpty) {
      final opfPath = task.pendingOpfFiles.first;
      try {
        await _bookService.importOpfFile(opfPath);
      } catch (e) {
        _log.w('LibraryImportService', '导入失败: $opfPath - $e');
      }

      task.pendingOpfFiles.removeAt(0);
      task.importedCount++;

      if (task.importedCount % 10 == 0) {
        refreshSignal.value++;
        await _saveProgress();
      }

      // 让出事件循环，避免长时间占用导致 UI 卡顿
      await Future<void>.delayed(Duration.zero);
    }

    // 导入完成
    refreshSignal.value++;
    _currentTask = null;
    await _deleteProgress();
    _log.info('LibraryImportService', '导入完成: 共 ${task.importedCount} 本');
  }

  /// 保存导入进度（供程序退出时调用）
  Future<void> saveProgress() => _saveProgress();

  Future<void> _saveProgress() async {
    final task = _currentTask;
    if (task == null) return;
    try {
      final path = await _progressFilePath();
      await File(path).writeAsString(jsonEncode(task.toJson()));
    } catch (e, stackTrace) {
      _log.e('LibraryImportService', '保存导入进度失败', e, stackTrace);
    }
  }

  Future<void> _deleteProgress() async {
    try {
      final path = await _progressFilePath();
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e, stackTrace) {
      _log.e('LibraryImportService', '删除导入进度失败', e, stackTrace);
    }
  }

  Future<String> _progressFilePath() async {
    final appDir = await StorageConfig.getAppDirectory();
    return p.join(appDir.path, _progressFileName);
  }
}

/// 书库导入任务（可序列化，用于断点续传）
class LibraryImportTask {
  LibraryImportTask({
    required this.libraryPath,
    required this.pendingOpfFiles,
    required this.importedCount,
  });

  final String libraryPath;
  final List<String> pendingOpfFiles;
  int importedCount;

  Map<String, dynamic> toJson() => {
        'libraryPath': libraryPath,
        'pendingOpfFiles': pendingOpfFiles,
        'importedCount': importedCount,
      };

  factory LibraryImportTask.fromJson(Map<String, dynamic> json) {
    return LibraryImportTask(
      libraryPath: json['libraryPath'] as String? ?? '',
      pendingOpfFiles: (json['pendingOpfFiles'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      importedCount: json['importedCount'] as int? ?? 0,
    );
  }
}
