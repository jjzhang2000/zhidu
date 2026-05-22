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
