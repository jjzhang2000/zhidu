# LogService - 日志服务伪代码文档

## 概述

LogService 是一个单例模式的日志管理服务，提供分级日志输出、控制台输出和文件写入功能。

---

## 单例模式实现

```pseudocode
CLASS LogService:
    // 单例实例 - 静态私有变量
    PRIVATE STATIC _instance: LogService = LogService._internal()
    
    // 工厂构造函数 - 返回单例实例
    PUBLIC STATIC FACTORY LogService():
        RETURN _instance
    
    // 私有命名构造函数 - 防止外部实例化
    PRIVATE CONSTRUCTOR _internal():
        // 初始化默认配置
        _minLevel = LogLevel.verbose
        _writeToFile = false
        _logFilePath = null
        _logSink = null
```

---

## 数据结构

### LogLevel 枚举

```pseudocode
ENUM LogLevel:
    verbose  // 最详细调试信息 (index=0)
    debug    // 调试信息 (index=1)
    info     // 一般信息 (index=2)
    warning  // 警告信息 (index=3)
    error    // 错误信息 (index=4)
```

### 私有属性

```pseudocode
PRIVATE PROPERTIES:
    _minLevel: LogLevel          // 最低输出级别，低于此级别不输出
    _writeToFile: Boolean        // 是否写入文件
    _logFilePath: String?        // 日志文件路径
    _logSink: IOSink?            // 文件写入流
```

---

## 方法伪代码

### init() - 初始化日志服务

```pseudocode
ASYNC METHOD init(minLevel: LogLevel = verbose, writeToFile: Boolean = false):
    // 设置最低日志级别
    _minLevel = minLevel
    
    // 设置文件写入标志
    _writeToFile = writeToFile
    
    // 如果启用文件写入
    IF _writeToFile:
        // 生成时间戳格式的文件名
        timestamp = formatDateTime(now(), 'yyyyMMdd_HHmmss')
        _logFilePath = '{currentDirectory}/logs/app_{timestamp}.log'
        
        // 创建日志目录（如果不存在）
        logDir = Directory('{currentDirectory}/logs')
        IF NOT await logDir.exists():
            await logDir.create(recursive: true)
        
        // 打开文件写入流
        _logSink = File(_logFilePath).openWrite(mode: append)
        
        // 记录初始化完成日志
        info('LogService', '日志服务初始化完成，日志文件: {_logFilePath}')
```

**初始化流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│                     init() 初始化流程                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  设置 _minLevel = minLevel                                  │
│  设置 _writeToFile = writeToFile                            │
│                                                             │
│  IF _writeToFile:                                           │
│      ├─ 生成时间戳: yyyyMMdd_HHmmss                         │
│      ├─ 构建路径: logs/app_{timestamp}.log                  │
│      ├─ 检查目录是否存在                                     │
│      │   └─ 不存在 → 创建目录 (recursive)                   │
│      ├─ 打开文件写入流 (append mode)                         │
│      └─ 输出初始化完成日志                                   │
│                                                             │
│  ELSE:                                                      │
│      └─ 仅控制台输出模式                                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### dispose() - 关闭日志服务

```pseudocode
ASYNC METHOD dispose():
    // 如果有文件写入流
    IF _logSink != null:
        // 关闭写入流，确保所有日志写入文件
        await _logSink.close()
        
        // 清空引用
        _logSink = null
```

---

### _formatMessage() - 格式化日志消息

```pseudocode
PRIVATE METHOD _formatMessage(tag: String, message: String, level: LogLevel) -> String:
    // 生成时间戳
    timestamp = formatDateTime(now(), 'yyyy-MM-dd HH:mm:ss.SSS')
    
    // 格式化级别名称（大写，右填充7字符）
    levelName = level.name.toUpperCase().padRight(7)
    
    // 构建格式化字符串
    // 格式: [yyyy-MM-dd HH:mm:ss.SSS] LEVEL   [TAG] message
    formatted = '[{timestamp}] {levelName} [{tag}] {message}'
    
    RETURN formatted
```

**输出格式示例:**

```
[2026-04-22 10:30:15.123] INFO    [BookService] 书籍导入成功: 设计模式
[2026-04-22 10:30:16.456] WARNING [AIService] AI配置无效，请检查设置
[2026-04-22 10:30:17.789] ERROR   [SummaryService] 生成摘要失败: abc123_5
```

---

### _log() - 内部日志输出方法

```pseudocode
PRIVATE METHOD _log(tag: String, message: String, level: LogLevel):
    // 级别过滤：低于最低级别则不输出
    IF level.index < _minLevel.index:
        RETURN  // 跳过输出
    
    // 格式化消息
    formatted = _formatMessage(tag, message, level)
    
    // 输出到控制台
    print(formatted)
    
    // 如果启用文件写入且有写入流
    IF _writeToFile AND _logSink != null:
        // 写入文件（追加换行符）
        _logSink.writeln(formatted)
```

**级别过滤逻辑:**

```
LogLevel.index 比较:
  verbose (0) < debug (1) < info (2) < warning (3) < error (4)

示例: _minLevel = info (index=2)
  - verbose (0) → 跳过 (0 < 2)
  - debug (1)   → 跳过 (1 < 2)
  - info (2)    → 输出 (2 >= 2)
  - warning (3) → 输出 (3 >= 2)
  - error (4)   → 输出 (4 >= 2)
```

---

### v() - Verbose 级别日志

```pseudocode
PUBLIC METHOD v(tag: String, message: String):
    // 调用内部日志方法，使用 verbose 级别
    _log(tag, message, LogLevel.verbose)
```

**使用场景:** 函数进入/退出、变量值跟踪、详细执行流程

---

### d() - Debug 级别日志

```pseudocode
PUBLIC METHOD d(tag: String, message: String):
    // 调用内部日志方法，使用 debug 级别
    _log(tag, message, LogLevel.debug)
```

**使用场景:** 关键变量值、条件分支判断结果、方法调用

---

### info() - Info 级别日志

```pseudocode
PUBLIC METHOD info(tag: String, message: String):
    // 调用内部日志方法，使用 info 级别
    _log(tag, message, LogLevel.info)
```

**使用场景:** 服务初始化完成、用户操作记录、业务流程关键节点

---

### w() - Warning 级别日志

```pseudocode
PUBLIC METHOD w(tag: String, message: String):
    // 调用内部日志方法，使用 warning 级别
    _log(tag, message, LogLevel.warning)
```

**使用场景:** 配置项缺失、资源即将耗尽、使用已弃用API

---

### e() - Error 级别日志

```pseudocode
PUBLIC METHOD e(tag: String, message: String, error: dynamic = null, stackTrace: StackTrace? = null):
    // 构建完整错误消息
    fullMessage = message
    
    // 如果有错误对象，追加错误信息
    IF error != null:
        fullMessage += '\nError: {error}'
    
    // 如果有堆栈跟踪，追加堆栈信息
    IF stackTrace != null:
        fullMessage += '\nStackTrace:\n{stackTrace}'
    
    // 调用内部日志方法，使用 error 级别
    _log(tag, fullMessage, LogLevel.error)
```

**错误日志格式:**

```
[2026-04-22 10:30:17.789] ERROR   [SummaryService] 生成摘要失败
Error: NetworkException: Connection timeout
StackTrace:
  #0 SummaryService.generateSingleSummary (summary_service.dart:402)
  #1 SummaryService._generateChapterSummaries (summary_service.dart:552)
  ...
```

---

## 全局实例

```pseudocode
// 全局日志实例 - 提供便捷访问
GLOBAL log = LogService()
```

**使用示例:**

```pseudocode
// 导入服务
IMPORT services/log_service.dart

// 直接使用全局实例
log.info('MyClass', '这是一条日志')
log.e('MyClass', '发生错误', error, stackTrace)
```

---

## 错误处理

### 文件创建失败

```pseudocode
TRY:
    logDir.create(recursive: true)
CATCH e:
    // 记录错误，继续使用控制台模式
    print('无法创建日志目录: {e}')
    _writeToFile = false
```

### 文件写入失败

```pseudocode
TRY:
    _logSink.writeln(formatted)
CATCH e:
    // 文件写入失败，仅输出到控制台
    print('日志文件写入失败: {e}')
```

---

## 数据持久化策略

### 文件存储

```
存储位置: {工作目录}/logs/
文件名格式: app_yyyyMMdd_HHmmss.log
写入模式: append（追加模式）

示例文件:
  logs/app_20260422_103015.log
  logs/app_20260422_143052.log
```

### 文件生命周期

```
创建时机: init(writeToFile=true) 调用时
关闭时机: dispose() 调用时或应用退出
清理策略: 无自动清理，需手动管理
```

---

## 并发控制

LogService 不使用并发控制机制，原因:

1. 日志输出是轻量级操作
2. IOSink 内部有缓冲机制
3. print() 是同步操作

**注意事项:**

- 高频日志可能影响性能
- 文件写入有缓冲，dispose() 确保写入完成
- 多线程环境下日志顺序可能不确定

---

## 性能考量

### 级别过滤优化

```pseudocode
// 在 _log() 方法开头进行级别检查
IF level.index < _minLevel.index:
    RETURN  // 快速返回，避免格式化开销
```

### 文件写入优化

```pseudocode
// 使用 IOSink 而非每次打开文件
// IOSink 内部有缓冲，减少磁盘 I/O
_logSink.writeln(formatted)  // 缓冲写入
```

---

## 测试支持

```pseudocode
// 测试用例示例
TEST LogService:
    // 测试级别过滤
    log.init(minLevel: LogLevel.info)
    log.v('Test', 'verbose')  // 不应输出
    log.info('Test', 'info')  // 应输出
    
    // 测试文件写入
    log.init(writeToFile: true)
    log.info('Test', 'test message')
    // 验证文件内容包含 test message
    
    // 测试错误日志
    TRY:
        throw Exception('test error')
    CATCH e, stackTrace:
        log.e('Test', 'error occurred', e, stackTrace)
        // 验证日志包含错误和堆栈信息
```