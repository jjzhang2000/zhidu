# 智读 (Zhidu) 可视化类/函数调用关系图 (Mermaid)

> **文档版本**: v2.20 | **更新日期**: 2026-11-26

---

## 一、全局架构总图

```mermaid
graph TB
    subgraph 入口层["main.dart"]
        MAIN["main() 函数"] --> IW["initDesktopWindow()（恢复窗口位置/尺寸/最大化）"]
        MAIN --> INIT["Service 初始化链"]
        MAIN --> ZHIDU["ZhiduApp"]
    end

    subgraph 服务层["Services (单例)"]
        LS["LogService"]
        SS["SettingsService"]
        FS["FileStorageService"]
        SC["StorageConfig"]
        BS["BookService"]
        AS["AIService"]
        AP["AiPrompts"]
        SuS["SummaryService"]
        ORS["OpfReaderService"]
        LIS["LibraryImportService"]
    end

    subgraph 解析器["Parsers"]
        FR["FormatRegistry"]
        EP["EpubParser"]
        PP["PdfParser"]
        BFP["<<interface>> BookFormatParser"]
    end

    subgraph 模型层["Models"]
        BK["Book"]
        CH["Chapter"]
        CL["ChapterLocation"]
        OM["OpfMetadata\n(定义在book.dart)"]
        BM["BookMetadata\n(定义在book_format_parser.dart)"]
        AIS["AppSettings/AiSettings"]
    end

    subgraph UI层["Screens"]
        HS["HomeScreen"]
        BKS["BookScreen"]
        CHS["ChapterScreen"]
        ST["SettingsScreen"]
        AIC["AiConfigScreen"]
    end

    INIT --> LS
    INIT --> SS
    INIT --> FS
    INIT --> SC
    INIT --> BS
    INIT --> AS
    INIT --> SuS
    INIT --> LIS
    INIT --> FR

    FR --> EP
    FR --> PP
    EP -.-> BFP
    PP -.-> BFP

    BS --> FR
    BS --> ORS
    BS --> FS
    BS --> SuS

    AS --> AP
    AS --> SS
    AS --> LS

    SuS --> AS
    SuS --> FS
    SuS --> BS

    ORS --> OM
    EP --> BM
    PP --> BM

    SS --> FS

    ZHIDU --> HS
    ZHIDU --> ST

    HS --> BS
    HS --> BKS

    BKS --> BS
    BKS --> AS
    BKS --> SuS
    BKS --> CHS

    CHS --> BS
    CHS --> AS
    CHS --> SuS

    ST --> AIC
    ST --> THS
    ST --> LAS

    AIC --> SS
    AIC --> AS

    THS --> SS
    LAS --> SS
```

---

## 二、书籍导入流程（详细）

```mermaid
flowchart TD
    UI["HomeScreen"] --> |"用户点击导入"| FP["file_picker 选择文件"]
    FP --> |".epub"| EPUB["EpubParser.extractBasicMetadata()"]
    FP --> |".pdf"| PDF["PdfParser.extractBasicMetadata()"]

    subgraph EPUB解析流程
        EPUB --> E1["只读 dc:title/dc:creator/dc:language"]
        EPUB --> E3["封面提取"]
        EPUB --> E4["OpfReaderService.readFromSameDirectory()"]
        E4 --> E5["_parseOpfContent() XML解析"]
        E5 --> E6["OpfMetadata"]
    end

    subgraph PDF解析流程
        PDF --> P1["文件名标题 + 首页封面"]
        PDF --> P4["OpfReaderService.readFromSameDirectory()"]
        P4 --> P5["_parseOpfContent() XML解析"]
        P5 --> P6["OpfMetadata"]
    end

    E1 --> MERGE["合并OPF元数据 + 基本信息"]
    P1 --> MERGE
    E6 --> MERGE
    P6 --> MERGE

    MERGE --> BOOK["Book 对象"]
    BOOK --> SAVE["FileStorageService 持久化"]
    SAVE --> SAVE1["writeJson(metadata.json)"]
    SAVE --> SAVE2["writeJson(books.json)"]

    SAVE --> NOTE["（导入阶段不生成摘要；进入章节页时按需读取缓存缩写/译文）"]
```

---

## 三、阅读流程

```mermaid
flowchart TD
    HOME["HomeScreen 书架"] --> |"BookCard.onTap"| BOOK_SCREEN["Navigator.push(BookScreen)"]

    subgraph "BookScreen 书籍详情页"
        BS_INIT["initState()"] --> LU["_updateLastReadAt() → BookService.updateBook()"]
        BS_INIT --> EL["_loadChapters() → 命中缓存直接显示 / ensureBookFileLocal() → getChapters()（后台 isolate）"]
        READ["阅读按钮 → _startReading()"]
        READ --> |"lastChapterIndex > 0"| RESUME["_resumeReading() → _openChapter(恢复 章节+页码)"]
        READ --> |"lastChapterIndex == -1"| OPEN_RESUME["_loadOpeningContent() → _openOpening(恢复开头页页码)"]
        READ --> |"lastChapterIndex == 0"| FIRST["_openChapter(首章, initialPagedPage)"]
        READ --> |"首次(无记录)"| OPEN2["getOpeningContent() → RenderedContent"]
        READ --> |"PDF"| OPEN1["_openChapter(首章, initialPage:1)"]
        OPEN2 --> |"html 非空"| OPEN3["_openOpening(rendered) → ChapterScreen(openingContent+fonts+isVertical+plainText)"]
        OPEN2 --> |"空"| OPEN1
        CHAPTER_LIST["章节列表"] --> |"点击章节"| CHAPTER_SCREEN["Navigator.push(ChapterScreen)"]
    end

    subgraph "ChapterScreen 章节阅读页"
        CS_INIT["initState()"] --> TAB["垂直Tab: 原文(0) | 缩写(1) | 译文(2) | 目录(3)"]
        TAB_ORIG["原文Tab（默认）"]
        TAB_ORIG --> |"PDF"| ORIG_PDF["PdfDocumentViewBuilder 单页"]
        TAB_ORIG --> |"竖排"| ORIG_VERT["VerticalText(tategaki)"]
        TAB_ORIG --> |"分页(默认)"| ORIG_PAGE["PagedReadingView(纯视图) + PagedReaderController(页列表/当前页/过渡)"]
        TAB_ORIG --> |"滚动"| ORIG_SCROLL["HtmlWidget(fwfh_core)"]
        ORIG_PAGE --> BOOKPAGE["BookPaginator 全书后台分页(优先当前章→相邻章→前缀章) → 底部显示全书页码"]
        ORIG_PAGE --> INDICATOR["页码指示：全书页码就绪则 本章起始页+页内偏移 / 全书总页数，否则章节内页码"]
        TAB_ABBR["缩写Tab → _loadAbbreviation() → getChapterAbbreviation() 读缓存"]
        TAB_TRANS["译文Tab → _ensureTranslation() → ensureChapterTranslation()"]
        TAB_TOC["目录Tab → ChapterDirectory(封面+章节列表) → _jumpFromDirectory() 原地跳章"]
        NAV["翻页入口统一(点击左右1/3/键盘/滚轮/overscroll) → PagedReaderController.turnPage(±1) → 章内翻页或 onBoundary 跨章"]
        NAV --> |"普通章节边界"| NAV2["_onReaderBoundary() → _navigateToChapter() → 有后台缓存则 _reader.openPages(pages)，否则 _loadChapterContent()+_reader.open(html)"]
        NAV --> |"第一章首页向前"| NAV3["_openOpeningPage(lastPage:true) → 开头页末页(_showingOpening)"]
        NAV --> |"开头页末页向后"| NAV4["_navigateToChapter(0) → 第一章首页"]

        TAB_TRANS --> TRANS["generateTranslationStream() → AIService.translateContent()"]
        TRANS --> |"SSE流式"| TRANS_UI["UI实时显示译文"]
    end

    HOME --> BOOK_SCREEN
```

---

## 四、Service 核心交互关系图

```mermaid
graph LR
    subgraph 核心服务
        BS["BookService<br/>书籍CRUD"]
        AS["AIService<br/>AI API交互"]
        SuS["SummaryService<br/>摘要/翻译管理"]
    end

    subgraph 文件解析
        FR["FormatRegistry<br/>解析器注册表"]
        EP["EpubParser<br/>EPUB解析"]
        PP["PdfParser<br/>PDF解析"]
    end

    subgraph 基础设施
        SS["SettingsService<br/>设置管理"]
        FS["FileStorageService<br/>文件操作"]
        LS["LogService<br/>日志"]
        SC["StorageConfig<br/>路径配置"]
    end

    subgraph 扩展功能
        ORS["OpfReaderService<br/>OPF元数据"]
        LIS["LibraryImportService<br/>书库后台导入"]
    end

    BS -->|"注册表取解析器"| FR
    BS -->|"持久化"| FS
    BS -->|"读取OPF"| ORS
    BS -->|"触发生成"| SuS

    LIS -->|"扫描/导入"| BS
    LIS -.-> LS

    FR -->|"创建"| EP
    FR -->|"创建"| PP

    SuS -->|"调用AI"| AS
    SuS -->|"保存摘要/译文"| FS
    SuS -->|"查询书籍"| BS

    AS -->|"读取配置"| SS
    AS -->|"日志"| LS

    SS -->|"读/写设置"| FS

    EP -.-> LS
    PP -.-> LS
    BS -.-> LS
    AS -.-> LS
    SuS -.-> LS
    ORS -.-> LS

    style BS fill:#4fc3f7,color:#000
    style AS fill:#4fc3f7,color:#000
    style SuS fill:#4fc3f7,color:#000
    style LS fill:#81c784,color:#000
    style FS fill:#81c784,color:#000
    style SS fill:#81c784,color:#000
    style FR fill:#ffb74d,color:#000
    style EP fill:#ffb74d,color:#000
    style PP fill:#ffb74d,color:#000
    style ORS fill:#ce93d8,color:#000
    style LIS fill:#ce93d8,color:#000
```

---

## 五、数据库/文件持久化 UML

```mermaid
erDiagram
  SettingsService ||--|| FileStorageService : "读/写 settings.json"
  BookService ||--|| FileStorageService : "读/写 books.json + metadata.json"
  SummaryService ||--|| FileStorageService : "写 Summary-XXX-zh.md"
  SummaryService ||--|| FileStorageService : "写 chapter-XXX-en.html"

  FileStorageService ||--|| StorageConfig : "使用路径约定"

  settings_json {
    string ai_provider
    string api_key
    string model
    string base_url
    string theme_mode
    string ui_language
    string output_language
  }

  books_json {
    array Book list
  }

  Book {
    string id PK
    string title
    string author
    string filePath
    string coverPath
    string format epub_or_pdf
    int totalChapters
    int currentChapter
    double readingProgress
    datetime addedAt
    datetime lastReadAt
    string language
  }

  chapter_nnn_zh_md {
    string summary_markdown
  }

  chapter_nnn_en_html {
    string translation_html
  }
```

---

## 六、AIService 内部调用链

```mermaid
flowchart TD
    subgraph AIService内部
        CONFIG["_loadConfig()<br/>从SettingsService读取配置"]
        STREAM["_callAIStream()<br/>HttpClient SSE流式请求"]
        DETECT["detectLanguageFromContent()<br/>语言检测"]
        RESOLVE["resolveOutputLanguage()<br/>输出语言解析"]
        TEST["testConnection()<br/>API连接测试"]
    end

    subgraph 流式公开方法
        TC["translateContent()<br/>HTML格式保留流式翻译"]
    end

    CONFIG --> TC
    CONFIG --> DETECT
    CONFIG --> RESOLVE
    CONFIG --> TEST

    TC --> STREAM

    STREAM --> |"SSE onChunk"| CB["回调函数<br/>onChunk(String partialText)"]
```

---

## 七、译文防重复机制

```mermaid
flowchart TD
    REQ["SummaryService.ensureChapterTranslation()<br/>收到章节译文请求"]

    REQ --> CHECK_CACHE{"getTranslation()<br/>缓存是否已存在?"}

    CHECK_CACHE --> |"是"| RETURN["直接返回缓存译文"]
    CHECK_CACHE --> |"否"| CHECK_GEN{"_generatingTranslationKeys<br/>是否已在生成中?"}

    CHECK_GEN --> |"是"| WAIT["等待已有生成完成"]
    CHECK_GEN --> |"否"| MARK["标记 _generatingTranslationKeys.add(key)"]
    MARK --> AI["AIService.translateContent()"]

    AI --> |"chunk流式"| CALLBACK["onContentUpdate(accumulatedContent)"]
    CALLBACK --> UI["UI setState() 实时显示"]

    AI --> DONE["生成完成 → saveTranslation() 保存到文件"]
    DONE --> CLEANUP["清理 _generatingTranslationKeys"]
```

---

## 八、设置响应式更新流程（ValueNotifier）

```mermaid
flowchart LR
    subgraph 用户操作
        U1["AiConfigScreen<br/>修改AI配置"]
        U2["SettingsScreen<br/>修改主题"]
        U3["SettingsScreen<br/>修改语言"]
    end

    subgraph SettingsService
        SAVE["_saveSettings()"]
        AI_NF["aiSettings (ValueNotifier)"]
        T_NF["themeMode (ValueNotifier)"]
        L_NF["languageSettings (ValueNotifier)"]
        BS_NF["bookshelfSortType (ValueNotifier)"]
    end

    subgraph 监听者
        Z_APP["ZhiduApp<br/>_onAppSettingsChanged()"]
    end

    subgraph 文件系统
        FILE["FileStorageService.writeJson()<br/>settings.json"]
    end

    U1 --> SAVE
    U2 --> SAVE
    U3 --> SAVE

    SAVE --> FILE

    U1 --> AI_NF
    U2 --> T_NF
    U3 --> L_NF

    AI_NF -.-> |"addListener"| Z_APP
    T_NF -.-> |"addListener"| Z_APP
    L_NF -.-> |"addListener"| Z_APP

    Z_APP --> |"rebuild MaterialApp"| APP["New MaterialApp<br/>with updated ThemeData + locale"]
```

---

## 九、UI 导航层级结构

```mermaid
flowchart TD
    APP["MaterialApp(ZhiduApp)"] --> HS["HomeScreen<br/>书架 + 导入按钮 + 排序按钮"]

    HS --> BS_NAV["Navigator.push(BookScreen)"]
    HS --> SET["设置 → SettingsScreen"]

    SET --> AIC["AiConfigScreen"]
    SET --> LIB["书库设置（内联：浏览/刷新/清空书架）"]

    BS_NAV --> |"阅读按钮 / 点击章节"| CS_NAV["Navigator.push(ChapterScreen)"]

    CS_NAV --> |"Tab: 译文"| TRANS["SummaryService.ensureChapterTranslation()"]

    CS_NAV --> |"返回"| POP["Navigator.pop()"]
    BS_NAV --> |"返回"| POP
    AIC --> |"返回"| POP
```

---

## 十、格式解析器架构（策略+注册表）

```mermaid
classDiagram
    class BookFormatParser {
        <<interface>>
        +parseMetadata(filePath, bookId) BookMetadata?
        +extractBasicMetadata(filePath, bookId) BookMetadata?
        +getChapters(filePath) List~Chapter~
        +getChapterContent(filePath, chapter) Chapter
        +getChapterContentMerged(filePath, chapter, chapters) RenderedContent?
        +getOpeningContent(filePath) RenderedContent?
    }

    class EpubParser {
        +parseMetadata()
        +extractBasicMetadata()
        +getChapters()
        +getChapterContent()
        +getChapterContentMerged()
        +getOpeningContent()
    }

    class EpubCssEngine {
        +render(chapterHtml) RenderedContent
    }

    class PdfParser {
        +parseMetadata()
        +extractBasicMetadata()
        +getChapters()
        +getChapterContent()
        +getChapterContentMerged()
        +getOpeningContent()
    }

    class RenderedContent {
        +html: String
        +fonts: List~EmbeddedFont~
        +isVertical: bool
        +plainText: String
    }

    class FormatRegistry {
        -static _parsers: Map
        +static register(extension, parser)
        +static getParser(extension) BookFormatParser?
        +static isSupported(extension) bool
        +static getSupportedFormats() List~String~
        +static clear()
    }

    BookFormatParser <|.. EpubParser : implements
    BookFormatParser <|.. PdfParser : implements
    FormatRegistry ..> BookFormatParser : stores
    FormatRegistry --> EpubParser : creates
    FormatRegistry --> PdfParser : creates
    EpubParser --> EpubCssEngine : uses
    EpubCssEngine --> RenderedContent : returns
```

---

## 十一、数据模型关系图

```mermaid
erDiagram
    Book ||--o{ Chapter : contains
    Book ||--o| OpfMetadata : enriches
    Chapter ||--|| ChapterLocation : uses
    OpfReaderService ||--o| OpfMetadata : parses

    Book {
        string id PK
        string title
        string author
        string coverPath
        string filePath
        BookFormat format
        int totalChapters
        int currentChapter
        double readingProgress
        datetime addedAt
        datetime lastReadAt
        string language
    }

    Chapter {
        string bookId
        int index UK
        string title
        int level
        string htmlContent
        string objectiveSummary
        ChapterLocation location
    }

    ChapterLocation {
        string href
        int startPage
        int endPage
    }

    OpfMetadata {
        string title
        string author
        string language
        string coverPath
    }

    BookMetadata {
        string title
        string author
        int totalChapters
        string coverPath
        string language
    }
```

---

## 更新记录

| 日期 | 更新内容 |
|------|----------|
| 2026-11-27 | 阅读字号统一相对化 — 新增 `AppSettings.readerFontSize` 基准字号（默认 21，含 SettingsService 通知与 setter，暂无 UI）；正文/竖排/页码/开头页目录全部按其推导（目录改为 `0.76em`、缩进 `1em/级`），章节列表与各页面文字改用主题文本样式，仅 `app_theme.dart` 保留字号定义 |
| 2026-11-27 | 修复窗口状态恢复 — 最大化退出重进被还原：Windows runner 首帧 `Show()` 由 `SW_SHOWNORMAL` 改 `SW_SHOW`，Dart 侧先最大化再 show 并在显示后确认；最小化退出重进回默认位置：最小化时 `getBounds()` 为任务栏图标坐标，保存时改取最近一次普通窗口矩形（或上次文件尺寸）并校验后写入 |
| 2026-11-27 | 开头页目录排版 + 详情页进入流畅性 + 窗口状态恢复 — ①`EpubCssEngine.render(frontMatter: true)` 只调整目录条目：字号 16px、行高 1.8、行首空白换算 `margin-left` 分级缩进，段落缩进跳过目录条目，版权页等非链接文字不变；②`EpubParser.getChapters()` 改用 `Isolate.run`，`BookScreen` 增加章节内存缓存、出版信息补充后置；③`main.dart` 退出时保存窗口矩形与最大化状态到 `window_state.json`，启动时校验可见性后恢复 |
| 2026-11-27 | 全书页码 + 后台一次性分页 — 新增 `html_pagination`（共用分页算法与离屏测量列）、`BookPaginator`/`BookPaginatorHost`（进入阅读页/窗口变化后后台逐章分页，优先当前章→相邻章→前缀章，`adopt` 回填控制器测量结果）；`PagedReaderController` 新增 `openPages`/`replacePages`/`onLayout`/`bookPaging`；`ChapterScreen` 命中后台缓存时直接 `openPages`（跨章无测量等待、减少闪动），底部页码改为全书页码（前缀未就绪时回退章节内页码）；`reader_flow_test` 改为全书页码断言并新增 `book_paginator_test`，422 个测试通过 |
| 2026-11-27 | 修复跨章回退跳动 + 开头页可回退 — ①`PageView` 改 `ClampingScrollPhysics`（越界不位移，切章快照接管不再「跳回」），越界累计超过 12px 才翻章；②新增 `_showingOpening`：开头页（目录/版权等前置页）作为第一章之前的位置，第一章首页向前翻回到开头页末页、开头页末页向后翻进入第一章、开头页首页向前翻无操作；阅读位置以 `lastChapterIndex = -1` 表示开头页，`_startReading()` 区分 `-1/0/>0/null`；③点击左右 1/3 改用原始指针 down/up 判定（`<a>` 的 GestureDetector 会抢走点击导致目录页无法翻页）；新增「越界拖动不位移」「第一章首页↔开头页」回归用例 |
| 2026-11-27 | 修复真实运行翻页错乱 — 当前页层固定包在同一层级 `SlideTransition`（过渡结束不重建 PageView，避免回到第 0 页导致向前跨章显示成首页、后续翻页跳错章）；旧页过渡层取消不透明底色（白页闪块）；滑动越界方向修正并为 BouncingPhysics 增加越界 pixels 判定；新增真实 EPUB + 1280×800 的 ChapterScreen 全流程回归测试 |
| 2026-11-27 | 分页阅读状态收敛重构 — 新增 `PagedReaderController`（页列表/当前页/待定位目标/过渡动画），`PagedReadingView` 变为纯视图；`turnPage(±1)` 为唯一翻页入口，章内与跨章共用页列表模型；状态收敛为「测量中/定位中/过渡中」三个；`ChapterScreen` 改为 `_reader.open(html, target)` 表达打开意图并监听控制器保存位置；续读/目录锚点/PDF 分支行为不变，412 个测试全部通过 |
| 2026-11-27 | 修复跨章滑动过渡引入的翻页跳转错乱 — ①切章时复位过渡进度（`_slideController.value = 0`），否则下一次切章的旧页快照按终点值渲染到屏幕外，测量期间白屏后突然弹回；②快照清理改由 `AnimationStatus.completed` 监听驱动，`TickerFuture.whenComplete` 在动画被 `stop()` 中断时永不完成，会导致快照永久残留；③新增 `_positioning` 输入锁：定位完成前忽略点击/键盘/滚轮/overscroll（此前会作用于 Opacity(0) 的新页而误跳章）；④`ChapterScreen._switchingChapter`：内容加载完成前忽略新的翻章请求（此前连点右侧会依据旧章页码跳过整章）；⑤新增两条回归用例 |
| 2026-11-26 | 跨章翻页改为滑动过渡 — 切章时冻结当前页为旧页快照（测量期间继续显示，避免空白），新章分页稳定后 260ms 滑动：旧页滑出、新章滑入，方向随翻章方向 |
| 2026-11-26 | 移除底部大翻页按钮（EPUB），仅 PDF 原文保留 `<`/`>`；`PagedReadingView` 新增鼠标滚轮翻页（`PointerScrollEvent`，180ms 节流，边界跨章） |
| 2026-11-26 | 修复续读定位失效 — `_finalizePosition()` 延迟读 `widget.initialPageIndex` 时该值已被父级重置为 0；改为 `_pendingPageIndex` 在 initState/didUpdateWidget 固化目标页，定位后清空；新增回归测试 |
| 2026-11-26 | 修复页码保存为 0 — `TabBarView` 销毁远离子页导致 `PagedReadingView` 重建、页码归零并覆盖父级 `_pagedCurrentPage`；加 `AutomaticKeepAliveClientMixin` 保活 + `initialPageIndex: _initialPagedPage ?? _pagedCurrentPage` + 翻章重置页码 |
| 2026-11-26 | 修复续读位置不准 — `_startReading()` 先 `getBookById()` 刷新 `_book`（否则再次点「阅读」读不到新进度，退回全书首页）；首章进度经 `_openOpening(initialPagedPage:)` 恢复；翻页后 2s 防抖保存 + 已保存位置去重 |
| 2026-11-26 | 书架续读（入口调整）— `Book` 新增 `lastChapterIndex`/`lastPageIndex`；`ChapterScreen._saveReadingPosition()` 在翻章/退出时保存位置；书架点击仍进书籍详情，详情页「阅读」`_startReading()` 有记录时 `_resumeReading()` 续读，否则开全书首页；`PagedReadingView.initialPageIndex` 恢复页码 |
| 2026-11-26 | 阅读页新增「目录」Tab — `ChapterScreen` 垂直 Tab 扩为 4 个（原文/缩写/译文/目录）；新增 `lib/widgets/chapter_directory.dart`（`BookCover` + `buildChapterTiles` + `ChapterDirectory`），书籍详情页与阅读页复用同一套封面/章节列表；点击原地跳章，子章节定位标题所在页，同章内用 `positionToken` 触发重定位 |
| 2026-11-26 | 章节列表全层级可点击 — `BookScreen` 取消仅 L0 可点，子章节经 `_topLevelChapterOf()` 定位顶层章节 + `initialAnchor` 定位标题所在页（`PagedReadingView._pageForAnchor()`） |
| 2026-11-26 | 修复合并章节丢失正文 — `ChapterScreen` 新增 `_allChapters`（完整章节列表），`_loadChapterContent()` 用它调用 `getChapterContentMerged()`；此前误传仅 `level==0` 的 `_chapters`，导致子章节所在文件的正文整段丢失 |
| 2026-11-21 | 分页阅读翻页导航完善 — 修复跨章闪动（`_pageViewHidden` + `_finalizePosition()` 分页稳定后定位目标页）；翻页入口统一（`PagedReadingView` 新增 `onPrevChapter`/`onNextChapter`，点击/键盘到边界跨章）；滑动跨章（`BouncingScrollPhysics` + overscroll 监听，`_crossChapterTriggered` 防重复） |
| 2026-11-20 | EPUB 显示能力改进 — 渲染器替换 `flutter_html` → `flutter_widget_from_html_core`（`HtmlWidget`）；CSS 内联重写为 `EpubCssEngine`（csslib + cascadia + 特异性级联）；`@font-face` 字体嵌入（SHA-1 反混淆 + `FontLoader`）；图片内联（background-image/SVG）；竖排 `VerticalText`（tategaki）；分页阅读 `PagedReadingView`（TextPainter 切页，默认模式）；`getChapterContentMerged`/`getOpeningContent` 返回值改为 `RenderedContent`，新增 `RenderedContent`/`EmbeddedFont` 模型 |
| 2026-11-19 | 阅读/章节页重构 — 删除 AI 缩写预处理与全书摘要；`BookFormatParser` 新增 `getOpeningContent()`（阅读按钮直达第一页）；`ChapterScreen` 删除「生成缩写」按钮、缩写改为 `_loadAbbreviation` 仅读缓存；章节 Tab 重排为 原文/缩写/译文；翻章改为原地渲染 `_navigateToChapter()`（保留旧内容后台加载无闪动）；翻页按钮样式调整 |
| 2026-11-18 | 打开书籍自动本地化文件 — `BookService.ensureBookFileLocal()` 判断 `filePath` 是否在应用目录，非本地复制到 `books/{bookId}/book{ext}` 并更新持久化；`BookScreen._loadChapters()` 解析前调用 |
| 2026-11-17 | 书架排序功能 — 新增 `BookSortType` 枚举（7 种排序）；`SettingsService` 新增 `bookshelfSortType` ValueNotifier + `setBookshelfSortType()`；HomeScreen 新增排序按钮，`_sortedBooks()` 按排序方式排序并持久化 |
| 2026-11-17 | 阅读进度追踪：`BookScreen.initState` 新增 `_updateLastReadAt()`（打开书籍更新最后阅读时间并持久化）；`_loadChapters` 成功后保存 `totalChapters`；HomeScreen 书架按 `lastReadAt` 降序排序（新增 `_sortedBooks()`） |
| 2026-11-17 | AI/界面语言设置合并为统一「语言」设置 — `LanguageSettings` 精简为 `languageMode`+`language`（删「跟随书籍」，仅「跟随系统/用户自选」）；`resolveOutputLanguage`/`needsTranslation` 简化、删除 `_detectLanguageFromMetadataAndContentWithBookId`；设置页语言 UI 合并为一组；清理 18 个 l10n 僵尸 key |
| 2026-11-17 | 首页书架 UI 优化 — 移除底部状态栏（书籍总数移至 AppBar 标题）；搜索范围含书名+作者；卡片比例 3:4.5；封面 `fitWidth + topCenter` 兼容竖/横封面；书名/作者叠加封面底部半透明条；封面右上角格式徽章；书架键盘滚动（↑/↓/PgUp/PgDn） |
| 2026-11-16 | Calibre 书库导入 + 首页书架优化 — 服务层新增 `LibraryImportService`（后台导入、断点续传、refreshSignal）；导入改为 `extractBasicMetadata`（只读书名/作者/封面，不解析章节）；`BookFormatParser`/`EpubParser`/`PdfParser` 新增 `extractBasicMetadata()`；导入阶段不再直接生成摘要；SettingsScreen 新增书库设置；OPF 封面改从 `<guide>` 读 |
| 2026-11-13 | 冗余代码清理同步 — 删除 `EpubService`/`PdfService`/`TranslationService`（已合并/删除），统一为 `EpubParser`/`PdfParser`/`SummaryService`；`_initWindowManager()` → `initDesktopWindow()`；`_onThemeChanged()`/`_onLocaleChanged()` → `_onAppSettingsChanged()`；删除 `_generateBookSummaryFromPreface()` 分支（统一章节摘要→全书摘要）；`translateHtmlStream()` → `translateContent()`；`TranslationService.translateEpubContent()` → `SummaryService.generateTranslationStream()`；解析器接口新增 `parseMetadata()`、删除 `extractCover()`；OpfMetadata 精简为 4 字段、新增 BookMetadata 实体；章节摘要文件名 `chapter-XXX-zh.md` → `Summary-XXX-zh.md` |
| 2026-05-11 | 完整 Mermaid 可视化：全局架构图、导入/阅读/翻译流程图、Service交互图、并发控制图、ValueNotifier数据流图、导航图、解析器架构图、数据模型ER图 |
