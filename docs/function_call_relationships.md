# 智读 (Zhidu) 类/函数调用关系图

> **文档版本**: v2.11 | **更新日期**: 2026-11-13 | **基于代码版本**: v1.7

---

## 一、全局架构调用关系

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           main.dart (入口)                               │
│  initDesktopWindow()  →  window_manager + screen_retriever               │
│  Service 初始化链:                                                        │
│    LogService → SettingsService → FileStorageService → StorageConfig     │
│    → BookService → AIService → AiPrompts → SummaryService                │
│  FormatRegistry.register('.epub', EpubParser())                          │
│  FormatRegistry.register('.pdf', PdfParser())                            │
└─────────────────────────────────────────────────────────────────────────┘
        │
        └── runApp(ZhiduApp)
                │
                ├── home: HomeScreen
                │       └── BookCard ──→ BookScreen
                │
                ├── settings: SettingsScreen
                │       ├── AiConfigScreen
                │       ├── ThemeSettingsScreen
                │       ├── LanguageSettingsScreen
                │
                └── 全局监听 (ValueNotifier):
                        ├── SettingsService.themeMode → AppTheme
                        └── SettingsService.languageSettings → AppLocalizations
```

---

## 二、模块间依赖矩阵

| 调用方 \ 被调用方 | BkSvc | AiSvc | SumSvc | FormatReg | EpubPsr | PdfPsr | SetSvc | OpfRdr | LogSvc | FileSvc |
|-------------------|:-----:|:-----:|:------:|:---------:|:-------:|:------:|:------:|:------:|:------:|:-------:|
| **main.dart**     |   ✓   |   ✓   |   ✓    |     ✓     |   ✓     |   ✓    |   ✓    |   —    |   ✓    |   ✓    |
| **HomeScreen**    |   ✓   |   —   |   —    |     ✓     |   —     |   —    |   —    |   —    |   —    |   —    |
| **BookScreen**    |   ✓   |   ✓   |   ✓    |     ✓     |   —     |   —    |   —    |   —    |   ✓    |   —    |
| **ChapterScreen** |   ✓   |   ✓   |   ✓    |     ✓     |   —     |   —    |   —    |   —    |   ✓    |   —    |
| **PdfReaderScreen**|  ✓   |   —   |   —    |     ✓     |   —     |   —    |   —    |   —    |   —    |   —    |
| **AiConfigScreen**|  —   |   ✓   |   —    |     —     |   —     |   —    |   ✓    |   —    |   ✓    |   —    |
| **BookService**   |  —   |   —   |   —    |     ✓     |   —     |   —    |   —    |   ✓    |   ✓    |   ✓    |
| **AIService**     |  ✓   |   —   |   —    |     —     |   —     |   —    |   ✓    |   —    |   ✓    |   —    |
| **SummaryService**|  ✓   |   ✓   |   —    |     ✓     |   —     |   —    |   —    |   —    |   ✓    |   ✓    |
| **SettingsSvc**   |  ✓   |   ✓   |   —    |     —     |   —     |   —    |   —    |   —    |   ✓    |   ✓    |
| **EpubParser**    |  —   |   —   |   —    |     —     |   —     |   —    |   —    |   —    |   ✓    |   —    |
| **PdfParser**     |  —   |   —   |   —    |     —     |   —     |   —    |   —    |   —    |   ✓    |   —    |

> 缩写对照: BkSvc=BookService, AiSvc=AIService, SumSvc=SummaryService, FormatReg=FormatRegistry, EpubPsr=EpubParser, PdfPsr=PdfParser, SetSvc=SettingsService, OpfRdr=OpfReaderService, LogSvc=LogService, FileSvc=FileStorageService

---

## 三、核心业务流程调用链

### 3.1 书籍导入流程

```
HomeScreen._importBook()
    │
    ├── BookService().importBook()
    │       └── importBookFromPath(filePath)
    │               │
    │               ├── OpfReaderService.readFromSameDirectory(filePath)
    │               │       └── _parseOpfContent() → OpfMetadata
    │               │
    │               ├── 识别格式 (扩展名) → FormatRegistry.getParser(extension)
    │               │       ├── .epub → EpubParser().parseMetadata(filePath, bookId)
    │               │       │           ├── EpubReader.readBook() (epub_plus库)
    │               │       │           ├── _extractChapters(epubBook)
    │               │       │           └── _extractCover(bytes, bookId)
    │               │       │
    │               │       └── .pdf → PdfParser().parseMetadata(filePath, bookId)
    │               │                   ├── PdfDocument.openFile() (sync_pdf_renderer库)
    │               │                   ├── _detectChapters(document)
    │               │                   └── _extractCover(document, bookId)
    │               │
    │               ├── 合并 OPF 元数据 + 解析结果 → Book 对象
    │               │       ├── opfMetadata.title ?? metadata.title
    │               │       ├── opfMetadata.author ?? metadata.author
    │               │       ├── opfMetadata.language
    │               │       └── ...
    │               │
    │               ├── FileStorageService().writeJson(metadataPath, book.toJson())
    │               ├── FileStorageService().writeJson(booksIndexPath, booksList)
    │               └── 返回 Book 对象（摘要生成不在此处触发）
    │
    └── UI 刷新: setState() → 书架更新、新书显示

    ※ 注意：摘要生成在 BookScreen._startPreGeneration() 中触发，详见 3.2 节
```

### 3.2 阅读 + 摘要查看流程

```
HomeScreen.BookCard.onTap → Navigator.push(BookScreen)
    │
    ├── BookScreen.initState()
    │       ├── 加载章节列表 (_loadChapters)
    │       ├── 注册流式回调: registerBookStreamingCallback()
    │       ├── 初始化 TabController (2 tabs)
    │       ├── 启动定时刷新: Timer.periodic(3s) → _refreshBookIfNeeded()
    │       └── addPostFrameCallback → _startPreGeneration()  (首次build后触发)
    │
    ├── BookScreen.build() (首次渲染，Tab框架就绪)
    │       ├── Tab 0 (全书摘要) — 此时显示空占位/加载中
    │       └── Tab 1 (章节目录)
    │               └── 点击章节 → Navigator.push(ChapterScreen)
    │                       │
    │                       ├── ChapterScreen.initState()
    │                       │       ├── _initializeContent()  (加载章节全文)
    │                       │       ├── 初始化 TabController (3 tabs)
    │                       │       ├── _initializeLanguageSettings()
    │                       │       └── addPostFrameCallback → _loadSummary()  (首次build后触发)
    │                       │
    │                       ├── ChapterScreen.build() (首次渲染，Tab框架就绪)
    │                       │       ├── Tab 0 (摘要) — 此时显示空占位/加载中
    │                       │       ├── Tab 1 (译文)
    │                       │       └── Tab 2 (原文)
    │                       │
    │                       └── _loadSummary() (addPostFrameCallback 触发，在build完成之后)
    │                               │
    │                               ├── 后台生成中 (generatingFuture != null)
    │                               │       └── await generatingFuture → 加载最终摘要
    │                               │
    │                               ├── 摘要已缓存 → Markdown渲染章节摘要
    │                               │
    │                               └── 摘要不存在 → _generateSummaryWithStreaming()
    │                                       └── SummaryService.generateSingleSummary()
    │                                           └── AIService.generateFullChapterSummaryStream()
    │                                               └── _callAIStream() → SSE → onContentUpdate → UI实时显示
    │                                                   └── 生成完成 → 保存文件 → 切换最终 Markdown
    │
    └── _startPreGeneration() (addPostFrameCallback 触发，在build完成之后)
            │
            └── SummaryService.generateSummariesForBook()
                    │
                    ├── [EPUB/PDF] generateSingleSummary() × N (并发控制: semaphore max=3)
                    │               └── AIService.generateFullChapterSummaryStream()
                    │                   └── _callAIStream() → SSE → onChunk → onContentUpdate回调
                    │
                    └── [EPUB/PDF] _generateBookSummaryFromChapters()
                                └── AIService.generateBookSummaryStream()
                                    └── _callAIStream() → SSE → onChunk → _notifyBookStreamingContent()
            │
            └── 流式回调 → setState → Tab 0 实时显示 _streamingBookSummary
                    └── 生成完成 → _refreshTimer 检测到变化 → 切换到最终 Markdown 摘要
```

### 3.3 翻译流程

```
ChapterScreen._generateTranslationWithStreaming()
    │
    └── SummaryService().generateTranslationStream(
            bookId, chapterIndex, content, targetLang, ...)
            │
            ├── 防止重复生成 (_generatingTranslationKeys)
            │
            ├── AIService.translateContent(htmlContent, sourceLang, targetLang, onProgress)
            │       └── _callAIStream(systemPrompt, userPrompt, onChunk)
            │           └── HttpClient.post() → SSE 流式响应
            │               └── onProgress(currentTranslation)
            │                   ├── 更新进度
            │                   └── 通知 UI 回调 (onContentUpdate)
            │
            ├── saveTranslation(bookId, chapterIndex, lang, html)
            │       └── FileStorageService().writeText(path, htmlContent)
            │
            └── 清理 _generatingTranslationKeys
```

### 3.4 设置变更流程

```
SettingsScreen / AiConfigScreen / ThemeSettingsScreen / LanguageSettingsScreen
    │
    └── SettingsService().updateXxxSettings(newValue)
            │
            ├── 更新内部状态
            ├── _saveSettings()
            │       └── FileStorageService().writeJson(settingsPath, appSettings.toJson())
            │
            └── ValueNotifier 通知所有监听器
                    ├── _themeNotifier → ZhiduApp._onThemeChanged()
                    │       └── 重建 MaterialApp (全新主题)
                    ├── _localeNotifier → ZhiduApp._onLocaleChanged()
                    │       └── setState → rebuild with new localizationsDelegates
                    └── AI Settings Notifier → AiConfigScreen._onAiConfigChanged()
```

---

## 四、Service 层详细调用关系

### 4.1 AIService → 被调用方

| AIService 方法 | 调用方 |
|---|---|
| `AIService()` (构造) | main.dart |
| `_loadConfig()` (内部) | 构造时、SettingsService 变更时 |
| `generateFullChapterSummaryStream()` | SummaryService.generateSingleSummary() |
| `generateBookSummaryStream()` | SummaryService._generateBookSummaryFromChapters() |
| `translateContent()` | SummaryService.generateTranslationStream() |
| `testConnection()` | AiConfigScreen 测试按钮 |
| `detectLanguageFromContent()` | `detectSourceLanguage()`, `resolveOutputLanguage()` |
| `detectSourceLanguage()` | `_detectLanguageFromMetadataAndContentWithBookId()`, ChapterScreen._initializeLanguageSettings() |
| `detectSystemLanguage()` | `resolveOutputLanguage()`, `_getPromptLoc()` |
| `needsTranslation()` | (已废弃，ChapterScreen 改用源语言==目标语言判断) |
| `convertLanguageCodeToStandard()` | `detectSourceLanguage()` |
| `_callAIStream()` (内部) | 所有流式方法 |
| `get config` | SummaryService, SettingsScreen |
| `get availableModels` | AiConfigScreen |
| `get isConfigured` | BookScreen, ChapterScreen |

### 4.2 SummaryService → 被调用方

| SummaryService 方法 | 调用方 |
|---|---|
| `SummaryService()` (构造) | main.dart, BookScreen, ChapterScreen |
| `generateSummariesForBook()` | BookScreen._startPreGeneration() |
| `generateSingleSummary()` | ChapterScreen._loadSummary(), ChapterScreen._generateSummaryWithStreaming() |
| `_generateBookSummaryFromChapters()` (内部) | generateSummariesForBook() (EPUB/PDF) |
| `registerBookStreamingCallback()` | BookScreen.initState() |
| `unregisterBookStreamingCallback()` | BookScreen.dispose() |
| `_notifyBookStreamingContent()` (内部) | 流式回调时 |
| `getTranslation()` | ChapterScreen._loadTranslation(), ChapterScreen._generateTranslationWithStreaming() |
| `generateTranslationStream()` | ChapterScreen._generateTranslationWithStreaming() |

### 4.3 SettingsService → 被调用方

| SettingsService 方法 | 调用方 |
|---|---|
| `SettingsService()` (构造) | main.dart |
| `init()` | main.dart |
| `get settings` | AIService._loadConfig(), 各设置页面 |
| `get aiSettings` (ValueNotifier) | AIService, AiConfigScreen |
| `updateAiSettings()` | AiConfigScreen |
| `setThemeMode()` | ThemeSettingsScreen |
| `updateLanguageSettings()` | LanguageSettingsScreen |
| `get themeMode` (ValueNotifier) | ZhiduApp, AppTheme |
| `get languageSettings` (ValueNotifier) | ZhiduApp |

---

## 五、Screen 层导航/调用关系

```
ZhiduApp (MaterialApp)
    │
    ├── HomeScreen
    │       ├── AppBar搜索框 → 过滤书籍
    │       ├── FAB → BookService().importBook() → 文件选择 → 导入
    │       └── BookCard.onTap → Navigator.push(BookScreen)
    │
    ├── BookScreen (接收 Book 对象)
    │       ├── 章节列表 → Navigator.push(ChapterScreen)
    │       ├── 全书摘要 → 点击进入第一章 (ChapterScreen)
    │       └── 返回 → Navigator.pop()
    │
    └── ChapterScreen (接收 bookId + chapterIndex)
                    ├── 垂直Tab: 摘要 | 原文 | 译文
                    ├── 译文Tab → SummaryService.generateTranslationStream()
                    └── 返回 → Navigator.pop()
```

---

## 六、模型依赖关系

```
BookService         → Book, Chapter
EpubParser          → BookMetadata, Chapter
PdfParser           → BookMetadata, Chapter
AIService           → AiPrompts, AiSettings (直接使用 AppSettings 中的 AiSettings)
SummaryService      → Chapter, Book (通过summary-zh.md文件存储全书摘要)
SettingsService     → AppSettings, AiSettings, ThemeSettings, LanguageSettings
OpfReaderService    → OpfMetadata

Chapter 模型包含:
  ├── bookId: String (可选)
  ├── index: int
  ├── title: String
  ├── location: ChapterLocation
  ├── level: int
  ├── htmlContent: String?
  └── objectiveSummary: String?

Book 模型包含:
  ├── String id, title, author, filePath, coverPath
  ├── BookFormat format (epub/pdf)
  ├── int totalChapters, currentChapter
  ├── DateTime addedAt, lastReadAt
  ├── double readingProgress
  └── String? language (OPF 元数据字段)

全书摘要独立存储在 books/{bookId}/summary-zh.md，不再使用 aiIntroduction 字段
```

---

## 七、数据持久化调用关系

```
写操作:
SettingsService._saveSettings()
    → FileStorageService().writeJson(settings.json, appSettings.toJson())

BookService._saveBooksIndex()
    → FileStorageService().writeJson(books.json, booksList)

BookService._saveBookMetadata()
    → FileStorageService().writeJson(metadata.json, book.toJson())

SummaryService.saveSummary()
    → FileStorageService().writeText(Summary-XXX-zh.md, markdownContent)

SummaryService.saveTranslation()
    → FileStorageService().writeText(chapter-XXX-en.html, htmlContent)

读操作:
SettingsService.init()
    → FileStorageService().readJson(settings.json)

BookService._loadBooks()
    → FileStorageService().readJson(books.json)

BookService.getBook()
    → FileStorageService().readJson(metadata.json)

SummaryService.getSummary()
    → FileStorageService().readText(Summary-XXX-zh.md)

SummaryService.getBookSummary()
    → FileStorageService().readText(summary-zh.md)
```

---

## 八、设计模式总结

| 模式 | 应用位置 | 说明 |
|------|----------|------|
| **单例模式** | 所有 Service 类 | 全局唯一实例，通过工厂构造函数 `factory` 实现 |
| **工厂模式** | `FormatRegistry.register()` | 扩展名 → 解析器映射，动态创建解析器 |
| **策略模式** | `BookFormatParser` 接口 | `EpubParser` / `PdfParser` 实现统一接口 |
| **观察者模式** | `ValueNotifier` + 流式回调 | 设置变更通知 / 流式内容实时推送 |
| **并发控制** | `Semaphore` 类 | 限制并发 AI 请求数 (max=3) |
| **防重复** | `_generatingKeys` | 防止重复生成同一章节 |
| **回调注册** | `registerBookStreamingCallback` | UI 注册回调监听流式全书摘要 |
| **章节流式通知** | `onContentUpdate` 参数 | 章节摘要流式内容直接通过方法参数回调 |

---

## 九、完整类图 (UML 风格)

```
┌──────────────────────────────────────────────────────────────────┐
│                        MODELS (数据模型)                           │
├──────────────────────────────────────────────────────────────────┤
│  Book                      Chapter               ChapterLocation  │
│  - id: String              - bookId: String       - href: String? │
│  - title: String           - index: int           - startPage: int?│
│  - author: String          - title: String        - endPage: int? │
│  - coverPath: String?      - location: ChapterLocation            │
│  - filePath: String        - level: int                           │
│  - format: BookFormat      - htmlContent: String?                 │
│  - totalChapters: int      - objectiveSummary: String?            │
│  - currentChapter: int                                            │
│  - readingProgress: double                                        │
│  - addedAt: DateTime                                              │
│  - lastReadAt: DateTime?                                          │
│  - language: String?                                              │
│                                                                    │
│  OpfMetadata (定义在 book.dart)   AppSettings     AiSettings       │
│  - title: String?                 - ai: AiSettings - provider      │
│  - author: String?                - theme         - apiKey         │
│  - language: String?              - language      - model          │
│  - coverPath: String?                             - baseUrl        │
│                                                                    │
│  BookMetadata (定义在 book_format_parser.dart)                    │
│  - title / author / totalChapters / coverPath? / language?        │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       SERVICES (业务服务)                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  BookService              AIService              SummaryService   │
│  ─────────────            ──────────             ───────────────  │
│  + books (getter)         + generateFullChapterSummaryStream()    │
│  + importBook()           + generateBookSummaryStream()           │
│  + importBookFromPath()   + translateContent()   + generateSingleSummary()│
│  + getBookById()          + testConnection()     + generateSummariesForBook()│
│  + deleteBook()           + detectLanguageFromContent()           │
│  + updateBook()           + detectSourceLanguage()                │
│  + searchBooks()          + resolveOutputLanguage()               │
│  + _saveBooksIndex()      + needsTranslation()   + getSummary()   │
│  + _saveBookMetadata()    + fetchAvailableModels()+ saveSummary() │
│                           + _callAIStream()      + getBookSummary()│
│                                                  + saveBookSummary()│
│  SettingsService          SummaryService(续)     + getTranslation()│
│  ───────────────          ────────────────       + saveTranslation()│
│  + init()                 + generateTranslationStream()           │
│  + settings (getter)      + ensureChapterTranslation()            │
│  + themeMode (getter)     + registerBookStreamingCallback()       │
│  + aiSettings (getter)    + Semaphore (并发控制 max=3)            │
│  + languageSettings      + _generatingKeys                        │
│  + updateAiSettings()     LogService                               │
│  + setThemeMode()         ──────────                               │
│  + updateLanguageSettings() + v() / d() / info() / w() / e()      │
│  + getSavedAiConfigForProvider()  + init()                        │
│                                                                  │
│  FileStorageService        OpfReaderService       StorageConfig   │
│  ──────────────────        ────────────────       ─────────────   │
│  + writeJson()/readJson()  + readFromOpfFile()    + getAppDirectory()│
│  + writeText()/readText()  + readFromSameDirectory()+ getBooksIndexPath()│
│  + deleteFile()            - _parseOpfContent()   + getBookDirectoryPath()│
│  + deleteDirectory()                              + getBookDirectory()│
│                                                   + getBookMetadataPath()│
│                                                   + getBookSummaryPath()│
│                                                   + getChapterSummaryPath()│
│                                                   + getChapterTranslationPath()│
│                                                   + getCoverSavePath()│
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    PARSERS (格式解析器)                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  <<interface>>               EpubParser        PdfParser         │
│  BookFormatParser            ──────────        ─────────         │
│  ────────────────            + parseMetadata() + parseMetadata() │
│  + parseMetadata()           + getChapters()   + getChapters()   │
│  + getChapters()             + getChapterContent()               │
│  + getChapterContent()       + getChapterContent()               │
│                                                                  │
│  FormatRegistry                                                   │
│  ──────────────                                                   │
│  + static register(extension, parser)                            │
│  + static getParser(extension) → BookFormatParser?               │
│  + static isSupported(extension)                                 │
│  + static getSupportedFormats()                                  │
│  + static clear()                                                │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       SCREENS (UI页面)                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  HomeScreen               BookScreen            ChapterScreen    │
│  ──────────               ──────────            ─────────────    │
│  - BookService            - BookService         - BookService    │
│                           - SummaryService      - SummaryService │
│                           - AIService           - AIService      │
│  + _importBook()          + _startPreGeneration()+ _loadSummary()│
│  + _buildEmptyState()     + _refreshBookIfNeeded()+ _generateTranslationWithStreaming()│
│  + _buildBookGrid()                                           │
│                                                                    │
│  SettingsScreen           AiConfigScreen        PdfReaderScreen  │
│  ──────────────           ──────────────        ─────────────── │
│  - SettingsService        - SettingsService     - BookService    │
│  + 导航到各设置页         - AIService           - PdfParser      │
│                           - LogService                           │
│                           + _testConnection()                    │
│                           + _fetchModelsForCurrentProvider()     │
│                                                                  │
│  ThemeSettingsScreen      LanguageSettingsScreen                 │
│  ──────────────────       ────────────────────                   │
│  - SettingsService        - SettingsService                     │
└──────────────────────────────────────────────────────────────────┘
```

---

## 十、更新记录

| 日期 | 更新内容 |
|------|----------|
| 2026-11-13 | 冗余代码清理 + 注释规整 + 文档同步 — 代码侧：删除未使用 import/字段、清理冗余空安全操作符、删除死 l10n key `promptPrefaceSummary`、修复 stale 测试；文档侧：类图 UML 修复（删除 `chapterTitles`、`EpubService`/`PdfService` → `EpubParser`/`PdfParser`、删除 `fileExists()`/`getBooksDirectory()`/`getCoverPath()`、PdfReaderScreen `PdfService` → `PdfParser`、`translateHtmlStream()` → `translateContent()`、`_saveBooks()` → `_saveBooksIndex()`、`getBook()` → `getBookById()`）；`index.md` 修正章节摘要文件名 `Summary-{index}-{lang}.md` |
| 2026-05-21 | EpubService/PdfService 僵尸代码清理 + 测试同步 — EpubService 删除 8 个公共方法（extractPrefaceContent/getHierarchicalChapterList/getSectionContent/getChapterContentFromHref/getChapterHtml/getSectionHtml/getSectionsInChapter/getChapterList）及 10+ 私有依赖方法、2 个内部类（ChapterInfo/SectionInfo），1265→422 行；PdfService 删除 3 个公共方法（getChapterPages/getChapterPageRange/getPageContent）及 2 个内部类（PdfChapter/PdfPageContent 改为私有 _PdfChapter），472→189 行；同步删除 epub_service_test.pdf_service_test 中对应用例、删除 epub_parser_test/pdf_parser_test 中 extractCover 用例；更新 epub_service.md/pdf_service.md/function_call_relationships.md/index.md |
| 2026-05-21 | BookService: 删除僵尸方法 `saveBooksIndex()`（无外部调用），精简注释（434→289行，-33%），同步更新伪代码 |
| 2026-05-21 | AI 语言检测：`detectLanguageFromContent` 改为 AI 识别；`detectSourceLanguage` 新增 bookId + 回写；合并 `getTargetLanguage` → `resolveOutputLanguage` |
| 2026-05-19 | fix: 删除失败 SnackBar 硬编码中文改 i18n key `loc.failed` |
| 2026-05-19 | fix: BookCard 删除检查 deleteBook() 返回值，防止 IO 失败时目录残留 |
| 2026-05-19 | HomeScreen + BookshelfScreen 合并为单层 Scaffold；删除 GlobalKey/嵌套 Scaffold/重复 BookService 实例 |
| 2026-05-19 | HomeScreen: 删除 SummaryService/LogService 依赖；BookService.deleteBook() 已自动清理书籍目录，无需单独调用 SummaryService |
| 2026-05-18 | AiConfigScreen: 新增 LogService 依赖、_fetchModelsForCurrentProvider 方法；依赖矩阵更新 LogSvc ✓ |
| 2026-05-11 | 初始版本：完整类/函数调用关系图，含新服务(TranslationService, OpfReaderService)、新模型(OpfMetadata)、OPF元数据集成流程 |