import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 日志级别，按严重程度从低到高排列
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// 日志服务：分级输出到控制台与文件（单例）
///
/// 日志格式：`[yyyy-MM-dd HH:mm:ss.SSS] LEVEL [TAG] message`
/// 日志文件超过 1MB 时会在下次启动初始化时自动清空。
class LogService {
  static final LogService _instance = LogService._internal();

  factory LogService() => _instance;

  LogService._internal();

  static const int _maxLogSizeBytes = 1024 * 1024;

  LogLevel _minLevel = LogLevel.verbose;

  bool _writeToFile = false;

  String? _logFilePath;

  IOSink? _logSink;

  Future<void> init({
    LogLevel minLevel = LogLevel.verbose,
    bool writeToFile = false,
  }) async {
    _minLevel = minLevel;
    _writeToFile = writeToFile;

    if (_writeToFile) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final logDir = Directory('${appDir.path}/zhidu/logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        _logFilePath = '${logDir.path}/app.log';
        final logFile = File(_logFilePath!);
        if (await logFile.exists()) {
          final length = await logFile.length();
          if (length > _maxLogSizeBytes) {
            await logFile.delete();
          }
        }
        _logSink = File(_logFilePath!).openWrite(mode: FileMode.append);
        info('LogService', '日志服务初始化完成，日志文件: $_logFilePath');
      } catch (e) {
        _writeToFile = false;
        w('LogService', '无法创建日志文件，已禁用文件写入: $e');
      }
    }
  }

  /// 关闭日志文件写入流（应用退出前调用，确保日志已落盘）
  Future<void> dispose() async {
    if (_logSink != null) {
      await _logSink!.close();
      _logSink = null;
    }
  }

  /// 生成统一格式的日志字符串
  String _formatMessage(String tag, String message, LogLevel level) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final levelName = level.name.toUpperCase().padRight(7);
    return '[$timestamp] $levelName [$tag] $message';
  }

  /// 内部日志输出：按级别过滤后写控制台与文件
  void _log(String tag, String message, LogLevel level) {
    if (level.index < _minLevel.index) return;

    final formatted = _formatMessage(tag, message, level);

    // 输出到控制台
    print(formatted);

    // 写入文件
    if (_writeToFile && _logSink != null) {
      _logSink!.writeln(formatted);
    }
  }

  /// Verbose 级日志（最详细的调试信息）
  void v(String tag, String message) => _log(tag, message, LogLevel.verbose);

  /// Debug 级日志（调试信息）
  void d(String tag, String message) => _log(tag, message, LogLevel.debug);

  /// Info 级日志（正常业务流程）
  void info(String tag, String message) => _log(tag, message, LogLevel.info);

  /// Warning 级日志（潜在问题）
  void w(String tag, String message) => _log(tag, message, LogLevel.warning);

  /// Error 级日志（异常 + 堆栈）
  void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    var fullMessage = message;
    if (error != null) {
      fullMessage += '\nError: $error';
    }
    if (stackTrace != null) {
      fullMessage += '\nStackTrace:\n$stackTrace';
    }
    _log(tag, fullMessage, LogLevel.error);
  }
}


