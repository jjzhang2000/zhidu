# 智读 (Zhidu) 类/函数调用关系图

> **文档版本**: v2.10 | **更新日期**: 2026-05-22 | **基于代码版本**: v1.7

---

## 一、全局架构调用关系

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           main.dart (入口)                               │
│  _initWindowManager()  →  window_manager + screen_retriever              │
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
                        ├── SettingsService.themeNotifier → AppTheme
                        └── SettingsService.localeNotifier → AppLocalizations
```

---

## 二、模块间依赖矩阵

| 调用方 \ 被调用方 | BkSvc | AiSvc | SumSvc | FormatReg | EpubPsr | PdfPsr | SetSvc | OpfRdr | LogSvc | FileSvc | WinUtils |
|-------------------|:-----:|:-----:|:------:|:---------:|:-------:|:------:|:------:|:------:|:------:|:-------:|:--------:|
| **main.dart**     |   ✓   |   ✓   |   ✓    |     ✓     |   ✓     |   ✓    |   ✓    |   —    |   ✓    |   ✓    |   ✓    |
| **HomeScreen**    |   ✓   |   —   |   —    |     ✓     |   —     |   —    |   —    |   —    |   —    |   —    |
| **BookScreen**    |   ✓   |   ✓   |   ✓    |     ✓     |   —     |   —    |   —    |   —    |   ✓    |   —    |
| **ChapterScreen** |   ✓   |   ✓   |   ✓    |     ✓     |   —     |   —    |   —    |   —    |   ✓    |   —    |
| **PdfReaderScreen**|  ✓   |   —   |   —    |     ✓     |   —     |   —    |   —    |   —    |   —    |   —    |
| **AiConfigScreen**|  —   |   ✓   |   —    |     —     |   —     |   —    |   ✓    |   —    |   ✓    |   —    |
| **BookService**   |  —   |   —   |   —    |     ✓     |   —     |   —    |   —    |   —    |   ✓    |   ✓    |
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
| `generateBookSummaryFromPrefaceStream()` | SummaryService._generateBookSummaryFromPreface() |
| `translateContent()` | SummaryService.generateTranslationStream() |
| `testConnection()` | AiConfigScreen 测试按钮 |
| `detectLanguageFromContent()` | `detectSourceLanguage()`, `resolveOutputLanguage()` |
| `detectSourceLanguage()` | `_detectLanguageFromMetadataAndContentWithBookId()`, ChapterScreen._initializeLanguageSettings() |
| `detectSystemLanguage()` | `resolveOutputLanguage()`, `_getPromptLoc()` |
| `needsTranslation()` | ChapterScreen._initializeLanguageSettings() |
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
| `_generateBookSummaryFromPreface()` (内部) | generateSummariesForBook() (EPUB) |
| `_generateBookSummaryFromChapters()` (内部) | generateSummariesForBook() (PDF) |
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
EpubService         → Book, BookFormat
PdfService          → Book, BookFormat
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
  ├── int totalChapters, currentChapterIndex
  ├── DateTime addedAt, lastReadAt
  ├── double readingProgress
  ├── String? language (OPF 元数据字段)
  ├── Map<int, String>? chapterTitles (AI 生成的章节标题)
  └── Map<String, String>? translations (译文状态)

全书摘要独立存储在 books/{bookId}/summary-zh.md，不再使用 aiIntroduction 字段
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
│  Book                  Chapter              ChapterLocation       │
│  - id: String          - bookId: String      - href: String?      │
│  - title: String       - index: int          - startPage: int?    │
│  - author: String      - title: String       - endPage: int?      │
│  - filePath: String    - location: ChapterLoc│
│  - coverPath: String?  - level: int                              │
│  - format: BookFormat  - htmlContent: String?                    │
│  - totalChapters: int  - objectiveSummary:                        │
│  - currentChapter: int       String?                              │
│  - readingProgress: double                                        │
│  - language: String?                                              │
│  - chapterTitles: Map?  AppSettings           AiSettings          │
│                          - ai: AiSettings      - provider: String   │
│                          - theme: ThemeSettings- apiKey: String    │
│                          - language: LangSettings- model: String   │
│                                                - baseUrl: String   │
│                                                                    │
│  OpfMetadata (定义在 book.dart 末尾)                              │
│  - title: String?                                                 │
│  - author: String?                                                │
│  - language: String?                                              │
│  - coverPath: String?                                             │
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
│                             + fileExists()                       │
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
│  ────────────────            + getChapters()   + getChapters()   │
│  + getChapters()             + getChapterContent() + getChapterContent│
│  + getChapterContent()                                           │
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
│                           - SummaryService      - SummaryService │
│                           - AIService           - AIService      │
│  + _importBook()          + _startPreGeneration() - Translation..│
│  + _buildEmptyState()     + _refreshBookIfNeeded()+ _loadSummary │
│  + _buildBookGrid()                                           │
│                                                                    │
│  SettingsScreen           AiConfigScreen        PdfReaderScreen  │
│  ──────────────           ──────────────        ─────────────── │
│  - SettingsService        - SettingsService     - BookService    │
│  + 导航到各设置页         - AIService           - PdfService     │
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
| 2026-05-21 | EpubService/PdfService 僵尸代码清理 + 测试同步 — EpubService 删除 8 个公共方法（extractPrefaceContent/getHierarchicalChapterList/getSectionContent/getChapterContentFromHref/getChapterHtml/getSectionHtml/getSectionsInChapter/getChapterList）及 10+ 私有依赖方法、2 个内部类（ChapterInfo/SectionInfo），1265→422 行；PdfService 删除 3 个公共方法（getChapterPages/getChapterPageRange/getPageContent）及 2 个内部类（PdfChapter/PdfPageContent 改为私有 _PdfChapter），472→189 行；同步删除 epub_service_test.pdf_service_test 中对应用例、删除 epub_parser_test/pdf_parser_test 中 extractCover 用例；更新 epub_service.md/pdf_service.md/function_call_relationships.md/index.md |
| 2026-05-21 | BookService: 删除僵尸方法 `saveBooksIndex()`（无外部调用），精简注释（434→289行，-33%），同步更新伪代码 |
| 2026-05-21 | AI 语言检测：`detectLanguageFromContent` 改为 AI 识别；`detectSourceLanguage` 新增 bookId + 回写；合并 `getTargetLanguage` → `resolveOutputLanguage` |
| 2026-05-19 | fix: 删除失败 SnackBar 硬编码中文改 i18n key `loc.failed` |
| 2026-05-19 | fix: BookCard 删除检查 deleteBook() 返回值，防止 IO 失败时目录残留 |
| 2026-05-19 | HomeScreen + BookshelfScreen 合并为单层 Scaffold；删除 GlobalKey/嵌套 Scaffold/重复 BookService 实例 |
| 2026-05-19 | HomeScreen: 删除 SummaryService/LogService 依赖；BookService.deleteBook() 已自动清理书籍目录，无需单独调用 SummaryService |
| 2026-05-18 | AiConfigScreen: 新增 LogService 依赖、_fetchModelsForCurrentProvider 方法；依赖矩阵更新 LogSvc ✓ |
| 2026-05-11 | 初始版本：完整类/函数调用关系图，含新服务(TranslationService, OpfReaderService)、新模型(OpfMetadata)、OPF元数据集成流程 |