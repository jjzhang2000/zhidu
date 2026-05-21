# BookService - 书籍管理服务伪代码文档

## 概述

BookService 是单例模式的书籍管理服务，负责导入、存储、查询和删除。支持 EPUB/PDF 格式，使用文件存储架构。

---

## 单例模式

```pseudocode
CLASS BookService:
    PRIVATE STATIC _instance: BookService = BookService._internal()
    PUBLIC STATIC FACTORY BookService():
        RETURN _instance
    PRIVATE CONSTRUCTOR _internal():
        _epubService = EpubService()
        _pdfService = PdfService()
        _uuid = Uuid()
        _log = LogService()
        _fileStorage = FileStorageService()
        _books = []
```

---

## 数据结构

```pseudocode
PRIVATE PROPERTIES:
    _epubService: EpubService
    _pdfService: PdfService
    _uuid: Uuid
    _log: LogService
    _fileStorage: FileStorageService
    _books: List<Book>

PUBLIC PROPERTIES:
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

### init() - 初始化

```pseudocode
ASYNC METHOD init():
    await _loadBooks()
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

### _loadBooks() - 从索引文件加载元数据

```pseudocode
PRIVATE ASYNC METHOD _loadBooks():
    indexPath = await StorageConfig.getBooksIndexPath()
    data = await _fileStorage.readJson(indexPath)
    
    IF data == null:
        _books = []
        RETURN
    
    booksList = data['books'] as List<dynamic>? ?? []
    _books = []
    
    FOR bookJson IN booksList:
        bookId = bookJson['id'] as String?
        IF bookId == null:
            CONTINUE
        
        metadataPath = await StorageConfig.getBookMetadataPath(bookId)
        metadata = await _fileStorage.readJson(metadataPath)
        
        IF metadata != null:
            TRY:
                _books.add(Book.fromJson(metadata))
            CATCH e:
                _log.e('BookService', '解析书籍元数据失败: {bookId}', e)
    
    _log.d('BookService', '从文件加载了 {_books.length} 本书')
```

---

### _saveBooksIndex() - 保存索引文件

```pseudocode
PRIVATE ASYNC METHOD _saveBooksIndex():
    indexPath = await StorageConfig.getBooksIndexPath()
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
    await _fileStorage.writeJson(indexPath, data)
```

---

### _saveBookMetadata() - 保存书籍元数据

```pseudocode
PRIVATE ASYNC METHOD _saveBookMetadata(book: Book):
    metadataPath = await StorageConfig.getBookMetadataPath(book.id)
    data = book.toJson()
    await _fileStorage.writeJson(metadataPath, data)
```

---

### importBookFromPath() - 从文件路径导入

```pseudocode
ASYNC METHOD importBookFromPath(filePath: String) -> Book?:
    TRY:
        // 读取同目录 OPF 元数据
        opfMetadata: OpfMetadata?
        TRY:
            opfMetadata = await OpfReaderService.readFromSameDirectory(filePath)
        CATCH e:
            _log.w('BookService', '读取外部OPF元数据失败: {e}')
        
        extension = getExtension(filePath).toLowerCase()
        bookId = _uuid.v4()
        book: Book?
        
        IF extension == '.epub':
            book = await _epubService.parseEpubFile(filePath, bookId)
        ELSE IF extension == '.pdf':
            book = await _pdfService.parsePdfFile(filePath, bookId)
        ELSE:
            _log.w('BookService', '不支持的文件格式: {extension}')
            RETURN null
        
        // 合并 OPF 元数据
        IF book != null AND opfMetadata != null:
            finalCoverPath = book.coverPath
            IF opfMetadata.coverPath != null:
                // 复制外部封面文件
                coverDestPath = await StorageConfig.getCoverSavePath(...)
                TRY:
                    await File(coverAbsPath).copy(coverDestPath)
                    finalCoverPath = coverDestPath
                CATCH e:
                    _log.w('BookService', '复制封面失败: {e}')
            book = book.copyWith(
                title: opfMetadata.title ?? book.title,
                author: opfMetadata.author ?? book.author,
                language: opfMetadata.language ?? book.language,
                coverPath: finalCoverPath,
            )
        
        // 标题+作者去重
        IF book != null:
            existingBook = _books.where((b) =>
                b.title == book.title AND b.author == book.author
            ).firstOrNull
            IF existingBook != null:
                _log.info('BookService', '书籍已存在: {book.title}')
                RETURN existingBook
            
            _books.add(book)
            await _saveBooksIndex()
            await _saveBookMetadata(book)
            _log.info('BookService', '书籍导入成功: {book.title}')
            RETURN book
        
        RETURN null
    
    CATCH e, stackTrace:
        _log.e('BookService', '导入书籍失败: {filePath}', e, stackTrace)
        RETURN null
```

---

### importBook() - 通过文件选择器导入

```pseudocode
ASYNC METHOD importBook() -> Book?:
    TRY:
        result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['epub', 'pdf'],
            dialogTitle: '选择电子书'
        )
        
        IF result == null OR result.files.isEmpty:
            RETURN null
        
        filePath = result.files.first.path
        
        IF filePath == null:
            _log.w('BookService', '文件路径为空')
            RETURN null
        
        RETURN await importBookFromPath(filePath)
    
    CATCH e, stackTrace:
        _log.e('BookService', '导入书籍失败', e, stackTrace)
        RETURN null
```

---

### getBookById() - 根据ID获取书籍

```pseudocode
PUBLIC METHOD getBookById(id: String) -> Book?:
    RETURN _books.where((b) => b.id == id).firstOrNull
```

---

### deleteBook() - 删除书籍及其所有数据

```pseudocode
ASYNC METHOD deleteBook(id: String) -> Boolean:
    _log.d('BookService', '删除书籍: {id}')
    
    TRY:
        book = getBookById(id)
        
        IF book == null:
            _log.w('BookService', '要删除的书籍不存在: {id}')
            RETURN false
        
        bookDirPath = await StorageConfig.getBookDirectoryPath(id)
        bookDir = Directory(bookDirPath)
        
        IF await bookDir.exists():
            deleted = await _fileStorage.deleteDirectory(bookDirPath)
            IF NOT deleted:
                _log.e('BookService', '删除书籍目录失败: {book.title} ({id})')
                RETURN false
        
        _books.removeWhere((b) => b.id == id)
        await _saveBooksIndex()
        
        _log.info('BookService', '书籍删除成功: {book.title}')
        RETURN true
    
    CATCH e, stackTrace:
        _log.e('BookService', '删除书籍失败: {id}', e, stackTrace)
        RETURN false
```

---

### updateBook() - 替换内存中的书并持久化

```pseudocode
ASYNC METHOD updateBook(book: Book):
    _log.d('BookService', '更新书籍: {book.title}')
    
    TRY:
        index = _books.indexWhere((b) => b.id == book.id)
        
        IF index >= 0:
            _books[index] = book
            await _saveBooksIndex()
            await _saveBookMetadata(book)
    
    CATCH e, stackTrace:
        _log.e('BookService', '更新书籍失败: {book.id}', e, stackTrace)
```

---

### searchBooks() - 按标题或作者模糊搜索

```pseudocode
PUBLIC METHOD searchBooks(query: String) -> List<Book>:
    lowerQuery = query.toLowerCase()
    RETURN _books.where((book) => 
        book.title.toLowerCase().contains(lowerQuery) OR
        book.author.toLowerCase().contains(lowerQuery)
    ).toList()
```

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