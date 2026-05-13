# 智读 (Zhidu) 可视化类/函数调用关系图 (Mermaid)

> **文档版本**: v2.0 | **更新日期**: 2026-05-11

---

## 一、全局架构总图

```mermaid
graph TB
    subgraph 入口层["main.dart"]
        MAIN["main() 函数"] --> WM["_initWindowManager()"]
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
        ES["EpubService"]
        PS["PdfService"]
        TS["TranslationService"]
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
        CS["ChapterSummary"]
        CC["ChapterContent"]
        CL["ChapterLocation"]
        BM["BookMetadata"]
        OM["OpfMetadata"]
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
    INIT --> ES
    INIT --> PS
    INIT --> TS
    INIT --> FR

    FR --> EP
    FR --> PP
    EP -.-> BFP
    PP -.-> BFP

    BS --> ES
    BS --> PS
    BS --> FS
    BS --> SuS

    AS --> AP
    AS --> SS
    AS --> LS

    SuS --> AS
    SuS --> FS
    SuS --> BS

    ES --> ORS
    PS --> ORS
    EP --> ORS
    PP --> ORS
    ORS --> OM

    TS --> AS
    TS --> BS
    TS --> FS

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
    CHS --> TS

    PDS --> BS
    PDS --> PS

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
    UI["HomeScreen / BookshelfScreen"] --> |"用户点击导入"| FP["file_picker 选择文件"]
    FP --> |".epub"| EPUB["EpubService.parseEpubFile()"]
    FP --> |".pdf"| PDF["PdfService.parsePdfFile()"]

    subgraph EPUB解析流程
        EPUB --> E1["EpubReader.readFromUri()"]
        E1 --> E2["_extractChapters()"]
        E1 --> E3["_extractCover()"]
        E1 --> E4["OpfReaderService.readFromSameDirectory()"]
        E4 --> E5["_parseOpfContent() XML解析"]
        E5 --> E6["OpfMetadata"]
    end

    subgraph PDF解析流程
        PDF --> P1["PdfDocument.openFile()"]
        P1 --> P2["_detectChapters() 正则匹配"]
        P1 --> P3["_extractCover() 渲染PNG"]
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
    GEN --> |EPUB| BSP["_generateBookSummaryFromPreface()"]
    GEN --> |ALL| CSS["generateSingleSummary() × N 并发max=3"]
    GEN --> |PDF| BSC["_generateBookSummaryFromChapters()"]

    BSP --> AI1["AIService.generateBookSummaryFromPrefaceStream()"]
    CSS --> AI2["AIService.generateFullChapterSummaryStream()"]
    BSC --> AI3["AIService.generateBookSummaryStream()"]

    AI1 --> SSE["_callAIStream() SSE流式"]
    AI2 --> SSE
    AI3 --> SSE

    SSE --> |"onChunk"| NOTIFY["_notifyStreamingContent() / _notifyBookStreamingContent()"]
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
        CS_INIT["initState()"] --> LOAD["_loadSummary()"]
        LOAD --> LOCAL["_loadFromLocal() → readText(summaryPath)"]
        LOCAL --> |"摘要不存在"| GEN["SummaryService.generateSingleSummary()"]
        GEN --> AI["AIService.generateFullChapterSummaryStream()"]
        AI --> STREAM["SSE流式 → onChunk → UI实时显示"]

        CS_INIT --> REG_CB["registerStreamingCallback()"]
        TAB_SUMMARY["Tab 0: 摘要 (Markdown渲染)"]
        TAB_ORIG["Tab 1: 原文 (HTML/纯文本)"]
        TAB_TRANS["Tab 2: 译文"]

        TAB_TRANS --> |"点击翻译"| TRANS["TranslationService.translateEpubContent()"]
        TRANS --> TRANS_AI["AIService.translateHtmlStream()"]
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
        SuS["SummaryService<br/>摘要管理"]
    end

    subgraph 文件解析
        ES["EpubService<br/>EPUB解析"]
        PS["PdfService<br/>PDF解析"]
    end

    subgraph 基础设施
        SS["SettingsService<br/>设置管理"]
        FS["FileStorageService<br/>文件操作"]
        LS["LogService<br/>日志"]
        SC["StorageConfig<br/>路径配置"]
    end

    subgraph 扩展功能
        TS["TranslationService<br/>翻译服务"]
        ORS["OpfReaderService<br/>OPF元数据"]
    end

    BS -->|"导入"| ES
    BS -->|"导入"| PS
    BS -->|"持久化"| FS
    BS -->|"触发生成"| SuS

    ES -->|"读取OPF"| ORS
    PS -->|"读取OPF"| ORS

    SuS -->|"调用AI"| AS
    SuS -->|"保存摘要"| FS
    SuS -->|"查询书籍"| BS

    AS -->|"读取配置"| SS
    AS -->|"日志"| LS

    TS -->|"调用AI翻译"| AS
    TS -->|"保存译文"| FS
    TS -->|"查询书籍"| BS

    SS -->|"读/写设置"| FS

    ES -.-> LS
    PS -.-> LS
    BS -.-> LS
    AS -.-> LS
    SuS -.-> LS
    TS -.-> LS
    ORS -.-> LS

    style BS fill:#4fc3f7,color:#000
    style AS fill:#4fc3f7,color:#000
    style SuS fill:#4fc3f7,color:#000
    style LS fill:#81c784,color:#000
    style FS fill:#81c784,color:#000
    style SS fill:#81c784,color:#000
    style ES fill:#ffb74d,color:#000
    style PS fill:#ffb74d,color:#000
    style TS fill:#ce93d8,color:#000
    style ORS fill:#ce93d8,color:#000
```

---

## 五、数据库/文件持久化 UML

```mermaid
erDiagram
  SettingsService ||--|| FileStorageService : "读/写 settings.json"
  BookService ||--|| FileStorageService : "读/写 books.json + metadata.json"
  SummaryService ||--|| FileStorageService : "写 chapter-XXX-zh.md"
  TranslationService ||--|| FileStorageService : "写 chapter-XXX-en.html"

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
    string aiIntroduction
    int totalChapters
    datetime addedAt
    string language
    string publisher
    string description
    array subjects
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
        DETECT["detectLanguage()<br/>语言检测"]
        TEST["testConnection()<br/>API连接测试"]
    end

    subgraph 流式公开方法
        FS["generateFullChapterSummaryStream()<br/>章节摘要流式生成"]
        BS["generateBookSummaryStream()<br/>全书摘要流式生成"]
        BFP["generateBookSummaryFromPrefaceStream()<br/>基于前言的全书摘要"]
        THS["translateHtmlStream()<br/>HTML格式保留流式翻译"]
    end

    CONFIG --> FS
    CONFIG --> BS
    CONFIG --> BFP
    CONFIG --> THS
    CONFIG --> DETECT
    CONFIG --> TEST

    FS --> STREAM
    BS --> STREAM
    BFP --> STREAM
    THS --> STREAM

    STREAM --> |"SSE onChunk"| CB["回调函数<br/>onChunk(String partialText)"]
```

---

## 七、并发控制机制

```mermaid
flowchart TD
    REQ["SummaryService.generateSingleSummary()<br/>收到章节摘要生成请求"]

    REQ --> CHECK_GEN{"_generatingKeys<br/>是否已在生成中?"}

    CHECK_GEN --> |"是"| WAIT["_generatingFutures.get()<br/>复用已有的Completer.future"]
    CHECK_GEN --> |"否"| SEM["semaphore.acquire()<br/>等待并发槽位 (max=3)"]

    SEM --> MARK["标记 _generatingKeys.add(key)"]
    MARK --> COMPLETER["创建 Completer<String?>()"]
    COMPLETER --> STORE["存储 _generatingFutures[key] = completer"]
    STORE --> AI["AIService.generateFullChapterSummaryStream()"]

    AI --> |"chunk流式"| NOTIFY["_notifyStreamingContent()"]
    NOTIFY --> UI["UI setState() 实时显示"]

    AI --> DONE["生成完成 → 保存到文件"]

    DONE --> COMPLETE["completer.complete(result)"]
    COMPLETE --> RELEASE["semaphore.release()"]
    RELEASE --> CLEANUP["清理 _generatingKeys 和 _generatingFutures"]

    WAIT --> RESULT["返回已有结果"]
    COMPLETE --> RESULT
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
        AI_NF["_aiConfigNotifier"]
        T_NF["_themeNotifier"]
        L_NF["_localeNotifier"]
    end

    subgraph 监听者
        Z_AI["ZhiduApp<br/>AIConfigScreen"]
        Z_T["ZhiduApp<br/>_onThemeChanged()"]
        Z_L["ZhiduApp<br/>_onLocaleChanged()"]
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

    AI_NF -.-> |"addListener"| Z_AI
    T_NF -.-> |"addListener"| Z_T
    L_NF -.-> |"addListener"| Z_L

    Z_T --> |"rebuild MaterialApp"| APP["New MaterialApp<br/>with updated ThemeData"]
    Z_L --> |"setState"| LOCALE["New locale + LocalizationsDelegates"]
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

    CS_NAV --> |"Tab: 译文"| TRANS["TranslationService.translateEpubContent()"]

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
        +parse(filePath) BookMetadata
        +getChapters(filePath) List~Chapter~
        +getChapterContent(filePath, index) ChapterContent
        +extractCover(filePath, bookId) String?
    }

    class EpubParser {
        +parse()
        +getChapters()
        +getChapterContent()
        +extractCover()
    }

    class PdfParser {
        +parse()
        +getChapters()
        +getChapterContent()
        +extractCover()
    }

    class FormatRegistry {
        -static _registry: Map
        +static register(extension, parser)
        +static getParser(extension) BookFormatParser
        +static get supportedFormats List~String~
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
    Book ||--o| BookMetadata : during-import
    Book ||--o| OpfMetadata : enriches
    Book ||--o| ChapterSummary : has-summaries
    Chapter ||--|| ChapterLocation : uses
    Chapter ||--o| ChapterContent : has
    Chapter ||--o| ChapterSummary : has
    OpfReaderService ||--o| OpfMetadata : parses

    Book {
        string id PK
        string title
        string author
        string filePath
        BookFormat format
        int totalChapters
        string aiIntroduction
    }

    Chapter {
        int index UK
        string title
        string id UK
        ChapterLocation location
        bool isPreface
    }

    ChapterSummary {
        int chapterIndex UK
        string summary
        string language
        int wordCount
    }

    ChapterContent {
        string htmlContent
        string plainText
    }

    ChapterLocation {
        string href
        int pageNumber
    }

    OpfMetadata {
        string title
        string author
        string language
        string coverPath
        string publisher
        string description
        array subjects
    }
```

---

## 更新记录

| 日期 | 更新内容 |
|------|----------|
| 2026-05-11 | 完整 Mermaid 可视化：全局架构图、导入/阅读/翻译流程图、Service交互图、并发控制图、ValueNotifier数据流图、导航图、解析器架构图、数据模型ER图 |