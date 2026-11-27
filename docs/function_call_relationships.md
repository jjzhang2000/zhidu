# 智读 (Zhidu) 类/函数调用关系图

> **文档版本**: v2.18 | **更新日期**: 2026-11-20 | **基于代码版本**: v1.9

---

## 一、全局架构调用关系

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           main.dart (入口)                               │
│  initDesktopWindow()  →  window_manager + screen_retriever（恢复上次窗口位置/尺寸/最大化） │
│  Service 初始化链:                                                        │
│    LogService → SettingsService → FileStorageService → StorageConfig     │
│    → BookService → AIService → AiPrompts → SummaryService                │
│    → LibraryImportService                                                │
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
                │       └── 主题/语言/书库设置（内联）
                │
                └── 全局监听 (ValueNotifier):
                        ├── SettingsService.themeMode → AppTheme
                        └── SettingsService.languageSettings → AppLocalizations
```

---

## 二、模块间依赖矩阵

| 调用方 \ 被调用方 | BkSvc | AiSvc | SumSvc | FormatReg | EpubPsr | PdfPsr | SetSvc | OpfRdr | LogSvc | FileSvc | LibImpSvc |
|-------------------|:-----:|:-----:|:------:|:---------:|:-------:|:------:|:------:|:------:|:------:|:-------:|:--------:|
| **main.dart**     |   ✓   |   ✓   |   ✓    |     ✓     |   ✓     |   ✓    |   ✓    |   —    |   ✓    |   ✓    |    ✓     |
| **HomeScreen**    |   ✓   |   —   |   —    |     ✓     |   —     |   —    |   —    |   —    |   —    |   —    |    ✓     |
| **BookScreen**    |   ✓   |   ✓   |   ✓    |     ✓     |   —     |   —    |   —    |   —    |   ✓    |   —    |    —     |
| **ChapterScreen** |   ✓   |   ✓   |   ✓    |     ✓     |   —     |   —    |   —    |   —    |   ✓    |   —    |    —     |
| **AiConfigScreen**|  —   |   ✓   |   —    |     —     |   —     |   —    |   ✓    |   —    |   ✓    |   —    |    —     |
| **SettingsScreen**|  ✓   |   —   |   —    |     —     |   —     |   —    |   ✓    |   —    |   —    |   —    |    ✓     |
| **BookService**   |  —   |   —   |   —    |     ✓     |   —     |   —    |   —    |   ✓    |   ✓    |   ✓    |    —     |
| **AIService**     |  ✓   |   —   |   —    |     —     |   —     |   —    |   ✓    |   —    |   ✓    |   —    |    —     |
| **SummaryService**|  ✓   |   ✓   |   —    |     ✓     |   —     |   —    |   —    |   —    |   ✓    |   ✓    |    —     |
| **SettingsSvc**   |  ✓   |   ✓   |   —    |     —     |   —     |   —    |   —    |   —    |   ✓    |   ✓    |    —     |
| **LibraryImportService** | ✓ | — | — | — | — | — | — | — | ✓ | — | — |
| **EpubParser**    |  —   |   —   |   —    |     —     |   —     |   —    |   —    |   —    |   ✓    |   —    |    —     |
| **PdfParser**     |  —   |   —   |   —    |     —     |   —     |   —    |   —    |   —    |   ✓    |   —    |    —     |

> 缩写对照: BkSvc=BookService, AiSvc=AIService, SumSvc=SummaryService, FormatReg=FormatRegistry, EpubPsr=EpubParser, PdfPsr=PdfParser, SetSvc=SettingsService, OpfRdr=OpfReaderService, LogSvc=LogService, FileSvc=FileStorageService, LibImpSvc=LibraryImportService

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
    │               │       ├── .epub → EpubParser().extractBasicMetadata(filePath, bookId)
    │               │       │           └── 只读 dc:title/dc:creator/dc:language + 封面（不解析章节）
    │               │       │
    │               │       └── .pdf → PdfParser().extractBasicMetadata(filePath, bookId)
    │               │                   └── 只读文件名标题 + 首页封面（跳过章节检测）
    │               │
    │               ├── 合并 OPF 元数据 + 基本信息 → Book 对象
    │               │       ├── opfMetadata.title ?? basicInfo.title ?? 文件名
    │               │       ├── opfMetadata.author ?? basicInfo.author ?? '未知作者'
    │               │       ├── opfMetadata.language
    │               │       └── ...
    │               │
    │               ├── FileStorageService().writeJson(metadataPath, book.toJson())
    │               ├── FileStorageService().writeJson(booksIndexPath, booksList)
    │               └── 返回 Book 对象（摘要生成不在此处触发）
    │
    └── UI 刷新: setState() → 书架更新、新书显示
```

### 3.1.1 Calibre 书库导入流程

```
SettingsScreen._browseCalibreLibrary() / _refreshCalibreLibrary()
    │
    └── LibraryImportService().startImport(libraryPath)
            │
            ├── BookService.scanCalibreOpfFiles(libraryPath)
            │       └── 递归扫描 metadata.opf，跳过隐藏目录(.caltrash/.calnotes)
            │
            └── _runImportLoop() 后台循环
                    ├── BookService.importOpfFile(opfPath)
                    │       ├── OpfReaderService.parseOpf() → OpfMetadata
                    │       ├── 封面从 guide 段落读 reference type="cover"
                    │       ├── _findBookFile() 定位 .epub/.pdf
                    │       ├── title+author 去重
                    │       └── _saveBooksIndex + _saveBookMetadata
                    │
                    ├── 每 10 本: refreshSignal++ → HomeScreen setState
                    └── 完成: refreshSignal++ → _deleteProgress()
```

### 3.2 阅读 + 缩写查看 + 译文查看流程

```
HomeScreen.BookCard.onTap → Navigator.push(BookScreen) 书籍详情
    │
    ├── BookScreen.initState()
    │       ├── _updateLastReadAt()  (更新最后阅读时间并持久化)
    │       └── _loadChapters() → 命中内存缓存直接显示；否则 ensureBookFileLocal()（非本地复制到应用目录）→ EpubParser.getChapters()（后台 isolate 解析）→ 保存 totalChapters → 出版信息补充（异步，不阻塞首屏）
    │
    ├── BookScreen.build() (单页：封面行 + 章节列表，无Tab)
    │       ├── 封面行「阅读」按钮 → _startReading()
    │       │       ├── 先 getBookById() 刷新 _book（避免使用过期快照）
    │       │       ├── [lastChapterIndex > 0] _resumeReading(index) → _openChapter(章节, 恢复页码)
    │       │       ├── [lastChapterIndex == -1] 上次停在开头页 → _loadOpeningContent() → _openOpening(opening, 恢复页码)
    │       │       ├── [lastChapterIndex == 0] 上次停在第一章 → _openChapter(首章, initialPagedPage)
    │       │       ├── [PDF] _openChapter(首章, initialPage: 1 / lastPage+1)
    │       │       └── [lastChapterIndex == null] 首次阅读 → _loadOpeningContent()（EPUB 前置页）
    │       │               └── 返回 RenderedContent（spine 首文件，经 EpubCssEngine 内联 CSS/图片 + SVG 封面转 <img> + 提取内嵌字体）
    │       │                       ├── html 非空 → _openOpening(rendered) → ChapterScreen(openingContent + openingFonts + openingIsVertical + openingPlainText)
    │       │                       └── 空 → _openChapter(首章)
    │       └── 点击章节 → _openChapter(chapter) → Navigator.push(ChapterScreen)
    │
    └── ChapterScreen (垂直Tab: 原文(0) | 缩写(1) | 译文(2) | 目录(3)，默认进入原文)
            │
            ├── initState()
            │       ├── 初始化 TabController(4) → 默认 index 0 = 原文
            │       ├── _initializeLanguageSettings()（源语言检测 + 目标语言）
            │       └── _initializeContent()（openingContent / chapterContent / filePath）
            │               ├── _loadEmbeddedFonts()（EPUB 内嵌字体经 FontLoader 注册）
            │               └── _checkContentLength()（内容过短置灰缩写 Tab）
            │
            ├── 原文 Tab 渲染（_buildOriginalTextView）
            │       ├── [PDF] PdfDocumentViewBuilder 单页查看器（initialPage）
            │       ├── [竖排] VerticalText（tategaki，writing-mode: vertical-rl/lr）
            │       ├── [分页] PagedReadingView（纯视图：渲染页 + 离屏测量，默认模式）
            │       │       ├── PagedReaderController（章节内容/块/页列表/当前页/目标/过渡）
            │       │       │       └── open(html)/openPages(pages)：自行测量 或 直接采用后台分页结果
            │       │       └── 底部页码指示：就绪时显示全书页码（本章起始页 + 页内偏移 / 全书总页数），
            │       │               否则回退章节内页码（单独 widget，只监听页码信息，避免重绘整页）
            │       └── [滚动] HtmlWidget（flutter_widget_from_html_core）
            │
            ├── 全书后台分页（BookPaginator + BookPaginatorHost）
            │       ├── _onReaderLayout(w,h)（控制器上报可用宽高）→ configure(w,h, exclude: 当前章)
            │       │       └── 尺寸变化 → 全部失效，按「当前章 → 下一章/上一章 → 前缀章 → 其余」重排
            │       ├── 逐章 loader(index) → RenderedContent → buildHtmlBlocks → 离屏列测高 → paginateBlocks
            │       ├── 当前章由控制器测量，测完 adopt() 回填（避免重复测量、页码一致）
            │       ├── 已分页章节：_navigateToChapter 直接用 pagesFor(index) → _reader.openPages()
            │       │       （跨章无需现场测量，无白屏等待）
            │       └── 可视章节页列表变化（尺寸重排）→ _reader.replacePages()（按页起始块保持阅读位置）
            │
            ├── 缩写 Tab → _loadAbbreviation()（仅读缓存，不生成、不调用 AI）
            │       └── SummaryService.getChapterAbbreviation()
            │
            ├── 译文 Tab → _ensureTranslation()（切换到译文 Tab 时触发）
            │       └── SummaryService.ensureChapterTranslation()（读缓存或流式生成）
            │
            ├── 目录 Tab → ChapterDirectory（复用书籍详情页封面 + 章节列表）
            │       └── _jumpFromDirectory() → 跨章 _navigateToChapter(index, anchor) / 同章 _reader.retarget()
            │
            └── 翻章（上一章/下一章）→ _navigateToChapter()（原地渲染，不触发路由）
                    ├── 更新 _currentIndex/_title，保留旧内容后台加载
                    ├── _loadChapterContent(target) → getChapterContentMerged() → RenderedContent（复用 _chapters，无需重复解析）
                    ├── _loadAbbreviation()（读取新章节缓存摘要）
                    ├── 内容就绪后 _reader.open(html, target)：「打开到某位置」的意图交给控制器
                    └── 翻页入口统一：点击左右 1/3 / 键盘 ←→ / 鼠标滚轮 / 滑动越界
                        全部经 PagedReaderController.turnPage(±1)
                        ├── 章内：页列表还有相邻页 → PageView 翻页
                        ├── 章节边界：onBoundary(delta) → ChapterScreen._onReaderBoundary()
                        │       ├── 普通章节：_navigateToChapter()（向后落新章首页、向前落上一章末页）
                        │       ├── 第一章首页向前翻：_openOpeningPage(lastPage: true) 回到开头页末页
                        │       │       （开头页 = 封面/目录/版权等未列入章节的前置页，_showingOpening）
                        │       └── 开头页末页向后翻：_navigateToChapter(0) 进入第一章首页；开头页首页向前翻无操作
                        ├── _positioning：换章定位完成前忽略翻页输入
                        ├── _exitingBlocks：过渡中的旧页（滑出）；分页稳定后 260ms 统一过渡
                        │       （当前页层始终包在同一层级的 SlideTransition，避免过渡结束时
                        │        PageView 被重建回到第 0 页；旧页层不铺不透明底色，避免白页闪块）
                        ├── 点击左右 1/3：原始指针 down/up 判定（位移 ≤ kTouchSlop 才算点击）
                        │       HTML 的 <a> 自带 GestureDetector 会抢走点击，故不用 GestureDetector.onTapUp
                        ├── 滑动越界：PageView 用 ClampingScrollPhysics（越界时页面不位移，切章不会跳回）；
                        │       OverscrollNotification 累计超过 12px 才翻章（负=越过开头→上一章、正=越过末尾→下一章），
                        │       兼容 Bouncing 平台的 ScrollUpdate 越界 pixels 判定
                        └── _switchingChapter：上一章内容加载完成前忽略新的翻章请求
```

### 3.3 翻译流程

```
ChapterScreen._ensureTranslation()
    │
    └── SummaryService.ensureChapterTranslation(bookId, chapterIndex, content, ...)
            │
            ├── getTranslation() 读缓存 → 命中直接返回
            │
            ├── 未命中 → generateTranslationStream()
            │       ├── 防止重复生成 (_generatingTranslationKeys)
            │       └── AIService.translateContent(...)
            │               └── _callAIStream() → SSE 流式响应
            │                   └── onContentUpdate 回调 → _notifyTranslationContent()
            │
            ├── saveTranslation() → FileStorageService().writeText()
            │
            └── 再读缓存返回
```

### 3.4 设置变更流程

```
SettingsScreen / AiConfigScreen
    │
    └── SettingsService().updateXxxSettings(newValue)
            │
            ├── 更新内部状态
            ├── _saveSettings()
            │       └── FileStorageService().writeJson(settingsPath, appSettings.toJson())
            │
            └── ValueNotifier 通知所有监听器
                    ├── themeMode → ZhiduApp._onAppSettingsChanged()
                    │       └── 重建 MaterialApp (全新主题)
                    ├── languageSettings → ZhiduApp._onAppSettingsChanged()
                    │       └── setState → 更新界面语言 Locale
                    └── aiSettings → AIService._onAiSettingsChanged()
```

---

## 四、Service 层详细调用关系

### 4.1 AIService → 被调用方

| AIService 方法 | 调用方 |
|---|---|
| `AIService()` (构造) | main.dart |
| `_loadConfig()` (内部) | 构造时、SettingsService 变更时 |
| `translateContent()` | SummaryService.generateTranslationStream() |
| `testConnection()` | AiConfigScreen 测试按钮 |
| `detectLanguageFromContent()` | `detectSourceLanguage()` |
| `detectSourceLanguage()` | ChapterScreen._initializeLanguageSettings() |
| `detectSystemLanguage()` | `resolveOutputLanguage()` |
| `resolveOutputLanguage()` | AIService 译文生成方法, ChapterScreen._initializeLanguageSettings() |
| `needsTranslation()` | (已废弃，ChapterScreen 改用源语言==目标语言判断) |
| `convertLanguageCodeToStandard()` | `detectSourceLanguage()` |
| `_callAIStream()` (内部) | 所有流式方法 |
| `get config` | SummaryService, SettingsScreen |
| `get availableModels` | AiConfigScreen |
| `get isConfigured` | ChapterScreen |

### 4.2 SummaryService → 被调用方

| SummaryService 方法 | 调用方 |
|---|---|
| `SummaryService()` (构造) | ChapterScreen |
| `getChapterAbbreviation()` | ChapterScreen._loadAbbreviation() |
| `saveChapterAbbreviation()` | (无调用方，保留供后续使用) |
| `getTranslation()` | SummaryService.ensureChapterTranslation() |
| `saveTranslation()` | SummaryService.generateTranslationStream() |
| `generateTranslationStream()` | SummaryService.ensureChapterTranslation() |
| `ensureChapterTranslation()` | ChapterScreen._ensureTranslation() |
| `registerTranslationCallback()` | ChapterScreen._ensureTranslation() |
| `unregisterTranslationCallback()` | ChapterScreen.dispose(), ChapterScreen._navigateToChapter() |
| `stripHtml()` | ChapterScreen._checkContentLength() |
| `shouldAbbreviate()` | ChapterScreen._checkContentLength() |
| `removeThinkingProcess()` | 内部（缩写/译文读取时清理 AI 思考标签） |

### 4.3 SettingsService → 被调用方

| SettingsService 方法 | 调用方 |
|---|---|
| `SettingsService()` (构造) | main.dart |
| `init()` | main.dart |
| `get settings` | AIService._loadConfig(), 各设置页面 |
| `get aiSettings` (ValueNotifier) | AIService, AiConfigScreen |
| `updateAiSettings()` | AiConfigScreen |
| `setThemeMode()` | SettingsScreen |
| `updateLanguageSettings()` | SettingsScreen |
| `get themeMode` (ValueNotifier) | ZhiduApp, AppTheme |
| `get languageSettings` (ValueNotifier) | ZhiduApp, SettingsScreen |
| `get calibreLibraryPath` (ValueNotifier) | SettingsScreen |
| `setCalibreLibraryPath()` | SettingsScreen._browseCalibreLibrary() |
| `get bookshelfSortType` (ValueNotifier) | HomeScreen |
| `setBookshelfSortType()` | HomeScreen |

### 4.4 LibraryImportService → 被调用方

| LibraryImportService 方法 | 调用方 |
|---|---|
| `LibraryImportService()` (构造) | main.dart, HomeScreen, SettingsScreen |
| `init()` | main.dart |
| `startImport()` | SettingsScreen._browseCalibreLibrary(), _refreshCalibreLibrary() |
| `saveProgress()` | ZhiduApp.onWindowClose() |
| `get refreshSignal` (ValueNotifier) | HomeScreen |
| `_runImportLoop()` (内部) | init(), startImport() |
| `_saveProgress()` (内部) | startImport(), _runImportLoop(), saveProgress() |
| `_deleteProgress()` (内部) | init(), _runImportLoop() |

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
    │       ├── 阅读按钮 → _startReading() → 第一页（getOpeningContent）
    │       └── 返回 → Navigator.pop()
    │
    └── ChapterScreen (接收 bookId + chapterIndex)
                    ├── 垂直Tab: 原文 | 缩写 | 译文
                    ├── 缩写Tab → 读缓存（getChapterAbbreviation）
                    ├── 译文Tab → SummaryService.ensureChapterTranslation()
                    ├── 上一章/下一章 → _navigateToChapter()（原地渲染）
                    └── 返回 → Navigator.pop()
```

---

## 六、模型依赖关系

```
BookService         → Book, Chapter
EpubParser          → BookMetadata, Chapter, RenderedContent
EpubCssEngine       → RenderedContent, EmbeddedFont
PdfParser           → BookMetadata, Chapter, RenderedContent
AIService           → AiPrompts, AiSettings (直接使用 AppSettings 中的 AiSettings)
SummaryService      → Chapter (通过abbr-XXX-lang.md存储缩写、chapter-XXX-lang.html存储译文)
SettingsService     → AppSettings, AiSettings, ThemeSettings, LanguageSettings, BookSortType
OpfReaderService    → OpfMetadata
LibraryImportService → LibraryImportTask

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

章节缩写独立存储在 books/{bookId}/abbr-{index}-{lang}.md，译文存储在 chapter-{index}-{lang}.html
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

SummaryService.saveChapterAbbreviation()
    → FileStorageService().writeText(abbr-XXX-lang.md, markdownContent)

SummaryService.saveTranslation()
    → FileStorageService().writeText(chapter-XXX-lang.html, htmlContent)

读操作:
SettingsService.init()
    → FileStorageService().readJson(settings.json)

BookService._loadBooks()
    → FileStorageService().readJson(books.json)

BookService.getBook()
    → FileStorageService().readJson(metadata.json)

SummaryService.getChapterAbbreviation()
    → FileStorageService().readText(abbr-XXX-lang.md)
```

---

## 八、设计模式总结

| 模式 | 应用位置 | 说明 |
|------|----------|------|
| **单例模式** | 所有 Service 类 | 全局唯一实例，通过工厂构造函数 `factory` 实现 |
| **工厂模式** | `FormatRegistry.register()` | 扩展名 → 解析器映射，动态创建解析器 |
| **策略模式** | `BookFormatParser` 接口 | `EpubParser` / `PdfParser` 实现统一接口 |
| **观察者模式** | `ValueNotifier` + 流式回调 | 设置变更通知 / 流式内容实时推送 |
| **防重复** | `_generatingTranslationKeys` | 防止重复生成同一章节译文 |
| **回调注册** | `registerTranslationCallback` | UI 注册回调监听流式译文 |

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
│  - coverPath: String?             - calibreLibraryPath: String?    │
│                                                  - baseUrl        │
│                                                                    │
│  BookMetadata (定义在 book_format_parser.dart)                    │
│  - title / author / totalChapters / coverPath? / language?        │
│                                                                    │
│  RenderedContent (定义在 rendered_content.dart)                    │
│  - html: String                                                    │
│  - fonts: List<EmbeddedFont>                                       │
│  - isVertical: bool                                                │
│  - plainText: String                                               │
│                                                                    │
│  EmbeddedFont (定义在 rendered_content.dart)                       │
│  - family: String                                                  │
│  - bytes: List<int>                                                │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       SERVICES (业务服务)                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  BookService              AIService              SummaryService   │
│  ─────────────            ──────────             ───────────────  │
│  + books (getter)         + translateContent()   + getChapterAbbreviation()│
│  + importBook()           + testConnection()     + saveChapterAbbreviation()│
│  + importBookFromPath()   + detectLanguageFromContent()           │
│  + scanCalibreOpfFiles()  + detectSourceLanguage()                │
│  + importOpfFile()        + resolveOutputLanguage()               │
│  + clearAllBooks()        + needsTranslation()   + getTranslation()│
│  + getBookById()          + fetchAvailableModels()+ saveTranslation()│
│  + deleteBook()           + _callAIStream()      + generateTranslationStream()│
│  + updateBook()                                  + ensureChapterTranslation()│
│  + ensureBookFileLocal()                         + registerTranslationCallback()│
│  + searchBooks()                                 + unregisterTranslationCallback()│
│  + _saveBooksIndex()                             + stripHtml()    │
│  + _saveBookMetadata()                           + shouldAbbreviate()│
│                                                  + removeThinkingProcess()│
│  SettingsService                                                  │
│  ───────────────                                                  │
│  + init()                                                         │
│  + settings (getter)                                              │
│  + themeMode (getter)                                             │
│  + aiSettings (getter)                                            │
│  + languageSettings                                               │
│  + updateAiSettings()     LogService                              │
│  + setThemeMode()         ──────────                              │
│  + updateLanguageSettings() + v() / d() / info() / w() / e()      │
│  + getSavedAiConfigForProvider()                                  │
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
│                                                                  │
│  LibraryImportService                                             │
│  ────────────────────                                             │
│  + init()                                                        │
│  + startImport(libraryPath)                                      │
│  + saveProgress()                                                │
│  + refreshSignal (ValueNotifier<int>)                            │
│  - _runImportLoop()                                              │
│  - _saveProgress() / _deleteProgress()                           │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    PARSERS (格式解析器)                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  <<interface>>               EpubParser        PdfParser         │
│  BookFormatParser            ──────────        ─────────         │
│  ────────────────            + parseMetadata() + parseMetadata() │
│  + parseMetadata()           + extractBasicMetadata()            │
│  + extractBasicMetadata()    + getChapters()   + extractBasicMetadata()│
│  + getChapters()             + getChapterContent()               │
│  + getChapterContent()       + getChapterContentMerged()         │
│  + getChapterContentMerged() + getOpeningContent()               │
│  + getOpeningContent()                        + getChapters()    │
│                                    + getChapterContent()         │
│                                    + getChapterContentMerged()   │
│                                    + getOpeningContent()         │
│  返回 RenderedContent? 的接口:                                     │
│   getChapterContentMerged / getOpeningContent                    │
│                                                                  │
│  EpubCssEngine (CSS 内联引擎)                                      │
│  ────────────────                                                 │
│  + render(chapterHtml) → RenderedContent                         │
│  （csslib 解析 + cascadia 选择器匹配 + 字体提取 + 图片内联）          │
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
│  - BookService            - BookService         - SummaryService │
│                           - FormatRegistry      - AIService      │
│  + _importBook()          + _updateLastReadAt() + _initializeContent()│
│  + _sortedBooks()         + _loadChapters()     + _loadChapterContent()│
│  + _buildEmptyState()     + _startReading()     + _loadEmbeddedFonts()│
│  + _buildBookGrid()       + _openOpening()      + _loadAbbreviation()│
│                           + _openChapter()      + _ensureTranslation()│
│                                                 + _buildOriginalTextView()│
│                                                 + _navigateToChapter()│
│                                                                    │
│  可复用组件 (lib/widgets/)                                          │
│  ────────────────                                                 │
│  PagedReadingView + PagedReaderController（分页阅读：控制器持页列表，视图渲染+测量） │
│  BookPaginator + BookPaginatorHost（全书后台分页：逐章测量缓存、优先当前章、尺寸变化重排） │
│  html_pagination（buildHtmlBlocks / paginateBlocks / HtmlMeasureColumn 共用分页与测量） │
│  依赖: HtmlWidget(flutter_widget_from_html_core) / PageView / HtmlWidget 离屏测量列 │
│                                                                    │
│  SettingsScreen           AiConfigScreen                          │
│  ──────────────           ──────────────                          │
│  - SettingsService        - SettingsService                       │
│  + 主题/语言/书库内联设置 - AIService                             │
│                           - LogService                            │
│                           + _testConnection()                     │
│                           + _fetchModelsForCurrentProvider()      │
└──────────────────────────────────────────────────────────────────┘
```

---

## 十、更新记录

| 日期 | 更新内容 |
|------|----------|
| 2026-11-27 | 阅读字号统一相对化 — 新增 `AppSettings.readerFontSize`（默认 21，`SettingsService.readerFontSize` + `setReaderFontSize()`，暂无 UI）；阅读页字号全部由基准字号推导：正文、竖排（×0.86）、底部页码（×0.57）、开头页目录（`font-size: 0.76em`、缩进 `1em/级`，改为相对单位不再写死 px）；章节列表用 `textTheme.bodyLarge` 派生，阅读/书架/设置页固定 `fontSize` 改为主题文本样式，仅 `app_theme.dart` 保留字号定义 |
| 2026-11-27 | 修复窗口状态恢复 — ①最大化退出后重进被还原成普通窗口：Windows runner 首帧回调 `Win32Window::Show()` 原用 `SW_SHOWNORMAL`，会把 Dart 已恢复的最大化状态还原，改为 `SW_SHOW`；`initDesktopWindow` 改为「先最大化再 show」，显示后再确认一次最大化（避免普通窗口闪现）；②最小化退出后重进回到默认位置：最小化时 `getBounds()` 返回任务栏图标坐标，`_saveWindowState` 改为最大化/最小化时取 `_lastNormalBounds`、其次上次文件中的尺寸，并校验矩形可用后才写入；`flutter analyze lib` 无告警、`flutter build windows --debug` 通过 |
| 2026-11-27 | 开头页目录排版 + 详情页进入流畅性 + 窗口状态恢复 — ①`EpubCssEngine.render(html, frontMatter: true)` 只调整目录条目：`_normalizeTocEntries()` 处理「内容全为链接的块级元素」，字号统一 16px、行高 1.8，行首空格/`&nbsp;` 换算为 `margin-left` 分级缩进（2 个空白≈16px 一级）；`_applyReaderTypography` 跳过这些条目，避免统一 2em 首行缩进抹平层级；版权页等非链接文字不变；开头页 rem→px（根字号 16）以兼容 fwfh 不支持 rem；②`EpubParser.getChapters()` 改用 `Isolate.run` 后台解析（isolate 内重建解析器），避免进入书籍详情页转场期间阻塞 UI；`BookScreen` 新增章节内存缓存（`bookId|filePath`），出版信息补充后置；③`main.dart` 新增窗口状态持久化（见下一条修复）；`flutter analyze lib` 无告警、425 个测试通过 |
| 2026-11-27 | 全书页码 + 后台一次性分页 — ①新增 `lib/widgets/html_pagination.dart`：把「HTML → 块列表 → 按测量高度累积切页」抽成 `buildHtmlBlocks`/`paginateBlocks`/`pageIndexForBlock`/`HtmlMeasureColumn`，分页阅读与后台分页共用同一算法与测量列，保证两套页码一致；②`PagedReaderController` 新增 `openPages(pages, target)`（直接采用后台页列表、不做测量）、`replacePages(pages)`（尺寸重排后按页起始块原地换页、保持位置）、`reportLayout(w,h)` + `onLayout` 回调（把可用几何尺寸上报父级）、`bookPaging`（`BookPageInfo`，页码指示据此显示全书页码；前缀未知时回退章节内页码）、`pageStartBlocks`/`blockTexts` getter；打开/换页期间用 `_updating` 暂停通知，避免父级在「章节已切换但页列表尚未替换」的中间态读到旧页；③新增 `lib/widgets/book_paginator.dart`：`BookPaginator` 进入阅读页/尺寸变化后在后台逐章测量并缓存（`loader(index)` 取 `RenderedContent`，含开头页 index=-1），优先级为「当前章 → 下一章 → 上一章 → 当前章之前的章节（拼出页码前缀）→ 其余」，`adopt()` 回填控制器测量结果避免重复测量，`provideContent()` 复用已解析内容，`configure(w,h, exclude:)` 尺寸变化整体失效重排；`BookPaginatorHost` 作为离屏测量列挂在阅读页 Stack 顶层（切 Tab 不销毁）；④`ChapterScreen` 接线：`_onReaderLayout` 驱动后台重排、`_onPaginatorChanged` 刷新页码并在尺寸重排后替换可视章节页列表、`_navigateToChapter` 命中缓存时直接 `openPages`（跨章不再现场测量，减少闪动/等待）、`_adoptVisibleChapter` 回填；底部页码改为全书页码；⑤`reader_flow_test` 改写为全书页码断言（相邻页 ±1、跨章末页/首页往返），新增 `book_paginator_test`（优先当前章、前缀就绪判断、adopt 不重复测量、尺寸变化重排）；`flutter analyze lib` 无告警、422 个测试通过 |
| 2026-11-27 | 修复跨章回退跳动 + 开头页可回退 — ①`PageView` 改用 `ClampingScrollPhysics`：越界时页面不再随拖动位移，跨章瞬间旧页快照与画面位置一致，消除「从章节首页向前翻，原首页在屏幕上跳动一次」；越界改为累计 `OverscrollNotification` 超过 12px 才翻章（保留 Bouncing 平台的 `ScrollUpdate` 越界 pixels 判定）；②`ChapterScreen` 新增 `_showingOpening` 把开头页（封面/目录/版权等未列入章节的前置页）作为第一章之前的独立位置：`_onReaderBoundary` 在第一章首页向前翻时经 `_openOpeningPage(lastPage: true)` 回到开头页末页，开头页末页向后翻进入第一章（不再跳过第一章），开头页首页向前翻无操作；开头页优先复用 `BookScreen` 传入的 `openingContent`，否则按 `getOpeningContent()` 解析；③阅读位置以 `lastChapterIndex = -1` 表示开头页，`BookScreen._startReading()` 区分 `-1/0/>0/null`；④点击左右 1/3 改由原始指针 down/up 判定（位移 ≤ `kTouchSlop`）：`<a>` 链接自带的 `GestureDetector` 会抢走点击，导致目录页无法点击翻页；⑤新增用例「越界拖动时页面不位移」「第一章首页向前翻回到开头页末页」「开头页首页向前翻无变化 / 向后翻进入第一章」，`flutter analyze lib` 无告警、420 个测试通过 |
| 2026-11-27 | 修复真实运行中的翻页错乱/白页/首页无法后退 — ①`PagedReadingView` 当前页层始终包在同一层级 `SlideTransition`，过渡结束不再重建 PageView（否则回到第 0 页，向前翻章落在上一章末页会显示成首页并导致后续翻页跳错章）；②旧页过渡层去掉不透明 `ColoredBox`，避免与阅读区底色不一致造成白页闪块；③滑动越界方向修正（负=越过开头→上一章、正=越过末尾→下一章），并为 `BouncingScrollPhysics` 增加越界 pixels 判定（12px 阈值），修复首页/末页滑动只回弹；④过渡完成用 PageView 实际页码校正控制器；新增 `test/screens/reader_flow_test.dart` 用真实 EPUB + 1280×800 驱动 ChapterScreen 实测页码落点，417 个测试通过 |
| 2026-11-27 | 分页阅读状态收敛重构 — 新增 `lib/widgets/paged_reader_controller.dart`（`PagedReaderController extends ChangeNotifier`）：统一持有章节 HTML、块列表、页列表、当前页、待定位目标（`PagedOpenTarget`：首页/末页/指定页/锚点）与跨章过渡；`open(html, target)` 为唯一打开入口，`turnPage(±1)` 为唯一翻页入口（点击左右 1/3、键盘、滚轮、overscroll 全部走同一条路径），章内翻页与跨章共用同一页列表模型（章节只是分段，边界经 `onBoundary` 打开相邻章节）；状态收敛为「测量中 `isMeasuring` / 定位中 `isPositioning` / 过渡中 `exitingBlocks` 非空」三个；`PagedReadingView` 重写为纯视图（渲染页与旧页过渡层、离屏测量列、输入转发），`ChapterScreen` 删除 `_pagedController/_pagedCurrentPage/_pagedTotalPages/_startAtLastPage/_initialAnchor/_positionToken/_initialPagedPage` 与 `_onPagedPageChanged` 双向同步，改为 `_reader.open(...)` 表达意图 + 监听控制器按页保存位置；续读、目录锚点、PDF/竖排分支行为不变；分页视图测试改写并新增「章首页向前翻落上一章末页」「点击/方向键/滚轮统一入口」「同章 retarget」用例，`flutter analyze lib` 无告警、412 个测试全部通过 |
| 2026-11-27 | 修复跨章滑动过渡引入的翻页跳转错乱 — ①`PagedReadingView.didUpdateWidget(htmlChanged)` 复位 `_slideController.value = 0`：过渡结束后 controller 停在 1.0，下次切章的旧页快照会按 1.0 渲染（整体平移到屏幕外），新章测量期间白屏、过渡开始时才突然弹回；②快照清理改由 `_slideController.addStatusListener(completed)` 驱动，不再依赖 `TickerFuture.whenComplete`（动画被 `stop()` 中断时 TickerFuture 永不完成，`_frozenBlocks` 会残留并永久盖住新章）；③新增 `_positioning`（=`_pageViewHidden`）输入锁，`_prevPage`/`_nextPage`/`_onScrollNotification` 在定位完成前忽略输入：此时 PageView 以 Opacity(0) 隐藏、页码仍是上一章遗留值，点击会作用于看不见的新页而误跳章；④`ChapterScreen` 新增 `_switchingChapter`，`_navigateToChapter()` 在上一章内容加载完成前忽略新的翻章请求（此前加载期间连点右侧会依据旧章页码再跳一章、跳过整章），由 `_loadChapterContent().whenComplete` 复位；⑤新增回归用例「连续切章时旧页快照仍显示在屏幕内（过渡进度已复位）」「切章定位完成前点击右侧不触发跨章（防跳过整章）」 |
| 2026-11-26 | 代码审核清理 + 删除 `PdfReaderScreen` — 删除未被应用流程调用的 `lib/screens/pdf_reader_screen.dart` 及其测试（PDF 阅读实际由 `ChapterScreen` 内置 `PdfDocumentViewBuilder` 处理），同步更新类图、章节原文 Tab 说明与依赖关系；清理恒真分页开关、重复 HTML 渲染、未使用参数与冗长/过时注释，`flutter analyze lib` 无告警 |
| 2026-11-26 | 跨章翻页改为滑动过渡 — `PagedReadingView.didUpdateWidget(htmlChanged)` 先把当前页冻结为 `_frozenBlocks`（新章测量期间继续显示旧页），新章分页稳定后 `_finalizePosition` 播放 260ms 过渡：旧页向反方向滑出、新章滑入（`_slideDirection` 决定方向）；新增 `_slideController`（SingleTickerProviderStateMixin）与 `_buildPageContent()` 共用单页版式 |
| 2026-11-26 | 移除底部大翻页按钮、新增滚轮翻页 — `ChapterScreen` 删除 `<<`/`>>`（及 `_prevPageOrChapter`/`_nextPageOrChapter`/`_isPagedOriginalView`/`_hoverPrev`/`_hoverNext`），`_buildNavigationButtons()` 仅 PDF 原文保留 `<`/`>`；`PagedReadingView` 用 `Listener.onPointerSignal` 处理 `PointerScrollEvent`（下滚下一页、上滚上一页，边界跨章，180ms 节流） |
| 2026-11-26 | 修复续读定位失效 — `PagedReadingView._finalizePosition()` 原在分页稳定后读 `widget.initialPageIndex`，此时父级已把一次性页码清空并改传 `_pagedCurrentPage`(0)，导致跳首页。改为 `_pendingPageIndex` 在 `initState`/`didUpdateWidget(htmlChanged)` 固化目标页、定位后清空；`test/screens/chapter_screen_test.dart` 新增续读定位回归用例 |
| 2026-11-26 | 清理 metadata.json 冗余字段 — 删除 `Book.currentChapter`（仅写不读，位置语义已由 `lastChapterIndex` 覆盖），同步移除 `copyWith`/`toJson`/`fromJson`/`saveReadingPosition` 及相关测试引用；旧文件残留键由 `fromJson` 忽略，下次写入自动消失 |
| 2026-11-26 | 修复页码保存为 0（续读失败根因）— 依据 `metadata.json`（`lastChapterIndex:1`、`lastPageIndex:0`）定位：`TabBarView` 的 `PageView` 销毁远离当前页的子页，切到缩写/译文/目录再回原文时 `PagedReadingView` 重建、`_currentPage` 归零并通过 `onPageChanged` 把 `ChapterScreen._pagedCurrentPage` 覆盖为 0，退出即保存 0。修复：`PagedReadingView` 加 `AutomaticKeepAliveClientMixin`（`wantKeepAlive=true`，`build` 调 `super.build`）；`initialPageIndex: _initialPagedPage ?? _pagedCurrentPage` 支持同内容重建回位；`_navigateToChapter()` 重置 `_pagedCurrentPage/_pagedTotalPages`；开头页分支首帧后清空 `_initialPagedPage` |
| 2026-11-26 | 阅读位置持久化加固 — 新增 `BookService.saveReadingPosition(bookId, chapterIndex, pageIndex, progress:)`：按 id 从内存书籍列表取权威记录（不再依赖调用方可能过期的 Book 快照），并同时写入 `readingProgress`（已读章节 + 章内页占比）；`ChapterScreen._saveReadingPosition()` 改用该接口并输出日志。字段含义：`currentChapter` 历史字段（现与 `lastChapterIndex` 同步写入）、`readingProgress` 全书进度（书架进度条）、`lastChapterIndex` 上次阅读顶层章节、`lastPageIndex` 上次阅读页码（0 起）。位置写入 `books/{bookId}/metadata.json`，`books_index.json` 仅存 id/书名/作者/格式/路径/addedAt |
| 2026-11-26 | 修复续读位置不准 — `BookScreen._startReading()` 先用 `BookService().getBookById()` 刷新 `_book`（本页缓存可能是进入阅读前的快照，导致再次点「阅读」读不到新进度而退回全书首页）；首章进度改由 `_openOpening(initialPagedPage:)` 恢复，保证与首次阅读的文档一致；`ChapterScreen` 翻页后 2s 防抖 `_scheduleSaveReadingPosition()` + `_savedChapterIndex/_savedPageIndex` 去重写入 |
| 2026-11-26 | 书架续读 — `Book` 新增 `lastChapterIndex`/`lastPageIndex` 并持久化；`ChapterScreen._saveReadingPosition()` 在翻章与 `dispose` 时保存位置；新增 `initialPagedPage` → `PagedReadingView.initialPageIndex` 恢复页码。入口：书架点击进入书籍详情，详情页「阅读」`_startReading()` 在有 `lastChapterIndex` 时调 `_resumeReading()` 续读，否则从全书首页开始；章节点击逻辑不变 |
| 2026-11-26 | 阅读页新增「目录」Tab — `ChapterScreen` 垂直 Tab 扩为 4 个（原文/缩写/译文/目录），第 4 个显示全书章节树；新增 `lib/widgets/chapter_directory.dart`（`BookCover` + `buildChapterTiles` + `ChapterDirectory`），书籍详情页与阅读页目录 Tab 复用同一套封面/列表代码；`_jumpFromDirectory()` 点击原地跳章（子章节带 `initialAnchor` 定位标题所在页），同章内点击通过 `PagedReadingView.positionToken` 递增触发重定位，并 `animateTo(0)` 切回原文 |
| 2026-11-26 | 章节列表全层级可点击 — `BookScreen._buildChapterList()` 取消「仅 level==0 可点」，0/1/2 级目录均可跳转；`_openChapter()` 用 `_topLevelChapterOf()` 解析子章节所属顶层章节，并传 `initialAnchor`（子章节标题）→ `ChapterScreen` → `PagedReadingView`，分页稳定后 `_pageForAnchor()` 按块纯文本（忽略空白）定位到标题所在页；`ChapterScreen` 首次加载后清空锚点避免翻章重复定位 |
| 2026-11-26 | 修复合并章节丢失正文 — `ChapterScreen` 新增 `_allChapters` 保存完整章节列表（含子章节），`_loadChapterContent()` 改用它调用 `getChapterContentMerged()`。此前 `_chapters` 被过滤为仅 `level==0` 并作为合并入参，导致 `_collectChapterGroup` 立即遇到下一个顶层章节而只返回顶层章节自身，子章节所在文件的正文整段丢失（如《三国配角演义》「街 亭」仅剩 3KB 标题页，合并后应为 346KB，含「街亭败战」「马谡入狱」等） |
| 2026-11-21 | 分页阅读翻页导航完善 — ① 修复跨章闪动：翻回上一章（`startAtLastPage`）不再「先首页/中间页再末页」，`PagedReadingView` 分页稳定后由 `_finalizePosition()` 定位目标页（翻上一章为末页、翻下一章/初始为首页），期间用 `_pageViewHidden`（Opacity 隐藏）避免闪动；② 翻页入口统一：`PagedReadingView` 新增 `onPrevChapter`/`onNextChapter` 回调，点击左右 1/3 与键盘 ←/→ 到达章节边界即跨章（与底部大按钮一致）；③ 滑动跨章：`PageView` 改用 `BouncingScrollPhysics` + `NotificationListener` 监听 overscroll，滑到末页/首页继续滑动即跨章，`_crossChapterTriggered` 防重复触发 |
| 2026-11-20 | EPUB 显示能力改进 — ① 渲染器替换：`flutter_html` → `flutter_widget_from_html_core`（`HtmlWidget`），CSS 内联重写为 `EpubCssEngine`（csslib 解析 + cascadia 选择器匹配 + !important/特异性/源顺序级联）；② 字体嵌入：`@font-face` 提取 + SHA-1 反混淆 + `FontLoader` 运行时注册；③ 图片完善：`background-image` 转 data URI、SVG 封面转 `<img>`、保留尺寸；④ 竖排：检测 `writing-mode: vertical-rl/lr`，用 `tategaki` 的 `VerticalText` 渲染；⑤ 分页阅读：新增 `PagedReadingView`（TextPainter 切页 + PageView），设为 EPUB 横排原文默认模式（滚动为可选，切换入口后续放设置项）。`BookFormatParser.getChapterContentMerged`/`getOpeningContent` 返回值改为 `RenderedContent`（html + fonts + isVertical + plainText），新增 `RenderedContent`/`EmbeddedFont` 模型 |
| 2026-11-19 | 阅读/章节页重构 — ① 删除 AI 缩写预处理与生成：SummaryService 删除 `generateSingleSummary`/`generateSummariesForBook`/`_generateBookSummaryFromChapters`/`Semaphore`/`registerBookStreamingCallback`/`init`/`dispose`，保留译文生成与缩写/译文读写缓存；BookScreen 删除后台预生成 `_startPreGeneration` 与全书摘要 Tab；ChapterScreen 删除「生成缩写」按钮与 `_ensureAbbreviation`，缩写改为 `_loadAbbreviation` 仅读缓存。② 阅读按钮跳转第一页：`BookFormatParser` 新增 `getOpeningContent`，`EpubParser` 实现（spine 首文件 + CSS/图片内联 + SVG 封面转 `<img>`），`PdfParser` 返回 null。③ 章节 Tab 重排为 原文/缩写/译文 且默认进入原文。④ 翻章改为原地渲染 `_navigateToChapter`（不再 `Navigator.pushReplacement`），保留旧内容后台加载无闪动、滚动重置到顶部。⑤ 翻页按钮样式（放大、透明度、悬停变色、单箭头图标） |
| 2026-11-18 | 打开书籍自动本地化文件 — `BookService.ensureBookFileLocal()` 判断书籍 `filePath` 是否位于应用存储目录，非本地（如 Calibre 书库）则复制到 `books/{bookId}/book{ext}` 并更新 `filePath` 持久化；`BookScreen._loadChapters()` 解析前先调用，后续解析使用本地副本 |
| 2026-11-17 | 书架排序返回刷新 — `BookCard` 新增 `onOpened` 回调，从书籍详情返回时若排序为「最近阅读时间」则刷新书架重排（`_openBook` 返回后经回调通知 `_HomeScreenState`，仅 `_sortType == BookSortType.lastRead` 时 `setState`） |
| 2026-11-17 | 书架排序功能 — 新增 `BookSortType` 枚举（最近阅读/加入时间/书名/作者 × 升序/降序共 7 种）；`AppSettings` 新增 `bookshelfSortType` 字段持久化；`SettingsService` 新增 `bookshelfSortType` ValueNotifier + `setBookshelfSortType()`；HomeScreen 新增排序按钮（AppBar 设置按钮左侧），`_sortedBooks()` 按排序方式排序、初始值从 SettingsService 读取 |
| 2026-11-17 | 阅读进度追踪：`totalChapters` 首次解析章节后保存到 `Book` 并优先读取缓存（章节数展示无需等待解析）；`lastReadAt` 打开书籍时更新并持久化；HomeScreen 书架按 `lastReadAt` 降序排序（最近阅读在前、未读在后）。新增 `BookScreen._updateLastReadAt()`、`HomeScreen._sortedBooks()` |
| 2026-11-17 | AI/界面语言设置合并为统一「语言」设置 — `LanguageSettings` 精简为 `languageMode`+`language`（删「跟随书籍」，仅「跟随系统/用户自选」）；`resolveOutputLanguage`/`needsTranslation` 简化、删除 `_detectLanguageFromMetadataAndContentWithBookId`；设置页语言 UI 合并为一组；清理 18 个 l10n 僵尸 key |
| 2026-11-17 | 首页书架 UI 优化 — 移除底部状态栏（书籍总数移至 AppBar 标题括号内，搜索时显示命中/总数）；搜索框提示改"搜索书名/作者"、删除 l10n `bookCount`；卡片比例改 3:4.5；封面改 `fitWidth + topCenter`（竖/横封面均不裁左右）；书名/作者叠加封面底部半透明条；封面右上角格式徽章；书架支持键盘滚动（↑/↓/PgUp/PgDn） |
| 2026-11-17 | 删除 `docs/pseudocode/` 伪代码文档目录 — 不再维护伪代码文档，提交前规则仅保留 function_call_relationships 与 AGENTS.md 版本历史同步 |
| 2026-11-16 | Calibre 书库导入 + 首页书架优化 — 新增 `LibraryImportService`（后台导入、断点续传、refreshSignal）；导入改为 `extractBasicMetadata`（只读书名/作者/封面，不解析章节/摘要）；OPF 封面改从 `<guide>` 读；`scanCalibreOpfFiles` 跳过隐藏目录；退出 `onWindowClose` 用 `exit(0)`；首页书架网格自适应列数 + 底部状态栏 + 卡片 UI 优化 |
| 2026-11-13 | 冗余代码清理 + 注释规整 + 文档同步 — 代码侧：删除未使用 import/字段、清理冗余空安全操作符、删除死 l10n key `promptPrefaceSummary`、修复 stale 测试；文档侧：类图 UML 修复（删除 `chapterTitles`、`EpubService`/`PdfService` → `EpubParser`/`PdfParser`、删除 `fileExists()`/`getBooksDirectory()`/`getCoverPath()`、PdfReaderScreen `PdfService` → `PdfParser`、`translateHtmlStream()` → `translateContent()`、`_saveBooks()` → `_saveBooksIndex()`、`getBook()` → `getBookById()`）；`index.md` 修正章节摘要文件名 `Summary-{index}-{lang}.md` |
| 2026-05-21 | EpubService/PdfService 僵尸代码清理 + 测试同步 — EpubService 删除 8 个公共方法（extractPrefaceContent/getHierarchicalChapterList/getSectionContent/getChapterContentFromHref/getChapterHtml/getSectionHtml/getSectionsInChapter/getChapterList）及 10+ 私有依赖方法、2 个内部类（ChapterInfo/SectionInfo），1265→422 行；PdfService 删除 3 个公共方法（getChapterPages/getChapterPageRange/getPageContent）及 2 个内部类（PdfChapter/PdfPageContent 改为私有 _PdfChapter），472→189 行；同步删除 epub_service_test.pdf_service_test 中对应用例、删除 epub_parser_test/pdf_parser_test 中 extractCover 用例；更新 epub_service.md/pdf_service.md/function_call_relationships.md/index.md |
| 2026-05-21 | BookService: 删除僵尸方法 `saveBooksIndex()`（无外部调用），精简注释（434→289行，-33%） |
| 2026-05-21 | AI 语言检测：`detectLanguageFromContent` 改为 AI 识别；`detectSourceLanguage` 新增 bookId + 回写；合并 `getTargetLanguage` → `resolveOutputLanguage` |
| 2026-05-19 | fix: 删除失败 SnackBar 硬编码中文改 i18n key `loc.failed` |
| 2026-05-19 | fix: BookCard 删除检查 deleteBook() 返回值，防止 IO 失败时目录残留 |
| 2026-05-19 | HomeScreen + BookshelfScreen 合并为单层 Scaffold；删除 GlobalKey/嵌套 Scaffold/重复 BookService 实例 |
| 2026-05-19 | HomeScreen: 删除 SummaryService/LogService 依赖；BookService.deleteBook() 已自动清理书籍目录，无需单独调用 SummaryService |
| 2026-05-18 | AiConfigScreen: 新增 LogService 依赖、_fetchModelsForCurrentProvider 方法；依赖矩阵更新 LogSvc ✓ |
| 2026-05-11 | 初始版本：完整类/函数调用关系图，含新服务(TranslationService, OpfReaderService)、新模型(OpfMetadata)、OPF元数据集成流程 |