# BookFormatParser - 书籍格式解析器接口

## 概述

`BookFormatParser` 是书籍格式解析器的抽象接口，定义所有解析器必须实现的通用方法。采用策略模式（Strategy Pattern），将书籍解析行为抽象为接口，不同格式的解析器实现相同的接口。

## 设计模式

```
┌─────────────────────────────────────────────────────────────┐
│                    Strategy Pattern                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────┐                                    │
│  │ BookFormatParser    │  ← Abstract Interface              │
│  │ (abstract class)    │                                    │
│  └─────────────────────┘                                    │
│            ▲                                                │
│            │ implements                                     │
│  ┌─────────┴─────────┐                                    │
│  │                   │                                    │
│  │  ┌──────────────┐ │  ┌──────────────┐                 │
│  │  │ EpubParser   │ │  │ PdfParser    │                 │
│  │  └──────────────┘ │  └──────────────┘                 │
│  │                   │                                    │
│  └───────────────────┘                                    │
│                                                              │
│  调用方: FormatRegistry, BookService, SummaryService        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 接口方法定义

### 1. parse() - 解析书籍元数据

```
FUNCTION parse(filePath: String) -> Future<BookMetadata>
    PURPOSE: 解析书籍文件，提取元数据信息
    
    PARAMETERS:
        filePath: 书籍文件的完整本地路径
    
    RETURNS:
        BookMetadata object containing:
        - title: 书籍标题
        - author: 作者名称
        - coverPath: 封面图片路径（可能为null）
        - totalChapters: 总章节数
        - format: 书籍格式（EPUB/PDF）
    
    CALLERS:
        BookService.importBook()
    
    ASYNC REASON:
        需要读取文件系统并解析文件内容
    
    EXAMPLE USAGE:
        parser = EpubParser()
        metadata = await parser.parse('/path/to/book.epub')
        print(metadata.title)  // 输出书名
END FUNCTION
```

### 2. getChapters() - 获取章节列表

```
FUNCTION getChapters(filePath: String) -> Future<List<Chapter>>
    PURPOSE: 获取书籍的所有章节列表
    
    PARAMETERS:
        filePath: 书籍文件的完整本地路径
    
    RETURNS:
        List<Chapter> 按顺序排列的章节列表
        Each Chapter contains:
        - id: 章节唯一标识
        - index: 章节序号（顶层章节递增，子章节为-1）
        - title: 章节标题
        - location: 章节位置信息（href或页码范围）
        - level: 层级深度（0为顶层）
    
    FORMAT-SPECIFIC BEHAVIOR:
        EPUB: 从NCX/Nav导航文件解析章节结构
        PDF: 从书签或页面内容提取章节信息
    
    CALLERS:
        BookService.importBook() - 导入时获取章节列表
        BookScreen - 显示书籍目录
    
    ASYNC REASON:
        需要读取文件系统并解析章节结构
    
    EXAMPLE USAGE:
        chapters = await parser.getChapters('/path/to/book.epub')
        FOR chapter IN chapters:
            print('第${chapter.index}章: ${chapter.title}')
END FUNCTION
```

### 3. getChapterContent() - 获取章节内容

```
FUNCTION getChapterContent(filePath: String, chapter: Chapter) -> Future<ChapterContent>
    PURPOSE: 获取指定章节的完整内容
    
    PARAMETERS:
        filePath: 书籍文件的完整本地路径
        chapter: 要获取内容的章节对象（包含位置信息）
    
    RETURNS:
        ChapterContent object containing:
        - plainText: 纯文本内容（去除HTML标签）
        - htmlContent: HTML格式内容（保留格式，可能为null）
    
    CALLERS:
        SectionReaderScreen - 显示章节内容
        SummaryService - 生成AI摘要时获取章节文本
        EpubReaderScreen - EPUB阅读界面
        PdfReaderScreen - PDF阅读界面
    
    ASYNC REASON:
        需要读取文件系统并解析章节内容
    
    EXAMPLE USAGE:
        content = await parser.getChapterContent(filePath, chapter)
        print(content.plainText)  // 输出纯文本内容
END FUNCTION
```

### 4. extractCover() - 提取封面图片

```
FUNCTION extractCover(filePath: String) -> Future<String?>
    PURPOSE: 提取书籍封面图片
    
    PARAMETERS:
        filePath: 书籍文件的完整本地路径
    
    RETURNS:
        String? 封面图片的存储路径
        - 成功时返回封面图片的本地文件路径
        - 如果书籍没有封面则返回null
    
    CALLERS:
        BookService.importBook() - 导入时提取封面
        BookScreen - 显示书籍封面
    
    FORMAT-SPECIFIC IMPLEMENTATION:
        EPUB: 从OPF文件指定的封面图片提取，或使用第一张图片
        PDF: 通常提取第一页渲染为图片（当前不支持）
    
    ASYNC REASON:
        需要读取文件系统、解析图片并保存到本地
    
    EXAMPLE USAGE:
        coverPath = await parser.extractCover('/path/to/book.epub')
        IF coverPath != null:
            // 显示封面图片
END FUNCTION
```

## 数据模型依赖

### BookMetadata

```
CLASS BookMetadata
    PROPERTIES:
        title: String          // 书籍标题
        author: String         // 作者名称
        coverPath: String?     // 封面图片路径
        totalChapters: int     // 总章节数
        format: BookFormat     // 格式类型（epub/pdf）
END CLASS
```

### Chapter

```
CLASS Chapter
    PROPERTIES:
        id: String             // 章节唯一标识（UUID）
        index: int             // 章节序号（顶层递增，子章节-1）
        title: String          // 章节标题
        location: ChapterLocation  // 章节位置信息
        level: int             // 层级深度（0=顶层）
END CLASS
```

### ChapterLocation

```
CLASS ChapterLocation
    PROPERTIES:
        href: String?          // EPUB章节文件路径
        startPage: int?        // PDF起始页码（1-based）
        endPage: int?          // PDF结束页码（1-based）
END CLASS
```

### ChapterContent

```
CLASS ChapterContent
    PROPERTIES:
        plainText: String      // 纯文本内容
        htmlContent: String?   // HTML格式内容
END CLASS
```

## 实现类

| 实现类 | 格式 | 特点 |
|--------|------|------|
| EpubParser | EPUB | XML/ZIP解析，多层级目录，锚点处理 |
| PdfParser | PDF | 页面渲染，章节标题检测，封面跳过 |

## 调用流程图

```
┌──────────────────────────────────────────────────────────────────┐
│                      Book Import Flow                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  User selects file                                                │
│         │                                                         │
│         ▼                                                         │
│  ┌─────────────────┐                                              │
│  │ BookService     │                                              │
│  │ .importBook()   │                                              │
│  └─────────────────┘                                              │
│         │                                                         │
│         ▼                                                         │
│  ┌─────────────────┐                                              │
│  │ FormatRegistry  │                                              │
│  │ .getParser()    │──────► Returns appropriate parser            │
│  └─────────────────┘                                              │
│         │                                                         │
│         ▼                                                         │
│  ┌─────────────────┐                                              │
│  │ parser.parse()  │──────► Extract metadata                      │
│  └─────────────────┘                                              │
│         │                                                         │
│         ▼                                                         │
│  ┌─────────────────┐                                              │
│  │ parser          │──────► Extract chapter list                  │
│  │ .getChapters()  │                                              │
│  └─────────────────┘                                              │
│         │                                                         │
│         ▼                                                         │
│  ┌─────────────────┐                                              │
│  │ parser          │──────► Extract cover image                   │
│  │ .extractCover() │                                              │
│  └─────────────────┘                                              │
│         │                                                         │
│         ▼                                                         │
│  Save to storage                                                  │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## 扩展指南

要添加新的书籍格式支持：

1. 创建实现 `BookFormatParser` 接口的新解析器类
2. 实现所有四个抽象方法
3. 在 `FormatRegistry.initialize()` 中注册新解析器
4. 或在运行时通过 `FormatRegistry.register()` 动态注册

```
// 新格式解析器示例
class MobiParser implements BookFormatParser {
    @override
    Future<BookMetadata> parse(String filePath) async {
        // MOBI格式解析逻辑
    }
    
    @override
    Future<List<Chapter>> getChapters(String filePath) async {
        // MOBI章节提取逻辑
    }
    
    @override
    Future<ChapterContent> getChapterContent(String filePath, Chapter chapter) async {
        // MOBI内容提取逻辑
    }
    
    @override
    Future<String?> extractCover(String filePath) async {
        // MOBI封面提取逻辑
    }
}

// 注册新格式
FormatRegistry.register('.mobi', MobiParser());
```

## 错误处理约定

所有实现类应遵循以下错误处理约定：

1. **文件不存在**: 抛出 `Exception('File not found: $filePath')`
2. **解析失败**: 记录日志并尝试回退方案
3. **内容为空**: 返回空对象而非抛出异常
4. **封面缺失**: 返回 `null` 而非抛出异常

## 性能考虑

1. **异步操作**: 所有方法都是异步的，避免阻塞UI
2. **资源释放**: PDF解析器需要显式释放文档资源
3. **缓存策略**: 解析器实例可复用（无状态设计）
4. **按需解析**: 只解析用户请求的内容，避免全量解析