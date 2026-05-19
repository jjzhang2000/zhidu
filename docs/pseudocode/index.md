# 智读 (Zhidu) 伪代码文档索引

## 项目概述

**智读**是一款基于 Flutter 的 AI 分层阅读器，通过 AI 分层解析实现"先读薄，再读厚"的阅读体验。

### 技术栈

- **框架**: Flutter >= 3.0.0
- **语言**: Dart >= 3.0.0
- **平台**: Windows, Android, iOS, macOS, Linux
- **AI服务**: 智谱 AI、通义千问、Ollama (本地)

### 核心功能

- EPUB/PDF文件解析
- AI 章节摘要生成（流式）
- AI 全书摘要生成（流式）
- AI 翻译（HTML格式保留）
- 分层阅读体验
- 多语言界面支持
- Calibre OPF 元数据集成

---

## 文档目录结构

```
docs/pseudocode/
├── index.md                      # 本文档
├── main.md                       # 应用入口
├── l10n/
│   └── app_localizations.md      # 国际化
├── models/
│   ├── app_settings.md           # 应用设置模型
│   ├── book.md                   # 书籍模型（含OpfMetadata）
│   └── chapter.md                # 章节模型（含ChapterLocation）
├── screens/
│   ├── ai_config_screen.md       # AI 配置页面
│   ├── book_screen.md            # 书籍详情页面
│   ├── chapter_screen.md         # 章节摘要页面
│   ├── home_screen.md            # 首页
│   ├── language_settings_screen.md # 语言设置页面
│   ├── pdf_reader_screen.md      # PDF 阅读器页面
│   ├── settings_screen.md        # 设置主页面
│   └── theme_settings_screen.md  # 主题设置页面
├── services/
│   ├── ai_prompts.md             # AI 提示词模板
│   ├── ai_service.md             # AI服务
│   ├── book_service.md           # 书籍管理服务
│   ├── epub_service.md           # EPUB解析服务
│   ├── file_storage_service.md   # 文件存储服务
│   ├── log_service.md            # 日志服务
│   ├── opf_reader_service.md     # OPF元数据读取服务
│   ├── pdf_service.md            # PDF解析服务
│   ├── settings_service.md       # 设置管理服务
│   ├── storage_config.md         # 存储路径配置
│   ├── summary_service.md        # 摘要管理服务
│   └── parsers/
│       ├── book_format_parser.md # 解析器接口
│       ├── epub_parser.md        # EPUB解析器
│       ├── format_registry.md    # 格式注册表
│       └── pdf_parser.md         # PDF 解析器
└── utils/
    └── app_theme.md              # 应用主题配置
```

---

## 模块说明

### 入口模块 (main.dart)

应用启动和初始化，负责：

- 初始化窗口管理器（桌面版窗口尺寸和位置）
- 初始化所有 Service（单例模式）
- 注册文件格式解析器
- 启动 Flutter 应用
- 管理全局主题和语言（ValueNotifier 响应式更新）

**文档**: [main.md](main.md)

---

### 数据模型模块 (models/)

| 文件 | 模型 | 说明 |
|------|------|------|
| `app_settings.dart` | `AiSettings`, `ThemeSettings`, `LanguageSettings`, `AppSettings`, `ThemeMode` | AI/主题/语言/完整设置聚合 |
| `book.dart` | `Book`, `BookFormat`, `OpfMetadata` | 书籍实体 + OPF元数据，含阅读进度 |
| `chapter.dart` | `Chapter`, `ChapterLocation` | 统一章节模型（元数据+内容+摘要），含定位信息 |

---

### UI 模块 (screens/)

| 文件 | 页面 | 功能 |
|------|------|------|
| `ai_config_screen.dart` | AI配置页 | 提供商选择/API Key/模型/Base URL/连接测试 |
| `book_screen.dart` | 书籍详情 | 全书摘要+章节列表+流式摘要显示 |
| `chapter_screen.dart` | 章节阅读 | 摘要/原文/译文三Tab垂直布局 |
| `home_screen.dart` | 首页 | 书架界面+书籍导入 |
| `language_settings_screen.dart` | 语言设置 | AI输出语言/界面语言(跟随/手动) |
| `pdf_reader_screen.dart` | PDF阅读器 | 分页阅读+章节导航 |
| `settings_screen.dart` | 设置主页 | 入口：AI/主题/语言/存储/数据管理 |
| `theme_settings_screen.dart` | 主题设置 | 系统/浅色/深色三种模式 |

---

### 服务模块 (services/)

| 文件 | 服务 | 核心职责 |
|------|------|----------|
| `ai_service.dart` | `AIService` | AI API交互：流式摘要生成、翻译、语言检测、连接测试 |
| `ai_prompts.dart` | `AiPrompts` | 静态提示词模板：章节摘要/全书摘要/翻译 |
| `book_service.dart` | `BookService` | 书籍CRUD：导入、存储、查询、删除、搜索 |
| `epub_service.dart` | `EpubService` | EPUB文件解析：元数据/章节/封面提取 |
| `file_storage_service.dart` | `FileStorageService` | 文件系统操作：JSON/文本读写、文件删除 |
| `log_service.dart` | `LogService` | 分级别日志：verbose/debug/info/warning/error |
| `opf_reader_service.dart` | `OpfReaderService` | Calibre OPF文件读取与解析 |
| `pdf_service.dart` | `PdfService` | PDF文件解析：元数据/章节/封面提取 |
| `settings_service.dart` | `SettingsService` | 统一设置管理：AI/主题/语言，ValueNotifier响应式 |
| `storage_config.dart` | `StorageConfig` | 存储路径配置：统一路径管理 |
| `summary_service.dart` | `SummaryService` + `Semaphore` | 摘要生成/存储/并发控制/流式回调 |

---

### 解析器模块 (services/parsers/)

| 文件 | 类 | 模式 |
|------|------|------|
| `book_format_parser.dart` | `BookFormatParser` | 策略模式抽象接口 |
| `epub_parser.dart` | `EpubParser` | EPUB解析实现 |
| `pdf_parser.dart` | `PdfParser` | PDF解析实现 |
| `format_registry.dart` | `FormatRegistry` | 注册表模式，扩展名→解析器映射 |

---

### 工具模块 (utils/)

| 文件 | 类 | 功能 |
|------|------|------|
| `app_theme.dart` | `AppTheme` | Material 3亮色/暗色主题配置 |

---

### 国际化模块 (l10n/)

| 文件 | 说明 |
|------|------|
| `app_localizations.dart` | 国际化基类 |
| `app_localizations_zh.dart` | 简体中文翻译 |
| `app_localizations_en.dart` | 英文翻译 |
| `app_localizations_ja.dart` | 日文翻译 |

---

## 核心数据流

```
用户导入书籍
    ↓
BookService.importBook()
    ↓
EpubService.parseEpubFile() / PdfService.parsePdfFile()
    ↓
OpfReaderService.readFromSameDirectory() → 读取 metadata.opf（Calibre）
    ↓
合并 OPF 元数据 + 解析结果 → Book 对象
    ↓
保存索引 (books.json) + 元数据 (metadata.json) + 封面
    ↓
SummaryService.generateSummariesForBook()
    ↓
┌─────────────────────────────────────────────────────────┐
│ EPUB 格式                                                │
│ 1. 从前言/目录生成全书摘要（流式）                       │
│    └─ _generateBookSummaryFromPreface()                 │
│       └─ AIService.generateBookSummaryFromPrefaceStream()│
│       └─ 实时更新到 UI (notifyBookStreamingContent)     │
│ 2. 生成章节摘要（流式，并发控制 max=3）                 │
│    └─ generateSingleSummary()                           │
│       └─ AIService.generateFullChapterSummaryStream()   │
│       └─ 实时更新到 UI (notifyStreamingContent)         │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ PDF 格式                                                 │
│ 1. 生成章节摘要（流式，并发控制 max=3）                 │
│    └─ generateSingleSummary()                           │
│       └─ AIService.generateFullChapterSummaryStream()   │
│ 2. 从章节摘要生成全书摘要（流式）                       │
│    └─ _generateBookSummaryFromChapters()                │
│       └─ AIService.generateBookSummaryStream()          │
│       └─ 实时更新到 UI (notifyBookStreamingContent)     │
└─────────────────────────────────────────────────────────┘
    ↓
翻译功能（可选）
SummaryService.generateTranslationStream()
    ↓
AIService.translateContent()
    ↓
SSE 流式响应 → 实时回调 → UI 实时显示
    ↓
保存译文 (chapter-XXX-en.html)
```

---

## 设计模式

### 单例模式 (Singleton)

所有 Service 使用单例模式：
- `LogService` / `SettingsService` / `AIService` / `BookService`
- `SummaryService` / `EpubService` / `PdfService` / `FileStorageService`
- `FormatRegistry`

### 工厂模式 / 注册表模式 (Factory + Registry)

- `FormatRegistry`: 扩展名→解析器映射，支持动态注册

### 策略模式 (Strategy)

- `BookFormatParser` 抽象接口
- `EpubParser` / `PdfParser` 具体策略

### 响应式编程 (Reactive)

- `ValueNotifier` + `addListener` 实现设置变更的实时响应
- UI 自动重建以应用新设置

### 流式回调（观察者模式）

- 全书流式: `registerBookStreamingCallback()` / `unregisterBookStreamingCallback()` / `_notifyBookStreamingContent()`
- 章节流式通知: 通过 `onContentUpdate` 回调参数直接传递

### 并发控制

- `Semaphore` 类控制并发 AI 请求数（max=3）
- `_generatingKeys` 防止重复生成

---

## 存储架构

### 文件结构

```
Documents/zhidu/                   (可自定义)
├── settings.json                  # 应用设置
├── books.json                     # 书籍索引
└── books/
    └── {bookId}/
        ├── metadata.json          # 书籍完整元数据
        ├── summary-zh.md          # 全书摘要（中文）
        ├── chapter-000-zh.md      # 章节摘要（中文）
        ├── chapter-000-en.html    # 章节译文（英文）
        ├── chapter-001-zh.md
        └── cover.jpg/png          # 封面图片
```

### 命名规则

- 章节摘要: `chapter-{index:3d}-{lang}.md`（如 `chapter-003-zh.md`）
- 书籍摘要: `summary-{lang}.md`（如 `summary-zh.md`）
- 章节译文: `chapter-{index:3d}-{lang}.html`（如 `chapter-003-en.html`）

---

## 国际化支持

### 支持语言

- 简体中文 (zh)
- 英语 (en)
- 日语 (ja)

### 实现方式

- Flutter `flutter_localizations`
- ARB 文件格式
- 自动生成本地化代码 `flutter gen-l10n`

---

## AI 集成

### 支持的 AI 提供商

- **智谱 AI**: glm-4-flash, glm-4, glm-4-plus
- **通义千问**: qwen-turbo, qwen-plus, qwen-max
- **DeepSeek**: deepseek-chat, deepseek-reasoner
- **MiniMax**: abab6.5s-chat
- **Ollama**: 本地部署的开源模型
- **LM Studio**: 本地部署的开源模型

### 摘要生成

- **章节摘要**: 200-300 字，提取核心内容+关键要点+总结
- **全书摘要**: 400-600 字，综合各章节或基于前言

### 翻译

- HTML 标签完整保留
- 流式输出（SSE）
- 支持代码块保护（占位符机制）

### 语言检测

- 优先使用 Calibre OPF 元数据中的语言
- 回退到字符比例分析（支持中/英/日/韩/法/德/俄/西）
- 系统语言检测（Platform.localeName）

---

## 开发指南

### 添加新文件格式

1. 实现 `BookFormatParser` 接口（parse/getChapters/getChapterContent/extractCover）
2. 创建对应的 Service（如 MobiService）
3. 在 `main.dart` 中注册解析器 `FormatRegistry.register('.mobi', MobiParser())`

### 添加新语言

1. 在 `lib/l10n/` 下创建 ARB 文件
2. 翻译所有键值
3. 更新 `ZhiduApp._updateLocaleFromSettings()` 中的 switch-case
4. 运行 `flutter gen-l10n`

### 添加新 AI 提供商

1. 在 `AiSettings.requiresApiKey` 中添加本地模型 provider
2. 验证 OpenAI 兼容接口格式
3. 在 `AiConfigScreen` 中添加选项
4. 确保 `baseUrl` 和 `model` 配置正确

---

## 文档维护

### 文档命名规范

- 文件名与源文件一致（.dart → .md）
- 目录结构与 lib/ 一致
- 使用小写和下划线

---

## 版本信息

- **文档更新时间**: 2026-05-19
- **项目版本**: v1.3
- **Flutter 版本**: >= 3.0.0

### 近期更新

#### 2026-05-19: HomeScreen + BookshelfScreen 合并

- **合并**: `HomeScreen` + `BookshelfScreen` 合并为单层 `Scaffold`（AppBar + body + FAB），消除嵌套布局
- **删除**: `GlobalKey<_BookshelfScreenState>`、`refresh()` 方法、嵌套 `Scaffold`、重复 `BookService` 实例
- **简化**: 导入成功后直接 `setState((){})` 刷新书架，无需 GlobalKey 跨层调用

#### 2026-05-19: HomeScreen 僵尸代码清理与冗余日志删除

- **删除**: `_BookCardState._summaryService` 僵尸字段（从未调用）及 `SummaryService` import；BookService.deleteBook() 已自动清理整个书籍目录
- **删除**: `_HomeScreenState._log` 字段 + 3条 `_log.v()` 追踪日志 + `_BookshelfScreenState._log` 字段 + `_log.d()` 调用 + `LogService` import — 共删14行
- **更新文档**: `home_screen.md` 伪代码同步、`function_call_relationships.md` 依赖矩阵更新

#### 2026-05-18: AIService 新增 `needsTranslation()` + ChapterScreen 语言归口

- **新增**: `AIService.needsTranslation(sourceLang)` — 统一判断是否需要翻译，供所有 Screen 使用
- **删除**: `_resolveTargetLang()`（16行）— ChapterScreen 改为 `_aiService.getTargetLanguage()` + `_aiService.needsTranslation()`
- **原则**: 所有语言判断逻辑统一归口到 AIService，Screen 层不再重复

#### 2026-05-18: 全项目日志精简 — 397→212条 (-47%)

- **删除**: 所有 `_log.v` 追踪日志、chunk级流式日志（SSE数据块）、逐步骤进度/确认冗余日志
- **合并**: 相邻重复信息日志合并为一条
- **保留**: 全部 `_log.e`/`_log.w` 错误和警告
- **原则**: 每函数最多1-2条log；内外层调用不重复log同一信息
- **明细**: epub_service 107→42, summary_service 51→37, ai_service 42→27, epub_parser 50→33, book_service 38→18, chapter_screen 20→9 等

#### 2026-05-18: ChapterScreen 重构为 BookScreen 模式，摘要/翻译编排逻辑归口 SummaryService

- **SummaryService 新增**: 章节级流式回调（`registerChapterCallback`/`registerTranslationCallback`）+ 一站式方法 `ensureChapterSummary()` / `ensureChapterTranslation()`
- **ChapterScreen 简化**: 删除 `_loadSummary()`、`_generateSummaryWithStreaming()`、`_loadTranslation()`、`_generateTranslationWithStreaming()` 四个方法（~260行），改为 `_ensureSummary()` / `_ensureTranslation()`（各~25行）
- **模式对齐**: ChapterScreen 不再自行组装「检查→判断→onContentUpdate→生成→加载→UI更新」，全部委托 SummaryService

#### 2026-05-18: AIService 新增 `detectSourceLanguage()` 统一源语言检测

- **提取**: 新增 `detectSourceLanguage()` public 方法，合并 ChapterScreen 和 `_detectLanguageFromMetadataAndContentWithBookId` 两处重复的「元数据→convert / 内容→detect」模式
- **简化**: `_detectLanguageFromMetadataAndContentWithBookId` 从 15 行简化为 3 行委托调用；ChapterScreen `_initializeLanguageSettings` 省 7 行
- **更新文档**: `ai_service.md` 新增 `detectSourceLanguage()` 伪代码，更新 `_detectLanguageFromMetadataAndContentWithBookId`

#### 2026-05-18: ChapterScreen `detectSystemLanguage` 合并到 AIService + Tab 顺序调整

- **合并**: `_detectSystemLanguage()` 从 ChapterScreen 合并到 `AIService.detectSystemLanguage()`（public），删除 ChapterScreen 副本（含残留韩语分支），删除 `import 'dart:io'`
- **删除**: `_updateTargetLanguage()` — 用户进入 ChapterScreen 后不可能变更 AI 语言设置，Tab 切换时直接调 `_loadTranslation()`
- **Tab 顺序**: 调整为 0=章节摘要 / 1=原文 / 2=译文（原为 0/1=译文/2=原文）
- **更新文档**: `ai_service.md` 新增 `detectSystemLanguage()`、`getTargetLanguage()` 伪代码；`chapter_screen.md` 同步所有变更

#### 2026-05-18: ChapterScreen 僵尸代码清理与重复代码提取

- **删除僵尸代码**: `_generateSummary()`（阻塞版，已被流式版替代）、`_uiRefreshTimer`（从未赋值）、`_getCurrentSummaryLanguage()`（从未调用）— 共约87行
- **提取重复代码**: `_htmlStyle` getter（消除3处~86行重复HTML样式Map）、`_buildTypingIndicator()`+`_typingDot()`（消除2处~20行重复圆点动画）、`_resolveTargetLang()`（消除2处~12行重复语言解析switch）— 共省约118行
- **更新文档**: `chapter_screen.md` 全面重写，新增 `_resolveTargetLang`、`_buildTypingIndicator`、`_htmlStyle`、`_generateSummaryWithStreaming`、`_loadTranslation`、`_generateTranslationWithStreaming`、`_captureScrollAnchor`、`_syncScrollToTab` 等伪代码

#### 2026-05-18: BookScreen 日志修正与重复代码提取

- **修正**: `_startPreGeneration` 内日志/注释从"章节摘要"改为"摘要"（实际同时生成全书+章节摘要）
- **提取**: `_htmlStyle` getter + `_buildSummaryWithMarkdown()` 公共方法，消除 `_buildAIIntroductionContent` 与 `_buildStreamingBookSummary` 之间约120行重复代码
- **更新文档**: `book_screen.md` 新增 `_loadBookSummary`、`_htmlStyle`、`_buildSummaryWithMarkdown` 伪代码，修正 `_refreshBookIfNeeded` 逻辑描述

#### 2026-05-18: AiConfigScreen 注释规范化与死代码清理

- **删除**: `_recommendedModels` getter（冗余包装）、`_getLocalizedProviders` 方法（内联到 `_getCurrentProviders`）
- **修复**: `_buildModelSection` 注释与实际代码不一致（已禁止手动输入模型名）
- **规范化**: 所有方法/字段 doc 注释补全（字段→单行、逻辑方法→编号流程、构建方法→内容列表）
- **更新文档**: `ai_config_screen.md` 新增 `_getCurrentProviders`、`_fetchModelsForCurrentProvider`、`_getMenuPosition`、`_showModelMenu`、`_tryFetchModels` 伪代码

#### 2026-05-11: 新增伪代码文档

- **新增模型文档**: `opf_metadata.md`
- **新增服务文档**: `epub_service.md`, `file_storage_service.md`, `opf_reader_service.md`, `pdf_service.md`, `storage_config.md`
- **新增**: Calibre OPF 元数据集成流程（OpfReaderService → OpfMetadata → Book合并）
- **新增**: 章节译文字段和文件路径规则

#### 2026-05-05: 窗口DPI双重缩放修复

- **修复**: C++ 层 `main.cpp` DPI 双重缩放
- **新增**: Dart 层 `_initWindowManager()`（window_manager + screen_retriever）
- **新增依赖**: `screen_retriever: ^0.2.0`

#### 2026-04-26: UI垂直Tab布局

- BookScreen / ChapterScreen 引入 TabController 垂直Tab布局

#### 2026-04-24: 流式显示功能

- SSE 流式响应支持（`_callAIStream`）
- 章节/全书流式回调机制
- UI 实时显示生成内容