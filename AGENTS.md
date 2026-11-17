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
├── services/                 # book, ai, summary, storage_config, file_storage, settings, log
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
- **文件结构**: `settings.json`, `books_index.json`, `books/{bookId}/metadata.json`, `summary-zh.md`, `summary-{lang}.md`, `chapter-{index}-{lang}.html`
- **AI配置**: SettingsService集中管理，`savedAiConfigs`多配置保存
- **流式生成**: HttpClient + SSE，章节通过`onContentUpdate`回调，全书通过`_streamingCallbacks`Map（key=`{bookId}_{language}`）
- **语言支持**: AI摘要按语言分别存储（zh/en/ja），`PlatformDispatcher`获取系统语言

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
**每次提交前必须先同步更新受影响的文档：**
1. 更新 `docs/function_call_relationships*.md`
2. 更新本文件版本历史
3. 最后再 git commit + push

---

### 版本历史

**2026-11-17**: AI/界面语言设置合并为统一「语言」设置 — `LanguageSettings` 精简为 `languageMode`+`language`（删「跟随书籍」，仅「跟随系统/用户自选」），AI 摘要/翻译与界面显示统一使用此语言；`resolveOutputLanguage`/`needsTranslation` 简化、删除 `_detectLanguageFromMetadataAndContentWithBookId` 死代码；设置页语言 UI 合并为一组单选；清理 18 个 l10n 僵尸 key；同步 `function_call_relationships*.md`
**2026-11-17**: 首页书架 UI 优化 — 移除底部状态栏（书籍总数移至 AppBar 标题括号内，搜索时显示命中/总数）；搜索框提示改"搜索书名/作者"、删除 l10n `bookCount`；卡片比例改 3:4.5；封面改 `fitWidth + topCenter`（竖/横封面均不裁左右）；书名/作者区改为叠加封面底部的半透明条；封面右上角新增格式徽章（PDF/EPUB）；书架支持键盘滚动（↑/↓/PgUp/PgDn）
**2026-11-17**: 删除 `docs/pseudocode/` 伪代码文档目录 — 决定不再维护伪代码文档，提交前规则移除伪代码同步项，仅保留 function_call_relationships 与版本历史
**2026-11-16**: Calibre 书库导入 + 首页书架优化 — 书库侧：设置页新增「书库设置」区块（浏览/刷新/清空书架，只读不修改第三方文件）；新增 `LibraryImportService`（后台异步导入 + 断点续传 + refreshSignal 每 10 本或完成触发首页刷新）；导入改为轻量模式（`extractBasicMetadata` 只读书名/作者/封面，不解析章节、不生成摘要）；OPF 封面改从 `<guide>` 段落读 `reference type="cover"`；`scanCalibreOpfFiles` 跳过隐藏目录（修复 Calibre `.caltrash` 回收站误导入）；`clearAllBooks()` 清空书架；退出优化：`onWindowClose` 保存进度后 `exit(0)` 立即退出（修复关闭延迟 5 秒）；首页侧：书架网格改 `SliverGridDelegateWithMaxCrossAxisExtent` 自适应列数、底部半透明状态栏显示书籍总数、卡片书名 2 行 + 溢出 Tooltip、作者改用主题色、卡片加 outline 描边；文档侧：新增 `library_import_service.md`，同步 `main.md`/`book_service.md`/`settings_service.md`/`app_settings.md`/`opf_reader_service.md`/`book_format_parser.md`/`epub_parser.md`/`pdf_parser.md`/`home_screen.md`/`settings_screen.md`/`index.md`/`function_call_relationships*.md`
**2026-11-13**: 冗余代码清理、注释规整与文档同步 — 代码侧：删除未使用 import（book.dart 等多处）；删除未使用字段（`chapter_screen._bookService`、`summary_service._bookService`、`Semaphore._maxPermits`）；清理冗余空安全操作符（epub_parser 10处、book_service 2处、ai_service 1处）；删除死 l10n key `promptPrefaceSummary`；修复 stale 测试（`bookSummaryFromPreface` 用例等）；注释侧：文件头部 doc 注释 `///` → `//`（消除 dangling_library_doc_comments）、doc 注释尖括号加反引号（消除 unintended_html_in_doc_comment）；文档侧：删除 `window_utils.md`、`opf_metadata.md`；更新 `main.md`/`book.md`/`index.md`/`function_call_relationships.md`/`function_call_relationships_visual.md` 的 stale 引用（`EpubService`/`PdfService`/`TranslationService`、`chapterTitles`、`translateHtmlStream()`、`_generateBookSummaryFromPreface()` 等）

**2026-05-24**: AI思考过程清理 — 新增 `removeThinkingProcess()` 方法清理 `<thinking>`/`<think>` 标签；`getSummary()` 读取章节摘要时自动清理；`generateSingleSummary()` 生成章节摘要时先清理再提取标题；`_generateBookSummaryFromChapters()` 保存全书摘要前清理；BookScreen 加载/刷新文件摘要时调用清理方法，文件摘要优先于流式内容显示；增强 `AIService` system prompt 明确禁止AI输出思考过程标签（中/英/日三语）

**2026-05-23**: AI摘要语言支持 — 全书/章节摘要按语言分别生成存储（zh/en/ja）；BookScreen 语言跟随修复（`PlatformDispatcher`获取系统语言）；摘要长度优化改为按比例（原文1/100），替代固定字数要求；system prompt 明确禁止标题输出；统一EPUB/PDF生成流程为"先章节摘要→再全书摘要"，章节摘要上限30个，截取前400字；修复章节摘要language参数传递；强化system/user prompt语言约束（禁止使用其他语言）
**2026-05-23**: window_utils 合并到 main.dart，删除 `lib/utils/window_utils.dart`；setState 单行格式统一（book_screen 3处、chapter_screen 3处）
**2026-05-23**: models 注释精简 — app_settings 补全缺失字段注释统一风格；chapter 从108行精简至52行
**2026-05-23**: l10n 注释统一 — 补全 55 个缺失的 @key 描述，消除所有 "No description provided"；统一注释风格（分类+用途）
**2026-05-23**: l10n 僵尸字符串清理 — 删除 43 个未使用 key，消除重复键，补齐跨语言缺失；arb 文件精简约 100 行
**2026-05-23**: LogService 日志路径添加 zhidu，移除文件名时间戳，1MB 自动滚动；消除重复解析（generateSummariesForBook 接收 chapters 参数）；语言设置防重更新
**2026-05-22**: 合并 EpubService/PdfService 到 EpubParser/PdfParser，统一元数据解析接口，删除两服务文件
**2026-05-21**: 僵尸代码清理 — EpubService(-67%)、PdfService(-60%)、BookService(-33%)；删除 chapterTitles 持久化；AI语言检测改用流式识别
**2026-05-21**: AiPrompts 精简 — 提示词 l10n 化，消除占位符和死方法，删除 systemMessage 参数
**2026-05-20**: epub_parser 重构 — extractCover 接口删除，改用 package:html DOM 查询
**2026-05-20**: bookId 收归 BookService，OPF 读取去重（从3遍→1遍）
**2026-05-19**: epub/pdf_parser 僵尸代码清理；format_registry 合并到 book_format_parser；settings_screen 冗余清理
**2026-05-19**: HomeScreen + BookshelfScreen 合并，修复删除失败 SnackBar i18n 和 BookCard 返回值检查
**2026-05-18**: ChapterScreen 重构为 BookScreen 模式，SummaryService 新增章节级流式回调
**2026-05-18**: AIService 统一语言检测，新增 needsTranslation()；全项目日志精简(-47%)
**2026-05-17**: AI配置页面动态获取模型列表；OpfMetadata/Book/Chapter 类合并清理
**2026-05-16**: SummaryService 回调合并；AIService 重构删除韩语支持
**2026-05-15**: 章节摘要文件名规范化；SettingsService 精简；统一 JSON 写入逻辑
**2026-05-14**: 多平台构建修复
**2026-05-11**: 多显示器 DPI 窗口定位
**2026-05-05**: 窗口 DPI 双重缩放修复
**2026-04-26**: UI 垂直 Tab 布局
**2026-04-24**: 流式显示
**2026-04-20**: 国际化 zh/en/ja
**2026-04-15**: SettingsService 统一设置管理
**2026-04-14**: 代码审查清理(853行)
**2026-04-09**: 修复章节摘要死循环
