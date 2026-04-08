import 'dart:io';
import 'package:intl/intl.dart';

/// 日志级别
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// 日志服务 - 统一管理应用日志
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  LogLevel _minLevel = LogLevel.verbose;
  bool _writeToFile = false;
  String? _logFilePath;
  IOSink? _logSink;

  /// 初始化日志服务
  Future<void> init({
    LogLevel minLevel = LogLevel.verbose,
    bool writeToFile = false,
  }) async {
    _minLevel = minLevel;
    _writeToFile = writeToFile;

    if (_writeToFile) {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      _logFilePath = '${Directory.current.path}/logs/app_$timestamp.log';
      final logDir = Directory('${Directory.current.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      _logSink = File(_logFilePath!).openWrite(mode: FileMode.append);
      info('LogService', '日志服务初始化完成，日志文件: $_logFilePath');
    }
  }

  /// 关闭日志服务
  Future<void> dispose() async {
    if (_logSink != null) {
      await _logSink!.close();
      _logSink = null;
    }
  }

  String _formatMessage(String tag, String message, LogLevel level) {
    final timestamp =
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final levelName = level.name.toUpperCase().padRight(7);
    return '[$timestamp] $levelName [$tag] $message';
  }

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

  /// Verbose级别日志 - 最详细的调试信息
  void v(String tag, String message) => _log(tag, message, LogLevel.verbose);

  /// Debug级别日志 - 调试信息
  void d(String tag, String message) => _log(tag, message, LogLevel.debug);

  /// Info级别日志 - 一般信息
  void info(String tag, String message) => _log(tag, message, LogLevel.info);

  /// Warning级别日志 - 警告信息
  void w(String tag, String message) => _log(tag, message, LogLevel.warning);

  /// Error级别日志 - 错误信息
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

/// 全局日志实例
final log = LogService();
