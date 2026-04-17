# AGENTS.md

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
│   ├── home_screen.dart     # 首页（书架/发现/我的）
│   ├── book_detail_screen.dart # 书籍详情（全书概览）
│   ├── summary_screen.dart  # 章节摘要页
│   ├── pdf_reader_screen.dart # PDF阅读器
│   ├── ai_config_screen.dart # AI配置页面
│   ├── settings_screen.dart # 设置主页面
│   ├── theme_settings_screen.dart # 主题设置页面
│   ├── language_settings_screen.dart # 语言设置页面
│   └── storage_settings_screen.dart # 存储设置页面
├── services/                 # 业务服务层（单例模式）
│   ├── book_service.dart    # 书籍管理（导入、解析）
│   ├── epub_service.dart    # EPUB文件解析
│   ├── pdf_service.dart     # PDF文件解析
│   ├── ai_service.dart      # AI服务（智谱/通义千问API）
│   ├── ai_prompts.dart      # AI提示词模板（集中管理）
│   ├── summary_service.dart # 摘要生成与管理
│   ├── export_service.dart  # Markdown导出
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
  - `books/{bookId}/summary.md` - 全书摘要
  - `books/{bookId}/chapter-{index}.md` - 章节摘要
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
  }
}
```
- 支持智谱(zhipu)和通义千问(qwen)
- API Key有效性检查：不能为占位符字符串
- 通过SettingsService可动态更新配置

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

### Lessons Learned (重要教训)

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