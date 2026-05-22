import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// 日志服务 - 封装 logger 库 + 内置文件轮转输出
///
/// 基于 logger 第三方库，提供：
/// - 分级日志输出（trace/debug/info/warning/error/fatal）
/// - 控制台输出（PrettyPrinter 彩色格式化）
/// - 文件持久化（AdvancedFileOutput 1MB 自动轮转，最多保留 2 份备份）
///
/// 初始化（通常在 main.dart 中调用）：
/// ```dart
/// await LogHelper.init();
/// ```
///
/// 使用（各模块内部创建 Logger 实例）：
/// ```dart
/// import 'package:logger/logger.dart';
///
/// final _log = LogHelper.createLogger('EpubParser');
/// _log.i('开始解析: $filePath');
/// _log.w('解析失败，使用回退方案');
/// _log.e('致命错误', error: error, stackTrace: stackTrace);
/// ```
class LogHelper {
  static const int _maxFileSizeKB = 1024; // 1MB
  static const int _maxRotatedFilesCount = 2;
  static const String _logFileName = 'app.log';

  static AdvancedFileOutput? _output;

  /// 创建带模块标签的 Logger 实例
  ///
  /// 标签会显示在每条日志输出中，方便区分来源模块。
  static Logger createLogger(String tag) {
    return Logger(
      printer: _TaggedPrinter(tag),
      output: _output ?? ConsoleOutput(),
    );
  }

  /// 初始化日志服务
  ///
  /// 同时输出到控制台和文件。文件达到 1MB 时自动轮转。
  static Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${appDir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    Logger.level = Level.trace;
    _output = AdvancedFileOutput(
      path: logDir.path,
      latestFileName: _logFileName,
      maxFileSizeKB: _maxFileSizeKB,
      maxRotatedFilesCount: _maxRotatedFilesCount,
    );
    Logger.defaultOutput = () => _output!;
  }
}

/// 自定义日志打印机：在 PrettyPrinter 输出前加上模块标签
class _TaggedPrinter extends LogPrinter {
  final String _tag;
  final PrettyPrinter _printer;

  _TaggedPrinter(this._tag) : _printer = PrettyPrinter(methodCount: 0);

  @override
  List<String> log(LogEvent event) {
    final lines = _printer.log(event);
    return lines.map((line) => '[$_tag] $line').toList();
  }
}
