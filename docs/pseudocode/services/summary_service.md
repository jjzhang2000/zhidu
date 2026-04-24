# SummaryService - 摘要服务伪代码文档

## 概述

SummaryService 是一个单例模式的摘要管理服务，负责章节摘要和全书摘要的生成、存储、读取和删除。支持并发控制、流式内容更新，防止同一章节被重复生成摘要。

---

## 单例模式实现

```pseudocode
CLASS SummaryService:
    // 单例实例 - 静态私有变量
    PRIVATE STATIC _instance: SummaryService = SummaryService._internal()
    
    // 工厂构造函数 - 返回单例实例
    PUBLIC STATIC FACTORY SummaryService():
        RETURN _instance
    
    // 私有命名构造函数 - 防止外部实例化
    PRIVATE CONSTRUCTOR _internal():
        // 初始化服务依赖
        _aiService = AIService()
        _bookService = BookService()
        _log = LogService()
        _fileStorage = FileStorageService()
        
        // 初始化并发控制
        _concurrentRequestSemaphore = Semaphore(3)
        _generatingKeys = Set<String>()
        _generatingFutures = Map<String, Future<void>>()
        _streamingCallbacks = Map<String, Function(String)>()
        _bookStreamingCallbacks = Map<String, Function(String)>()
        _generatingBookSummaryKeys = Set<String>()
```

---

## 数据结构

### Semaphore 类（信号量）

```pseudocode
CLASS Semaphore:
    PRIVATE _maxPermits: int              // 最大许可数
    PRIVATE _availablePermits: int        // 可用许可数
    PRIVATE _waitingQueue: List<Completer<void>>  // 等待队列
    
    CONSTRUCTOR Semaphore(maxPermits: int):
        _maxPermits = maxPermits
        _availablePermits = maxPermits
        _waitingQueue = []
    
    // 获取许可
    ASYNC METHOD acquire():
        IF _availablePermits > 0:
            _availablePermits--
            RETURN
        
        // 无可用许可，等待
        completer = Completer<void>()
        _waitingQueue.add(completer)
        RETURN completer.future
    
    // 释放许可
    METHOD release():
        IF _waitingQueue.isNotEmpty:
            // 有等待者，唤醒第一个
            completer = _waitingQueue.removeAt(0)
            completer.complete()
        ELSE:
            // 无等待者，增加可用许可
            _availablePermits++
```

### 私有属性

```pseudocode
PRIVATE PROPERTIES:
    _aiService: AIService                    // AI 服务
    _bookService: BookService                // 书籍服务
    _log: LogService                         // 日志服务
    _fileStorage: FileStorageService         // 文件存储服务
    
    // 并发控制
    _concurrentRequestSemaphore: Semaphore   // AI 请求信号量（最大3）
    _generatingKeys: Set<String>              // 正在生成的章节标识
    _generatingFutures: Map<String, Future<void>>  // 生成中的 Future
    
    // 流式内容回调
    _streamingCallbacks: Map<String, Function(String)>  // 章节流式回调
    _bookStreamingCallbacks: Map<String, Function(String)>  // 全书流式回调
    _generatingBookSummaryKeys: Set<String>   // 全书摘要生成中标记
    _completedKeys: Set<String>              // 已完成章节key集合
```

---

## 流式回调管理

### 注册章节流式回调

```pseudocode
PUBLIC METHOD registerStreamingCallback(
    bookId: String,
    chapterIndex: int,
    callback: Function(String)
):
    // 生成章节唯一标识键
    key = _key(bookId, chapterIndex)
    
    // 注册回调函数
    _streamingCallbacks[key] = callback
    _log.d('SummaryService', '注册章节流式回调: {key}')
```

### 取消章节流式回调

```pseudocode
PUBLIC METHOD unregisterStreamingCallback(
    bookId: String,
    chapterIndex: int
):
    key = _key(bookId, chapterIndex)
    _streamingCallbacks.remove(key)
    _log.d('SummaryService', '取消章节流式回调: {key}')
```

### 触发章节流式内容更新

```pseudocode
PRIVATE METHOD _notifyStreamingContent(
    bookId: String,
    chapterIndex: int,
    content: String
):
    key = _key(bookId, chapterIndex)
    callback = _streamingCallbacks[key]
    
    IF callback != null:
        callback(content)
```

### 注册全书流式回调

```pseudocode
PUBLIC METHOD registerBookStreamingCallback(
    bookId: String,
    callback: Function(String)
):
    _bookStreamingCallbacks[bookId] = callback
    _generatingBookSummaryKeys.add(bookId)
    _log.d('SummaryService', '注册全书摘要流式回调: {bookId}')
```

### 取消全书流式回调

```pseudocode
PUBLIC METHOD unregisterBookStreamingCallback(bookId: String):
    _bookStreamingCallbacks.remove(bookId)
    _generatingBookSummaryKeys.remove(bookId)
    _log.d('SummaryService', '取消全书摘要流式回调: {bookId}')
```

### 触发全书流式内容更新

```pseudocode
PRIVATE METHOD _notifyBookStreamingContent(
    bookId: String,
    content: String
):
    callback = _bookStreamingCallbacks[bookId]
    
    IF callback != null:
        callback(content)
```

### 检查全书摘要是否正在生成

```pseudocode
PUBLIC METHOD isGeneratingBookSummary(bookId: String) -> bool:
    RETURN _generatingBookSummaryKeys.contains(bookId)
```

---

## 存储架构

### 摘要文件结构

```
{storage_path}/books/{bookId}/
├── book-summary.md          # 全书摘要
├── chapter-000.md           # 第0章摘要
├── chapter-001.md           # 第1章摘要
├── chapter-002.md           # 第2章摘要
└── ...
```

### 文件命名规则

```
章节摘要: chapter-{index}.md
  - index 为3位数字，如 000, 001, 002
  - 对应顶层章节索引（level==0）

全书摘要: book-summary.md
  - 存储书籍整体概览
```

---

## 方法伪代码

### init() - 初始化服务

```pseudocode
ASYNC METHOD init():
    // 文件存储模式下无需初始化
    _log.d('SummaryService', '文件存储模式，无需初始化')
```

---

### _key() - 生成章节唯一标识键

```pseudocode
PRIVATE METHOD _key(bookId: String, chapterIndex: int) -> String:
    // 组合书籍ID和章节索引
    RETURN '{bookId}_{chapterIndex}'
```

---

### isGenerating() - 检查是否正在生成

```pseudocode
PUBLIC METHOD isGenerating(bookId: String, chapterIndex: int) -> Boolean:
    // 检查章节标识是否在生成集合中
    RETURN _generatingKeys.contains(_key(bookId, chapterIndex))
```

---

### getGeneratingFuture() - 获取生成中的 Future

```pseudocode
PUBLIC METHOD getGeneratingFuture(
    bookId: String,
    chapterIndex: int
) -> Future<void>?:
    // 返回正在生成的 Future，用于等待完成
    RETURN _generatingFutures[_key(bookId, chapterIndex)]
```

---

### getSummary() - 获取章节摘要

```pseudocode
ASYNC METHOD getSummary(
    bookId: String,
    chapterIndex: int
) -> ChapterSummary?:
    _log.v('SummaryService', 
        'getSummary 开始执行, bookId: {bookId}, chapterIndex: {chapterIndex}')
    
    TRY:
        // 获取摘要文件路径
        filePath = await StorageConfig.getChapterSummaryPath(bookId, chapterIndex)
        
        // 读取文件内容
        content = await _fileStorage.readText(filePath)
        
        // 内容为空
        IF content == null OR content.isEmpty:
            _log.v('SummaryService', 'getSummary 加载完成, result: 空')
            RETURN null
        
        // 构建 ChapterSummary 对象
        summary = ChapterSummary(
            bookId: bookId,
            chapterIndex: chapterIndex,
            chapterTitle: '',  // 标题从书籍元数据获取
            objectiveSummary: content,
            aiInsight: '',
            keyPoints: [],
            createdAt: DateTime.now()
        )
        
        _log.v('SummaryService', 'getSummary 加载完成, result: 有内容')
        RETURN summary
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'getSummary 失败', e, stackTrace)
        RETURN null
```

---

### saveSummary() - 保存章节摘要

```pseudocode
ASYNC METHOD saveSummary(summary: ChapterSummary):
    TRY:
        // 获取摘要文件路径
        filePath = await StorageConfig.getChapterSummaryPath(
            summary.bookId, summary.chapterIndex)
        
        // 写入摘要内容
        await _fileStorage.writeText(filePath, summary.objectiveSummary)
        
        _log.d('SummaryService', 
            '摘要已保存: {summary.bookId}_{summary.chapterIndex}')
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'saveSummary 失败', e, stackTrace)
```

---

### deleteSummary() - 删除章节摘要

```pseudocode
ASYNC METHOD deleteSummary(bookId: String, chapterIndex: int):
    TRY:
        // 获取摘要文件路径
        filePath = await StorageConfig.getChapterSummaryPath(bookId, chapterIndex)
        
        // 删除文件
        await _fileStorage.deleteFile(filePath)
        
        _log.d('SummaryService', '摘要已删除: {bookId}_{chapterIndex}')
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'deleteSummary 失败', e, stackTrace)
```

---

### getSummariesForBook() - 获取书籍所有章节摘要

```pseudocode
ASYNC METHOD getSummariesForBook(bookId: String) -> List<ChapterSummary>:
    TRY:
        // 获取书籍目录
        bookDir = await StorageConfig.getBookDirectory(bookId)
        
        // 列出所有 .md 文件
        files = await _fileStorage.listFiles(bookDir.path, extension: '.md')
        
        summaries = []
        
        // 遍历文件
        FOR file IN files:
            filename = getBasename(file.path)
            
            // 匹配章节摘要文件：chapter-000.md 格式
            IF filename.startsWith('chapter-') AND filename.endsWith('.md'):
                // 提取章节索引
                indexStr = filename.substring(8, 11)  // chapter-000.md -> 000
                index = int.tryParse(indexStr)
                
                IF index != null:
                    // 读取摘要内容
                    content = await _fileStorage.readText(file.path)
                    
                    IF content != null AND content.isNotEmpty:
                        // 获取文件修改时间
                        lastModified = await file.lastModified()
                        
                        // 构建 ChapterSummary
                        summaries.add(ChapterSummary(
                            bookId: bookId,
                            chapterIndex: index,
                            chapterTitle: '',
                            objectiveSummary: content,
                            aiInsight: '',
                            keyPoints: [],
                            createdAt: lastModified
                        ))
        
        // 按章节索引排序
        summaries.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex))
        
        RETURN summaries
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'getSummariesForBook 失败: {bookId}', e, stackTrace)
        RETURN []
```

---

### getBookSummary() - 获取全书摘要

```pseudocode
ASYNC METHOD getBookSummary(bookId: String) -> String?:
    TRY:
        // 获取全书摘要文件路径
        filePath = await StorageConfig.getBookSummaryPath(bookId)
        
        // 读取文件内容
        RETURN await _fileStorage.readText(filePath)
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'getBookSummary 失败: {bookId}', e, stackTrace)
        RETURN null
```

---

### saveBookSummary() - 保存全书摘要

```pseudocode
ASYNC METHOD saveBookSummary(bookId: String, summary: String):
    TRY:
        // 获取全书摘要文件路径
        filePath = await StorageConfig.getBookSummaryPath(bookId)
        
        // 写入摘要内容
        await _fileStorage.writeText(filePath, summary)
        
        _log.d('SummaryService', '书籍摘要已保存: {bookId}')
        
        // 同时更新书籍元数据中的 aiIntroduction 字段
        book = _bookService.getBookById(bookId)
        
        IF book != null:
            updatedBook = book.copyWith(aiIntroduction: summary)
            await _bookService.updateBook(updatedBook)
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'saveBookSummary 失败: {bookId}', e, stackTrace)
```

---

### generateSingleSummary() - 生成单个章节摘要（带流式和并发控制）

```pseudocode
ASYNC METHOD generateSingleSummary(
    bookId: String,
    chapterIndex: int,
    chapterTitle: String,
    content: String,
    onContentUpdate: Function(String)?  // 实时内容更新回调（可选）
) -> Boolean:
    // 生成章节唯一标识
    key = _key(bookId, chapterIndex)
    
    // 并发控制：检查是否正在生成
    IF _generatingKeys.contains(key):
        _log.d('SummaryService', '摘要生成中，跳过重复请求: {key}')
        RETURN false
    
    // 获取并发 AI 请求许可
    await _concurrentRequestSemaphore.acquire()
    
    // 标记为"生成中"
    _generatingKeys.add(key)
    
    // 创建 Completer 用于其他调用者等待
    completer = Completer<void>()
    _generatingFutures[key] = completer.future
    
    TRY:
        _log.d('SummaryService', '开始生成摘要: {key}')
        
        // 调用 AI 流式生成摘要
        stream = _aiService.generateFullChapterSummaryStream(
            content,
            chapterTitle: chapterTitle,
            bookId: bookId
        )
        
        accumulatedContent = ''
        
        // 实时接收流式内容
        AWAIT FOR chunk IN stream:
            accumulatedContent += chunk
            
            // 触发流式内容更新（回调 + 广播）
            IF onContentUpdate != null:
                onContentUpdate(accumulatedContent)
            _notifyStreamingContent(bookId, chapterIndex, accumulatedContent)
        
        // 生成完成，处理最终内容
        IF accumulatedContent.isNotEmpty:
            // 提取 AI 返回的章节标题
            extractedTitle = extractTitleFromSummary(accumulatedContent)
            cleanSummary = removeTitleLineFromSummary(accumulatedContent)
            
            // 如果提取到有效标题，更新书籍元数据
            IF extractedTitle != null AND extractedTitle.isNotEmpty:
                await _bookService.updateChapterTitle(
                    bookId, chapterIndex, extractedTitle)
                _log.d('SummaryService', '提取并更新章节标题: {extractedTitle}')
            
            // 构建并保存摘要对象
            chapterSummary = ChapterSummary(
                bookId: bookId,
                chapterIndex: chapterIndex,
                chapterTitle: extractedTitle ?? chapterTitle,
                objectiveSummary: cleanSummary,
                aiInsight: '',
                keyPoints: [],
                createdAt: DateTime.now()
            )
            
            await saveSummary(chapterSummary)
            
            _log.info('SummaryService', '摘要生成成功: {key}')
            completer.complete()
            RETURN true
        
        ELSE:
            _log.w('SummaryService', 'AI返回空摘要: {key}')
            completer.completeError('Empty summary')
            RETURN false
    
    CATCH e, stackTrace:
        _log.e('SummaryService', '生成摘要失败: {key}', e, stackTrace)
        completer.completeError(e)
        RETURN false
    
    FINALLY:
        // 清理并发控制标记
        _generatingKeys.remove(key)
        _generatingFutures.remove(key)
        
        // 释放并发 AI 请求许可
        _concurrentRequestSemaphore.release()
```

**流式生成流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│       generateSingleSummary() 流式生成流程                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  用户点击生成                                                │
│      ↓                                                      │
│  isGenerating 检查                                          │
│      ├─ 正在生成 → RETURN false                             │
│      ↓                                                      │
│  获取信号量许可                                              │
│      ↓                                                      │
│  加入 _generatingKeys                                       │
│      ↓                                                      │
│  创建 Completer                                             │
│      ↓                                                      │
│  调用 AI 流式生成 (Stream)                                  │
│      ↓                                                      │
│  实时接收 chunks                                            │
│      ↓                                                      │
│  累积内容 → 触发回调                                        │
│      ├─ onContentUpdate(callback参数)                       │
│      └─ _notifyStreamingContent(广播机制)                    │
│      ↓                                                      │
│  流结束                                                     │
│      ↓                                                      │
│  提取标题 → 更新章节标题                                     │
│      ↓                                                      │
│  保存摘要文件                                                │
│      ↓                                                      │
│  complete() Completer                                       │
│      ↓                                                      │
│  清理标记 + 释放信号量                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### generateSummariesForBook() - 为整本书生成摘要

```pseudocode
ASYNC METHOD generateSummariesForBook(book: Book):
    _log.d('SummaryService', '开始为书籍生成摘要: {book.title}')
    
    TRY:
        // 使用 FormatRegistry 获取解析器
        extension = IF book.format == BookFormat.epub THEN '.epub' ELSE '.pdf'
        parser = FormatRegistry.getParser(extension)
        
        IF parser == null:
            _log.w('SummaryService', '不支持的格式: {book.format}')
            RETURN
        
        // 获取章节列表
        chapters = await parser.getChapters(book.filePath)
        _log.d('SummaryService', '获取到 {chapters.length} 个章节')
        
        // 根据格式选择生成策略
        IF book.format == BookFormat.epub:
            // EPUB：先生成全书摘要，再生成章节摘要
            _log.d('SummaryService', 'EPUB格式：先生成全书摘要')
            await _generateBookSummaryFromPreface(book, chapters, parser)
            await _generateChapterSummaries(book, chapters, parser)
        
        ELSE:
            // PDF：先生成章节摘要，再生成全书摘要
            _log.d('SummaryService', 'PDF格式：先生成章节摘要')
            await _generateChapterSummaries(book, chapters, parser)
            await _generateBookSummaryFromChapters(book, chapters)
        
        _log.info('SummaryService', '书籍摘要生成完成: {book.title}')
    
    CATCH e, stackTrace:
        _log.e('SummaryService', '生成书籍摘要失败: {book.title}', e, stackTrace)
```

**生成策略流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│         generateSummariesForBook() 生成策略                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  输入: book (书籍对象)                                       │
│      ↓                                                      │
│  获取解析器 (FormatRegistry)                                 │
│      ↓                                                      │
│  获取章节列表                                                │
│      ↓                                                      │
│  判断书籍格式                                                │
│      │                                                      │
│      ├─ EPUB 格式                                            │
│      │   ├─ 先生成全书摘要（基于目录）                       │
│      │   │   └─ _generateBookSummaryFromPreface()            │
│      │   │       └─ 流式生成 + 实时回调                      │
│      │   └─ 再生成章节摘要                                   │
│      │       └─ _generateChapterSummaries()                 │
│      │                                                      │
│      └─ PDF 格式                                             │
│          ├─ 先生成章节摘要                                   │
│          │   └─ _generateChapterSummaries()                  │
│          │       └─ 流式生成 + 实时回调                      │
│          └─ 再生成全书摘要（基于章节摘要）                   │
│              └─ _generateBookSummaryFromChapters()           │
│                  └─ 流式生成 + 实时回调                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### _generateChapterSummaries() - 生成章节摘要

```pseudocode
PRIVATE ASYNC METHOD _generateChapterSummaries(
    book: Book,
    chapters: List<Chapter>,
    parser: dynamic
):
    // 只为顶层章节（level==0）生成摘要
    topLevelChapters = chapters.where((c) -> c.level == 0).toList()
    _log.d('SummaryService', 
        '开始生成章节摘要: 顶层章节 {topLevelChapters.length} 章')
    
    // 创建并发任务队列
    futures = []
    semaphore = Semaphore(3)  // 最多3个并发任务
    
    FOR chapter IN topLevelChapters:
        // 获取顶层章节索引
        chapterIndex = chapter.index
        
        IF chapterIndex < 0:
            CONTINUE  // 跳过无效索引
        
        // 跳过已有摘要的章节
        existingSummary = await getSummary(book.id, chapterIndex)
        
        IF existingSummary != null:
            _log.d('SummaryService', '章节 {chapterIndex} 已有摘要，跳过')
            CONTINUE
        
        // 创建并发任务
        future = _processChapterConcurrently(
            book, chapter, chapterIndex, parser, semaphore
        )
        
        futures.add(future)
    
    // 等待所有任务完成
    await Future.wait(futures)
    
    _log.d('SummaryService', '所有章节摘要生成完成')
```

---

### _processChapterConcurrently() - 并发处理单个章节

```pseudocode
PRIVATE ASYNC METHOD _processChapterConcurrently(
    book: Book,
    chapter: Chapter,
    chapterIndex: int,
    parser: dynamic,
    semaphore: Semaphore
):
    // 等待信号量许可
    await semaphore.acquire()
    
    TRY:
        // 获取章节内容
        content = await parser.getChapterContent(book.filePath, chapter)
        chapterContent = content.htmlContent
        
        IF chapterContent != null AND chapterContent.isNotEmpty:
            // 生成摘要（使用流式方法）
            await generateSingleSummary(
                book.id,
                chapterIndex,
                chapter.title,
                chapterContent
            )
    
    CATCH e, stackTrace:
        _log.e('SummaryService', '处理章节 {chapterIndex} 时出错', e, stackTrace)
    
    FINALLY:
        // 释放信号量许可
        semaphore.release()
```

---

### _generateBookSummaryFromPreface() - 从前言生成全书摘要（流式）

```pseudocode
PRIVATE ASYNC METHOD _generateBookSummaryFromPreface(
    book: Book,
    chapters: List<Chapter>,
    parser: dynamic
):
    _log.d('SummaryService', '从前言/目录生成全书摘要: {book.title}')
    
    TRY:
        // 检查是否已有全书摘要
        existingSummary = await getBookSummary(book.id)
        
        IF existingSummary != null AND existingSummary.isNotEmpty:
            _log.d('SummaryService', '已有全书摘要，跳过: {book.title}')
            RETURN
        
        // 收集目录信息
        prefaceContent = StringBuffer()
        prefaceContent.writeln('本书目录结构：\n')
        
        // 添加前20章标题
        FOR i = 0 TO min(chapters.length, 20) - 1:
            prefaceContent.writeln('第{i+1}章：{chapters[i].title}')
        
        IF chapters.length > 20:
            prefaceContent.writeln('... 等共 {chapters.length} 章')
        
        // 添加第一章内容样本用于语言检测
        IF chapters.isNotEmpty:
            TRY:
                firstChapter = chapters[0]
                chapterContent = await parser.getChapterContent(
                    book.filePath, firstChapter)
                contentSample = chapterContent.htmlContent
                
                IF contentSample != null AND contentSample.isNotEmpty:
                    // 取前500字符作为语言检测样本
                    sampleLength = min(contentSample.length, 500)
                    prefaceContent.writeln(
                        '\n\n第一章内容样本（用于语言识别）：\n' +
                        contentSample.substring(0, sampleLength)
                    )
            
            CATCH e:
                _log.w('SummaryService', '获取第一章内容用于语言检测失败: {e}')
        
        // 调用 AI 流式生成全书摘要
        stream = _aiService.generateBookSummaryFromPrefaceStream(
            title: book.title,
            author: book.author,
            prefaceContent: prefaceContent.toString(),
            totalChapters: chapters.length,
            bookId: book.id
        )
        
        accumulatedContent = ''
        
        // 实时接收流式内容
        AWAIT FOR chunk IN stream:
            accumulatedContent += chunk
            // 触发流式内容更新
            _notifyBookStreamingContent(book.id, accumulatedContent)
        
        IF accumulatedContent.isNotEmpty:
            await saveBookSummary(book.id, accumulatedContent)
            _log.info('SummaryService', '全书摘要生成成功: {book.title}')
        
        ELSE:
            _log.w('SummaryService', 'AI返回空的全书摘要: {book.title}')
    
    CATCH e, stackTrace:
        _log.e('SummaryService', '从前言生成全书摘要失败: {book.title}', e, stackTrace)
```

---

### _generateBookSummaryFromChapters() - 从章节摘要生成全书摘要（流式）

```pseudocode
PRIVATE ASYNC METHOD _generateBookSummaryFromChapters(
    book: Book,
    chapters: List<Chapter>
):
    _log.d('SummaryService', '从章节摘要生成全书摘要: {book.title}')
    
    TRY:
        // 检查是否已有全书摘要
        existingSummary = await getBookSummary(book.id)
        
        IF existingSummary != null AND existingSummary.isNotEmpty:
            _log.d('SummaryService', '已有全书摘要，跳过: {book.title}')
            RETURN
        
        // 收集章节摘要
        chapterSummaries = []
        contentSamples = []
        
        // 最多使用前10章摘要
        FOR i = 0 TO min(chapters.length, 10) - 1:
            summary = await getSummary(book.id, i)
            
            IF summary != null AND summary.objectiveSummary.isNotEmpty:
                // 截取前200字避免过长
                shortSummary = IF summary.objectiveSummary.length > 200
                               THEN summary.objectiveSummary.substring(0, 200)
                               ELSE summary.objectiveSummary
                chapterSummaries.add('第{i+1}章：{shortSummary}...')
            
            // 获取原始内容样本用于语言检测（最多3个）
            IF contentSamples.length < 3:
                TRY:
                    parser = FormatRegistry.getParser(getExtension(book.filePath))
                    
                    IF parser != null:
                        chapterContent = await parser.getChapterContent(
                            book.filePath, chapters[i])
                        
                        IF chapterContent.htmlContent != null AND
                           chapterContent.htmlContent.isNotEmpty:
                            content = chapterContent.htmlContent
                            sampleLength = min(content.length, 300)
                            contentSamples.add(
                                '第{i+1}章内容样本：{content.substring(0, sampleLength)}')
                
                CATCH e:
                    _log.w('SummaryService', 
                        '获取第{i+1}章内容样本用于语言检测失败: {e}')
        
        IF chapterSummaries.isEmpty:
            _log.w('SummaryService', '没有章节摘要，无法生成全书摘要: {book.title}')
            RETURN
        
        // 合并摘要内容
        combinedContent = chapterSummaries.join('\n\n')
        
        // 添加内容样本用于语言检测
        IF contentSamples.isNotEmpty:
            combinedContent += 
                '\n\n参考内容样本（用于语言识别）：\n' +
                contentSamples.join('\n\n')
        
        // 调用 AI 流式生成全书摘要
        stream = _aiService.generateBookSummaryStream(
            title: book.title,
            author: book.author,
            chapterSummaries: combinedContent,
            totalChapters: chapters.length,
            bookId: book.id
        )
        
        accumulatedContent = ''
        
        // 实时接收流式内容
        AWAIT FOR chunk IN stream:
            accumulatedContent += chunk
            // 触发流式内容更新
            _notifyBookStreamingContent(book.id, accumulatedContent)
        
        IF accumulatedContent.isNotEmpty:
            await saveBookSummary(book.id, accumulatedContent)
            _log.info('SummaryService', '全书摘要生成成功: {book.title}')
        
        ELSE:
            _log.w('SummaryService', 'AI返回空的全书摘要: {book.title}')
    
    CATCH e, stackTrace:
        _log.e('SummaryService', '从章节摘要生成全书摘要失败: {book.title}', e, stackTrace)
```

---

### extractTitleFromSummary() - 从摘要提取章节标题

```pseudocode
PUBLIC METHOD extractTitleFromSummary(summary: String) -> String?:
    // 分割行
    lines = summary.split('\n')
    
    IF lines.isEmpty:
        RETURN null
    
    // 获取第一行
    firstLine = lines[0].trim()
    
    // 匹配格式：## 章节标题：xxx 或 ## 章节标题:xxx
    titlePattern = RegExp('^##\s*章节标题[：:]\s*(.+)$')
    match = titlePattern.firstMatch(firstLine)
    
    IF match != null:
        title = match.group(1)?.trim() ?? ''
        
        // 验证标题有效性
        // 1. 不能为空或过长
        IF title.isEmpty OR title.length > 50:
            RETURN null
        
        // 2. 不能包含 Markdown 格式符号
        IF title.contains('#') OR title.contains('**') OR title.contains('*'):
            RETURN null
        
        RETURN title
    
    RETURN null
```

---

### removeTitleLineFromSummary() - 移除摘要中的标题行

```pseudocode
PUBLIC METHOD removeTitleLineFromSummary(summary: String) -> String:
    // 分割行
    lines = summary.split('\n')
    
    IF lines.isEmpty:
        RETURN summary
    
    // 获取第一行
    firstLine = lines[0].trim()
    
    // 匹配标题模式：## 章节标题：xxx 或 ## 第X章：xxx 等
    titlePattern = RegExp(
        '^##\s*(章节标题[：:]\s*.+|' +
        '第[一二三四五六七八九十0-9]+章[：:]\s*.+|' +
        '前言|序言|引言|序|跋|后记|附录.*)$'
    )
    
    IF titlePattern.hasMatch(firstLine):
        // 如果第二行是空行，跳过前两行
        IF lines.length > 1 AND lines[1].trim().isEmpty:
            RETURN lines.skip(2).join('\n').trim()
        
        // 否则只跳过第一行
        RETURN lines.skip(1).join('\n').trim()
    
    RETURN summary
```

---

### getAllSummaries() - 获取所有书籍的所有摘要

```pseudocode
ASYNC METHOD getAllSummaries() -> List<ChapterSummary>:
    allSummaries = []
    
    // 获取应用目录
    appDir = await StorageConfig.getAppDirectory()
    booksDir = Directory('{appDir.path}/books')
    
    IF NOT await booksDir.exists():
        RETURN []
    
    // 获取所有书籍目录
    bookDirs = await booksDir.list()
        .where((e) -> e is Directory)
        .cast<Directory>()
        .toList()
    
    // 遍历每个书籍目录
    FOR bookDir IN bookDirs:
        bookId = getBasename(bookDir.path)
        summaries = await getSummariesForBook(bookId)
        allSummaries.addAll(summaries)
    
    RETURN allSummaries
```

---

### deleteAllSummariesForBook() - 删除书籍所有摘要

```pseudocode
ASYNC METHOD deleteAllSummariesForBook(bookId: String):
    _log.d('SummaryService', '删除书籍所有摘要: {bookId}')
    
    // 文件存储模式下，书籍目录的删除由 BookService 处理
    // 此方法保留为兼容旧代码的接口
```

---

## 流式回调架构

### 双层流式回调机制

```
┌─────────────────────────────────────────────────────────────┐
│                    流式回调架构                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  第一层：方法参数回调 (onContentUpdate)                      │
│      ├─ 通过 generateSingleSummary() 参数传入               │
│      ├─ 适用于单个调用者的实时更新                          │
│      └─ 生命周期：单次方法调用                              │
│                                                             │
│  第二层：注册式回调 (registerStreamingCallback)             │
│      ├─ 通过 registerStreamingCallback() 注册              │
│      ├─ 适用于多个监听者的广播机制                          │
│      └─ 生命周期：需要手动 unregister                       │
│                                                             │
│  工作流程:                                                   │
│      1. UI 注册回调 registerStreamingCallback()             │
│      2. 调用 generateSingleSummary()                        │
│      3. 流式接收 AI 内容                                    │
│      4. 触发回调 onContentUpdate(accumulatedContent)        │
│      5. 广播内容 _notifyStreamingContent()                  │
│      6. UI 更新状态 setState(() => _streamingSummary)        │
│      7. 生成完成，UI 清理回调 unregisterStreamingCallback() │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 并发控制机制

### 三层并发控制

```
┌─────────────────────────────────────────────────────────────┐
│                    并发控制架构                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  第一层：章节级并发控制                                       │
│      ├─ _generatingKeys: Set<String>                       │
│      ├─ _generatingFutures: Map<String, Future<void>>       │
│      ├─ 防止同一章节被重复生成                               │
│      └─ 允许其他调用者等待完成                               │
│                                                             │
│  第二层：AI请求级并发控制                                     │
│      ├─ _concurrentRequestSemaphore: Semaphore(3)          │
│      ├─ 限制同时进行的AI请求总数                             │
│      └─ 防止API限流和性能问题                                │
│                                                             │
│  第三层：任务级并发控制                                       │
│      ├─ _processChapterConcurrently 中的局部 Semaphore       │
│      ├─ 控制同时处理的章节数量                               │
│      └─ 每个书籍生成任务独立管理                              │
│                                                             │
│  工作流程:                                                   │
│      1. 检查 _generatingKeys（章节级）                       │
│      2. 获取 _concurrentRequestSemaphore（AI级）              │
│      3. 执行流式生成任务                                     │
│      4. 实时触发回调                                         │
│      5. 释放资源                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 信号量工作原理

```
┌─────────────────────────────────────────────────────────────┐
│                  Semaphore(3) 工作原理                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  初始状态: _availablePermits = 3                            │
│                                                             │
│  任务1 acquire() → _availablePermits = 2                   │
│  任务2 acquire() → _availablePermits = 1                   │
│  任务3 acquire() → _availablePermits = 0                   │
│                                                             │
│  任务4 acquire() → 无许可，加入等待队列                     │
│  任务5 acquire() → 无许可，加入等待队列                     │
│                                                             │
│  任务1 release() → 唤醒任务4                               │
│  任务2 release() → 唤醒任务5                               │
│  任务3 release() → _availablePermits = 1                    │
│                                                             │
│  结果: 最多3个任务同时执行                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 错误处理

### AI 调用失败

```pseudocode
CATCH e, stackTrace:
    _log.e('SummaryService', '生成摘要失败: {key}', e, stackTrace)
    completer.completeError(e)
    RETURN false
```

### 文件读取失败

```pseudocode
CATCH e, stackTrace:
    _log.e('SummaryService', 'getSummary 失败', e, stackTrace)
    RETURN null
```

### 空摘要处理

```pseudocode
IF accumulatedContent.isEmpty:
    _log.w('SummaryService', 'AI返回空摘要: {key}')
    completer.completeError('Empty summary')
    RETURN false
```

---

## 数据持久化策略

### 文件存储

```
章节摘要: chapter-{index}.md
  - Markdown 格式
  - 包含 AI 生成的摘要内容
  - 标题行已移除（存储在书籍元数据中）

全书摘要: book-summary.md
  - Markdown 格式
  - 包含书籍整体概览
  - 同时更新书籍元数据的 aiIntroduction 字段
```

### 元数据同步

```pseudocode
// 保存全书摘要时同步更新书籍元数据
await saveBookSummary(book.id, summary)

// 同时更新书籍元数据
book = _bookService.getBookById(book.id)
IF book != null:
    updatedBook = book.copyWith(aiIntroduction: summary)
    await _bookService.updateBook(updatedBook)
```

---

## 性能考量

### 并发数选择

```
最大并发数: 3

原因:
1. AI API 通常有速率限制
2. 过多并发可能导致超时
3. 3个并发可平衡效率和稳定性
```

### 内容截断

```pseudocode
// 章节摘要截取前200字
shortSummary = summary.substring(0, 200)

// 语言检测样本截取前500字
sampleLength = min(content.length, 500)

// 避免内容过长导致 API 调用失败
```

---

## 版本历史

- **2026-04-24**: 添加流式显示功能
  - 新增流式回调注册/取消方法
  - 新增 `_notifyStreamingContent` 和 `_notifyBookStreamingContent`
  - 更新 `generateSingleSummary` 支持流式生成
  - 更新 `_generateBookSummaryFromPreface` 支持流式生成
  - 更新 `_generateBookSummaryFromChapters` 支持流式生成
  - 更新 `removeTitleLineFromSummary` 支持更多标题格式
