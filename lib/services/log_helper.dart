import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// 日志服务 - 封装 logger 库 + 文件轮转输出
///
/// 基于 logger 第三方库，提供：
/// - 分级日志输出（trace/debug/info/warning/error/fatal）
/// - 控制台输出（PrettyPrinter 彩色格式化）
/// - 文件持久化（1MB 自动轮转，只保留最近一份）
///
/// 初始化（通常在 main.dart 中调用）：
/// ```dart
/// await LogHelper.init();
/// ```
///
/// 使用（各模块内部创建 Logger 实例，共享同一个 LogOutput）：
/// ```dart
/// import 'package:logger/logger.dart';
///
/// final _log = Logger(tag: 'EpubParser', output: LogHelper.output);
/// _log.i('开始解析: $filePath');
/// _log.w('解析失败，使用回退方案');
/// _log.e('致命错误', error: error, stackTrace: stackTrace);
/// ```
class LogHelper {
  static const int _maxLogFileSize = 1 * 1024 * 1024;
  static const String _logFileName = 'app.log';

  /// 全局日志输出器，所有 Logger 实例共享
  static LogOutput? output;

  /// 初始化日志服务
  ///
  /// 同时输出到控制台和文件。文件达到 1MB 时自动清空轮转。
  static Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${appDir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final logFile = File('${logDir.path}/$_logFileName');

    output = _FileRotatingOutput(logFile);
  }

  /// 关闭日志服务，释放资源
  static Future<void> dispose() async {
    await output?.destroy();
    output = null;
  }
}

/// 自定义日志输出：同时写入控制台和文件，支持大小轮转
class _FileRotatingOutput extends LogOutput {
  final File _logFile;

  _FileRotatingOutput(this._logFile);

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      print(line);
    }

    final content = event.lines.join('\n');
    try {
      final stat = _logFile.statSync();
      if (stat.size > LogHelper._maxLogFileSize) {
        _logFile.writeAsStringSync('', mode: FileMode.write);
      }
      _logFile.writeAsStringSync('$content\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // 文件写入失败时静默忽略
    }
  }
}
