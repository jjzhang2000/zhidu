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

**2026-11-28**: 章节内标题链接回到目录对应条目 — 书中各章节标题常写成 `text00000.html#tocN` 链回目录；此前解析出目标文件后忽略锚点，总是落到目录第一页。新增 `BookFormatParser.getAnchorText()`（EPUB 按 id 取元素文本，PDF 返回 null）；`ChapterScreen._onLinkTap` 在「文件命中但锚点不匹配任何子章节」时，经 `_gotoChapterAnchor()` 按锚点 id 取文本，再用 `PagedOpenTarget.atAnchor(文本)` 定位到该条目所在页（同章 retarget、跨章携带 anchor）；锚点命中子章节仍优先。新增解析器「按 id 取锚点文本」用例；`flutter analyze lib` 无告警、439 个测试通过

**2026-11-28**: 目录中的图片项通用地插入为独立页 — 书籍目录项（未必是首项）可能直接指向独立图片（如「封面」→ `Image00000.jpg`），而全书没有任何页面包含该图，此前点击无反应或另开图片查看页（打断翻页，已废弃）。改为在 `EpubParser._readChapters()` 解析章节后用 `_injectImageTocEntries()`：以第一个顶层章节的 HTML 作为目录页，按其链接顺序，把图片项注入为 level 0 的合成章节，位置为「前一个可匹配章节之后（无则最前）」，从而位于上一项末页与下一项首页之间；`getChapterContent`/`getChapterContentMerged` 对图片章节返回 `_renderImageChapterPage()`（带 `data-zhidu-image-page` 标记的单图页）；分页层**显式建模**「1 个图片条目 = 1 页」：`html_pagination` 的 `isImagePageBlocks()`/`imagePageResult()` 识别图片页后直接认定为 1 页、**不测量**（`BookPaginator._finishImagePage()` 与 `PagedReaderController` 均短路测量），与图片像素尺寸完全无关（此前按图片原始尺寸测量会被当成成百上千页，导致全书页码暴涨、顺序错乱）；`PagedReadingView._buildPageContent()` 识别图片页标记，用 `Image.memory(fit: BoxFit.contain)` 等比缩放填充整页；图片章节即普通章节，天然参与分页、翻页、页码与目录点击跳转（`ChapterScreen._onLinkTap` 无需图片特判）；`getOpeningContent()` 仍「无前置页返回 null」，但界定前置页范围时**跳过图片类章节**，改用第一个 HTML 章节比较 spine（否则图片章节 href 是图片文件、匹配不到任何 spine 文档，会把整本书当作开头页 → 封面落到书末、全书重复一遍）；新增/更新「图片目录项注入位置（首项与中间项）」「点击封面跳到图片页」「目录首项为图片时开头页返回 null」用例；`flutter analyze lib` 无告警、438 个测试通过

**2026-11-28**: 修复目录章节重复出现（开头页与第一章同一文件）— 根因：`EpubParser.getOpeningContent()` 在「第一个内容文档即第一个章节」时（如该书 spine 首文件 `text00000.html` 正是第一章「目录」），仍把首文件作为开头页返回，且以 `frontMatter: true` 做了目录归一化（字号缩到 0.76em），于是第一章首页向前翻会回到「字体变小、同样可点击」的重复目录。修复：`firstChapterHref != null` 且前置页列表为空时返回 `null`（无真正前置页），`BookScreen` 自动回退到第一章；`BookPaginator` 对 index=-1 的 `null` 结果经 `_finishWithoutPages` 跳过、不占页码；更新解析器用例为「无真正前置页时返回 null」；`flutter analyze lib` 无告警、435 个测试通过

**2026-11-28**: 阅读页支持点击目录链接跳章 — ①`PagedReadingView` 新增 `onLinkTap`：`HtmlWidget` 传 `onTapUrl` 处理链接点击；点中链接时置 `_linkTapped`，「点击左右 1/3 翻页」延后到微任务执行，链接优先于翻页（未启用链接时保持同步翻页原行为）；②`ChapterScreen` 新增 `_onLinkTap()`/`_findChapterByHref()`：按当前章节文件解析相对 href（含 `../`、`#anchor`、绝对路径），在 `_allChapters` 中按「文件+锚点」匹配章节，子章节定位到其标题所在页；目录点击与正文链接共用 `_gotoChapterNode()`；分页原文与滚动原文均启用链接跳转（缩写/译文不启用），外部链接与非章节链接忽略；③`reader_flow_test` 开头页回翻改用阅读区左侧留白坐标（目录文字链接现会跳章）；新增「点链接优先于翻页」「点击目录链接跳转到对应章节」用例；`flutter analyze lib` 无告警、435 个测试通过

**2026-11-28**: 修复目录页链接深色不可读与源码外露 — ①`EpubCssEngine` 新增 `_normalizeLinkColors()`：在 `render()` 中移除 `<a>` 及其后代元素内联样式里的 `color`，交由 `flutter_widget_from_html` 按主题取链接色（`colorScheme.primary`），修复书籍 `a{color:#0000CC}` 深蓝在深色模式下无法辨认；②`EpubParser._extractChapterByAnchor()` 修正锚点回溯：循环停在 `<` 之后的第一个字符，需再回退一格把 `<` 纳入片段，此前片段以标签名开头（`a href="Image00000.jpg" id="toc1">封面`），被当作纯文本渲染出 `a href=...&gt;封面` 源码（首个章节「目录」来源）；新增解析器（锚点提取保留完整起始标签）与 CSS 引擎（链接颜色移除）回归用例；`flutter analyze lib` 无告警、433 个测试通过

**2026-11-28**: 代码审核与注释规整 — 修复 `AppSettings` 类文档误挂到 `_unsetReaderValue`、`html_pagination` 新增声明插入 `buildHtmlBlocks` 文档中间导致注释错挂、`pdf_parser.getOpeningContent` 重复 `@override`；压缩 `storage_config`/`ai_config_screen`/`log_service`/`settings_screen`/`book_screen` 的模板化与过时注释（提供商列表、数据流向字段名、章节样式规则、导入节流描述等）；`flutter analyze lib` 无告警、430 个测试通过

**2026-11-28**: 原书排版作为起步值与重置目标 — 新增 `ReaderTypography` 模型与 `BookFormatParser.getReaderTypography()`：`EpubParser` 用探针 HTML 经 `EpubCssEngine` 套用书籍 CSS 后读取字号/行距/段落 `margin-bottom`（相对字号以应用默认 21px 为基准，绝对单位取原值），`PdfParser` 返回 null；`BookScreen` 与章节并行解析并传给 `ChapterScreen`（章节命中缓存时后台补充）；阅读页三项排版设置改为可空的「全局覆盖值」：`+/-` 写入覆盖、跨书生效；「重置」按项清除覆盖（只清该项），回到当前书原书排版，书未定义回退 21/1.6/0.8；旧配置中等于默认值的字面值按「未覆盖」迁移；新增解析器与阅读页重置用例；`flutter analyze lib` 无告警、430 个测试通过

**2026-11-28**: 阅读页排版设置菜单 — AppBar 右侧新增 `Icons.format_size` 按钮（`MenuAnchor`，点击不自动关闭），面板含三组「文字/行距/段距」，每组为 `+`、`-`、重置（`Icons.settings_backup_restore`）；新增设置项 `readerLineHeight`（默认 1.6）与 `readerParagraphSpacing`（默认 0.8，段距=字号×系数），`SettingsService` 各配 ValueNotifier 与 setter；`ChapterScreen` 监听三项设置即时重排：更新 `_contentTextStyle`（字号+行高）、`PagedReaderController.updateTypography`/`BookPaginator.updateTypography`，分页视图经 `open(animate: false)` 保留当前页重新分页（旧页快照遮盖测量期，稳定后直接切换，不播放跨章滑动），竖排与缩写/译文同步生效；新增阅读页菜单用例；`flutter analyze lib` 无告警、426 个测试通过

**2026-11-28**: 配色主题化修复 — ①阅读页 AppBar 标题显式取 `appBarTheme.foregroundColor`：`textTheme.titleMedium` 自带 onSurface 颜色，浅色模式下会在主色背景上显示成黑色；②清理写死颜色：底部页码、加载/错误/空状态/翻译提示、Tab 未选中态与分隔线、书架空状态、默认封面、详情页出版信息、AI 配置提示框与连通性结果等改用 `colorScheme` 语义色（`onSurfaceVariant`/`outline`/`outlineVariant`/`error`/`surfaceContainerHighest`）；③`accentColor` 统一为深橙 `#FF5722`（书架 FAB 与详情页阅读按钮同色），新增 `dangerColor` 深红 `#B71C1C` 用于封面删除按钮，清空书架确认弹窗「移除」按钮改用主题 error 色；`flutter analyze lib` 无告警，相关界面测试通过
**2026-11-28**: 完善 .gitignore — 取消忽略 `pubspec.lock`（应用需锁定依赖版本，本次一并纳入版本管理），移除过时的 `/books.json`，补充 `/Summaries/`、`.test_temp/`、`.opf_integration_test/`、`.ruff_cache/`、`.screenshots/`、`.sisyphus/` 忽略规则，构建输出改为 `**/build/` 覆盖各平台；取消跟踪历史上误提交的 `android/zhidu_android.iml` 与 `android/build/reports/problems/problems-report.html`
**2026-11-27**: 阅读字号统一相对化（为字号设置做准备）— 新增设置项底座 `AppSettings.readerFontSize`（默认 21，`SettingsService.readerFontSize` ValueNotifier + `setReaderFontSize()`，暂无 UI），阅读页所有字号均由它推导：正文 `_contentTextStyle`（基准字号 × 行高 1.6）、竖排 `基数×0.86`、底部页码 `正文字号×0.57`、开头页目录条目 `font-size: 0.76em` + 缩进 `1em/级`（改为 em 相对单位，随基准字号缩放，不再写死 16px）；章节列表字号改用 `textTheme.bodyLarge` 派生；阅读页/书架/设置页的固定 `fontSize` 改为主题文本样式（`bodyLarge/bodyMedium/bodySmall/labelSmall/headlineSmall/titleMedium`），仅 `app_theme.dart` 的 textTheme 保留字号定义；`flutter analyze lib` 无告警、425 个测试通过

**2026-11-27**: 修复窗口状态恢复 — ①最大化退出后重进会被还原成普通窗口：Windows runner 首帧回调 `Win32Window::Show()` 原用 `SW_SHOWNORMAL`，会把 Dart 侧已恢复的最大化状态还原，改为 `SW_SHOW`（保持当前状态），并把「先最大化再 `show()`」以避免普通窗口闪现，显示后再确认一次最大化；②最小化退出后重进回到默认位置/尺寸：最小化时 `getBounds()` 返回任务栏图标坐标（尺寸远小于最小值），`_saveWindowState` 改为「最大化/最小化时取最近一次记录的普通窗口矩形，其次沿用上次文件中的尺寸」，并对矩形做可用性校验后才写入；`flutter analyze lib` 无告警、`flutter build windows --debug` 通过

**2026-11-27**: 开头页目录排版 + 详情页进入流畅性 + 窗口状态恢复 — ①`EpubCssEngine.render(html, frontMatter: true)` 只调整目录条目：`_normalizeTocEntries()` 识别「内容全部是链接的块级元素」，字号统一缩到 16px（正文 21px，书籍常用 1.22em 会放大到 25px）、行高 1.8，并把行首空格/`&nbsp;` 换算为 `margin-left`（2 个空白≈16px 一级缩进），同时让 `_applyReaderTypography` 跳过这些条目（否则统一 2em 首行缩进会抹平层级）；版权页等非链接文字保持原样；开头页 rem 按 16px 根字号换算为 px（fwfh 不支持 rem）；②`EpubParser.getChapters()` 改用 `Isolate.run` 后台解析（isolate 内重建解析器，LogService 文件句柄不可跨 isolate 传递），避免进入书籍详情页转场期间解压解析阻塞 UI；`BookScreen` 新增章节内存缓存（`bookId|filePath`）命中即显示，出版信息补充改为章节显示后异步执行；③`main.dart` 窗口状态持久化：退出时把非最大化窗口矩形与最大化标记写入 `Documents/zhidu/window_state.json`（`onWindowResize/onWindowMove` 记录非最大化尺寸），启动时校验坐标仍在任一显示器可见区域内再恢复，最大化在 `show()` 后恢复；`flutter analyze lib` 无告警、425 个测试通过

**2026-11-27**: 全书页码 + 后台一次性分页 — 底部页码由「章节内页码」改为「全书页码」：进入阅读页后 `BookPaginator` 在后台逐章测量分页并缓存，优先级为「当前章 → 下一章/上一章 → 当前章之前的章节（拼出页码前缀）→ 其余」，避免用户长时间等待；新增 `lib/widgets/html_pagination.dart`（`buildHtmlBlocks`/`paginateBlocks`/`HtmlMeasureColumn`）让分页阅读与后台分页共用同一算法与测量列，保证两套页码一致；`PagedReaderController` 新增 `openPages(pages, target)`（直接采用后台页列表、不测量，跨章无白屏等待）、`replacePages`（尺寸变化重排后按页起始块原地换页保持位置）、`reportLayout`+`onLayout`（上报可用几何尺寸）、`bookPaging`（页码前缀未就绪时回退章节内页码）；`ChapterScreen` 接线：`_onReaderLayout` 驱动后台重排在窗口尺寸变化时整体失效重排、`_onPaginatorChanged` 刷新页码/替换可视章节页列表、`_navigateToChapter` 命中缓存直接 `openPages`、`_adoptVisibleChapter` 回填控制器测量结果避免重复测量；修复 `_updating` 通知竞态（章节已切换但页列表未替换时父级读到旧页导致页码前缀错乱）；`reader_flow_test` 改为全书页码断言并新增 `book_paginator_test`，`flutter analyze lib` 无告警、422 个测试通过

**2026-11-27**: 修复跨章回退跳动 + 开头页可回退 — ①`PagedReadingView` 的 `PageView` 改用 `ClampingScrollPhysics`：越界时页面不随拖动位移，跨章瞬间旧页快照与画面位置一致，消除「从章节首页向前翻到前章末页时，原首页在屏幕上跳动一次」；越界改为累计 `OverscrollNotification` 超过 12px 才翻章（同时保留 Bouncing 平台的 `ScrollUpdate` 越界 pixels 判定）；②`ChapterScreen` 新增 `_showingOpening`，把开头页（封面/目录/版权等未列入章节的前置页）作为第一章之前的独立位置：`_onReaderBoundary` 在第一章首页向前翻时经 `_openOpeningPage(lastPage: true)` 回到开头页末页，开头页末页向后翻经 `_navigateToChapter(0)` 进入第一章（不再跳过第一章），开头页首页向前翻无操作；开头页优先复用 `BookScreen` 传入的 `openingContent`，否则按 `getOpeningContent()` 解析（`_switchingChapter` 防重复触发）；③阅读位置语义扩展：`lastChapterIndex = -1` 表示开头页（`progress` 记 0），`BookScreen._startReading()` 区分 `-1`（恢复开头页页码）/`0`（恢复第一章页码）/`>0`（续读该章）/`null`（首次阅读打开开头页）——旧存档中 `0` 原表示开头页，现解释为第一章，属可接受的行为变更；④点击左右 1/3 改由原始指针 down/up 判定（位移 ≤ `kTouchSlop` 才算点击）：HTML 的 `<a>` 会被 fwfh 包上 `GestureDetector` 并在手势竞技场抢走点击，导致目录页（整页链接）点击左右区域完全无法翻页；新增用例「越界拖动时页面不位移」「真实 EPUB 第一章首页向前翻回到开头页末页」「开头页首页向前翻无变化 / 向后翻进入第一章」；删除 3 个临时诊断测试；`flutter analyze lib` 无告警、420 个测试通过
**2026-11-27**: 修复真实运行中的翻页错乱 / 跨章白页 / 首页无法后退 — ①`PagedReadingView` 的当前页层始终包在同一层级的 `SlideTransition` 中（不再按 `exitingBlocks` 有无增删）：否则过渡结束时 PageView 会被重建、滚动位置回到第 0 页，「向前翻章落在上一章末页」实际显示成该章首页，后续翻页基于错误页码跳错章；②旧页过渡层去掉不透明 `ColoredBox(scaffoldBackgroundColor)`：它与阅读区（primary@40）底色不同，滑动时出现白页/异色闪块；两层在滑动中恰好相邻铺满，无需底色；③滑动越界统一判定并修正方向：`OverscrollNotification` 负值=越过开头→上一章、正值=越过末尾→下一章；`BouncingScrollPhysics` 不产生 overscroll 通知，改用 `ScrollUpdateNotification` 的越界 pixels + 12px 阈值判断，修复首页/末页滑动只能回弹；④过渡完成时用 PageView 实际页码校正控制器，防止页码漂移；新增 `test/screens/reader_flow_test.dart`（真实 EPUB + 1280×800 驱动 ChapterScreen，逐项核对 1/22→2/22→1/22→上一章 13/13→1/22，并断言页码指示与 PageView 实际页一致），`flutter analyze lib` 无告警、417 个测试通过
**2026-11-27**: 分页阅读状态收敛重构 — 新增 `lib/widgets/paged_reader_controller.dart`（`PagedReaderController extends ChangeNotifier`）作为单一控制器，持有章节 HTML、块列表、页列表、当前页、待定位目标 `PagedOpenTarget`（首页/末页/指定页/锚点）与跨章过渡动画；`open(html, target)` 表达「打开到某位置」的意图，`turnPage(±1)` 是唯一翻页入口（点击左右 1/3、键盘 ←/→、鼠标滚轮、滑动越界、翻章都走这里），章内翻页与跨章共用同一页列表模型（章节只是页列表的分段，边界经 `onBoundary` 打开相邻章节）；状态收敛为「测量中 `isMeasuring`、定位中 `isPositioning`、过渡中 `exitingBlocks` 非空」三个，删除 `_frozenBlocks`/`_pageViewHidden`/`_crossChapterTriggered`/`_pendingPageIndex` 等互相牵制的标志；`PagedReadingView` 重写为纯视图（渲染页与旧页过渡层、离屏测量列、输入转发），`ChapterScreen` 删除 `_pagedController/_pagedCurrentPage/_pagedTotalPages/_startAtLastPage/_initialAnchor/_positionToken/_initialPagedPage` 及 `_onPagedPageChanged` 双向同步，改为 `_reader.open(...)` + 监听控制器按页保存位置；续读恢复、目录锚点定位、PDF/竖排分支行为不变；分页视图测试按新 API 改写并新增「章首页向前翻落上一章末页」「点击/方向键/滚轮统一入口」「同章 retarget」用例，`flutter analyze lib` 无告警、412 个测试全部通过
**2026-11-27**: 修复跨章滑动过渡引入的翻页跳转错乱 — ①`PagedReadingView.didUpdateWidget(htmlChanged)` 复位 `_slideController.value = 0`：过渡结束后 controller 停在终点值 1.0，下一次切章的旧页快照会按 1.0 渲染（整体平移到屏幕外），新章测量期间白屏、过渡开始时才突然弹回；②快照清理改由 `_slideController.addStatusListener(completed)` 驱动，不再用 `TickerFuture.whenComplete`（动画被 `stop()` 中断时 TickerFuture 永不完成，`_frozenBlocks` 残留会永久盖住新章）；③新增 `_positioning`（=`_pageViewHidden`）输入锁，`_prevPage`/`_nextPage`/`_onScrollNotification` 在定位完成前忽略输入——此时 PageView 以 Opacity(0) 隐藏且页码仍是上一章遗留值，点击会作用于看不见的新页而误跳章；④`ChapterScreen` 新增 `_switchingChapter`，`_navigateToChapter()` 在上一章内容加载完成前忽略新的翻章请求（此前加载期间连点右侧会依据旧章页码再跳一章、跳过整章），由 `_loadChapterContent().whenComplete` 复位；⑤新增回归用例「连续切章时旧页快照仍显示在屏幕内」「切章定位完成前点击右侧不触发跨章」，`flutter analyze lib` 无告警、409 个测试全部通过
**2026-11-26**: 代码审核清理 + 删除 PdfReaderScreen — 删除未被应用流程调用的 `lib/screens/pdf_reader_screen.dart` 及其测试（PDF 阅读实际由 `ChapterScreen` 内置 `PdfDocumentViewBuilder` 处理），同步更新 README、测试计划与 `function_call_relationships*.md`；清理 `ChapterScreen` 恒真分页开关、重复 `HtmlWidget` 构造、`List<dynamic>` 返回值与未使用的 `bookFormat` 参数；`SummaryService`/`AiConfigScreen` 去重；修复 `withOpacity`/`RadioListTile`/`Dropdown value`/`window` 等弃用 API 与 analyzer 告警；精简 models、file_storage、pdf_reader、ai_service 冗余注释并修正过时描述；`flutter analyze lib` 无告警，409 个测试全部通过
**2026-11-26**: 跨章翻页改为滑动过渡 — 此前章节内翻页是 PageView 左右滑动、跨章是整页内容直接替换（无滑动感）。`PagedReadingView` 在 `didUpdateWidget(htmlChanged)` 时把当前显示页冻结为 `_frozenBlocks` 快照（新章测量期间继续显示旧页，不再空白），新章分页稳定后由 `_finalizePosition` 播放 260ms `easeOutCubic` 过渡：旧页向翻章反方向滑出、新章从翻章方向滑入（`_slideDirection`：向后翻=1 从右进、向前翻=-1 从左进），结束后清空快照；新增 `SingleTickerProviderStateMixin` + `_slideController`，单页渲染抽出 `_buildPageContent()` 供分页与快照共用版式；新增用例「切章时保留旧页快照再滑出」。
**2026-11-26**: 移除底部大翻页按钮 + 新增鼠标滚轮翻页 — ①`ChapterScreen` 删除 `<<` / `>>` 大圆按钮及 `_prevPageOrChapter`/`_nextPageOrChapter`/`_isPagedOriginalView`/`_hoverPrev`/`_hoverNext`，`_buildNavigationButtons()` 仅在 PDF 原文保留 `<` / `>` 页码翻页（EPUB 已支持点击左右 1/3、方向键、滑动、滚轮翻页）；②`PagedReadingView` 包裹 `Listener`，`onPointerSignal` 处理 `PointerScrollEvent`：向下滚下一页、向上滚上一页，到边界经 `onPrevChapter`/`onNextChapter` 跨章，180ms 节流避免一次滚动手势连翻多页；测试改为断言 EPUB 无底部按钮。
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
