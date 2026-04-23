# FormatRegistry - 格式注册表

## 概述

`FormatRegistry` 是格式解析器的注册表，采用注册表模式（Registry Pattern）管理不同文件格式的解析器。支持运行时动态注册和获取解析器，便于扩展新的文件格式支持。

## 设计模式

```
┌─────────────────────────────────────────────────────────────────┐
│                    Registry Pattern                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    FormatRegistry                        │   │
│  │                    (Static Class)                        │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │                                                          │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ _parsers: Map<String, BookFormatParser>         │    │   │
│  │  │                                                  │    │   │
│  │  │  '.epub' ─────► EpubParser instance             │    │   │
│  │  │  '.pdf'  ─────► PdfParser instance              │    │   │
│  │  │  '.mobi' ─────► MobiParser instance (future)    │    │   │
│  │  │  ...                                             │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  │  Methods:                                                │   │
│  │  - register(extension, parser)                          │   │
│  │  - getParser(extension) → BookFormatParser?             │   │
│  │  - isSupported(extension) → bool                        │   │
│  │  - getSupportedFormats() → List<String>                 │   │
│  │  - clear()                                              │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Benefits:                                                       │
│  - Open/Closed Principle: 新增格式无需修改现有代码              │
│  - Single Instance: 全局共享解析器，节省内存                    │
│  - Dynamic Registration: 支持运行时扩展                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 核心数据结构

### 解析器映射表

```
STATIC VARIABLE _parsers: Map<String, BookFormatParser>

DESCRIPTION:
    键: 文件扩展名（小写，如 '.epub'、'.pdf'）
    值: 对应格式的解析器实例
    
DESIGN NOTES:
    - 使用静态私有变量确保全局只有一个映射表实例
    - 扩展名统一转为小写存储，实现大小写不敏感的查找
    - 解析器应为无状态对象，可安全复用
```

## 方法定义

### register() - 注册解析器

```
STATIC FUNCTION register(extension: String, parser: BookFormatParser) -> void
    PURPOSE: 将文件扩展名与解析器建立映射关系
    
    PARAMETERS:
        extension: 文件扩展名（如 '.epub'、'.pdf'）
            - 扩展名会自动转为小写存储
            - 建议传入带点号的完整扩展名格式
        parser: 实现 BookFormatParser 接口的解析器实例
            - 解析器应为无状态对象，可安全复用
    
    BEHAVIOR:
        IF extension已存在:
            新的解析器会覆盖旧的解析器
    
    IMPLEMENTATION:
        _parsers[extension.toLowerCase()] = parser
    
    EXAMPLE:
        // 注册EPUB解析器
        FormatRegistry.register('.epub', EpubParser())
        
        // 注册PDF解析器
        FormatRegistry.register('.pdf', PdfParser())
        
        // 大小写不敏感
        FormatRegistry.register('.EPUB', EpubParser())  // 会覆盖之前的注册
END FUNCTION
```

### getParser() - 获取解析器

```
STATIC FUNCTION getParser(extension: String) -> BookFormatParser?
    PURPOSE: 根据文件扩展名查找对应的解析器实例
    
    PARAMETERS:
        extension: 文件扩展名（如 '.epub'、'.pdf'）
            - 扩展名会自动转为小写进行匹配
    
    RETURNS:
        对应的解析器实例，如果该格式未注册解析器则返回 null
    
    IMPLEMENTATION:
        RETURN _parsers[extension.toLowerCase()]
    
    EXAMPLE:
        parser = FormatRegistry.getParser('.epub')
        IF parser != null:
            metadata = await parser.parse(filePath)
        
        // 处理不支持的格式
        parser = FormatRegistry.getParser('.unknown')
        IF parser == null:
            print('不支持的文件格式')
END FUNCTION
```

### isSupported() - 检查格式支持

```
STATIC FUNCTION isSupported(extension: String) -> bool
    PURPOSE: 判断该文件扩展名是否已注册对应的解析器
    
    PARAMETERS:
        extension: 文件扩展名
            - 扩展名会自动转为小写进行匹配
    
    RETURNS:
        true: 该格式已注册解析器
        false: 该格式尚未支持
    
    IMPLEMENTATION:
        RETURN _parsers.containsKey(extension.toLowerCase())
    
    EXAMPLE:
        // 在文件选择器中过滤支持的格式
        IF FormatRegistry.isSupported(extension):
            // 处理文件导入
        ELSE:
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('不支持的文件格式: $extension'))
            )
END FUNCTION
```

### getSupportedFormats() - 获取支持的格式列表

```
STATIC FUNCTION getSupportedFormats() -> List<String>
    PURPOSE: 返回当前注册表中支持的所有文件格式扩展名列表
    
    RETURNS:
        已注册解析器的文件扩展名列表
        - 扩展名均为小写格式（如 ['.epub', '.pdf', '.txt']）
        - 返回的是新的List实例，修改不会影响内部映射表
    
    IMPLEMENTATION:
        RETURN _parsers.keys.toList()
    
    EXAMPLE:
        // 获取并显示支持的格式
        formats = FormatRegistry.getSupportedFormats()
        print('支持的格式: ${formats.join(", ")}')
        // 输出: 支持的格式: .epub, .pdf
        
        // 用于文件选择器过滤
        allowedExtensions = FormatRegistry.getSupportedFormats()
        FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: allowedExtensions.map(e => e.replaceAll('.', '')).toList()
        )
END FUNCTION
```

### clear() - 清空注册表

```
STATIC FUNCTION clear() -> void
    PURPOSE: 移除注册表中的所有解析器映射关系
    
    USE CASES:
        1. 单元测试: 在setUp/tearDown中重置注册表
        2. 插件卸载: 卸载某个插件时清除其注册的解析器
        3. 重新初始化: 需要重新配置解析器时先清空再重新注册
    
    IMPLEMENTATION:
        _parsers.clear()
    
    NOTES:
        - 调用此方法后，getParser() 将返回 null
        - 需要重新调用 initialize() 或 register() 注册解析器
        - 生产环境中一般不需要调用此方法
    
    EXAMPLE:
        // 单元测试中使用
        setUp(() {
            FormatRegistry.clear()
        })
        
        tearDown(() {
            FormatRegistry.clear()
        })
        
        test('注册解析器', () {
            FormatRegistry.register('.test', MockParser())
            expect(FormatRegistry.isSupported('.test'), isTrue)
        })
END FUNCTION
```

## 使用流程

```
┌─────────────────────────────────────────────────────────────────┐
│                    FormatRegistry Usage Flow                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Phase 1: Initialization (main.dart)                     │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │                                                          │   │
│  │  void main() async {                                    │   │
│  │      WidgetsFlutterBinding.ensureInitialized()          │   │
│  │                                                          │   │
│  │      // Initialize services                              │   │
│  │      await LogService.instance.init()                   │   │
│  │      await DatabaseService.instance.init()              │   │
│  │                                                          │   │
│  │      // Register format parsers                          │   │
│  │      FormatRegistry.register('.epub', EpubParser())     │   │
│  │      FormatRegistry.register('.pdf', PdfParser())       │   │
│  │                                                          │   │
│  │      runApp(const MyApp())                              │   │
│  │  }                                                       │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Phase 2: File Import (BookService)                      │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │                                                          │   │
│  │  // Get file extension                                   │   │
│  │  extension = p.extension(filePath).toLowerCase()        │   │
│  │                                                          │   │
│  │  // Check if format is supported                         │   │
│  │  IF NOT FormatRegistry.isSupported(extension):          │   │
│  │      THROW Exception('Unsupported format: $extension')  │   │
│  │                                                          │   │
│  │  // Get appropriate parser                               │   │
│  │  parser = FormatRegistry.getParser(extension)           │   │
│  │                                                          │   │
│  │  // Use parser to extract metadata                       │   │
│  │  metadata = await parser.parse(filePath)                │   │
│  │  chapters = await parser.getChapters(filePath)          │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Phase 3: Content Extraction (SummaryService)            │   │
│  ├─────────────────────────────────────────────────────────┤ │
│  │                                                          │   │
│  │  // Get parser for book format                           │   │
│  │  parser = FormatRegistry.getParser(book.formatExtension)│   │
│  │                                                          │   │
│  │  // Extract chapter content                              │   │
│  │  content = await parser.getChapterContent(filePath, ch) │   │
│  │                                                          │   │
│  │  // Generate AI summary                                  │   │
│  │  summary = await aiService.generateSummary(content)     │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 扩展指南

### 添加新格式支持

```
┌─────────────────────────────────────────────────────────────────┐
│                    Adding New Format Support                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Step 1: Create Parser Implementation                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ class MobiParser implements BookFormatParser {          │   │
│  │     @override                                           │   │
│  │     Future<BookMetadata> parse(String filePath) async { │   │
│  │         // MOBI format parsing logic                    │   │
│  │     }                                                   │   │
│  │                                                          │   │
│  │     @override                                           │   │
│  │     Future<List<Chapter>> getChapters(String fp) async {│   │
│  │         // MOBI chapter extraction logic                │   │
│  │     }                                                   │   │
│  │                                                          │   │
│  │     @override                                           │   │
│  │     Future<ChapterContent> getChapterContent(           │   │
│  │         String filePath, Chapter chapter) async {       │   │
│  │         // MOBI content extraction logic                │   │
│  │     }                                                   │   │
│  │                                                          │   │
│  │     @override                                           │   │
│  │     Future<String?> extractCover(String filePath) async{│   │
│  │         // MOBI cover extraction logic                  │   │
│  │     }                                                   │   │
│  │ }                                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Step 2: Register Parser                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ // Option A: Static registration (main.dart)            │   │
│  │ FormatRegistry.register('.mobi', MobiParser())          │   │
│  │                                                          │   │
│  │ // Option B: Dynamic registration (plugin system)       │   │
│  │ void registerPluginParser() {                           │   │
│  │     FormatRegistry.register('.mobi', MobiParser())      │   │
│  │ }                                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Step 3: Update File Picker Filter                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ final formats = FormatRegistry.getSupportedFormats()    │   │
│  │ // Now includes '.mobi'                                 │   │
│  │                                                          │   │
│  │ FilePicker.platform.pickFiles(                          │   │
│  │     type: FileType.custom,                              │   │
│  │     allowedExtensions: formats                          │   │
│  │         .map(e => e.replaceAll('.', ''))                │   │
│  │         .toList()                                       │   │
│  │ )                                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 设计原则

### 开闭原则（Open/Closed Principle）

```
┌─────────────────────────────────────────────────────────────────┐
│                    Open/Closed Principle                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OPEN for Extension:                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ - New formats can be added via register()               │   │
│  │ - No need to modify existing code                       │   │
│  │ - Plugin system can dynamically add parsers             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  CLOSED for Modification:                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ - FormatRegistry class remains unchanged                │   │
│  │ - Existing parser implementations unaffected            │   │
│  │ - Core logic stable and predictable                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Example:                                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ // Adding MOBI support - NO changes to existing code    │   │
│  │ FormatRegistry.register('.mobi', MobiParser())          │   │
│  │                                                          │   │
│  │ // BookService automatically supports MOBI               │   │
│  │ // No modification to BookService required              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 单例存储（Singleton Storage）

```
┌─────────────────────────────────────────────────────────────────┐
│                    Singleton Storage                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Benefits:                                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 1. Memory Efficiency                                    │   │
│  │    - Single instance per parser type                    │   │
│  │    - No duplicate parser objects                        │   │
│  │                                                          │   │
│  │ 2. Consistency                                           │   │
│  │    - All callers use same parser instance               │   │
│  │    - Behavior predictable                               │   │
│  │                                                          │   │
│  │ 3. Performance                                           │   │
│  │    - No instantiation overhead                          │   │
│  │    - Immediate access to registered parsers             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Implementation:                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ // Static map ensures single instance                   │   │
│  │ static final Map<String, BookFormatParser> _parsers = {}│   │
│  │                                                          │   │
│  │ // All parsers stored once                              │   │
│  │ _parsers['.epub'] = EpubParser()  // Single instance    │   │
│  │ _parsers['.pdf'] = PdfParser()    // Single instance    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 与其他组件的交互

```
┌─────────────────────────────────────────────────────────────────┐
│                    Component Interaction                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐     ┌─────────────────┐     ┌─────────────┐   │
│  │ main.dart   │────►│FormatRegistry   │◄────│ BookService │   │
│  │             │     │                 │     │             │   │
│  │ register()  │     │ getParser()     │     │ importBook()│   │
│  └─────────────┘     │ isSupported()   │     └─────────────┘   │
│                      │                 │                        │
│                      └─────────────────┘                        │
│                             │                                    │
│                             │                                    │
│                             ▼                                    │
│                      ┌─────────────────┐                        │
│                      │ BookFormatParser│                        │
│                      │ (Interface)     │                        │
│                      └─────────────────┘                        │
│                             │                                    │
│              ┌──────────────┼──────────────┐                   │
│              │              │              │                   │
│              ▼              ▼              ▼                   │
│      ┌───────────┐  ┌───────────┐  ┌───────────┐              │
│      │EpubParser │  │ PdfParser │  │MobiParser │              │
│      │           │  │           │  │ (future)  │              │
│      └───────────┘  └───────────┘  └───────────┘              │
│                                                                  │
│  Call Sequence:                                                  │
│  1. main.dart → FormatRegistry.register()                       │
│  2. BookService → FormatRegistry.isSupported()                  │
│  3. BookService → FormatRegistry.getParser()                    │
│  4. BookService → parser.parse() / parser.getChapters()         │
│  5. SummaryService → parser.getChapterContent()                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 测试策略

```
┌─────────────────────────────────────────────────────────────────┐
│                    Testing Strategy                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Unit Tests:                                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ test('register adds parser to registry', () {           │   │
│  │     FormatRegistry.clear()                              │   │
│  │     FormatRegistry.register('.test', MockParser())      │   │
│  │     expect(FormatRegistry.isSupported('.test'), true)   │   │
│  │ })                                                      │   │
│  │                                                          │   │
│  │ test('getParser returns correct parser', () {           │   │
│  │     FormatRegistry.clear()                              │   │
│  │     FormatRegistry.register('.epub', EpubParser())      │   │
│  │     final parser = FormatRegistry.getParser('.epub')    │   │
│  │     expect(parser, isA<EpubParser>())                   │   │
│  │ })                                                      │   │
│  │                                                          │   │
│  │ test('case insensitive lookup', () {                    │   │
│  │     FormatRegistry.clear()                              │   │
│  │     FormatRegistry.register('.epub', EpubParser())      │   │
│  │     expect(FormatRegistry.isSupported('.EPUB'), true)   │   │
│  │     expect(FormatRegistry.isSupported('.Epub'), true)   │   │
│  │ })                                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Integration Tests:                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ test('BookService uses correct parser', () async {      │   │
│  │     // Setup                                             │   │
│  │     FormatRegistry.register('.epub', EpubParser())      │   │
│  │                                                          │   │
│  │     // Execute                                           │   │
│  │     final bookService = BookService()                   │   │
│  │     final metadata = await bookService.importBook(      │   │
│  │         'test.epub'                                      │   │
│  │     )                                                    │   │
│  │                                                          │   │
│  │     // Verify                                            │   │
│  │     expect(metadata.format, BookFormat.epub)            │   │
│  │ })                                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 边界情况处理

| 边界情况 | 处理方式 |
|----------|----------|
| 扩展名大小写 | 自动转为小写，大小写不敏感 |
| 重复注册 | 新解析器覆盖旧解析器 |
| 未注册格式 | `getParser()` 返回 `null` |
| 空扩展名 | 作为无效键存储，查找返回 `null` |
| 清空后使用 | 需重新注册解析器 |

## 性能考虑

1. **静态存储**: 解析器实例全局共享，避免重复创建
2. **快速查找**: Map结构提供O(1)查找性能
3. **无状态设计**: 解析器可安全复用，无需考虑并发问题
4. **延迟初始化**: 解析器在注册时创建，而非使用时创建