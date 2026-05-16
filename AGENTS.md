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
│   └── parsers/             # book_format_parser(接口), epub_parser, pdf_parser, format_registry
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
