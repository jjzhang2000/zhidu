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
├── screens/                  # home, book, chapter, settings系列页面
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

**2026-11-26**: 代码审核清理 + 删除 PdfReaderScreen — 删除未被应用流程调用的 `lib/screens/pdf_reader_screen.dart` 及其测试（PDF 阅读实际由 `ChapterScreen` 内置 `PdfDocumentViewBuilder` 处理），同步更新 README、测试计划与 `function_call_relationships*.md`；清理 `ChapterScreen` 恒真分页开关、重复 `HtmlWidget` 构造、`List<dynamic>` 返回值与未使用的 `bookFormat` 参数；`SummaryService`/`AiConfigScreen` 去重；修复 `withOpacity`/`RadioListTile`/`Dropdown value`/`window` 等弃用 API 与 analyzer 告警；精简 models、file_storage、pdf_reader、ai_service 冗余注释并修正过时描述；`flutter analyze lib` 无告警，409 个测试全部通过
**2026-11-26**: 测试源码纳入版本管理 — `.gitignore` 移除 `/test/` 整体忽略，改为仅忽略测试临时产物 `/test/.test_temp/`，`test/` 下用例与 fixtures 一并纳入 Git
**2026-11-26**: 修复续读定位失效（页码已正确写入但重进回落首页）— 根因：`PagedReadingView._finalizePosition()` 在分页稳定后才**延迟读取** `widget.initialPageIndex`，而 `ChapterScreen` 首帧后已清空 `_initialPagedPage`、父级重建改传 `_pagedCurrentPage`(0)，于是读到 0 并跳到首页。修复：新增 `_pendingPageIndex` 在 `initState`/`didUpdateWidget(htmlChanged)` 时固化目标页，定位后清空；新增回归测试「initialPagedPage 打开后定位到指定页」。
**2026-11-26**: 清理 metadata.json 冗余字段 — 删除 `Book.currentChapter`（历史遗留，仅写不读，阅读位置已由 `lastChapterIndex` 表达）：从字段/构造/`copyWith`/`toJson`/`fromJson` 及 `BookService.saveReadingPosition()`、相关测试中移除。保留字段用途：`totalChapters`（章节数缓存）、`readingProgress`（书架进度条）、`lastReadAt`（排序）、`lastChapterIndex`/`lastPageIndex`（续读）、`language`（AI 源语言识别）、`publisher`/`publishDate`（详情页展示）。旧 metadata.json 中残留的 `currentChapter` 会被 `fromJson` 忽略，下次写入时自动消失。
**2026-11-26**: 修复页码保存为 0（续读失败根因）— `TabBarView` 的 `PageView` 会销毁远离当前页的子页，切到缩写/译文/目录再回到原文时 `PagedReadingView` State 重建、`_currentPage` 归零并经 `onPageChanged` 把 `ChapterScreen._pagedCurrentPage` 覆盖为 0，退出时保存的就是 0。修复：①`PagedReadingView` 混入 `AutomaticKeepAliveClientMixin`（`wantKeepAlive => true`，`build` 先调 `super.build`）使分页结果在 Tab 切换时保活；②`initialPageIndex: _initialPagedPage ?? _pagedCurrentPage`，同内容重建时回到当前页；③`_navigateToChapter()` 重置 `_pagedCurrentPage/_pagedTotalPages`；④开头页（`openingContent`）分支也在首帧后清空 `_initialPagedPage`。
**2026-11-26**: 阅读位置持久化加固 — 新增 `BookService.saveReadingPosition(bookId, chapterIndex, pageIndex, progress:)`，按 id 取内存中的权威书籍记录（避免调用方过期快照），同时写入 `readingProgress`；`ChapterScreen._saveReadingPosition()` 改用它并打印日志。字段语义：`currentChapter` 历史字段（现同步写入）、`readingProgress` 全书进度（书架进度条）、`lastChapterIndex` 上次阅读章节、`lastPageIndex` 章节内页码（0 起）；位置存于 `books/{bookId}/metadata.json`，`books_index.json` 只存 id/书名/作者/格式/路径/addedAt。
**2026-11-26**: 修复续读位置不准 — ①`BookScreen._startReading()` 先从 `BookService` 重读最新书籍记录，避免使用本页缓存的过期 `_book`（此前返回阅读页后再次点「阅读」读不到刚保存的进度，退化为全书首页）；②首章进度按「开头页」（`_openOpening`）恢复，保证页码与文档一致；③`ChapterScreen` 翻页后经 2s 防抖 `_scheduleSaveReadingPosition()` 保存位置，并用 `_savedChapterIndex/_savedPageIndex` 跳过重复写文件。
**2026-11-26**: 书架续读（调整入口）— `Book` 新增 `lastChapterIndex`/`lastPageIndex`（持久化）；`ChapterScreen` 在翻章与 `dispose` 时经 `_saveReadingPosition()` 写入阅读位置，新增 `initialPagedPage` 恢复分页页码（`PagedReadingView.initialPageIndex`，定位期间 Opacity 隐藏防闪）。入口调整：书架点击仍进入书籍详情页，详情页「阅读」按钮 `_startReading()` 依据是否已有 `lastChapterIndex` 决定打开上次位置（`_resumeReading()`）或全书首页；章节列表点击逻辑不变。
**2026-11-26**: 阅读页新增「目录」Tab — `ChapterScreen` 的垂直 Tab 由 3 个（原文/缩写/译文）扩为 4 个，第 4 个 `Icons.toc` 显示全书章节目录；新增 `lib/widgets/chapter_directory.dart`（`BookCover` 封面 + `buildChapterTiles` 层级章节项 + `ChapterDirectory`），书籍详情页与本 Tab 复用同一套封面/列表代码；点击条目原地跳章（子章节定位到其标题所在页，同章内点击仅重定位，经 `PagedReadingView.positionToken` 触发），并自动切回原文 Tab。
**2026-11-26**: 章节列表全层级可点击 — `BookScreen._buildChapterList()` 取消「仅 level==0 可点」，0/1/2 级目录均可跳转；`_openChapter()` 新增 `_topLevelChapterOf()` 解析子章节所属顶层章节，并把子章节标题作为 `initialAnchor` 传入 `ChapterScreen`→`PagedReadingView`，分页稳定后由 `_pageForAnchor()` 定位到该标题所在页（块纯文本比对，忽略空白）；`ChapterScreen` 首次内容加载后清空锚点，避免后续翻章重复定位。
**2026-11-26**: 修复合并章节丢失正文 — `ChapterScreen` 新增 `_allChapters` 保存完整章节列表（含子章节），`_loadChapterContent()` 改用它作为 `getChapterContentMerged()` 的入参；此前误传过滤后的 `_chapters`（仅 `level==0`），使 `EpubParser._collectChapterGroup` 在下一个顶层章节处立即中断，只取顶层章节自身文件，根因导致子章节所在文件的正文整段丢失（如《三国配角演义》「街 亭」合并后由 3KB 恢复为 346KB，含「街亭败战」「马谡入狱」等）；同步 `function_call_relationships*.md`
**2026-11-21**: 分页阅读翻页导航完善 — ① 修复跨章闪动：翻回上一章（`startAtLastPage`）不再「先首页/中间页再末页」，`PagedReadingView` 在分页稳定后由 `_finalizePosition()` 定位目标页（翻上一章为末页、翻下一章/初始为首页），期间用 `_pageViewHidden`（Opacity 隐藏）使跳转全程不可见。② 翻页入口统一：`PagedReadingView` 新增 `onPrevChapter`/`onNextChapter` 回调，点击左右 1/3 区域与键盘 ←/→ 到达章节边界即跨章，与底部大按钮行为一致；`ChapterScreen` 传入回调复用 `_navigateToChapter`。③ 滑动跨章：`PageView` 改用 `BouncingScrollPhysics` + `NotificationListener` 监听 overscroll，滑到末页/首页继续滑动即跨章，`_crossChapterTriggered` 防重复触发；同步 `function_call_relationships*.md`
**2026-11-20**: EPUB 显示能力改进（分层阅读器四阶段）— ① 渲染器替换：`flutter_html` → `flutter_widget_from_html_core`（`HtmlWidget`），CSS 内联重写为 `EpubCssEngine`（csslib 解析 + cascadia 选择器匹配 + !important/特异性/源顺序级联），`getChapterContentMerged`/`getOpeningContent` 返回值改为 `RenderedContent`（html + fonts + isVertical + plainText），新增 `RenderedContent`/`EmbeddedFont` 模型。② 字体嵌入：`@font-face` 提取 + SHA-1 反混淆 + `FontLoader` 运行时注册。③ 图片完善：`background-image` 转 data URI、SVG 封面转 `<img>`、保留尺寸。④ 竖排：检测 `writing-mode: vertical-rl/lr`，用 `tategaki` 的 `VerticalText` 渲染。⑤ 分页阅读：新增 `PagedReadingView`（TextPainter 切页 + PageView），设为 EPUB 横排原文默认模式（滚动为可选，切换入口后续放设置项）；同步 `function_call_relationships*.md`
**2026-11-19**: 阅读/章节页重构 — ① 删除 AI 缩写预处理与生成：`SummaryService` 删除 `generateSingleSummary`/`generateSummariesForBook`/`_generateBookSummaryFromChapters`/`Semaphore`/`registerBookStreamingCallback`/`init`/`dispose`，保留译文生成与缩写/译文读写缓存；`BookScreen` 删除后台预生成 `_startPreGeneration` 与全书摘要 Tab；`ChapterScreen` 删除「生成缩写」按钮，缩写改为 `_loadAbbreviation` 仅读缓存、不调用 AI。② 阅读按钮直达第一页：`BookFormatParser` 新增 `getOpeningContent()`（`EpubParser` 实现 spine 首文件内联 CSS/图片、SVG 封面转 `<img>`，`PdfParser` 返回 null）。③ 章节 Tab 重排为 原文/缩写/译文 且默认进入原文。④ 翻章改为原地渲染 `_navigateToChapter()`（不再 `Navigator.pushReplacement`），保留旧内容后台加载无闪动、滚动重置到顶部。⑤ 翻页按钮样式（放大、透明度、悬停变色、单箭头图标）；同步 `function_call_relationships*.md`
**2026-11-18**: 打开书籍自动本地化文件 — `BookService.ensureBookFileLocal()` 判断书籍 `filePath` 是否位于应用存储目录 `books/{bookId}/`，非本地（如从 Calibre 书库导入）则复制到 `books/{bookId}/book{ext}` 并通过 `updateBook` 更新 `filePath` 持久化；`BookScreen._loadChapters()` 解析章节前先调用，后续解析统一使用本地副本；同步 `function_call_relationships*.md`
**2026-11-17**: 书架排序返回刷新 — `BookCard` 新增 `onOpened` 回调，从书籍详情页返回首页时若排序为「最近阅读时间」则刷新书架重新排序（`_openBook` 返回后经回调通知 `_HomeScreenState`，仅 `_sortType == BookSortType.lastRead` 时 `setState`）；同步 `function_call_relationships*.md`
**2026-11-17**: 书架排序功能 — 首页 AppBar 设置按钮左侧新增排序按钮，书架支持 7 种排序（最近阅读时间/加入时间/书名/作者 × 升序/降序）；新增 `BookSortType` 枚举并接入 `AppSettings.bookshelfSortType` 持久化（`SettingsService.setBookshelfSortType()` + `bookshelfSortType` ValueNotifier）；`HomeScreen._sortedBooks()` 按排序方式排序、初始值从 SettingsService 读取；同步 `function_call_relationships*.md`
**2026-11-17**: 阅读进度追踪（totalChapters/lastReadAt）— 打开书籍时 `BookScreen._updateLastReadAt()` 更新最后阅读时间并持久化；`_loadChapters()` 首次成功解析章节数后通过 `updateBook` 保存 `totalChapters`，章节数展示优先使用缓存值（加载中即可显示，避免等待解析）；`HomeScreen._sortedBooks()` 书架按 `lastReadAt` 降序排序（最近阅读在前、未读在后）；同步 `function_call_relationships*.md`
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
