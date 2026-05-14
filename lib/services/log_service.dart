import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// 日志级别枚举
///
/// 定义日志的严重程度，按优先级从低到高排列：
/// - [verbose]: 最详细的调试信息，用于开发调试
/// - [debug]: 调试信息，用于问题排查
/// - [info]: 一般信息，记录正常的业务流程
/// - [warning]: 警告信息，表示潜在问题
/// - [error]: 错误信息，表示程序异常
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// 日志服务 - 统一管理应用日志
///
/// 单例模式的日志管理服务，提供以下功能：
/// - 分级别日志输出（verbose/debug/info/warning/error）
/// - 控制台输出（开发调试）
/// - 文件写入（生产环境日志持久化）
/// - 统一格式化（时间戳 + 级别 + 标签 + 消息）
///
/// 使用示例：
/// ```dart
/// final log = LogService();
///
/// // 初始化（可选写入文件）
/// await log.init(writeToFile: true);
///
/// // 各级别日志
/// log.v('TAG', '详细调试信息');
/// log.d('TAG', '调试信息');
/// log.info('TAG', '一般信息');
/// log.w('TAG', '警告信息');
/// log.e('TAG', '错误信息', error, stackTrace);
///
/// // 关闭服务
/// await log.dispose();
/// ```
class LogService {
  static final LogService _instance = LogService._internal();

  /// 获取日志服务单例实例
  factory LogService() => _instance;

  /// 私有构造函数
  LogService._internal();

  /// 最低日志级别，低于此级别的日志不会输出
  LogLevel _minLevel = LogLevel.verbose;

  /// 是否将日志写入文件
  bool _writeToFile = false;

  /// 日志文件路径
  String? _logFilePath;

  /// 日志文件写入流
  IOSink? _logSink;

  /// 初始化日志服务
  ///
  /// [minLevel] 最低输出级别，默认为 [LogLevel.verbose]（输出所有级别）
  /// [writeToFile] 是否写入文件，默认为 false
  ///
  /// 当启用文件写入时，会在当前工作目录下创建 logs 文件夹，
  /// 日志文件名格式为 `app_yyyyMMdd_HHmmss.log`
  ///
  /// 示例：
  /// ```dart
  /// // 仅输出 debug 及以上级别，不写文件
  /// await log.init(minLevel: LogLevel.debug);
  ///
  /// // 输出所有级别，写入文件
  /// await log.init(minLevel: LogLevel.verbose, writeToFile: true);
  /// ```
  Future<void> init({
    LogLevel minLevel = LogLevel.verbose,
    bool writeToFile = false,
  }) async {
    _minLevel = minLevel;
    _writeToFile = writeToFile;

    if (_writeToFile) {
      try {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        // 使用应用文档目录作为日志存储位置
        final appDir = await getApplicationDocumentsDirectory();
        final logDir = Directory('${appDir.path}/logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        _logFilePath = '${logDir.path}/app_$timestamp.log';
        _logSink = File(_logFilePath!).openWrite(mode: FileMode.append);
        info('LogService', '日志服务初始化完成，日志文件: $_logFilePath');
      } catch (e) {
        // 如果无法创建日志文件，禁用文件写入
        _writeToFile = false;
        w('LogService', '无法创建日志文件，已禁用文件写入: $e');
      }
    }
  }

  /// 关闭日志服务
  ///
  /// 关闭日志文件写入流，释放资源。
  /// 在应用退出前调用，确保所有日志都已写入文件。
  Future<void> dispose() async {
    if (_logSink != null) {
      await _logSink!.close();
      _logSink = null;
    }
  }

  /// 格式化日志消息
  ///
  /// 生成统一格式的日志字符串：
  /// `[yyyy-MM-dd HH:mm:ss.SSS] LEVEL   [TAG] message`
  ///
  /// [tag] 日志标签，通常为调用者的类名或模块名
  /// [message] 日志消息内容
  /// [level] 日志级别
  ///
  /// 返回格式化的日志字符串
  String _formatMessage(String tag, String message, LogLevel level) {
    final timestamp =
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final levelName = level.name.toUpperCase().padRight(7);
    return '[$timestamp] $levelName [$tag] $message';
  }

  /// 内部日志输出方法
  ///
  /// 根据日志级别过滤，并输出到控制台和/或文件
  ///
  /// [tag] 日志标签
  /// [message] 日志消息
  /// [level] 日志级别
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

  /// Verbose 级别日志 - 最详细的调试信息
  ///
  /// 用于输出最详细的调试信息，如函数进入/退出、
  /// 变量值跟踪、详细执行流程等。
  ///
  /// [tag] 日志标签，建议使用类名或模块名
  /// [message] 日志消息
  void v(String tag, String message) => _log(tag, message, LogLevel.verbose);

  /// Debug 级别日志 - 调试信息
  ///
  /// 用于输出调试阶段的信息，如关键变量值、
  /// 条件分支判断结果、方法调用等。
  ///
  /// [tag] 日志标签，建议使用类名或模块名
  /// [message] 日志消息
  void d(String tag, String message) => _log(tag, message, LogLevel.debug);

  /// Info 级别日志 - 一般信息
  ///
  /// 用于输出正常的业务流程信息，如：
  /// - 服务初始化完成
  /// - 用户操作记录
  /// - 业务流程关键节点
  ///
  /// [tag] 日志标签，建议使用类名或模块名
  /// [message] 日志消息
  void info(String tag, String message) => _log(tag, message, LogLevel.info);

  /// Warning 级别日志 - 警告信息
  ///
  /// 用于输出潜在问题或需要关注的警告信息，如：
  /// - 配置项缺失但使用默认值
  /// - 资源即将耗尽
  /// - 使用了已弃用的API
  ///
  /// [tag] 日志标签，建议使用类名或模块名
  /// [message] 日志消息
  void w(String tag, String message) => _log(tag, message, LogLevel.warning);

  /// Error 级别日志 - 错误信息
  ///
  /// 用于输出错误和异常信息，包括错误详情和堆栈跟踪。
  ///
  /// [tag] 日志标签，建议使用类名或模块名
  /// [message] 错误描述消息
  /// [error] 可选的错误对象（Exception 或 Error）
  /// [stackTrace] 可选的堆栈跟踪信息
  ///
  /// 示例：
  /// ```dart
  /// try {
  ///   // 可能抛出异常的代码
  /// } catch (e, stackTrace) {
  ///   log.e('ServiceName', '操作失败', e, stackTrace);
  /// }
  /// ```
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
///
/// 提供便捷的全局访问点，无需每次创建新实例。
/// 在应用的任何位置都可以直接使用：
///
/// ```dart
/// import 'services/log_service.dart';
///
/// log.info('MyClass', '这是一条日志');
/// log.e('MyClass', '发生错误', error, stackTrace);
/// ```
final log = LogService();
