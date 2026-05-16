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
        _streamingCallbacks = Map<String, Function(String)>()
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
    _concurrentRequestSemaphore: Semaphore   // AI 请求信号量（本地模型=1，云端=3）
    _generatingKeys: Set<String>             // 正在生成的章节标识
    
    // 流式内容回调（仅全书摘要）
    _streamingCallbacks: Map<String, Function(String)>  // Key: bookId
    _completedKeys: Set<String>              // 已完成章节key集合
```

---

## 流式回调管理

### 注册全书流式回调

```pseudocode
PUBLIC METHOD registerBookStreamingCallback(
    bookId: String,
    callback: Function(String)
):
    _streamingCallbacks[bookId] = callback
    _log.d('SummaryService', '注册全书摘要流式回调: {bookId}')
```

### 取消全书流式回调

```pseudocode
PUBLIC METHOD unregisterBookStreamingCallback(bookId: String):
    _streamingCallbacks.remove(bookId)
    _log.d('SummaryService', '取消全书摘要流式回调: {bookId}')
```

### 触发全书流式内容更新

```pseudocode
PRIVATE METHOD _notifyBookStreamingContent(
    bookId: String,
    content: String
):
    callback = _streamingCallbacks[bookId]
    
    IF callback != null:
        callback(content)
```

---

## 存储架构

### 摘要文件结构

```
{storage_path}/books/{bookId}/
├── book-summary.md          # 全书摘要
├── Summary-001-zh.md        # 第1章摘要（中文）
├── Summary-002-zh.md        # 第2章摘要（中文）
└── ...
```

### 文件命名规则

```
章节摘要: Summary-{index}-{lang}.md
  - index 为3位数字，如 001, 002
  - lang 为语言代码，如 zh, en, ja

全书摘要: book-summary.md
  - 存储书籍整体概览
```

---

## 方法伪代码

### init() / dispose() - 生命周期管理

```pseudocode
ASYNC METHOD init():
    _initSemaphore()
    SettingsService().aiSettings.addListener(_onAiSettingsChanged)
    _log.d('SummaryService', '初始化完成')

PRIVATE METHOD _onAiSettingsChanged():
    _initSemaphore()

PRIVATE METHOD _initSemaphore():
    provider = _aiService.currentProvider
    isLocal = provider == 'ollama' OR provider == 'lmstudio'
    _concurrentRequestSemaphore = Semaphore(isLocal ? 1 : 3)
    _log.d('SummaryService', '并发限制初始化：provider={provider}, maxConcurrency={isLocal ? 1 : 3}')

METHOD dispose():
    SettingsService().aiSettings.removeListener(_onAiSettingsChanged)
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

### getSummary() - 获取章节摘要

```pseudocode
ASYNC METHOD getSummary(
    bookId: String,
    chapterIndex: int,
    language: String = 'zh'
) -> ChapterSummary?:
    _log.v('SummaryService', 
        'getSummary 开始执行, bookId: {bookId}, chapterIndex: {chapterIndex}, language: {language}')
    
    TRY:
        // 获取摘要文件路径
        filePath = await StorageConfig.getChapterSummaryPath(bookId, chapterIndex, language: language)
        
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
            chapterTitle: '',  // 标题从章节列表获取
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
ASYNC METHOD saveSummary(
    summary: ChapterSummary,
    language: String = 'zh'
):
    TRY:
        // 获取摘要文件路径
        filePath = await StorageConfig.getChapterSummaryPath(
            summary.bookId, summary.chapterIndex, language: language)
        
        // 写入摘要内容
        await _fileStorage.writeText(filePath, summary.objectiveSummary)
        
        _log.d('SummaryService', 
            '摘要已保存: {summary.bookId}_{summary.chapterIndex}_{language}')
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'saveSummary 失败', e, stackTrace)
```

---

### deleteSummary() - 删除章节摘要

```pseudocode
ASYNC METHOD deleteSummary(
    bookId: String, 
    chapterIndex: int,
    language: String = 'zh'
):
    TRY:
        // 获取摘要文件路径
        filePath = await StorageConfig.getChapterSummaryPath(bookId, chapterIndex, language: language)
        
        // 删除文件
        await _fileStorage.deleteFile(filePath)
        
        _log.d('SummaryService', '摘要已删除: {bookId}_{chapterIndex}_{language}')
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'deleteSummary 失败', e, stackTrace)
```

---

### getBookSummary() - 获取全书摘要

```pseudocode
ASYNC METHOD getBookSummary(
    bookId: String, 
    language: String = 'zh'
) -> String?:
    TRY:
        // 获取全书摘要文件路径
        filePath = await StorageConfig.getBookSummaryPath(bookId, language: language)
        
        // 读取文件内容
        RETURN await _fileStorage.readText(filePath)
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'getBookSummary 失败: {bookId}', e, stackTrace)
        RETURN null
```

---

### saveBookSummary() - 保存全书摘要

```pseudocode
ASYNC METHOD saveBookSummary(
    bookId: String, 
    summary: String,
    language: String = 'zh'
):
    TRY:
        // 获取全书摘要文件路径
        filePath = await StorageConfig.getBookSummaryPath(bookId, language: language)
        
        // 写入摘要内容
        await _fileStorage.writeText(filePath, summary)
        
        _log.d('SummaryService', '书籍摘要已保存: {bookId}, language: {language}')
        
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
    language: String = 'zh'             // 语言代码
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
    
    TRY:
        _log.d('SummaryService', '开始生成摘要: {key}, language: {language}')
        
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
            
            // 触发流式内容更新（通过回调参数）
            IF onContentUpdate != null:
                onContentUpdate(accumulatedContent)
        
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
            
            await saveSummary(chapterSummary, language: language)
            
            _log.info('SummaryService', '摘要生成成功: {key}, language: {language}')
            RETURN true
        
        ELSE:
            _log.w('SummaryService', 'AI返回空摘要: {key}')
            RETURN false
    
    CATCH e, stackTrace:
        _log.e('SummaryService', '生成摘要失败: {key}', e, stackTrace)
        RETURN false
    
    FINALLY:
        // 清理并发控制标记
        _generatingKeys.remove(key)
        
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
│  调用 AI 流式生成 (Stream)                                  │
│      ↓                                                      │
│  实时接收 chunks                                            │
│      ↓                                                      │
│  累积内容 → onContentUpdate 回调                            │
│      ↓                                                      │
│  流结束                                                     │
│      ↓                                                      │
│  提取标题 → 更新章节标题                                     │
│      ↓                                                      │
│  保存摘要文件                                                │
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
        existingSummary = await getSummary(book.id, chapterIndex, language: 'zh')
        
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
            // 生成摘要
            await generateSingleSummary(
                book.id,
                chapterIndex,
                chapter.title,
                chapterContent,
                language: 'zh'
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
            await saveBookSummary(book.id, accumulatedContent, language: 'zh')
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
            summary = await getSummary(book.id, i, language: 'zh')
            
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
            await saveBookSummary(book.id, accumulatedContent, language: 'zh')
            _log.info('SummaryService', '全书摘要生成成功: {book.title}')
        
        ELSE:
            _log.w('SummaryService', 'AI返回空的全书摘要: {book.title}')
    
    CATCH e, stackTrace:
        _log.e('SummaryService', '从章节摘要生成全书摘要失败: {book.title}', e, stackTrace)
```

---

### 译文管理

### getTranslation() - 获取章节译文

```pseudocode
ASYNC METHOD getTranslation(
    bookId: String,
    chapterIndex: int,
    targetLang: String
) -> String?:
    TRY:
        filePath = await StorageConfig.getChapterTranslationPath(
            bookId, chapterIndex, targetLang)
        content = await _fileStorage.readText(filePath)
        RETURN content
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 
            'getTranslation 失败: {bookId} chapter {chapterIndex} to {targetLang}', 
            e, stackTrace)
        RETURN null
```

### saveTranslation() - 保存章节译文

```pseudocode
ASYNC METHOD saveTranslation(
    bookId: String,
    chapterIndex: int,
    targetLang: String,
    content: String
):
    TRY:
        filePath = await StorageConfig.getChapterTranslationPath(
            bookId, chapterIndex, targetLang)
        await _fileStorage.writeText(filePath, content)
        _log.d('SummaryService', '译文已保存: {bookId}_{chapterIndex}_{targetLang}')
    
    CATCH e, stackTrace:
        _log.e('SummaryService', 'saveTranslation 失败', e, stackTrace)
```

### generateTranslationStream() - 流式生成章节译文

```pseudocode
ASYNC METHOD generateTranslationStream({
    bookId: String,
    chapterIndex: int,
    content: String,
    chapterTitle: String?,
    sourceLang: String,
    targetLang: String,
    bookFormat: String?,
    onContentUpdate: Function(String)?
}) -> Boolean:
    key = '{bookId}_{chapterIndex}_{targetLang}'
    
    // 防止重复生成
    IF _generatingTranslationKeys.contains(key):
        _log.d('SummaryService', '译文生成中，跳过重复请求: {key}')
        RETURN false
    
    _generatingTranslationKeys.add(key)
    
    TRY:
        _log.d('SummaryService', 
            '开始流式生成译文（格式保留）: {key}, format: {bookFormat}')
        
        translatedContent = await _aiService.translateContent(
            content,
            sourceLang: sourceLang,
            targetLang: targetLang,
            chapterTitle: chapterTitle,
            onProgress: (currentTranslation) {
                IF onContentUpdate != null:
                    onContentUpdate(currentTranslation)
            }
        )
        
        IF translatedContent.isNotEmpty:
            await saveTranslation(bookId, chapterIndex, targetLang, translatedContent)
            _log.info('SummaryService', '译文生成成功: {key}')
            RETURN true
        
        ELSE:
            _log.w('SummaryService', 'AI返回空译文: {key}')
            RETURN false
    
    CATCH e, stackTrace:
        _log.e('SummaryService', '流式生成译文失败: {key}', e, stackTrace)
        RETURN false
    
    FINALLY:
        _generatingTranslationKeys.remove(key)
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

## 流式回调架构

### 双层流式回调机制

```
┌─────────────────────────────────────────────────────────────┐
│                    流式回调架构                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  第一层：方法参数回调 (onContentUpdate)                      │
│      ├─ 通过 generateSingleSummary() 参数传入               │
│      ├─ 适用于章节摘要的实时更新                            │
│      └─ 生命周期：单次方法调用                              │
│                                                             │
│  第二层：注册式回调 (registerBookStreamingCallback)          │
│      ├─ 通过 registerBookStreamingCallback() 注册           │
│      ├─ 适用于全书摘要的实时更新                            │
│      └─ 生命周期：需要手动 unregister                       │
│                                                             │
│  工作流程（章节摘要）:                                       │
│      1. 调用 generateSingleSummary(onContentUpdate: ...)    │
│      2. 流式接收 AI 内容                                    │
│      3. 触发 onContentUpdate(accumulatedContent)            │
│      4. UI 更新状态                                          │
│                                                             │
│  工作流程（全书摘要）:                                       │
│      1. UI 注册回调 registerBookStreamingCallback()         │
│      2. generateSummariesForBook() 内部触发                 │
│      3. 流式接收 AI 内容                                    │
│      4. _notifyBookStreamingContent(bookId, content)        │
│      5. UI 更新状态                                          │
│      6. 生成完成，UI 清理回调 unregister...                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 并发控制机制

### 两层并发控制

```
┌─────────────────────────────────────────────────────────────┐
│                    并发控制架构                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  第一层：章节级并发控制                                       │
│      ├─ _generatingKeys: Set<String>                       │
│      ├─ 防止同一章节被重复生成                               │
│      └─ 快速检查，避免重复请求                               │
│                                                             │
│  第二层：AI请求级并发控制                                     │
│      ├─ _concurrentRequestSemaphore: Semaphore              │
│      ├─ 限制同时进行的AI请求总数                             │
│      ├─ 本地模型（ollama/lmstudio）设为1                     │
│      └─ 云端模型设为3                                       │
│                                                             │
│  工作流程:                                                   │
│      1. 检查 _generatingKeys（章节级）                       │
│      2. 获取 _concurrentRequestSemaphore（AI级）             │
│      3. 执行流式生成任务                                     │
│      4. 实时触发 onContentUpdate 回调                        │
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
    RETURN false
```

---

## 数据持久化策略

### 文件存储

```
章节摘要: Summary-{index}-{lang}.md
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
await saveBookSummary(book.id, summary, language: 'zh')

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
本地模型（ollama/lmstudio）: 最大并发数 = 1
云端模型（zhipu/qwen/deepseek等）: 最大并发数 = 3

原因:
1. 本地模型资源有限，串行处理更稳定
2. 云端模型通常有速率限制
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

- **2026-05-16**: 死代码清理与回调合并
  - 删除未使用字段: `_generatingBookSummaryKeys`, `_generatingFutures`
  - 删除未使用方法: `isGeneratingBookSummary`, `registerStreamingCallback`,
    `unregisterStreamingCallback`, `_notifyStreamingContent`,
    `getSummariesForBook`, `deleteTranslation`
  - 合并 `_bookStreamingCallbacks` 到 `_streamingCallbacks`，统一回调映射表
  - 章节流式通知改为通过 `onContentUpdate` 回调直接传递
  - 信号量改为动态初始化（本地模型=1，云端=3）
  - 添加 `dispose()` 方法清理监听器
