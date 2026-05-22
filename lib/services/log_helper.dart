import 'dart:io';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

/// 日志服务 - 封装 logging 标准库 + 文件写入功能
///
/// 基于 Dart 官方 logging 库，提供：
/// - 分级日志输出（verbose/debug/info/warning/error）
/// - 控制台输出
/// - 文件持久化
/// - 统一格式化
///
/// 初始化（通常在 main.dart 中调用）：
/// ```dart
/// await LogHelper.init(
///   minLevel: Level.ALL,
///   writeToFile: true,
/// );
/// ```
///
/// 使用（各模块内部创建 Logger 实例）：
/// ```dart
/// import 'package:logging/logging.dart';
///
/// final _log = Logger('EpubParser');
/// _log.info('开始解析: $filePath');
/// _log.warning('解析失败，使用回退方案');
/// _log.severe('致命错误', error, stackTrace);
/// ```
class LogHelper {
  static IOSink? _logSink;

  /// 初始化日志服务
  ///
  /// [minLevel] 最低输出级别，默认 [Level.ALL]（输出所有级别）
  /// [writeToFile] 是否写入文件，默认 false
  ///
  /// 启用文件写入时，日志会保存到应用文档目录的 logs/ 文件夹中。
  static Future<void> init({
    Level minLevel = Level.ALL,
    bool writeToFile = false,
  }) async {
    Logger.root.level = minLevel;
    Logger.root.onRecord.listen(_handleLogRecord);

    if (writeToFile) {
      try {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final appDir = await getApplicationDocumentsDirectory();
        final logDir = Directory('${appDir.path}/logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        final logFilePath = '${logDir.path}/app_$timestamp.log';
        _logSink = File(logFilePath).openWrite(mode: FileMode.append);
        Logger('LogHelper').info('日志服务初始化完成，日志文件: $logFilePath');
      } catch (e) {
        Logger('LogHelper').warning('无法创建日志文件，已禁用文件写入: $e');
      }
    }
  }

  /// 关闭日志服务，释放文件资源
  static Future<void> dispose() async {
    await _logSink?.close();
    _logSink = null;
  }

  static void _handleLogRecord(LogRecord record) {
    final timestamp =
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(record.time);
    final levelName = record.level.name.padRight(7);
    final formatted = '[$timestamp] $levelName [${record.loggerName}] ${record.message}';

    if (record.error != null) {
      print('$formatted\nError: ${record.error}');
      if (record.stackTrace != null) {
        print('StackTrace:\n${record.stackTrace}');
      }
    } else {
      print(formatted);
    }

    _logSink?.writeln(record.error != null
        ? '$formatted\nError: ${record.error}\nStackTrace:\n${record.stackTrace}'
        : formatted);
  }
}
