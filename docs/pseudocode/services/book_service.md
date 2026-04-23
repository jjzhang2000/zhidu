# BookService - 书籍管理服务伪代码文档

## 概述

BookService 是一个单例模式的书籍管理服务，负责书籍的导入、存储、查询和删除。支持 EPUB 和 PDF 格式，使用文件存储架构（JSON + Markdown）。

---

## 单例模式实现

```pseudocode
CLASS BookService:
    // 单例实例 - 静态私有变量
    PRIVATE STATIC _instance: BookService = BookService._internal()
    
    // 工厂构造函数 - 返回单例实例
    PUBLIC STATIC FACTORY BookService():
        RETURN _instance
    
    // 私有命名构造函数 - 防止外部实例化
    PRIVATE CONSTRUCTOR _internal():
        // 初始化服务依赖
        _epubService = EpubService()
        _pdfService = PdfService()
        _log = LogService()
        _fileStorage = FileStorageService()
        _books = []  // 内存中的书籍列表
```

---

## 数据结构

### 私有属性

```pseudocode
PRIVATE PROPERTIES:
    _epubService: EpubService       // EPUB 解析服务
    _pdfService: PdfService         // PDF 解析服务
    _log: LogService                // 日志服务
    _fileStorage: FileStorageService // 文件存储服务
    _books: List<Book>              // 内存中的书籍列表
```

### 公共属性

```pseudocode
PUBLIC PROPERTIES:
    // 只读访问书籍列表 - 外部不能直接修改
    books: List<Book> -> _books
```

---

## 存储架构

### 目录结构

```
{storage_path}/
├── books_index.json          # 索引文件（书籍ID列表）
└── books/
    ├── {book_id_1}/
    │   ├── metadata.json     # 书籍1的完整元数据
    │   ├── summary.md        # 全书摘要
    │   ├── chapter-000.md    # 章节摘要
    │   └── cover.jpg         # 封面图片
    └── {book_id_2}/
        └── metadata.json     # 书籍2的完整元数据
```

### 索引文件格式

```json
{
  "version": "1.0",
  "lastUpdated": "2026-04-22T10:30:00Z",
  "books": [
    {
      "id": "abc123",
      "title": "设计模式",
      "author": "GoF",
      "format": "epub",
      "originalFilePath": "/path/to/book.epub",
      "addedAt": "2026-04-22T10:30:00Z"
    }
  ]
}
```

---

## 方法伪代码

### init() - 初始化书籍服务

```pseudocode
ASYNC METHOD init():
    _log.v('BookService', 'init 开始执行')
    
    // 从文件加载书籍列表
    await _loadBooks()
    
    _log.v('BookService', 'init 执行完成, 加载书籍数量: {_books.length}')
```

**初始化流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│                     init() 初始化流程                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  调用 _loadBooks()                                          │
│      ↓                                                      │
│  读取索引文件 books_index.json                               │
│      ├─ 文件不存在 → _books = []                            │
│      ↓                                                      │
│  遍历索引中的书籍ID                                          │
│      ↓                                                      │
│  读取每本书的 metadata.json                                  │
│      ├─ 解析成功 → 添加到 _books                             │
│      ├─ 解析失败 → 记录错误，跳过                            │
│      ↓                                                      │
│  初始化完成                                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### _loadBooks() - 从文件加载所有书籍

```pseudocode
PRIVATE ASYNC METHOD _loadBooks():
    // 获取索引文件路径
    indexPath = await StorageConfig.getBooksIndexPath()
    
    // 读取索引文件
    data = await _fileStorage.readJson(indexPath)
    
    // 索引文件不存在，返回空列表
    IF data == null:
        _books = []
        RETURN
    
    // 提取书籍列表
    booksList = data['books'] as List<dynamic>? ?? []
    _books = []
    
    // 遍历每个书籍条目
    FOR bookJson IN booksList:
        // 提取书籍ID
        bookId = bookJson['id'] as String?
        IF bookId == null:
            CONTINUE  // 跳过无效条目
        
        // 获取元数据文件路径
        metadataPath = await StorageConfig.getBookMetadataPath(bookId)
        
        // 读取元数据
        metadata = await _fileStorage.readJson(metadataPath)
        
        IF metadata != null:
            TRY:
                // 解析元数据为 Book 对象
                _books.add(Book.fromJson(metadata))
            
            CATCH e:
                _log.e('BookService', '解析书籍元数据失败: {bookId}', e)
    
    _log.d('BookService', '从文件加载了 {_books.length} 本书')
```

---

### _saveBooksIndex() - 保存书籍索引文件

```pseudocode
PRIVATE ASYNC METHOD _saveBooksIndex():
    // 获取索引文件路径
    indexPath = await StorageConfig.getBooksIndexPath()
    
    // 构建索引数据
    data = {
        'version': '1.0',
        'lastUpdated': DateTime.now().toIso8601String(),
        'books': _books.map((b) => {
            'id': b.id,
            'title': b.title,
            'author': b.author,
            'format': b.format.name,
            'originalFilePath': b.filePath,
            'addedAt': b.addedAt.toIso8601String()
        }).toList()
    }
    
    // 写入文件
    await _fileStorage.writeJson(indexPath, data)
```

---

### _saveBookMetadata() - 保存单个书籍元数据

```pseudocode
PRIVATE ASYNC METHOD _saveBookMetadata(book: Book):
    // 获取元数据文件路径
    metadataPath = await StorageConfig.getBookMetadataPath(book.id)
    
    // 序列化 Book 对象
    data = book.toJson()
    
    // 写入文件
    await _fileStorage.writeJson(metadataPath, data)
```

---

### importBookFromPath() - 从指定路径导入书籍

```pseudocode
ASYNC METHOD importBookFromPath(filePath: String) -> Book?:
    _log.v('BookService', 'importBookFromPath 开始执行: {filePath}')
    
    TRY:
        _log.d('BookService', '开始导入书籍: {filePath}')
        
        // 获取文件扩展名
        extension = getExtension(filePath).toLowerCase()
        
        // 根据扩展名选择解析服务
        book: Book?
        
        IF extension == '.epub':
            _log.d('BookService', '开始解析EPUB...')
            book = await _epubService.parseEpubFile(filePath)
            _log.d('BookService', 'EPUB解析结果: {book?.title ?? "失败"}')
        
        ELSE IF extension == '.pdf':
            _log.d('BookService', '开始解析PDF...')
            book = await _pdfService.parsePdfFile(filePath)
            _log.d('BookService', 'PDF解析结果: {book?.title ?? "失败"}')
        
        ELSE:
            _log.w('BookService', '不支持的文件格式: {extension}')
            RETURN null
        
        // 解析成功
        IF book != null:
            // 检查是否已存在（标题+作者去重）
            existingBook = _books.where((b) => 
                b.title == book.title AND b.author == book.author
            ).firstOrNull
            
            IF existingBook != null:
                _log.info('BookService', '书籍已存在: {book.title}')
                RETURN existingBook
            
            // 添加到内存列表
            _books.add(book)
            
            // 保存索引和元数据
            await _saveBooksIndex()
            await _saveBookMetadata(book)
            
            _log.info('BookService', '书籍导入成功: {book.title}')
            RETURN book
        
        RETURN null
    
    CATCH e, stackTrace:
        _log.e('BookService', '导入书籍失败: {filePath}', e, stackTrace)
        RETURN null
```

**导入流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│           importBookFromPath() 导入流程                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  输入: filePath (文件路径)                                   │
│      ↓                                                      │
│  获取文件扩展名                                              │
│      ↓                                                      │
│  选择解析服务                                                │
│      ├─ .epub → EpubService.parseEpubFile()                 │
│      ├─ .pdf → PdfService.parsePdfFile()                    │
│      └─ 其他 → RETURN null                                  │
│      ↓                                                      │
│  解析文件                                                    │
│      ├─ 成功 → book 对象                                     │
│      └─ 失败 → RETURN null                                  │
│      ↓                                                      │
│  检查重复（标题+作者）                                        │
│      ├─ 已存在 → RETURN existingBook                        │
│      ↓                                                      │
│  添加到 _books                                               │
│      ↓                                                      │
│  保存索引文件                                                │
│      ↓                                                      │
│  保存元数据文件                                              │
│      ↓                                                      │
│  RETURN book                                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### importBook() - 通过文件选择器导入书籍

```pseudocode
ASYNC METHOD importBook() -> Book?:
    _log.v('BookService', 'importBook 开始执行')
    
    TRY:
        // 打开文件选择器
        result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['epub', 'pdf'],
            dialogTitle: '选择电子书'
        )
        
        // 用户取消选择
        IF result == null OR result.files.isEmpty:
            _log.d('BookService', '用户取消选择')
            RETURN null
        
        // 获取文件路径
        filePath = result.files.first.path
        
        IF filePath == null:
            _log.w('BookService', '文件路径为空')
            RETURN null
        
        // 调用路径导入方法
        RETURN await importBookFromPath(filePath)
    
    CATCH e, stackTrace:
        _log.e('BookService', '导入书籍失败', e, stackTrace)
        RETURN null
```

---

### getBookById() - 根据ID获取书籍

```pseudocode
PUBLIC METHOD getBookById(id: String) -> Book?:
    // O(n) 线性查找
    RETURN _books.where((b) => b.id == id).firstOrNull
```

---

### deleteBook() - 删除书籍

```pseudocode
ASYNC METHOD deleteBook(id: String) -> Boolean:
    _log.d('BookService', '删除书籍: {id}')
    
    TRY:
        // 查找书籍
        book = getBookById(id)
        
        IF book == null:
            _log.w('BookService', '要删除的书籍不存在: {id}')
            RETURN false
        
        // 删除书籍数据目录
        bookDir = await StorageConfig.getBookDirectory(id)
        await _fileStorage.deleteDirectory(bookDir.path)
        
        // 从内存列表移除
        _books.removeWhere((b) => b.id == id)
        
        // 更新索引文件
        await _saveBooksIndex()
        
        _log.info('BookService', '书籍删除成功: {book.title}')
        RETURN true
    
    CATCH e, stackTrace:
        _log.e('BookService', '删除书籍失败: {id}', e, stackTrace)
        RETURN false
```

**删除流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│              deleteBook() 删除流程                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  输入: id (书籍ID)                                           │
│      ↓                                                      │
│  查找书籍                                                    │
│      ├─ 不存在 → RETURN false                               │
│      ↓                                                      │
│  删除书籍目录                                                │
│      ├─ metadata.json                                       │
│      ├─ summary.md                                          │
│      ├─ chapter-*.md                                        │
│      └─ cover.*                                             │
│      ↓                                                      │
│  从 _books 移除                                              │
│      ↓                                                      │
│  更新索引文件                                                │
│      ↓                                                      │
│  RETURN true                                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### updateBook() - 更新书籍信息

```pseudocode
ASYNC METHOD updateBook(book: Book):
    _log.d('BookService', '更新书籍: {book.title}')
    
    TRY:
        // 在内存列表中查找索引
        index = _books.indexWhere((b) => b.id == book.id)
        
        IF index >= 0:
            // 替换内存中的 Book 对象
            _books[index] = book
            
            // 同步更新索引文件和元数据文件
            await _saveBooksIndex()
            await _saveBookMetadata(book)
            
            _log.d('BookService', '书籍更新成功: {book.title}')
    
    CATCH e, stackTrace:
        _log.e('BookService', '更新书籍失败: {book.id}', e, stackTrace)
```

---

### searchBooks() - 搜索书籍

```pseudocode
PUBLIC METHOD searchBooks(query: String) -> List<Book>:
    // 转换为小写，不区分大小写匹配
    lowerQuery = query.toLowerCase()
    
    // 匹配标题或作者中包含搜索词的书籍
    RETURN _books.where((book) => 
        book.title.toLowerCase().contains(lowerQuery) OR
        book.author.toLowerCase().contains(lowerQuery)
    ).toList()
```

---

### updateChapterTitle() - 更新章节标题映射

```pseudocode
ASYNC METHOD updateChapterTitle(bookId: String, chapterIndex: int, title: String):
    _log.d('BookService', 
        '更新章节标题: bookId={bookId}, index={chapterIndex}, title={title}')
    
    // 获取书籍
    book = getBookById(bookId)
    
    IF book == null:
        _log.w('BookService', '书籍不存在: {bookId}')
        RETURN
    
    // 复制现有标题映射
    updatedTitles = Map<int, String>.from(book.chapterTitles ?? {})
    
    // 更新指定索引的标题
    updatedTitles[chapterIndex] = title
    
    // 创建更新后的 Book 对象
    updatedBook = book.copyWith(chapterTitles: updatedTitles)
    
    // 持久化更新
    await updateBook(updatedBook)
    
    _log.d('BookService', '章节标题更新成功: {title}')
```

---

### saveBooksIndex() - 保存所有书籍索引

```pseudocode
PUBLIC ASYNC METHOD saveBooksIndex():
    // 用于外部服务在恢复数据后更新索引
    await _saveBooksIndex()
```

---

## 去重策略

### 去重逻辑

```pseudocode
// 使用标题+作者组合判断是否重复
existingBook = _books.where((b) => 
    b.title == book.title AND b.author == book.author
).firstOrNull

IF existingBook != null:
    // 重复时返回已存在的书籍，不创建新记录
    RETURN existingBook
```

### 去重原因

1. 避免同一本书多次导入
2. 保留已有的阅读进度和摘要
3. 减少存储空间占用

---

## 错误处理

### 文件解析失败

```pseudocode
CATCH e, stackTrace:
    _log.e('BookService', '导入书籍失败: {filePath}', e, stackTrace)
    RETURN null
```

### 元数据解析失败

```pseudocode
CATCH e:
    _log.e('BookService', '解析书籍元数据失败: {bookId}', e)
    // 跳过该书，继续加载其他书籍
```

### 删除失败

```pseudocode
CATCH e, stackTrace:
    _log.e('BookService', '删除书籍失败: {id}', e, stackTrace)
    RETURN false
```

---

## 数据持久化策略

### 双层存储架构

```
┌─────────────────────────────────────────────────────────────┐
│                    存储架构设计                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  索引层 (books_index.json)                                  │
│      ├─ 存储所有书籍的基本信息                               │
│      ├─ 体积小，加载快速                                     │
│      └─ 用于快速扫描和列表展示                               │
│                                                             │
│  元数据层 (metadata.json)                                   │
│      ├─ 每本书独立存储                                       │
│      ├─ 包含完整信息（章节、位置等）                         │
│      └─ 支持增量更新                                         │
│                                                             │
│  优势:                                                       │
│      ├─ 索引文件小，启动快速                                 │
│      ├─ 元数据独立，修改不影响索引                           │
│      └─ 支持增量更新，避免重写整个数据文件                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 写入时机

| 操作 | 索引文件 | 元数据文件 |
|------|----------|------------|
| 导入书籍 | 写入 | 写入 |
| 删除书籍 | 写入 | 删除目录 |
| 更新书籍 | 写入 | 写入 |
| 更新章节标题 | 写入 | 写入 |

---

## 并发控制

BookService 不使用并发控制，原因:

1. 书籍操作通常是用户手动触发，频率低
2. 文件写入是异步操作，不会阻塞
3. 内存列表操作是同步的，无竞态条件

**注意事项:**

- 快速连续导入可能导致索引文件多次写入
- 删除操作不可逆，需谨慎处理
- 更新操作会同时更新索引和元数据

---

## 性能考量

### 查找性能

```pseudocode
// getBookById 使用 O(n) 线性查找
// 对于大量书籍，可考虑使用 Map 优化

// 当前实现
RETURN _books.where((b) => b.id == id).firstOrNull

// 优化方案（可选）
PRIVATE _booksMap: Map<String, Book> = {}
RETURN _booksMap[id]
```

### 加载性能

```pseudocode
// 索引文件小，加载快速
// 元数据文件按需加载，不一次性加载所有

// 当前实现：启动时加载所有元数据
FOR bookJson IN booksList:
    metadata = await _fileStorage.readJson(metadataPath)
    _books.add(Book.fromJson(metadata))

// 优化方案（可选）：延迟加载元数据
// 仅加载索引，元数据按需加载
```

---

## 测试支持

```pseudocode
// 测试用例示例
TEST BookService:
    // 测试导入
    book = await BookService().importBookFromPath('/path/to/test.epub')
    ASSERT book != null
    ASSERT book.title == 'Test Book'
    
    // 测试去重
    book2 = await BookService().importBookFromPath('/path/to/test.epub')
    ASSERT book2.id == book.id  // 返回同一本书
    
    // 测试搜索
    results = BookService().searchBooks('设计')
    ASSERT results.length > 0
    
    // 测试删除
    success = await BookService().deleteBook(book.id)
    ASSERT success == true
    ASSERT BookService().getBookById(book.id) == null
```