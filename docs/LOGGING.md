# 日志系统使用指南

## 概述

应用使用统一的日志系统 (`LogService`) 来替代 `print()` 语句，提供更好的日志管理和调试体验。

## 日志级别

从低到高排列：

- **VERBOSE** - 最详细的调试信息（追踪代码执行流程）
- **DEBUG** - 调试信息（开发调试使用）
- **INFO** - 一般信息（重要事件记录）
- **WARNING** - 警告信息（非致命问题）
- **ERROR** - 错误信息（异常和错误）

## 使用方法

### 1. 导入日志服务

```dart
import '../services/log_service.dart';
```

### 2. 获取日志实例

在类中添加：
```dart
final _log = LogService();
```

或使用全局实例：
```dart
LogService().info('Tag', '消息');
```

### 3. 记录日志

```dart
// 详细调试
_log.v('Tag', '详细调试信息');

// 调试信息
_log.d('Tag', '调试信息');

// 一般信息
_log.info('Tag', '应用启动');

// 警告
_log.w('Tag', '警告信息');

// 错误（带异常和堆栈）
_log.e('Tag', '错误描述', error, stackTrace);
```

## 日志输出格式

```
[2024-01-15 10:30:45.123] INFO    [Main] 应用启动
[2024-01-15 10:30:45.456] DEBUG   [BookService] 加载了 5 本书籍
[2024-01-15 10:30:46.789] ERROR   [EpubService] 解析失败
Error: Exception: Invalid EPUB
StackTrace:
#0 ...
```

## 日志文件

- 日志文件保存在应用目录的 `logs/` 文件夹下
- 文件名格式：`app_YYYYMMDD_HHMMSS.log`
- 每次启动应用会创建新的日志文件
- **注意**：`logs/` 目录已加入 `.gitignore`，不会被提交到版本控制

## 配置

在 `main.dart` 中配置日志级别和文件输出：

```dart
await LogService().init(
  minLevel: LogLevel.debug,  // 只记录 DEBUG 及以上级别
  writeToFile: true,         // 同时写入文件
);
```

## 最佳实践

1. **使用有意义的 Tag**：使用类名作为 Tag，如 `'BookService'`, `'ReaderScreen'`
2. **适当的日志级别**：
   - 开发调试用 DEBUG 或 VERBOSE
   - 重要事件用 INFO
   - 潜在问题用 WARNING
   - 错误异常用 ERROR
3. **错误日志要完整**：记录异常对象和堆栈信息
4. **避免日志泄露敏感信息**：不要记录 API Key、密码等敏感数据
5. **使用中文描述**：项目代码注释和日志统一使用中文，便于理解