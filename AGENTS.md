# AGENTS.md

**项目以简体中文进行交互沟通**

## 智读 (Zhidu) - AI分层阅读器

Flutter跨平台AI智能阅读器，主打"分层阅读"和"知识蒸馏"。通过AI分层解析，实现"先读薄，再读厚"的阅读体验。

### Requirements

- **Flutter SDK**: >=3.0.0 <4.0.0
- **Dart SDK**: >=3.0.0
- **平台支持**: Windows（主要开发）、Android、iOS、macOS、Linux
- **Web限制**: Web平台仅支持演示，无法导入本地EPUB/PDF文件（浏览器沙箱限制）

### Development Commands
- `flutter run` - 运行调试（开发模式）
- `flutter run --release` - 运行生产模式
- `flutter test` - 运行测试
- `flutter analyze` - 静态代码分析
- `flutter pub get` - 安装依赖
- `flutter pub upgrade` - 升级依赖
- `flutter build windows --release` - 构建Windows
- `flutter build apk --release` - 构建Android APK
- `flutter build appbundle --release` - 构建Android App Bundle
- `flutter build ios --release` - 构建iOS
- `flutter build web --release` - 构建Web（功能受限）

### Project Structure
```
lib/
├── main.dart                 # 应用入口，初始化所有Service
├── models/                   # 数据模型
│   ├── app_settings.dart    # 应用设置模型（AI、主题、语言、存储）
│   ├── book.dart            # 书籍模型
│   ├── book_metadata.dart   # 书籍元数据（用于解析阶段）
│   ├── chapter.dart         # 章节模型
│   ├── chapter_content.dart # 章节内容
│   ├── chapter_location.dart # 章节位置
│   └── chapter_summary.dart # 章节摘要
├── screens/                  # UI页面
│   ├── home_screen.dart     # 首页（书架+书籍导入）
│   ├── book_screen.dart # 书籍详情（全书概览）
│   ├── chapter_screen.dart  # 章节摘要页
│   ├── pdf_reader_screen.dart # PDF阅读器
│   ├── ai_config_screen.dart # AI配置页面
│   ├── settings_screen.dart # 设置主页面
│   ├── theme_settings_screen.dart # 主题设置页面
│   ├── language_settings_screen.dart # 语言设置页面

├── services/                 # 业务服务层（单例模式）
│   ├── book_service.dart    # 书籍管理（导入、解析）
│   ├── epub_service.dart    # EPUB文件解析
│   ├── pdf_service.dart     # PDF文件解析
│   ├── ai_service.dart      # AI服务（智谱/通义千问API）
│   ├── ai_prompts.dart      # AI提示词模板（集中管理）
│   ├── summary_service.dart # 摘要生成与管理
│   ├── storage_config.dart  # 存储路径配置
│   ├── file_storage_service.dart # 文件存储服务
│   ├── settings_service.dart # 设置管理服务（AI、主题、语言、存储）
│   ├── log_service.dart     # 日志服务
│   └── parsers/             # 格式解析器
│       ├── book_format_parser.dart # 解析器接口
│       ├── epub_parser.dart # EPUB解析器
│       ├── pdf_parser.dart  # PDF解析器
│       └── format_registry.dart # 格式注册表
└── utils/
    └── app_theme.dart       # 主题配置
```

### Key Dependencies
- **EPUB**: `epub_plus`（EPUB解析）、`archive`（ZIP解压）、`xml`（XML解析）、`image`
- **PDF**: `pdf`（PDF渲染）、`sync_pdf_renderer`
- **UI**: `flutter_html`（HTML渲染）、`markdown`
- **文件**: `file_picker`（文件选择）、`path_provider`、`path`
- **网络**: `http`（AI API调用）
- **工具**: `uuid`（ID生成）、`intl`（国际化）

### Architecture Notes
- **状态管理**: 使用StatefulWidget + Service单例 + ValueNotifier响应式更新，无Riverpod/Provider
- **存储方案**: 文件存储（JSON + Markdown），数据存储在 Documents/zhidu/ 目录
  - Windows: `C:\Users\{username}\Documents\zhidu\`
  - macOS: `/Users/{username}/Documents/zhidu/`
  - Android: `/storage/emulated/0/Documents/zhidu/` 或应用私有目录
  - iOS: `/var/mobile/Containers/Data/Application/{uuid}/Documents/zhidu/`
- **文件结构**:
  - `settings.json` - 应用设置（AI、主题、语言、存储设置）
  - `books_index.json` - 书籍索引
  - `books/{bookId}/metadata.json` - 书籍元数据
  - `books/{bookId}/summary-zh.md` - 全书摘要
  - `books/{bookId}/Summary-{index}-{lang}.md` - 章节摘要
  - `books/{bookId}/cover.jpg/png` - 封面图片
- **Service初始化**: 所有Service在`main.dart`中顺序初始化
- **AI配置**: 通过SettingsService集中管理，兼容旧版`ai_config.json`格式

### Settings Service Architecture
- **统一设置管理**: SettingsService管理AI、主题、语言、存储四大类设置
- **响应式更新**: 使用ValueNotifier实现设置变更的实时响应
- **设置持久化**: 所有设置保存到settings.json文件
- **兼容性**: 支持从旧版ai_config.json格式迁移配置

### AI Service Configuration
项目现在通过SettingsService统一管理AI配置，同时兼容旧版`ai_config.json`格式：
```json
{
  "ai_provider": "qwen",
  "qwen": {
    "api_key": "YOUR_API_KEY",
    "model": "qwen-plus",
    "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1"
  },
  "savedAiConfigs": {
    "qwen": { "provider": "qwen", "apiKey": "...", "model": "qwen-plus", "baseUrl": "..." },
    "deepseek": { "provider": "deepseek", "apiKey": "...", "model": "deepseek-chat", "baseUrl": "..." }
  }
}
```
- **支持的AI提供商**:
  | 提供商 | 类型 | 需要API Key | 默认Base URL |
  |--------|------|-------------|--------------|
  | 智谱 (zhipu) | 云服务 | ✓ | `https://open.bigmodel.cn/api/paas/v4` |
  | 通义千问 (qwen) | 云服务 | ✓ | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
  | DeepSeek (deepseek) | 云服务 | ✓ | `https://api.deepseek.com/v1` |
  | MiniMax (minimax) | 云服务 | ✓ | `https://api.minimaxi.com/v1` |
  | Ollama (ollama) | 本地部署 | ✗ | `http://localhost:11434/v1` |
  | LM Studio (lmstudio) | 本地部署 | ✗ | `http://localhost:1234/v1` |
- **API Key有效性检查**: 不能为空，不能为占位符字符串(`YOUR_*_HERE`)
- **多配置保存**: `savedAiConfigs` 保存所有曾经配置过的提供商配置，按 provider 分组
- **自动迁移**: 启动时自动将当前有效的 aiSettings 添加到 savedAiConfigs
- **通过SettingsService可动态更新配置**

### Format Parser Architecture
- **设计模式**: 注册表模式（FormatRegistry）
- **接口**: BookFormatParser - 定义解析器接口
- **实现**: EpubParser、PdfParser
- **注册**: 在 main.dart 中通过 FormatRegistry.register() 注册
- **扩展**: 新增格式只需实现 BookFormatParser 接口并注册

### EPUB Parsing Strategy
- **按需提取**: 使用epub_plus库解析EPUB文件结构
- **目录解析**: 优先从OPF/Toc识别章节结构
- **内容提取**: 通过XML解析提取HTML正文
- **回退机制**: 当标准解析失败时，使用archive直接解析ZIP结构

### PDF Parsing Strategy
- **智能识别**: 自动识别章节标题（中文/英文编号格式）
- **封面跳过**: 自动跳过封面页（文本少于50字符的首页）
- **分页渲染**: 使用pdf库分页渲染内容

### Data Flow
```
文件导入 → 解析（EPUB/PDF） → AI分析 → 展示 → 存储（文件系统） → 导出（Markdown）
```

### Code Quality
- **Lint规则**: 使用`flutter_lints`，启用`prefer_single_quotes`
- **排除文件**: `**/*.g.dart`, `**/*.freezed.dart`
- **打印语句**: `avoid_print: false`（允许debug print）
- **国际化**: 避免硬编码文本，使用`AppLocalizations.of(context)`获取本地化文本

### Git Ignore（重要）
确保`.gitignore`包含以下内容：
```
# 配置文件（包含敏感信息）
ai_config.json

# 生成/运行时目录
/Summaries/
/SectionSummaries/
/Covers/
/logs/
/ReviewCards/
/temp_docs/

# 生成文件
*.log
*.iml
.flutter-plugins
.flutter-plugins-dependencies
```

### Important Files
- `settings.json` - 应用设置（AI、主题、语言、存储配置）
- `Requirement.md` - 产品需求文档
- `Technical_Plan.md` - 技术方案文档
- `docs/code-review/` - 代码审查报告

### Development Notes
- 修改Service后需重启应用（热重载对Service单例不完全生效）
- AI调用是异步的，注意处理loading状态
- EPUB解析复杂，涉及XML命名空间处理
- PDF解析需要注意封面页检测
- 设置变更通过ValueNotifier实现响应式更新

### Troubleshooting
- **EPUB无法解析**: 检查文件编码是否为UTF-8，尝试重新导入
- **PDF无法解析**: 检查PDF是否加密或损坏
- **AI无响应**: 检查SettingsService中的AI配置是否正确，API Key是否有效
- **Service找不到**: 修改Service后需完全重启应用，热重载不生效
- **设置未生效**: 检查ValueNotifier监听器是否正确绑定
- **存储路径问题**: 检查 Documents 目录是否存在且有写入权限

### Internationalization (国际化)

**实现方式**：
- 使用Flutter官方国际化方案：flutter_localizations 和 intl 包
- ARB (Application Resource Bundle) 文件格式存储翻译
- 自动生成本地化代码：`flutter gen-l10n`
- 支持多语言：简体中文、英语、日语

**文件结构**：
- `lib/l10n/` - 国际化资源文件目录
  - `app_zh.arb` - 中文翻译资源
  - `app_en.arb` - 英文翻译资源  
  - `app_ja.arb` - 日文翻译资源
  - `app_localizations.dart` - 自动生成的本地化代码

**实现要点**：
- 在需要国际化的Widget中使用 `AppLocalizations.of(context)`
- 为动态内容使用参数化消息（如 `helloName(String name)`）
- 保持一致的翻译键命名规范
- 测试各种语言环境下的UI适应性

**已国际化模块**：
- AI设置页面（提供商名称、按钮文本、标签等）
- 主题设置页面（选项标题、说明文字等）
- 语言设置页面（选项标题、说明文字等）
- 设置主页面（各项设置标题等）
- 首页（提示信息等）

#### 2026-04-09: 章节摘要无法显示问题

**问题描述**：用户点击章节后显示"暂无章节摘要"，无法生成摘要。

**根本原因**：ChapterListScreen在`_chapterSummaries.isEmpty`时只显示"暂无章节摘要"文本，用户**根本无法进入阅读界面**。这是一个死循环。

**正确的分析方法**：
1. **从完整用户流程入手**：用户从首页 → 书籍详情 → 章节列表 → 阅读界面，每一步都要验证
2. **不要想当然**：不要假设某个界面/功能一定可用，要验证
3. **日志是最好的线索**：如果某段代码的日志没有出现，说明那段代码根本没执行
4. **全局观至关重要**：不要只盯着局部代码修复，要看整个流程是否通畅

**修复方案**：让ChapterListScreen始终显示章节列表，即使没有摘要。用户点击章节后可以进入阅读界面，在阅读界面生成摘要。

#### 2026-04-14: 代码审查和清理

**清理内容**：
- 删除未使用的服务：SectionSummaryService（734行）
- 删除未使用的模型：BookSummary（199行）、SectionSummary（163行）
- 删除未使用的方法：BookMetadata.toJson/fromJson、ChapterSummary.copyWith
- 删除空的FormatRegistry.initialize()方法
- 删除临时调试文件和运行时数据目录
- 更新.gitignore

**总计删除**：约853行代码

**教训**：
- 定期进行代码审查，清理死代码
- 保持.gitignore与项目实际需要同步
- 临时文件和运行时数据不应提交到版本控制

#### 2026-04-15: 设置管理重构

**改进内容**：
- 统一设置管理：创建SettingsService管理AI、主题、语言、存储四大类设置
- 响应式更新：使用ValueNotifier实现设置变更的实时响应
- 配置持久化：所有设置保存到settings.json文件
- 向后兼容：支持从旧版ai_config.json格式迁移配置
- 模块化设计：各设置类别独立管理但统一协调

**优势**：
- 集中管理：所有应用设置在一个地方处理
- 实时响应：设置变更立即反映在UI上
- 易于维护：设置逻辑集中，便于扩展和修改
- 数据安全：设置文件集中管理，便于备份和恢复

#### 2026-04-20: 国际化功能实现

**实现内容**：
- 为AI设置、主题设置、语言设置等页面添加国际化支持
- 添加简体中文、英语、日语三种语言翻译
- 修复所有硬编码文本，替换为本地化文本
- 重构组件结构以支持AppLocalizations参数传递

**技术要点**：
- 使用AppLocalizations.of(context)获取本地化文本
- 重构UI组件以接受localizations参数
- 为动态内容添加参数化消息支持
- 重新生成国际化代码并验证所有界面正确显示

---

#### 2026-04-24: 流式显示功能实现

**功能描述**：
实现AI摘要生成过程中的实时流式显示，让用户无需等待完整结果，即可看到AI逐步生成内容的过程。

**核心实现**：

**1. AI服务层 (`ai_service.dart`)**
- 添加 `generateFullChapterSummaryStream` 方法：流式生成章节摘要
- 添加 `generateBookSummaryStream` 方法：流式生成基于章节摘要的全书摘要
- 添加 `generateBookSummaryFromPrefaceStream` 方法：流式生成基于前言的全书摘要
- 使用 `dart:io` 的原生 `HttpClient` 实现真正的流式请求，避免Flutter http包的缓冲问题
- SSE数据解析优化：正确处理被分割的数据块，支持增量式JSON解析

**2. 摘要服务层 (`summary_service.dart`)**
- 添加流式回调广播机制：
  - `_streamingCallbacks` / `_bookStreamingCallbacks`：章节/全书摘要回调映射
  - `registerStreamingCallback` / `registerBookStreamingCallback`：注册流式回调
  - `unregisterStreamingCallback` / `unregisterBookStreamingCallback`：取消注册
  - `_notifyStreamingContent` / `_notifyBookStreamingContent`：触发回调
- 修改 `generateSingleSummary`：内部使用流式方法，支持实时回调
- 修改 `_generateBookSummaryFromPreface`：使用流式方法
- 修改 `_generateBookSummaryFromChapters`：使用流式方法
- 修复标题移除逻辑：支持 `## 第X章：xxx` 等多种标题格式

**3. UI层 - ChapterScreen (`chapter_screen.dart`)**
- 添加 `_streamingSummary` 状态：存储流式内容
- 修改 `_loadSummary`：注册流式回调，实时显示生成内容
- 修改 `_buildBody`：生成中时显示流式内容而非静态加载
- 修复 `_buildNormalSummaryView`：使用 `_title` 而非固定"本章摘要"
- 添加防重复机制：`_hasLoadedSummary` 和 `_listeningChapterKey`

**4. UI层 - BookScreen (`book_screen.dart`)**
- 添加 `_streamingBookSummary` 状态：存储流式全书摘要
- 在 `initState` 中注册全书摘要流式回调
- 在 `dispose` 中取消回调注册
- 修改 `_buildAIIntroductionContent`：优先显示流式内容
- 添加 `_buildStreamingBookSummary` 方法：构建流式视图
- 修改 `_refreshBookIfNeeded`：检测到全书摘要变化后清空流式状态
- 修改标题栏：流式期间显示"AI正在生成摘要..."

**数据流**：
```
用户触发生成
    ↓
调用流式方法 (AIService._callAIStream)
    ↓
HttpClient 发送请求并监听 SSE 数据流
    ↓
每个 chunk 到达 → yield 内容片段
    ↓
SummaryService 累积内容并触发回调
    ↓
_notifyStreamingContent 调用 UI 回调
    ↓
UI setState 更新 _streamingSummary
    ↓
_buildBody / _buildAIIntroductionContent 显示流式内容
    ↓
生成完成 → 保存到文件 → BookService 更新 book.aiIntroduction
    ↓
_refreshTimer 检测变化 → 清空 _streamingSummary → 显示最终摘要
```

**关键技术点**：

**SSE数据处理**：
```dart
// 缓冲区处理，支持被分割的数据块
String buffer = '';
await for (final chunk in response.transform(utf8.decoder)) {
  buffer += chunk;
  while (buffer.contains('\n')) {
    // 提取完整行并解析
  }
}
```

**防重复生成**：
```dart
// UI层防止重复监听
if (_hasLoadedSummary && _listeningChapterKey == chapterKey) return;

// 服务层防止重复生成
if (_generatingKeys.contains(key)) return false;
```

**章节切换保护**：
```dart
// 使用闭包捕获当前章节信息
final capturedBookId = widget.bookId;
final capturedChapterIndex = widget.chapterIndex;
generatingFuture.then((_) {
  if (capturedBookId != widget.bookId) return; // 已切换章节，忽略
  // 处理完成逻辑
});
```

**标题移除正则**：
```dart
// 匹配多种标题格式
final titlePattern = RegExp(
  r'^##\s*(章节标题[：:]\s*.+|第[一二三四五六七八九十0-9]+章[：:]\s*.+|前言|序言|引言|序|跋|后记|附录.*)$'
);
```

**用户体验优化**：
- 生成中显示动画指示器（蓝色圆点跳动）
- 标题动态切换：生成中"AI正在生成摘要..." → 完成"内容介绍"
- 流式内容与最终摘要无缝切换
- 章节切换时自动清理旧回调，避免内存泄漏

**注意事项**：
- 流式生成依赖 AI API 的 SSE (Server-Sent Events) 支持
- 智谱和通义千问均支持流式响应
- 网络延迟可能影响流式体验（每字符约70-80ms）
- 应用完全重启才能生效（Service单例在热重载时可能保持旧状态）

---

#### 2026-04-26: UI垂直Tab布局改进

**功能描述**：
将原有的切换按钮改为垂直Tab布局，提升用户界面的易用性和美观度。

**核心实现**：

**1. BookScreen (`book_screen.dart`)**
- 引入 `TabController` 管理垂直Tab切换
- 实现 `TickerViewStateMixin` 以支持Tab控制器动画
- 创建 `_buildVerticalTab` 方法构建垂直Tab按钮
- 将原先的左右布局改为左列垂直Tab + 右侧内容区域布局
- 优化颜色层级：选中Tab使用主题色背景，未选中Tab使用灰色背景
- 保持与右侧内容区域相同的背景色

**2. ChapterScreen (`chapter_screen.dart`)**
- 引入 `TabController` 管理垂直Tab切换
- 实现 `TickerViewStateMixin` 以支持Tab控制器动画
- 创建 `_buildVerticalTab` 方法构建垂直Tab按钮
- 将原先的左右布局改为左列垂直Tab + 右侧内容区域布局
- 优化颜色层级：选中Tab使用主题色背景，未选中Tab使用灰色背景
- 保持与右侧内容区域相同的背景色
- 更新内容长度检查逻辑，内容过短时自动切换到原文视图

**UI布局结构**：
```
Row
├── Column (垂直Tab栏)
│   ├── Summary Tab (auto_awesome icon)
│   ├── Divider
│   └── Chapters/Original Text Tab (format_list_numbered/menu_book icon)
└── Expanded (TabBarView内容区)
    ├── Summary Content
    └── Chapter/Original Content
```

**用户体验优化**：
- 更直观的Tab切换体验
- 一致的视觉设计语言
- 无障碍访问支持
- 响应式布局适配不同屏幕尺寸

**注意事项**：
- Tab控制器需要在 `initState` 中初始化并在 `dispose` 中释放
- 需要正确处理Tab切换事件和状态更新
- 要考虑禁用状态下Tab的视觉表现

---

#### 2026-05-05: 窗口DPI双重缩放修复

**问题描述**：
应用启动时窗口尺寸远大于屏幕，部分内容超出屏幕可见区域，窗口位置偏移。

**根本原因**：
`windows/runner/main.cpp` 中存在 **DPI 双重缩放** 问题：
1. `SystemParametersInfo(SPI_GETWORKAREA, ...)` 对于 PerMonitorV2 DPI 感知应用返回**物理像素**值
2. 但 `Win32Window::Create()` 期望接收**逻辑像素**值，并会在内部再乘以 DPI 缩放因子
3. 结果：物理像素值被再次缩放 → 窗口尺寸远大于预期，部分超出屏幕

例如在 150% DPI 缩放的屏幕上：
- 工作区物理像素：1920×1040
- `Create()` 再乘以 1.5 → 变成 2880×1560，远超屏幕！

**修复方案**（双重保障）：

**1. C++ 层修复 (`windows/runner/main.cpp`)**
- 添加 `#include <flutter_windows.h>`
- 使用 `FlutterDesktopGetDpiForMonitor()` 获取主显示器 DPI 缩放因子
- 将 `SystemParametersInfo` 返回的物理像素**除以缩放因子**转换为逻辑像素
- 再传给 `Create()` 时就不会被双重缩放

```cpp
// 修复前（错误）：
LONG screenWidth = workArea.right - workArea.left;  // 物理像素

// 修复后（正确）：
HMONITOR primaryMonitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTONEAREST);
UINT dpi = FlutterDesktopGetDpiForMonitor(primaryMonitor);
double scale_factor = dpi / 96.0;
LONG screenWidth = static_cast<LONG>((workArea.right - workArea.left) / scale_factor);  // 逻辑像素
```

**2. Dart 层修复 (`lib/main.dart`)**
- 引入 `screen_retriever` 包获取屏幕实际可用尺寸（含 `visibleSize` 排除任务栏）
- 使用 `windowManager.waitUntilReadyToShow()` 阻止窗口在设置好之前闪现
- 根据屏幕尺寸计算窗口大小（高度=屏幕高，宽度=高度×0.75）
- 调用 `windowManager.setSize()` + `center()` + `show()` 精确控制
- 添加异常回退：获取屏幕信息失败时使用默认 960×720

**3. 依赖更新 (`pubspec.yaml`)**
- 新增 `screen_retriever: ^0.2.0` 直接依赖

**窗口初始化流程**：
```
应用启动
    ↓
C++ main.cpp: 创建窗口（DPI修正后的逻辑像素）
    ↓
Dart main(): windowManager.ensureInitialized()
    ↓
windowManager.waitUntilReadyToShow()  // 阻止窗口闪现
    ↓
screenRetriever.getPrimaryDisplay()  // 获取屏幕实际尺寸
    ↓
计算窗口大小 (高度=屏幕高, 宽度=高度×0.75)
    ↓
windowManager.setSize() + center()  // 精确设置尺寸和位置
    ↓
windowManager.setMinimumSize(600, 400)
    ↓
windowManager.show()  // 设置完成后才显示
```

**教训**：
- Windows PerMonitorV2 DPI 感知应用中，`SystemParametersInfo` 返回物理像素，需要手动转换
- `Win32Window::Create()` 内部会做 DPI 缩放，传入的应该是逻辑像素
- 双层保障（C++ + Dart）比单层更稳健，Dart 层的 `window_manager` 可以覆盖所有桌面平台

#### 2026-05-11: 多显示器 DPI 窗口定位修复

**问题描述**：
在多个不同分辨率和 DPI 缩放比例的显示器环境中，程序在主显示器上启动位置正确，但在副显示器上启动时出现在屏幕角落，且无法用鼠标拖动窗口。

**根本原因**（三个重叠问题）：

1. **`SystemParametersInfo(SPI_GETWORKAREA)` 只返回主显示器信息**
   - 该 API 返回的是**主显示器**的工作区，不包括副显示器的位置和尺寸
   - 多显示器时，窗口所在显示器的实际坐标系统与计算出的坐标不一致

2. **`MonitorFromPoint({0,0})` 定位错误**
   - 在多显示器布局中，主显示器不一定在虚拟桌面坐标 (0,0) 位置
   - 使用 (0,0) 点查找显示器 DPI，可能返回错误的显示器（导致 DPI 比例错误）

3. **Dart 层 `getPrimaryDisplay()` 只取主显示器**
   - `screenRetriever.getPrimaryDisplay()` 永远返回主显示器信息
   - 在副显示器上打开时，窗口被错误地定位到基于主显示器计算出的坐标

**结果**：窗口出现在屏幕角落（甚至超出可见区域），因为所有坐标计算都基于错误的显示器和错误的 DPI 比例。

**修复方案**（双层修复）：

**1. C++ 层简化 (`windows/runner/main.cpp`)**
- 移除所有复杂的 DPI/显示器计算代码
- C++ 层只创建默认大小窗口 (960×720, origin 0,0)
- 将多显示器定位和尺寸调整全部交给 Dart 层处理
- 移除 `#include <flutter_windows.h>` 依赖

```cpp
// 修复后（简化）：
// C++ 层不再做复杂的显示器/DPI 计算
// Dart 层的 window_manager + screen_retriever 处理所有定位
FlutterWindow window(project);
Win32Window::Point origin(0, 0);
Win32Window::Size size(960, 720);
if (!window.Create(L"智读", origin, size)) { ... }
```

**2. Dart 层修复 (`lib/main.dart`)**
- 使用 `screenRetriever.getAllDisplays()` 获取**所有**显示器
- 使用 `windowManager.getBounds()` 获取窗口当前实际位置
- 通过窗口中心点坐标匹配找到窗口实际所在的显示器
- 基于找到的**目标显示器**计算窗口尺寸和居中位置
- 使用 `windowManager.setBounds()` 精确设置窗口位置和尺寸

```dart
// 核心逻辑：
final displays = await screenRetriever.getAllDisplays();
final windowBounds = await windowManager.getBounds();

// 找到窗口中心所在的显示器
final windowCenterX = windowBounds.x + windowBounds.width / 2;
final windowCenterY = windowBounds.y + windowBounds.height / 2;

Display targetDisplay = displays.first;
for (final display in displays) {
  final displayLeft = display.visiblePosition?.dx ?? 0;
  final displayTop = display.visiblePosition?.dy ?? 0;
  final displayRight = displayLeft + display.size.width;
  final displayBottom = displayTop + display.size.height;
  if (windowCenterX >= displayLeft && ...) {
    targetDisplay = display;
    break;
  }
}

// 基于目标显示器计算窗口位置
final displayPos = targetDisplay.visiblePosition ?? const Offset(0, 0);
final visibleSize = targetDisplay.visibleSize ?? targetDisplay.size;

double windowHeight = visibleSize.height;
double windowWidth = windowHeight * 0.75;

final double windowLeft = displayPos.dx + (visibleSize.width - windowWidth) / 2;
final double windowTop = displayPos.dy + (visibleSize.height - windowHeight) / 2;

await windowManager.setBounds(Rect.fromLTWH(windowLeft, windowTop, windowWidth, windowHeight));
```

**screen_retriever Display 字段说明**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `visiblePosition` | `Offset?` | 工作区在虚拟桌面上的位置 (逻辑像素) |
| `visibleSize` | `Size?` | 工作区尺寸 (逻辑像素，排除任务栏) |
| `size` | `Size` | 显示器总分辨率 (逻辑像素) |
| `scaleFactor` | `num?` | DPI 缩放因子 |

**修复后流程**：
```
应用启动
    ↓
C++ main.cpp: 创建默认窗口 (960×720, pos 0,0)
    ↓
Dart _initWindowManager():
    ↓
screenRetriever.getAllDisplays()  → 获取所有显示器信息
    ↓
windowManager.getBounds()  → 获取窗口当前实际位置
    ↓
通过窗口中心点匹配 → 找到目标显示器
    ↓
基于目标显示器的工作区 → 计算窗口尺寸和居中位置
    ↓
windowManager.setBounds()  → 精确设置位置和尺寸
    ↓
windowManager.setMinimumSize(600, 400) → show()
```

**关键教训**：
- `SystemParametersInfo(SPI_GETWORKAREA)` 在多显示器场景下不可靠，只返回主显示器数据
- 多显示器 DPI 适配应在 Dart 层处理（更灵活、可跨平台）
- 使用 `getAllDisplays()` + 窗口中心点匹配来定位正确的显示器
- C++ 层保持简单，将复杂的显示器逻辑交给上层的 `window_manager` + `screen_retriever`

#### 2026-05-14: 多平台构建与兼容性修复

**问题描述**：
1. Android构建时Gradle卡在NDK依赖下载，多个插件（`jni`、`pdfrx`）要求不同版本的NDK
2. 升级到 `pdfrx 2.3.3` 后API变更导致编译错误
3. `window_manager` 和 `screen_retriever` 在Android模拟器上抛出 `MissingPluginException`
4. Android日志服务使用 `Directory.current.path` 导致无权限写入

**修复方案**：

**1. NDK版本统一**
- 升级 `pdfrx`: `^1.3.5` → `^2.3.3`（不再强制要求特定NDK版本）
- 同步升级 `archive`: `^3.4.10` → `^4.0.9`（pdfrx 2.x的依赖要求）
- 统一使用已安装的 NDK 30.0.14904198

**2. pdfrx API兼容性修复**
- `PdfPageRawText?` 可能为null → 使用 `pageText?.fullText ?? ''` 安全访问
- `backgroundColor` 参数从 `Color` 改为 `int` → `0xFFFFFFFF`
- `PdfImage.format` getter被移除 → pdfrx 2.x 固定返回 RGBA 格式，移除格式分支判断
- 修复文件：`lib/services/parsers/pdf_parser.dart`、`lib/services/pdf_service.dart`

**3. 跨平台窗口管理**
- 创建 `lib/utils/window_utils.dart` 统一处理窗口初始化
- 使用 `isDesktopPlatform()` 运行时检测（基于 `Platform.isWindows/MacOS/Linux`）
- 在非桌面平台上直接返回，不调用 `window_manager` 方法
- 关键：虽然Android会导入 `window_manager` 包，但运行时检查确保不会执行相关代码

**4. 日志路径修复**
- 使用 `path_provider` 的 `getApplicationDocumentsDirectory()` 替代 `Directory.current.path`
- 在Android上正确写入应用文档目录，避免权限错误

**依赖变更 (`pubspec.yaml`)**：
```yaml
pdfrx: ^2.3.3      # 之前: ^1.3.5
archive: ^4.0.9    # 之前: ^3.4.10
```

**关键教训**：
- 桌面平台专用插件（如 `window_manager`）在移动端编译时会通过，但运行时会崩溃
- 使用运行时平台检测（`Platform.is*`）比条件导入更简单可靠（`dart.library.io` 在Android上也是true，无法区分桌面和移动）
- 升级第三方库前先用 `flutter pub outdated` 检查依赖冲突

#### 2026-05-15: AI配置类重构 - 删除重复的AIConfig

**问题描述**：
- `AIConfig`（ai_service.dart）和 `AiSettings`（app_settings.dart）功能完全重复
- `AIConfig.isValid` 内部创建 `AiSettings` 实例来验证，属于间接验证
- 两份代码维护相同字段，增加维护成本

**重构方案**：
- 删除 `AIConfig` 类（117 行代码）
- `AIService._config` 从 `AIConfig?` 改为 `AiSettings?`
- `reloadConfig()` 和 `updateConfig()` 直接使用 `AiSettings` 实例
- 保留 `AiSettings` 作为唯一的 AI 配置数据模型

**AiSettings 设计优势**：
- 统一设置管理架构的一部分（与 ThemeSettings、LanguageSettings 并列）
- 内置 `requiresApiKey` 属性，支持动态扩展本地模型
- 通用占位符检测：`startsWith('YOUR_') && endsWith('_HERE')`

**关键教训**：
- 当两个类功能重复时，应尽早合并，避免维护成本翻倍
- 如果一个类的 isValid 方法需要创建另一个类的实例来验证，说明设计有冗余

#### 2026-05-15: SettingsService 死代码清理

**问题描述**：
- `SettingsService` 公开 API 共 24 个方法/属性，其中 13 个未被外部调用
- 7 个方法完全无代码调用（仅文档提及）
- 2 组方法功能重复
- `dispose()` 从未被调用，存在 ValueNotifier 内存泄漏风险

**清理内容**：

**1. 删除的未使用方法（7 个）**：
| 方法 | 说明 |
|------|------|
| `resetToDefaults()` | 无任何代码调用 |
| `exportToJson()` | 无任何代码调用 |
| `importFromJson()` | 无调用，与 `updateAllSettings()` 功能重叠 |
| `toAiConfigJson()` | 旧版 ai_config.json 兼容层，AIService 已改用 `settings.aiSettings` |
| `importFromAiConfigJson()` | 同上，旧版兼容层不再需要 |
| `updateAllSettings()` | 无调用，功能与 `importFromJson()` 重叠 |
| `isAiConfigured` getter | AIService 已有独立 `isConfigured` getter |

**2. 删除的未使用 getter（2 个）**：
- `savedAiConfigs` — 外部通过 `.settings.savedAiConfigs` 访问
- `settingsFilePath` — 仅内部使用

**3. 改为 private 的方法（2 个）**：
- `saveAiConfigForProvider` → `_saveAiConfigForProvider`（仅 `updateAiSettings` 内部调用）
- `updateThemeSettings` → `_updateThemeSettings`（仅 `setThemeMode` 内部调用）

**4. 修复内存泄漏**：
- 在 [main.dart](file:///d:/Projects/zhidu/lib/main.dart#L78) 的 `ZhiduApp.dispose()` 中添加 `_settingsService.dispose()` 调用

**重构结果**：
- 代码量：**378 行 → 217 行**（减少 43%）
- 公开 API：**22 个 → 13 个**
- `flutter analyze lib/` 无新增错误

**关键教训**：
- 随着架构演进，早期预留的"兼容层"方法会变成死代码
- 严格遵守"外部调用则保留 public，仅内部使用则 private"的原则
- 单例 Service 的 `dispose()` 需要在应用退出时显式调用

#### 2026-05-15: 存储层清理 - 消除重复目录创建逻辑

**问题描述**：
- `FileStorageService.exists()` 未被外部调用，各 service 直接使用 `File(path).exists()`
- `StorageConfig.getCoverPath()` 未被外部调用，封面逻辑使用的是 `getCoverSavePath()`
- `SettingsService.init()` 和 `StorageConfig.getAppDirectory()` 各自独立创建 `Documents/zhidu/` 目录，存在重复逻辑

**清理内容**：

**1. 删除未使用方法（2 个）**：
- `FileStorageService.exists()` — 仅是一行 `File(path).exists()` 的包装，调用方直接使用 dart:io
- `StorageConfig.getCoverPath()` — 被 `getCoverSavePath()` 替代

**2. 消除目录创建重复**：
- [SettingsService.init()](file:///d:/Projects/zhidu/lib/services/settings_service.dart#L75-L78) 原先独立调用 `getApplicationDocumentsDirectory()` + 创建 `zhidu/` 目录
- 改为直接调用 `StorageConfig.getAppDirectory()`，统一使用同一份目录创建逻辑
- 删除 `SettingsService` 中对 `path_provider` 包的直接依赖
- 新增 `import 'storage_config.dart'`

**重构结果**：
- `file_storage_service.dart`：406 行 → 384 行
- `storage_config.dart`：266 行 → 238 行
- `settings_service.dart` 减少了对 `path_provider` 的直接依赖
- `Documents/zhidu/` 目录创建逻辑现在只有一份代码

**关键教训**：
- 工具类之间的重复逻辑要尽早识别和合并，避免出现不一致
- "仅有一行包装"的 public 方法不值得存在，除非它封装了复杂的业务规则
- 同层 service 之间可以依赖，但要保持单向依赖（SettingsService → StorageConfig）

#### 2026-05-15: 版本号动态获取 - 消除硬编码

**问题描述**：
- [settings_screen.dart](file:///d:/Projects/zhidu/lib/screens/settings_screen.dart#L195) 中版本号硬编码为 `'0.1.0'`
- 修改 `pubspec.yaml` 的 `version` 字段后，设置页面不会同步更新

**修复方案**：
- 添加 `package_info_plus: ^9.0.1` 依赖
- 在 `_SettingsScreenState.initState()` 中异步加载版本号
- 使用 `PackageInfo.fromPlatform()` 获取 `version` 字段（自动读取 `pubspec.yaml`）
- 同步更新 SDK 约束 `>=3.0.0` → `>=3.6.0`（匹配实际环境 Dart 3.11.5）

**代码变更**：
```dart
// 修复前：
subtitle: Text('${loc.version} 0.1.0'),

// 修复后：
String _version = '';
Future<void> _loadVersion() async {
  final info = await PackageInfo.fromPlatform();
  if (mounted) setState(() { _version = info.version; });
}
subtitle: Text('${loc.version} $_version'),
```

**关键教训**：
- 版本号应该从 `pubspec.yaml` 单一来源读取，避免硬编码
- `package_info_plus` 是 Flutter 标准的版本信息获取方案
- SDK 约束应与实际安装的 Dart/Flutter 版本保持一致

#### 2026-05-15: 统一 JSON 写入逻辑

**问题描述**：
- `SettingsService._saveSettings()` 自己实现 JSON 序列化+写文件（`jsonEncode` + `File.writeAsString`），输出压缩格式
- `FileStorageService.writeJson()` 也做同样的事，但使用 2 空格缩进格式化
- 两处代码功能重复，且 `settings.json` 无法享用格式化输出

**修复方案**：
- `SettingsService._saveSettings()` 内部改为委托 `FileStorageService().writeJson()`
- 删除原有 `jsonEncode` + `File.writeAsString` 的手动序列化逻辑
- 新增 `import 'file_storage_service.dart'`

```dart
// 修复前（8 行，紧凑格式）：
Future<void> _saveSettings() async {
  if (_settingsFilePath == null) return;
  try {
    final file = File(_settingsFilePath!);
    final content = jsonEncode(_settings.toJson());
    await file.writeAsString(content);
    _log.d(...);
  } catch (e, stackTrace) {
    _log.e(...);
    rethrow;
  }
}

// 修复后（3 行，委托 FileStorageService，2 空格缩进格式化）：
Future<void> _saveSettings() async {
  if (_settingsFilePath == null) return;
  await FileStorageService().writeJson(_settingsFilePath!, _settings.toJson());
}
```

**关键教训**：
- 同一层 service 之间的 JSON 写入逻辑要复用，不要各写一套
- `FileStorageService` 是文件 I/O 的唯一入口，其他 service 不应绕过它直接操作文件
- 格式统一（2 空格缩进）能确保所有 JSON 配置文件可读一致

#### 2026-05-15: 章节摘要文件名模板修改 - 避免与译文重名

**问题描述**：
- `getChapterSummaryPath` 生成 `chapter-{index}-{lang}.md`
- `getChapterTranslationPath` 生成 `chapter-{index}-{lang}.html`
- 两者仅扩展名不同，在同一目录下容易混淆

**修复方案**：
- `getChapterSummaryPath` 文件名模板改为 `Summary-{index}-{lang}.md`
- 同步更新 `summary_service.dart` 中 `getSummariesForBook` 的文件扫描匹配规则
- 修复 `getChapterTranslationPath` 文档注释中的扩展名错误（`.md` → `.html`）
- 更新 `storage_config.dart` 目录结构图

**文件名变更**：
```
修复前：chapter-001-zh.md    chapter-001-en.md
修复后：Summary-001-zh.md    Summary-001-en.md

译文不变：chapter-001-en.html  chapter-001-ja.html
```

**关键教训**：
- 不同类型文件的命名模板应有明确区分（语义前缀 vs 格式后缀）
- 注释文档应保持与实际代码一致，避免产生误导

#### 2026-05-16: AIService 代码清理与重构

**改进内容**：

**1. 删除韩语（ko）支持代码**：
- `_detectSystemLanguage()` 中删除韩语 locale 检测分支
- `detectLanguageFromContent()` 中删除韩文字符检测（`koreanChars`）及相关逻辑
- `_getLanguageInstructionForLanguage()` 中删除韩语 case
- `convertLanguageCodeToStandard()` 中删除 `'kor': 'ko'` 映射
- `getTargetLanguage()` 返回值注释更新，移除 `'ko'`
- 项目目前仅支持 `zh`、`en`、`ja` 三种语言

**2. 函数重新排序**：
将 AIService 中所有函数按功能分为 8 个区域，同类方法聚合：
| 区域 | 包含方法 |
|------|---------|
| 测试辅助方法 | `resetForTest`, `setMockClient` |
| 生命周期管理 | `init`, `dispose`, `_onAiSettingsChanged`, `reloadConfig` |
| 配置管理 | `isConfigured`, `updateConfig`, `testConnection` |
| 核心AI调用 | `_callAI`, `_callAIStream` |
| 摘要生成-阻塞版 | `generateFullChapterSummary`, `generateBookSummaryFromPreface`, `generateBookSummary` |
| 摘要生成-流式版 | `generateFullChapterSummaryStream`, `generateBookSummaryStream`, `generateBookSummaryFromPrefaceStream` |
| 翻译 | `translateHtmlStream` |
| 语言检测与转换 | `_detectLanguageFromMetadataAndContentWithBookId`, `detectLanguageFromContent`, `convertLanguageCodeToStandard`, `_getLanguageInstructionForLanguage`, `_detectSystemLanguage`, `_getLanguageInstructionForModel`, `getTargetLanguage` |

**3. 统一配置检查**：
- 将所有 `if (_config == null || !_config!.isValid)` 替换为 `if (!isConfigured)`
- 涉及 8 个方法，消除重复代码，提升可维护性