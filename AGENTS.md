# AGENTS.md

**项目以简体中文进行交互沟通**

## 智读 (Zhidu) - AI分层阅读器

Flutter跨平台AI智能阅读器，主打"分层阅读"和"知识蒸馏"。

### Requirements
- **Flutter SDK**: >=3.0.0 <4.0.0
- **平台**: Windows（主要）、Android、iOS、macOS、Linux
- **Web限制**: 无法导入本地文件（浏览器沙箱）

### Development Commands
`flutter run` | `flutter run --release` | `flutter test` | `flutter analyze` | `flutter pub get` | `flutter build windows --release`

### Project Structure
```
lib/
├── main.dart                 # 入口，初始化所有Service
├── models/                   # app_settings, book, chapter, chapter_summary等
├── screens/                  # home, book, chapter, pdf_reader, settings系列页面
├── services/                 # book, epub, pdf, ai, summary, storage_config, file_storage, settings, log
│   └── parsers/             # book_format_parser(接口+注册表), epub_parser, pdf_parser
└── utils/                    # app_theme
```

### Key Dependencies
- **EPUB**: `epub_plus`, `archive`, `xml`, `image`
- **PDF**: `pdf`, `sync_pdf_renderer`
- **UI**: `flutter_html`, `markdown`
- **工具**: `http`, `file_picker`, `path_provider`, `uuid`, `intl`, `screen_retriever`, `window_manager`

### Architecture
- **状态管理**: StatefulWidget + Service单例 + ValueNotifier
- **存储**: Documents/zhidu/ 目录（JSON + Markdown）
- **文件结构**: `settings.json`, `books_index.json`, `books/{bookId}/metadata.json`, `summary-zh.md`, `Summary-{index}-{lang}.md`, `chapter-{index}-{lang}.html`
- **AI配置**: SettingsService集中管理，`savedAiConfigs`多配置保存
- **流式生成**: HttpClient + SSE，章节通过`onContentUpdate`回调，全书通过`_streamingCallbacks`Map

### AI Providers
| 提供商 | 类型 | API Key | 默认Base URL |
|--------|------|---------|--------------|
| 智谱/通义千问/DeepSeek/MiniMax | 云服务 | ✓ | 各自兼容接口 |
| Ollama/LM Studio | 本地部署 | ✗ | localhost:11434/1234 |

### Format Parser
注册表模式（FormatRegistry），扩展名→解析器映射。新增格式只需实现BookFormatParser接口并注册。

### Data Flow
文件导入 → 解析（EPUB/PDF）→ AI分析 → 展示 → 存储 → 导出

### Code Quality
- Lint: `flutter_lints` + `prefer_single_quotes`
- 国际化: `AppLocalizations.of(context)`，支持zh/en/ja
- 支持语言: zh, en, ja

### Git Ignore
`/Summaries/` `/logs/` `/temp_docs/` `*.log` `*.iml` `.flutter-plugins*`

### 开发要点
- 修改Service后需重启应用（热重载对单例不完全生效）
- AI调用异步，注意处理loading状态
- 设置变更通过ValueNotifier响应式更新
- 非桌面平台不调用`window_manager`（运行时`Platform.is*`检测）

### Git提交前规则（重要）
**每次提交前必须先同步更新受影响的文档和伪代码：**
1. 更新 `docs/pseudocode/` 下对应 `.md` 文件
2. 更新 `docs/function_call_relationships*.md`
3. 更新 `docs/pseudocode/index.md` 中引用
4. 更新本文件版本历史
5. 删除已不存在服务/方法的文档
6. 最后再 git commit + push

---

### 版本历史

**2026-05-20**: epub_parser 重构精简 — 删除 extractCover 接口+3个实现（死代码链）；删除 Level 2 冗余分支 `_extractChapterInfos`（与 NCX 同源）；`_extractTextFromHtml`+`_extractTitleFromHtmlContent` 手写正则→`package:html` DOM 查询（新增依赖）；epub_parser 647→436 行
**2026-05-20**: bookId 提炼 + OPF 读取去重 — `_uuid.v4()` 从 EpubService/PdfService 收归 BookService；删除两 Service 内部 OPF 读取块（之前每次导入读 3 遍，现只读 1 遍）；删除 `OpfReaderService` import + `language` 构造参数
**2026-05-20**: epub_service 封面提取日志降级 — `_extractCover`/`_extractCoverFromArchive`/`parseEpubFile` 回退路径 catch 从 `_log.e`+堆栈降为 `_log.w`（无异常dump）；EpubReader 解析失败属可恢复回退，不应报 error
**2026-05-19**: epub_parser + pdf_parser 僵尸代码清理 — epub 删除 6 个死方法 `_extractChapterTitles`/`_extractTitleFromPath`/`_parseContainerXml`/`_parseOpfFile`/`_parseNavigationFile`/`_findEpubChapterByIndex`+2个未用 import（1139→629 行）；pdf 删除冗余文件头/分节符/内联注释、死代码 `extractCover` 文件检查、3个未用 import（438→208 行）
**2026-05-19**: book_format_parser.dart 格式整理 — 抽象方法补一行 `///` 注释，两方法间隔统一，类属性与后续方法统一间距
**2026-05-19**: format_registry 合并到 book_format_parser — FormatRegistry 类合并入接口文件，删除死代码 `initialize()`；删除 `format_registry.dart`；更新 4 处 import + 3 处测试引用 + 文档；去掉冗余注释（286→42 行）
**2026-05-19**: settings_screen 僵尸代码清理 + loc getter 复用 — 删除 `_buildSection` 两个未使用参数 `title`/`icon`（全部3处调用白传）；`AppLocalizations.of(context)!` 提取为 getter，删除7处重复声明；注释精简（过时版本号、冗余内联）；theme_settings_screen 合并重复文件级/类级注释；更新 `settings_screen.md`、`index.md`
**2026-05-19**: language_settings_screen.dart 冗余清理 — switch → copyWith 简化 `_updateAiLanguageMode`/`_updateUiLanguageMode`（省 ~40 行）；`_buildLanguageSelector` 中 `_getLanguages` 提取为局部变量避免重复调用；删除 `_getLanguages` 中冗余 `??` fallback 及 `app_settings.dart` import
**2026-05-19**: fix — 删除失败 SnackBar 硬编码中文改为 i18n key `loc.failed`；原 `const Text('删除失败…')` 在 en/ja 界面下遗留中文且 `const` 导致语言切换不更新
**2026-05-19**: fix — BookCard 删除时检查 deleteBook() 返回值防止目录残留；`deleteBook()` 返回 `bool` 但此前不检查，磁盘 IO 失败（文件被占用/权限不足）时目录残留但卡片被移除；修复后仅成功才 `onDeleted`，失败显示错误 SnackBar
**2026-05-19**: HomeScreen + BookshelfScreen 合并 — 两个组件合并为单层 Scaffold；消除 GlobalKey `_bookshelfKey` + `refresh()` 方法；删除嵌套 Scaffold + 重复 `BookService` 实例化；import 后直接 `setState` 刷新书架；更新 `home_screen.md`、`function_call_relationships.md`
**2026-05-19**: HomeScreen 僵尸代码清理与冗余日志删除 — 删除 `_BookCardState._summaryService` 僵尸字段（从未调用）及 `SummaryService` import；删除 `_HomeScreenState`/`_BookshelfScreenState` 中 `_log` 字段及4条冗余日志 + `LogService` import；更新 `home_screen.md`、`function_call_relationships.md`、`index.md`
**2026-05-18**: ChapterScreen 重构为 BookScreen 模式 — SummaryService 新增章节级流式回调 + `ensureChapterSummary()` / `ensureChapterTranslation()`；ChapterScreen 删除 `_loadSummary`(`_generateSummaryWithStreaming()`)/`_loadTranslation`/`_generateTranslationWithStreaming()` 四个方法(~170行)，改为两个 `_ensureXxx()` 各 ~25 行；删除 `_hasLoadedSummary`/`_listeningChapterKey` 字段；所有摘要/翻译编排逻辑归口 SummaryService
**2026-05-18**: AIService 新增 `needsTranslation()` + 删除 `_resolveTargetLang()` — 所有语言判断统一归口到 AIService；`needsTranslation(sourceLang)` 判断源/目标语言是否需要翻译；ChapterScreen 删除 `_resolveTargetLang()`（16行），改为 `_aiService.getTargetLanguage()` + `_aiService.needsTranslation()`
**2026-05-18**: 全项目日志精简 — 397→212条(-47%)：删除 `_log.v` 追踪日志、chunk级流式日志、冗余入口/进度/确认日志；合并相邻重复日志；保留所有 error/warning；epub_service(107→42)、summary_service(51→37)、ai_service(42→27)、chapter_screen(20→9) 等全面清理
**2026-05-18**: AIService 新增 `detectSourceLanguage()` 统一源语言检测 — 合并 ChapterScreen 和 `_detectLanguageFromMetadataAndContentWithBookId` 两处重复的「元数据→convert/内容→detect」模式(~22行)；`_detectLanguageFromMetadataAndContentWithBookId` 简化为 3 行委托；ChapterScreen `_initializeLanguageSettings` 省 7 行；更新 `ai_service.md`、`chapter_screen.md`
**2026-05-18**: ChapterScreen detectSystemLanguage 合并与 Tab 顺序调整 — `_detectSystemLanguage()` 合并到 `AIService.detectSystemLanguage()`（public），删除 ChapterScreen 副本(~27行)及 `import 'dart:io'`；删除 `_updateTargetLanguage()`（用户进入 ChapterScreen 后不可能变语言）；Tab 顺序调整为 0=摘要/1=原文/2=译文；更新 `ai_service.md`、`chapter_screen.md`
**2026-05-18**: ChapterScreen 僵尸代码清理与重复代码提取 — 删除 `_generateSummary()`（阻塞版）、`_uiRefreshTimer`、`_getCurrentSummaryLanguage()` 三处僵尸代码(~87行)；提取 `_htmlStyle` getter、`_buildTypingIndicator()`+`_typingDot()`、`_resolveTargetLang()` 三处重复代码(~118行)；更新 `chapter_screen.md` 伪代码文档
**2026-05-18**: BookScreen 日志修正与重复代码提取 — 修正`_startPreGeneration`日志（"章节摘要"→"摘要"）；提取`_htmlStyle` getter和`_buildSummaryWithMarkdown()`，消除约120行重复代码；更新`book_screen.md`伪代码文档
**2026-05-18**: AiConfigScreen 注释规范化与死代码清理 — 删除`_recommendedModels`（冗余getter）和内联`_getLocalizedProviders`；修正`_buildModelSection`过时注释；所有字段/方法doc注释格式统一；更新伪代码文档新增5个方法
**2026-05-17**: AI配置页面模型选择改进 — 改为联网动态获取模型列表，纯下拉框选择，模型名称按字母排序；新增`fetchAvailableModels`方法；删除`cachedModels`缓存机制
**2026-05-17**: OpfMetadata类合并 — OpfMetadata类从opf_metadata.dart移动到book.dart文件末尾，删除独立的opf_metadata.dart文件，更新所有导入引用和文档
**2026-05-17**: Book模型清理 — 删除aiIntroduction字段（改用summary-zh.md独立文件存储全书摘要），删除publisher/description/subjects僵尸字段（OPF元数据从未被读取使用）
**2026-05-17**: Chapter类合并 — ChapterContent/ChapterSummary类合并到Chapter类，删除bookId以外所有JSON序列化方法，删除chapter.id字段（改用bookId），删除ChapterSummary的aiInsight/keyPoints/createdAt死字段，删除chapter_content.md/chapter_summary.md/chapter_location.md文档，getChapterContent返回类型改为Chapter
**2026-05-16**: SummaryService清理与回调合并 — 删除`_generatingBookSummaryKeys`/`_generatingFutures`等6个方法，合并回调Map；删除TranslationService文档引用
**2026-05-16**: AIService重构 — 删除韩语支持、阻塞版摘要方法(~250行)，统一配置检查，提取`_buildMessages()`
**2026-05-15**: 章节摘要文件名改为`Summary-{index}-{lang}.md`
**2026-05-15**: 统一JSON写入逻辑 — SettingsService委托FileStorageService
**2026-05-15**: 版本号动态获取 — `package_info_plus`
**2026-05-15**: 存储层清理 — 消除SettingsService/StorageConfig重复目录创建
**2026-05-15**: SettingsService死代码清理 — 378→217行，添加dispose()
**2026-05-15**: 删除AIConfig类 — 统一使用AiSettings
**2026-05-14**: 多平台构建修复 — pdfrx 2.x API适配、Android窗口管理检测、日志路径修复
**2026-05-11**: 多显示器DPI窗口定位 — `getAllDisplays()`+窗口中心匹配
**2026-05-05**: 窗口DPI双重缩放修复 — `screen_retriever`+`waitUntilReadyToShow`
**2026-04-26**: UI垂直Tab布局 — TabController管理章节/全书摘要页
**2026-04-24**: 流式显示 — HttpClient+SSE实时显示AI生成内容
**2026-04-20**: 国际化 — flutter_localizations，zh/en/ja
**2026-04-15**: SettingsService统一设置管理
**2026-04-14**: 代码审查清理 — 删除SectionSummaryService等死代码(853行)
**2026-04-09**: 修复章节摘要无法进入阅读界面死循环
