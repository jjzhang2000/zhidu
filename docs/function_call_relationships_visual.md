# 智读 (ZhiDu) - 可视化函数调用关系图

本文档使用可视化图表展示智读应用的函数调用关系，从main入口开始，通过调用关系或功能操作关系连接各个类和函数。

## 1. 应用架构总览图

```mermaid
graph TB
    subgraph "外部服务"
        AI[AI Provider API<br/>Zhipu/Qwen]
    end

    subgraph "应用层"
        subgraph "UI层"
            HS[HomeScreen<br/>主页]
            BS[BookshelfScreen<br/>书架]
            BC[BookCard<br/>书籍卡片]
            BDS[BookScreen<br/>书籍详情]
            SS[ChapterScreen<br/>摘要阅读]
            SET[SettingsScreen<br/>设置]
        end
        
        subgraph "服务层"
            BSVC[BookService<br/>书籍服务]
            AISC[AIService<br/>AI服务]
            SSVC[SummaryService<br/>摘要服务]
            SETSC[SettingsService<br/>设置服务]
            LOG[LogService<br/>日志服务]
            FSS[FileStorageService<br/>文件存储服务]
        end
        
        subgraph "解析层"
            FR[FormatRegistry<br/>格式注册表]
            EPUB[EpubParser<br/>EPUB解析器]
            PDF[PdfParser<br/>PDF解析器]
        end
        
        subgraph "模型层"
            BM[BookModel<br/>书籍模型]
            CM[ChapterModel<br/>章节模型]
            ASM[AppSettingsModel<br/>应用设置模型]
        end
    end

    subgraph "存储层"
        STG[documents/zhidu/<br/>本地存储]
    end

    %% UI层连接
    HS --> BS
    HS --> BC
    BS --> BC
    BC --> BDS
    BC --> SS
    HS --> SET
    
    %% 服务层连接
    BSVC --> FSS
    AISC --> LOG
    SSVC --> AISC
    SSVC --> BSVC
    SETSC --> LOG
    SETSC --> FSS
    
    %% 解析层连接
    FR --> EPUB
    FR --> PDF
    BSVC --> FR
    
    %% 存储连接
    BSVC --> STG
    SSVC --> STG
    SETSC --> STG
    
    %% AI服务连接
    AISC --> AI
    
    %% 模型连接
    BSVC --> BM
    BSVC --> CM
    SETSC --> ASM
```

## 2. 启动流程图

```mermaid
sequenceDiagram
    participant M as main()
    participant WB as WidgetsFlutterBinding
    participant LS as LogService
    participant FR as FormatRegistry
    participant BS as BookService
    participant AIS as AIService
    participant SS as SummaryService
    participant SETS as SettingsService
    participant ZA as ZhiduApp
    
    M->>WB: ensureInitialized()
    M->>LS: init()
    M->>FR: initializeFormatRegistry()
    M->>BS: init()
    M->>AIS: init()
    M->>SS: init()
    M->>SETS: init()
    M->>ZA: runApp()
    
    Note over BS,SETS: 所有服务初始化完成
    
    ZA->>HS: build HomeScreen
```

## 3. 书籍导入流程图

```mermaid
flowchart TD
    A[用户点击+按钮] --> B[HomeScreen._importBook]
    B --> C[BookService.importBook]
    C --> D[FilePicker.platform.pickFiles]
    D --> E{选择文件?}
    E -->|是| F[获取文件路径]
    E -->|否| G[用户取消]
    F --> H{文件类型}
    H -->|EPUB| I[EpubService.parseEpubFile]
    H -->|PDF| J[PdfService.parsePdfFile]
    H -->|其他| K[格式不支持]
    I --> L[BookMetadata创建]
    J --> L
    L --> M[_saveBooksIndex]
    L --> N[_saveBookMetadata]
    M --> O[BookshelfScreen刷新]
    N --> O
    O --> P[显示成功提示]

    style A fill:#e1f5fe
    style P fill:#e8f5e8
    style K fill:#ffebee
    style G fill:#ffebee
```

## 4. 服务层依赖关系图

```mermaid
graph LR
    subgraph "核心服务"
        LOG[LogService<br/>日志]
        SETS[SettingsService<br/>设置]
        FSS[FileStorageService<br/>文件存储]
    end
    
    subgraph "业务服务"
        BSVC[BookService<br/>书籍管理]
        AISC[AIService<br/>AI接口]
        SSVC[SummaryService<br/>摘要生成]
    end
    
    subgraph "解析器"
        EPUB[EpubParser]
        PDF[PdfParser]
    end
    
    subgraph "外部依赖"
        AI[AI API]
        FS[文件系统]
    end
    
    %% 核心服务关系
    LOG -.-> BSVC
    LOG -.-> AISC
    LOG -.-> SSVC
    LOG -.-> SETS
    
    %% 业务服务关系
    SETS --> AISC
    FSS --> BSVC
    FSS --> SSVC
    FSS --> SETS
    
    %% 解析器关系
    BSVC --> EPUB
    BSVC --> PDF
    
    %% 外部依赖
    AISC --> AI
    BSVC --> FS
    SSVC --> FS
    SETS --> FS
```

## 5. UI层交互流程图

```mermaid
journey
    title UI层交互流程
    section 书籍浏览
      用户打开应用: 5: HomeScreen
      浏览书籍列表: 3: BookshelfScreen
      选择书籍: 4: BookCard点击
    section 书籍阅读
      查看详情: 2: BookScreen
      选择章节: 1: ChapterScreen
      阅读内容: 5: ChapterScreen内容显示
    section 设置操作
      进入设置: 3: SettingsScreen
      修改配置: 4: 各类设置页面
```

## 6. AI摘要生成流程图

```mermaid
flowchart LR
    A[用户打开书籍详情] --> B[BookScreen.initState]
    B --> C[启动后台预生成]
    C --> D{AI服务配置?}
    D -->|已配置| E[SummaryService.generateSummariesForBook]
    D -->|未配置| F[跳过预生成]
    E --> G[FormatRegistry.getParser]
    G --> H[获取章节列表]
    H --> I{书籍格式}
    I -->|EPUB| J[从前言生成全书摘要]
    I -->|PDF| K[先生成章节摘要]
    J --> L[为每个章节生成摘要]
    K --> L
    L --> M[AIService.generateFullChapterSummary]
    M --> N[HTTP AI API请求]
    N --> O[获取AI响应]
    O --> P[保存摘要到文件]
    P --> Q[更新UI显示]

    style A fill:#e1f5fe
    style Q fill:#e8f5e8
    style F fill:#fff3e0
```

## 7. 设置变更传播图

```mermaid
graph TD
    A[SettingsService.updateXxx] --> B[ValueNotifier.notifyListeners]
    B --> C{变更类型}
    C -->|主题| D[ThemeModeChangeListener]
    C -->|AI设置| E[AIConfigChangeListener]
    C -->|语言| F[LanguageChangeListener]
    
    D --> G[UI重建应用新主题]
    E --> H[AIService重新加载配置]
    F --> I[AI提示词语言更新]
    
    G --> J[MaterialApp.theme更新]
    H --> K[AIService._callAI使用新配置]
    I --> L[AiPrompts.getLanguageInstruction]

    style A fill:#e1f5fe
    style J fill:#e8f5e8
    style K fill:#e8f5e8
    style L fill:#e8f5e8
```

## 8. 并发控制机制图

```mermaid
stateDiagram-v2
    [*] --> Idle: 初始化
    Idle --> Generating: 开始生成摘要
    Generating --> Checking: 检查是否已在生成
    Checking --> Wait: 已在生成，等待
    Checking --> Process: 未在生成，处理
    Process --> Store: 生成完成
    Store --> Notify: 通知监听者
    Notify --> Idle: 清理状态
    Wait --> Done: 等待完成
    Done --> Idle: 返回空闲
```

## 9. 数据流图

```mermaid
graph LR
    subgraph "输入源"
        USR[用户输入]
        FILE[文件数据]
        CONF[配置数据]
    end
    
    subgraph "处理层"
        UI[UI层]
        SVC[服务层]
        EXT[外部服务]
    end
    
    subgraph "存储层"
        MEM[内存]
        DISK[磁盘]
    end
    
    subgraph "输出"
        DISP[UI显示]
        SAVE[数据保存]
    end
    
    USR --> UI
    FILE --> SVC
    CONF --> SVC
    
    UI --> SVC
    SVC --> EXT
    SVC --> MEM
    SVC --> DISK
    
    MEM --> DISP
    DISK --> DISP
    SVC --> SAVE
```

## 10. 错误处理流程图

```mermaid
flowchart TD
    A[发生错误] --> B{错误类型}
    B -->|网络错误| C[AIService错误处理]
    B -->|文件错误| D[FileStorageService错误处理]
    B -->|解析错误| E[Parser错误处理]
    B -->|配置错误| F[SettingsService错误处理]
    
    C --> G[记录日志]
    D --> G
    E --> G
    F --> G
    
    G --> H{是否致命?}
    H -->|是| I[显示错误信息]
    H -->|否| J[使用默认值继续]
    
    I --> K[返回错误状态]
    J --> L[继续执行]
    
    style A fill:#ffebee
    style I fill:#ffcdd2
    style L fill:#e8f5e8
```

## 11. 架构分层图

```mermaid
graph BT
    subgraph "表现层"
        UI[UI Components<br/>Screens & Widgets]
    end
    
    subgraph "业务逻辑层" 
        SVC[Service Layer<br/>Business Logic]
    end
    
    subgraph "数据访问层"
        DAO[Data Access<br/>File I/O & API]
    end
    
    subgraph "数据层"
        DATA[Data Layer<br/>JSON/Markdown Files]
    end
    
    subgraph "外部服务"
        EXT[External Services<br/>AI APIs]
    end
    
    UI --> SVC
    SVC --> DAO
    DAO --> DATA
    SVC --> EXT
```

## 12. 组件交互矩阵

| 组件 | 调用 | 被调用 | 依赖 | 被依赖 |
|------|------|--------|------|--------|
| HomeScreen | BookService | - | - | LogService |
| BookService | FileStorageService | HomeScreen | FormatRegistry | LogService |
| AIService | HTTP Client | SummaryService | SettingsService | LogService |
| SummaryService | AIService | UI Components | BookService | - |
| SettingsService | FileStorageService | All Services | - | LogService |

## 13. 关键路径分析

```mermaid
gantt
    title 关键执行路径
    dateFormat  YYYY-MM-DD
    axisFormat  %H:%M:%S
    
    section UI渲染
    HomeScreen构建 :done, des1, 2026-04-17 09:00:00, 0.5s
    Bookshelf加载 :active, des2, 2026-04-17 09:00:00, 1s
    
    section 数据加载
    服务初始化 :des3, 2026-04-17 09:00:00, 2s
    书籍数据加载 :des4, 2026-04-17 09:00:01, 1s
    
    section AI处理
    摘要生成 :des5, 2026-04-17 09:00:02, 5s
    UI更新 :des6, 2026-04-17 09:00:07, 0.5s
```

这些可视化图表全面展示了智读应用的函数调用关系，从应用启动到用户交互再到数据处理的完整流程。