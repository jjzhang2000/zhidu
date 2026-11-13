# 智读 (Zhidu) 可视化类/函数调用关系图 (Mermaid)

> **文档版本**: v2.4 | **更新日期**: 2026-11-13

---

## 一、全局架构总图

```mermaid
graph TB
    subgraph 入口层["main.dart"]
        MAIN["main() 函数"] --> IW["initDesktopWindow()"]
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
        PDS["PdfReaderScreen"]
        ST["SettingsScreen"]
        AIC["AiConfigScreen"]
        THS["ThemeSettingsScreen"]
        LAS["LanguageSettingsScreen"]
    end

    INIT --> LS
    INIT --> SS
    INIT --> FS
    INIT --> SC
    INIT --> BS
    INIT --> AS
    INIT --> SuS
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

    PDS --> BS
    PDS --> PP

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
    FP --> |".epub"| EPUB["EpubParser.parseMetadata()"]
    FP --> |".pdf"| PDF["PdfParser.parseMetadata()"]

    subgraph EPUB解析流程
        EPUB --> E1["EpubReader.readBook()"]
        E1 --> E2["_extractChapters()"]
        EPUB --> E3["_extractCover()"]
        E1 --> E4["OpfReaderService.readFromSameDirectory()"]
        E4 --> E5["_parseOpfContent() XML解析"]
        E5 --> E6["OpfMetadata"]
    end

    subgraph PDF解析流程
        PDF --> P1["PdfDocument.openFile()"]
        P1 --> P2["_detectChapters() 正则匹配"]
        PDF --> P3["_extractCover() 渲染PNG"]
        P1 --> P4["OpfReaderService.readFromSameDirectory()"]
        P4 --> P5["_parseOpfContent() XML解析"]
        P5 --> P6["OpfMetadata"]
    end

    E2 --> MERGE["合并OPF元数据"]
    P2 --> MERGE
    E6 --> MERGE
    P6 --> MERGE

    MERGE --> BOOK["Book 对象"]
    BOOK --> SAVE["FileStorageService 持久化"]
    SAVE --> SAVE1["writeJson(metadata.json)"]
    SAVE --> SAVE2["writeJson(books.json)"]

    SAVE --> GEN["SummaryService.generateSummariesForBook()"]
    GEN --> CSS["generateSingleSummary() × N 并发max=3"]
    GEN --> BSC["_generateBookSummaryFromChapters()"]

    CSS --> AI2["AIService.generateFullChapterSummaryStream()"]
    BSC --> AI3["AIService.generateBookSummaryStream()"]

    AI2 --> SSE["_callAIStream() SSE流式"]
    AI3 --> SSE

    SSE --> |"onChunk"| NOTIFY["_notifyBookStreamingContent()"]
    NOTIFY --> UI_UPDATE["UI setState() 实时更新"]
```

---

## 三、阅读流程

```mermaid
flowchart TD
    HOME["HomeScreen 书架"] --> |"BookCard.onTap"| BOOK_SCREEN["Navigator.push(BookScreen)"]

    subgraph "BookScreen 书籍详情页"
        BS_INIT["initState()"] --> PRE["_startPreGeneration() → SummaryService"]
        BS_INIT --> REG["registerBookStreamingCallback()"]
        BS_INIT --> TIMER["Timer.periodic _refreshBookIfNeeded()"]
        TAB0["Tab 0: 全书摘要 (流式/最终)"]
        TAB1["Tab 1: 章节目录列表"]
        TAB1 --> |"点击章节"| CHAPTER_SCREEN["Navigator.push(ChapterScreen)"]
    end

    subgraph "ChapterScreen 章节阅读页"
        CS_INIT --> LOAD["_loadSummary()"]
        LOAD --> LOCAL["getSummary() → readText(summaryPath)"]
        LOCAL --> |"摘要不存在"| GEN["SummaryService.generateSingleSummary()"]
        GEN --> AI["AIService.generateFullChapterSummaryStream()"]
        AI --> STREAM["SSE流式 → onChunk → onContentUpdate回调 → UI实时显示"]

        TAB_SUMMARY["Tab 0: 摘要 (Markdown渲染)"]
        TAB_ORIG["Tab 1: 原文 (HTML/纯文本)"]
        TAB_TRANS["Tab 2: 译文"]

        TAB_TRANS --> |"点击翻译"| TRANS["SummaryService.generateTranslationStream()"]
        TRANS --> TRANS_AI["AIService.translateContent()"]
        TRANS_AI --> |"SSE流式"| TRANS_UI["UI实时显示译文"]
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
    end

    BS -->|"注册表取解析器"| FR
    BS -->|"持久化"| FS
    BS -->|"读取OPF"| ORS
    BS -->|"触发生成"| SuS

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
        FS["generateFullChapterSummaryStream()<br/>章节摘要流式生成"]
        BS["generateBookSummaryStream()<br/>全书摘要流式生成"]
        TC["translateContent()<br/>HTML格式保留流式翻译"]
    end

    CONFIG --> FS
    CONFIG --> BS
    CONFIG --> TC
    CONFIG --> DETECT
    CONFIG --> RESOLVE
    CONFIG --> TEST

    FS --> STREAM
    BS --> STREAM
    TC --> STREAM

    STREAM --> |"SSE onChunk"| CB["回调函数<br/>onChunk(String partialText)"]
```

---

## 七、并发控制机制

```mermaid
flowchart TD
    REQ["SummaryService.generateSingleSummary()<br/>收到章节摘要生成请求"]

    REQ --> CHECK_GEN{"_generatingKeys<br/>是否已在生成中?"}

    CHECK_GEN --> |"是"| SKIP["RETURN false<br/>跳过重复请求"]
    CHECK_GEN --> |"否"| SEM["semaphore.acquire()<br/>等待并发槽位 (max=3)"]

    SEM --> MARK["标记 _generatingKeys.add(key)"]
    MARK --> AI["AIService.generateFullChapterSummaryStream()"]

    AI --> |"chunk流式"| CALLBACK["onContentUpdate(accumulatedContent)"]
    CALLBACK --> UI["UI setState() 实时显示"]

    AI --> DONE["生成完成 → 保存到文件"]

    DONE --> RELEASE["semaphore.release()"]
    RELEASE --> CLEANUP["清理 _generatingKeys"]

    SKIP --> RESULT["返回 false"]
    DONE --> RESULT
```

---

## 八、设置响应式更新流程（ValueNotifier）

```mermaid
flowchart LR
    subgraph 用户操作
        U1["AiConfigScreen<br/>修改AI配置"]
        U2["ThemeSettingsScreen<br/>修改主题"]
        U3["LanguageSettingsScreen<br/>修改语言"]
    end

    subgraph SettingsService
        SAVE["_saveSettings()"]
        AI_NF["aiSettings (ValueNotifier)"]
        T_NF["themeMode (ValueNotifier)"]
        L_NF["languageSettings (ValueNotifier)"]
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
    APP["MaterialApp(ZhiduApp)"] --> HS["HomeScreen<br/>书架 + 导入按钮"]

    HS --> BS_NAV["Navigator.push(BookScreen)"]
    HS --> SET["设置 → SettingsScreen"]

    SET --> AIC["AiConfigScreen"]
    SET --> THS["ThemeSettingsScreen"]
    SET --> LAS["LanguageSettingsScreen"]

    BS_NAV --> CS_NAV["Navigator.push(ChapterScreen)"]
    BS_NAV --> |"点击全书摘要"| CS_FIRST["Navigator.push(ChapterScreen<br/>chapterIndex=0)"]

    CS_NAV --> |"Tab: 译文"| TRANS["SummaryService.generateTranslationStream()"]

    CS_NAV --> |"返回"| POP["Navigator.pop()"]
    BS_NAV --> |"返回"| POP
    AIC --> |"返回"| POP
    THS --> |"返回"| POP
    LAS --> |"返回"| POP
```

---

## 十、格式解析器架构（策略+注册表）

```mermaid
classDiagram
    class BookFormatParser {
        <<interface>>
        +parseMetadata(filePath, bookId) BookMetadata?
        +getChapters(filePath) List~Chapter~
        +getChapterContent(filePath, chapter) Chapter
    }

    class EpubParser {
        +parseMetadata()
        +getChapters()
        +getChapterContent()
    }

    class PdfParser {
        +parseMetadata()
        +getChapters()
        +getChapterContent()
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
| 2026-11-13 | 冗余代码清理同步 — 删除 `EpubService`/`PdfService`/`TranslationService`（已合并/删除），统一为 `EpubParser`/`PdfParser`/`SummaryService`；`_initWindowManager()` → `initDesktopWindow()`；`_onThemeChanged()`/`_onLocaleChanged()` → `_onAppSettingsChanged()`；删除 `_generateBookSummaryFromPreface()` 分支（统一章节摘要→全书摘要）；`translateHtmlStream()` → `translateContent()`；`TranslationService.translateEpubContent()` → `SummaryService.generateTranslationStream()`；解析器接口新增 `parseMetadata()`、删除 `extractCover()`；OpfMetadata 精简为 4 字段、新增 BookMetadata 实体；章节摘要文件名 `chapter-XXX-zh.md` → `Summary-XXX-zh.md` |
| 2026-05-11 | 完整 Mermaid 可视化：全局架构图、导入/阅读/翻译流程图、Service交互图、并发控制图、ValueNotifier数据流图、导航图、解析器架构图、数据模型ER图 |
