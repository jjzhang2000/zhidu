# 智读 (Zhidu) 类/函数调用关系图

> **文档版本**: v2.0 | **更新日期**: 2026-05-11 | **基于代码版本**: v1.3

---

## 一、全局架构调用关系

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           main.dart (入口)                               │
│  _initWindowManager()  →  window_manager + screen_retriever              │
│  Service 初始化链:                                                        │
│    LogService → SettingsService → FileStorageService → StorageConfig     │
│    → BookService → AIService → AiPrompts → SummaryService                │
│    → EpubService → PdfService → FormatRegistry     │
│  FormatRegistry.register('.epub', EpubParser())                          │
│  FormatRegistry.register('.pdf', PdfParser())                            │
└─────────────────────────────────────────────────────────────────────────┘
        │
        └── runApp(ZhiduApp)
                │
                ├── home: HomeScreen
                │       ├── BookshelfScreen
                │       │     └── BookCard ──→ BookScreen
                │       └── 导入按钮 → BookService.importBook()
                │
                ├── settings: SettingsScreen
                │       ├── AiConfigScreen
                │       ├── ThemeSettingsScreen
                │       ├── LanguageSettingsScreen
                │
                └── 全局监听 (ValueNotifier):
                        ├── SettingsService.themeNotifier → AppTheme
                        └── SettingsService.localeNotifier → AppLocalizations
```

---

## 二、模块间依赖矩阵

| 调用方 \ 被调用方 | BkSvc | AiSvc | SumSvc | EpubSvc | PdfSvc | SetSvc | OpfRdr | LogSvc | FileSvc |
|-------------------|:-----:|:-----:|:------:|:-------:|:------:|:------:|:------:|:------:|:-------:|
| **main.dart**     |   ✓   |   ✓   |   ✓    |    ✓    |   ✓    |   ✓    |   —    |   ✓    |   ✓    |
| **HomeScreen**    |   ✓   |   —   |   ✓    |    —    |   —    |   —    |   —    |   ✓    |   —    |
| **BookScreen**    |   ✓   |   ✓   |   ✓    |    —    |   —    |   —    |   —    |   ✓    |   —    |
| **ChapterScreen** |   ✓   |   ✓   |   ✓    |    —    |   —    |   —    |   —    |   ✓    |   —    |
| **PdfReaderScreen**|  ✓   |   —   |   —    |    —    |   ✓    |   —    |   —    |   —    |   —    |
| **AiConfigScreen**|  —   |   ✓   |   —    |    —    |   —    |   ✓    |   —    |   —    |   —    |
| **BookService**   |  —   |   —   |   ✓    |    ✓    |   ✓    |   —    |   —    |   ✓    |   ✓    |
| **AIService**     |  ✓   |   —   |   —    |    —    |   —    |   ✓    |   —    |   ✓    |   —    |
| **SummaryService**|  ✓   |   ✓   |   —    |    —    |   —    |   —    |   —    |   ✓    |   ✓    |
| **EpubService**   |  —   |   —   |   —    |    —    |   —    |   —    |   ✓    |   ✓    |   —    |
| **PdfService**    |  —   |   —   |   —    |    —    |   —    |   —    |   ✓    |   ✓    |   —    |
| **SettingsSvc**   |  ✓   |   ✓   |   —    |    —    |   —    |   —    |   —    |   ✓    |   ✓    |
| **EpubParser**    |  —   |   —   |   —    |    —    |   —    |   —    |   —    |   ✓    |   ✓    |
| **PdfParser**     |  —   |   —   |   —    |    —    |   —    |   —    |   —    |   ✓    |   ✓    |

> 缩写对照: BkSvc=BookService, AiSvc=AIService, SumSvc=SummaryService, SetSvc=SettingsService, OpfRdr=OpfReaderService, LogSvc=LogService, FileSvc=FileStorageService

---

## 三、核心业务流程调用链

### 3.1 书籍导入流程

```
HomeScreen._importBook() / BookshelfScreen._importBook()
    │
    ├── BookService().importBook(filePath)
    │       │
    │       ├── 识别格式 (扩展名)
    │       │       ├── .epub → EpubService().parseEpubFile(filePath)
    │       │       │           ├── EpubReader.readFromUri() (epub_plus库)
    │       │       │           ├── _extractChapters(epubBook)
    │       │       │           ├── _extractCover(epubBook, bookId)
    │       │       │           └── OpfReaderService.readFromSameDirectory()
    │       │       │               └── _parseOpfContent() → OpfMetadata
    │       │       │
    │       │       └── .pdf → PdfService().parsePdfFile(filePath)
    │       │                   ├── PdfDocument.openFile() (pdfrx库)
    │       │                   ├── _detectChapters(document)
    │       │                   ├── _extractCover(document, bookId)
    │       │                   └── OpfReaderService.readFromSameDirectory()
    │       │                       └── _parseOpfContent() → OpfMetadata
    │       │
    │       ├── 合并 OPF 元数据 → Book 对象
    │       │       ├── opfMeta.title ?? 解析标题
    │       │       ├── opfMeta.author ?? "Unknown"
    │       │       ├── opfMeta.language
    │       │       └── ...
    │       │
    │       ├── FileStorageService().writeJson(metadataPath, book.toJson())
    │       ├── FileStorageService().writeJson(booksIndexPath, booksList)
    │       └── 返回 Book 对象（摘要生成不在此处触发）
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
    │                                       └── SummaryService.generateSingleSummaryStream()
    │                                           └── AIService.generateFullChapterSummaryStream()
    │                                               └── _callAIStream() → SSE → onContentUpdate → UI实时显示
    │                                                   └── 生成完成 → 保存文件 → 切换最终 Markdown
    │
    └── _startPreGeneration() (addPostFrameCallback 触发，在build完成之后)
            │
            └── SummaryService.generateSummariesForBook()
                    │
                    ├── [EPUB] _generateBookSummaryFromPreface()
                    │           └── AIService.generateBookSummaryFromPrefaceStream()
                    │               └── _callAIStream() → SSE → onChunk → _notifyBookStreamingContent()
                    │
                    ├── [EPUB/PDF] generateSingleSummary() × N (并发控制: semaphore max=3)
                    │               └── AIService.generateFullChapterSummaryStream()
                    │                   └── _callAIStream() → SSE → onChunk → onContentUpdate回调
                    │
                    └── [PDF] _generateBookSummaryFromChapters()
                                └── AIService.generateBookSummaryStream()
                                    └── _callAIStream() → SSE → onChunk → _notifyBookStreamingContent()
            │
            └── 流式回调 → setState → Tab 0 实时显示 _streamingBookSummary
                    └── 生成完成 → _refreshTimer 检测到变化 → 切换到最终 Markdown 摘要
```

### 3.3 翻译流程

```
ChapterScreen._translateContent()
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
| `generateBookSummaryFromPrefaceStream()` | SummaryService._generateBookSummaryFromPreface() |
| `translateContent()` | SummaryService.generateTranslationStream() |
| `testConnection()` | AiConfigScreen 测试按钮 |
| `detectLanguage()` | SummaryService (语言检测) |
| `_callAIStream()` (内部) | 所有流式方法 |
| `get config` | SummaryService, SettingsScreen |
| `get availableModels` | AiConfigScreen |

### 4.2 SummaryService → 被调用方

| SummaryService 方法 | 调用方 |
|---|---|
| `SummaryService()` (构造) | main.dart, BookScreen, ChapterScreen |
| `generateSummariesForBook()` | BookService.importBook(), BookScreen._startPreGeneration() |
| `generateSingleSummary()` | ChapterScreen._loadSummary() |
| `_generateBookSummaryFromPreface()` (内部) | generateSummariesForBook() (EPUB) |
| `_generateBookSummaryFromChapters()` (内部) | generateSummariesForBook() (PDF) |
| `registerBookStreamingCallback()` | BookScreen.initState() |
| `unregisterBookStreamingCallback()` | BookScreen.dispose() |
| `_notifyBookStreamingContent()` (内部) | 流式回调时 |
| `getChapterSummaryContent()` | ChapterScreen._loadFromLocal() |
| `getBookSummaryContent()` | BookScreen |

### 4.3 SettingsService → 被调用方

| SettingsService 方法 | 调用方 |
|---|---|
| `SettingsService()` (构造) | main.dart |
| `init()` | main.dart |
| `getAiConfig()` / `getAiSettings()` | AIService._loadConfig(), AiConfigScreen |
| `updateAiSettings()` | AiConfigScreen._saveConfig() |
| `updateThemeSettings()` | ThemeSettingsScreen |
| `updateLanguageSettings()` | LanguageSettingsScreen |
| `get themeSettings` / `themeNotifier` | ZhiduApp, AppTheme |
| `get languageSettings` / `localeNotifier` | ZhiduApp |
| `isAIEnabled()` | various screens |

---

## 五、Screen 层导航/调用关系

```
ZhiduApp (MaterialApp)
    │
    ├── HomeScreen
    │       ├── 悬浮按钮 → BookService().importBook() → 文件选择 → 导入
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
BookService         → Book, BookMetadata, Chapter, ChapterSummary
EpubService         → Book, Chapter, ChapterContent, ChapterLocation
PdfService          → Book, PdfChapter, PdfPageContent
AIService           → AiPrompts, AiSettings (直接使用 AppSettings 中的 AiSettings)
SummaryService      → ChapterSummary, Book (aiIntroduction字段)
SettingsService     → AppSettings, AiSettings, ThemeSettings, LanguageSettings
OpfReaderService    → OpfMetadata

Book 模型包含:
  ├── String id, title, author, filePath, coverPath
  ├── BookFormat format (epub/pdf)
  ├── int totalChapters, currentChapterIndex
  ├── String? aiIntroduction (全书摘要Markdown)
  ├── DateTime addedAt, lastReadAt
  ├── double readingProgress
  ├── String? language, publisher, description (OPF 元数据字段)
  ├── List<String> subjects (OPF 元数据字段)
  └── Map<String, String>? translations (译文状态)
```

---

## 七、数据持久化调用关系

```
写操作:
SettingsService._saveSettings()
    → FileStorageService().writeJson(settings.json, appSettings.toJson())

BookService._saveBooks()
    → FileStorageService().writeJson(books.json, booksList)

BookService._saveMetadata()
    → FileStorageService().writeJson(metadata.json, book.toJson())

SummaryService._saveSummary()
    → FileStorageService().writeText(chapter-XXX-zh.md, markdownContent)

SummaryService.saveTranslation()
    → FileStorageService().writeText(chapter-XXX-en.html, htmlContent)

读操作:
SettingsService.init()
    → FileStorageService().readJson(settings.json)

BookService._loadBooks()
    → FileStorageService().readJson(books.json)

BookService.getBook()
    → FileStorageService().readJson(metadata.json)

SummaryService.getChapterSummaryContent()
    → FileStorageService().readText(chapter-XXX-zh.md)

SummaryService.getBookSummaryContent()
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
│  Book                  Chapter              ChapterSummary        │
│  - id: String          - index: int         - chapterIndex: int   │
│  - title: String       - title: String      - summary: String     │
│  - author: String      - location: Chapter  - generatedAt: DateTime│
│  - filePath: String          Location                            │
│  - coverPath: String?  - contentType: String                     │
│  - format: BookFormat                                         │
│  - totalChapters: int    ChapterLocation      ChapterContent      │
│  - aiIntroduction:       - href: String?      - htmlContent: String│
│     String?              - pageNumber: int?   - plainText: String │
│  - language: String?                                             │
│  - publisher: String?    OpfMetadata          AppSettings         │
│  - description: String?  - title: String?     - ai: AiSettings    │
│  - subjects: List<String>│- author: String?     - theme: ThemeSettings│
│  - translations: Map?    - language: String?    - language: LangSettings│
│                          - coverPath: String?                     │
│  BookMetadata            - publisher: String?   AiSettings        │
│  - title: String         - description: String?- provider: String  │
│  - author: String        - subjects: List<String>- apiKey: String │
│  - coverPath: String?                      - model: String       │
│  - chapterCount: int                       - baseUrl: String     │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       SERVICES (业务服务)                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  BookService              AIService              SummaryService   │
│  ─────────────────        ────────────           ───────────────  │
│  + importBook()           + generate..Stream()   + generateSummaries│
│  + getBooks()             + translateHtmlStream()+ generateSingle..│
│  + getBook()              + testConnection()     + getSummary...()│
│  + deleteBook()           + detectLanguage()     + _notifyBookSt..│
│  + searchBooks()          + _callAIStream()      + Semaphore      │
│  + _saveBooks()                                  - _generatingKeys│
│  SettingsService     SummaryService       LogService        │
│  ───────────────     ────────────────     ──────────        │
│  + init()            + generateTranslationStream() + v() / d() │
│  + getAiSettings()   + generateSingle..       + info() / w() │
│  + updateAiSettings()+ getSummary...()         + e()         │
│  + updateThemeSettings()                     + init()       │
│  + updateLanguageSettings()                                  │
│  + themeNotifier                                             │
│  + localeNotifier         FileStorageService                  │
│                             ──────────────────                  │
│  EpubService   PdfService   + writeJson() / readJson()           │
│  ────────────  ──────────── + writeText() / readText()           │
│  + parseEpub.. + parsePdf.. + deleteFile() / deleteDirectory()   │
│  + getChapter..+ getChapterPages() + fileExists()                │
│  + getChapterPageRange()                                        │
│                                                                  │
│  OpfReaderService          StorageConfig                         │
│  ────────────────          ─────────────                         │
│  + readFromOpfFile()       + getAppDirectory()                   │
│  + readFromSameDirectory() + getBooksDirectory()                 │
│  - _parseOpfContent()      + getBookDirectory()                  │
│                            + getBooksIndexPath()                 │
│                            + getBookMetadataPath()               │
│                            + getBookSummaryPath()                │
│                            + getChapterSummaryPath()             │
│                            + getChapterTranslationPath()         │
│                            + getCoverSavePath()                  │
│                            + getCoverPath()                      │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    PARSERS (格式解析器)                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  <<interface>>               EpubParser        PdfParser         │
│  BookFormatParser            ──────────        ─────────         │
│  ────────────────            + parse()         + parse()         │
│  + parse(filePath)           + getChapters()   + getChapters()   │
│  + getChapters()             + getChapterContent() + getChapterContent│
│  + getChapterContent()       + extractCover()  + extractCover()  │
│  + extractCover()                                               │
│                                                                  │
│  FormatRegistry                                                   │
│  ──────────────                                                   │
│  + static register(extension, parser)                            │
│  + static getParser(extension)                                   │
│  + static get supportedFormats                                  │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       SCREENS (UI页面)                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  HomeScreen               BookScreen            ChapterScreen    │
│  ──────────               ──────────            ─────────────    │
│  - BookService            - BookService         - BookService    │
│  - SummaryService         - SummaryService      - SummaryService │
│  + _importBook()          - AIService           - AIService      │
│  + BookshelfScreen         + _startPreGeneration() -Translation..│
│                           + _refreshBookIfNeeded()+ _loadSummary()│
│                                                                    │
│  SettingsScreen           AiConfigScreen        PdfReaderScreen  │
│  ──────────────           ──────────────        ─────────────── │
│  - SettingsService        - SettingsService     - BookService    │
│  + 导航到各设置页         - AIService           - PdfService     │
│                           + _testConnection()                    │
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
| 2026-05-11 | 初始版本：完整类/函数调用关系图，含新服务(TranslationService, OpfReaderService)、新模型(OpfMetadata)、OPF元数据集成流程 |