# LogHelper - 日志服务伪代码文档

## 概述

LogHelper 封装 Dart 官方 `logging` 库，提供统一的日志输出和文件持久化功能。

---

## 初始化

```dart
class LogHelper {
  static IOSink? _logSink;

  static Future<void> init({
    Level minLevel = Level.ALL,
    bool writeToFile = false,
  }) async {
    Logger.root.level = minLevel;
    Logger.root.onRecord.listen(_handleLogRecord);

    if (writeToFile) {
      // 创建日志目录
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDir.path}/logs');
      if (!await logDir.exists()) await logDir.create(recursive: true);

      // 打开日志文件
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final logFilePath = '${logDir.path}/app_$timestamp.log';
      _logSink = File(logFilePath).openWrite(mode: FileMode.append);
    }
  }

  static Future<void> dispose() async {
    await _logSink?.close();
    _logSink = null;
  }
}
```

---

## 日志处理

```dart
static void _handleLogRecord(LogRecord record) {
  final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(record.time);
  final levelName = record.level.name.padRight(7);
  final formatted = '[$timestamp] $levelName [${record.loggerName}] ${record.message}';

  // 控制台输出
  if (record.error != null) {
    print('$formatted\nError: ${record.error}');
    if (record.stackTrace != null) print('StackTrace:\n${record.stackTrace}');
  } else {
    print(formatted);
  }

  // 文件写入
  if (_logSink != null) {
    _logSink!.writeln(record.error != null
        ? '$formatted\nError: ${record.error}\nStackTrace:\n${record.stackTrace}'
        : formatted);
  }
}
```

---

## 使用方式

各模块内部创建 Logger 实例：

```dart
import 'package:logging/logging.dart';

class EpubParser implements BookFormatParser {
  final _log = Logger('EpubParser');

  Future<BookMetadata> parseMetadata(String filePath, String bookId) async {
    _log.info('开始解析元数据: $filePath');
    // ...
  }
}
```

---

## 日志级别

| logging 级别 | 语义 | 适用场景 |
|---|---|---|
| `Level.FINE` | 详细 | 最详细的调试信息 |
| `Level.INFO` | 信息 | 正常业务流程 |
| `Level.WARNING` | 警告 | 潜在问题 |
| `Level.SEVERE` | 严重 | 错误异常 |

---

## 日志格式

```
[yyyy-MM-dd HH:mm:ss.SSS] LEVEL   [LoggerName] message
```

示例：
```
[2026-05-22 10:30:45.123] INFO    [BookService] 开始导入书籍: C:\Books\test.epub
[2026-05-22 10:30:45.456] WARNING [EpubParser] EpubReader 解析失败，回退到 archive
[2026-05-22 10:30:45.789] SEVERE  [AIService] AI 请求失败
Error: TimeoutException
StackTrace: ...
```
