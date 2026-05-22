# LogHelper - 日志服务伪代码文档

## 概述

LogHelper 封装 `logger` 第三方库，提供统一的日志输出和文件轮转持久化功能。

---

## 初始化

```dart
class LogHelper {
  static const int _maxLogFileSize = 1 * 1024 * 1024; // 1MB
  static const String _logFileName = 'app.log';
  static LogOutput? output;

  static Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${appDir.path}/logs');
    if (!await logDir.exists()) await logDir.create(recursive: true);
    final logFile = File('${logDir.path}/$_logFileName');

    output = _FileRotatingOutput(logFile);
  }

  static Future<void> dispose() async {
    await output?.close();
    output = null;
  }
}
```

---

## 自定义 LogOutput（控制台 + 文件轮转）

```dart
class _FileRotatingOutput extends LogOutput {
  final File _logFile;

  @override
  void output(OutputEvent event) {
    // 控制台输出
    for (final line in event.lines) {
      print(line);
    }

    // 文件写入 + 轮转检查
    final content = event.lines.join('\n');
    final stat = _logFile.statSync();
    if (stat.size > _maxLogFileSize) {
      _logFile.writeAsStringSync('', mode: FileMode.write); // 清空轮转
    }
    _logFile.writeAsStringSync('$content\n', mode: FileMode.append, flush: true);
  }
}
```

---

## 使用方式

各模块内部创建 Logger 实例，共享 LogHelper.output：

```dart
import 'package:logger/logger.dart';
import 'services/log_helper.dart';

class EpubParser implements BookFormatParser {
  final _log = Logger(tag: 'EpubParser', output: LogHelper.output);

  Future<BookMetadata> parseMetadata(String filePath, String bookId) async {
    _log.i('开始解析元数据: $filePath');
    // ...
  }
}
```

---

## 日志级别

| 方法 | 语义 | 适用场景 |
|---|---|---|
| `_log.t()` | 追踪 | 最详细的调试信息 |
| `_log.d()` | 调试 | 调试阶段信息 |
| `_log.i()` | 信息 | 正常业务流程 |
| `_log.w()` | 警告 | 潜在问题 |
| `_log.e()` | 错误 | 错误异常 |
| `_log.f()` | 致命 | 致命错误（崩溃级） |

---

## 日志格式

```
[yyyy-MM-dd HH:mm:ss.SSS] LEVEL   [TagName] message
```

示例：
```
[2026-05-22 10:30:45.123] INFO    [BookService] 开始导入书籍: C:\Books\test.epub
[2026-05-22 10:30:45.456] WARNING [EpubParser] EpubReader 解析失败，回退到 archive
[2026-05-22 10:30:45.789] ERROR   [AIService] AI 请求失败
```

---

## 文件轮转

- 日志文件名固定为 `app.log`
- 单次写入前检查文件大小，超过 1MB 自动清空
- 只保留最近一份日志，旧日志不保留
