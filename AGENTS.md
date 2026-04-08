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
- `flutter test` - 运行测试（目前只有基础widget_test.dart）
- `flutter analyze` - 静态代码分析
- `flutter pub get` - 安装依赖
- `flutter pub upgrade` - 升级依赖
- `flutter build apk --release` - 构建Android APK
- `flutter build appbundle --release` - 构建Android App Bundle
- `flutter build ios --release` - 构建iOS
- `flutter build web --release` - 构建Web（功能受限）

### Project Structure
```
lib/
├── main.dart                 # 应用入口，初始化所有Service
├── models/                   # 数据模型（无代码生成）
│   ├── book.dart            # 书籍模型
│   ├── book_summary.dart    # 书籍摘要（全书概览）
│   ├── chapter_summary.dart # 章节摘要
│   └── section_summary.dart # 小节摘要
├── screens/                  # UI页面
│   ├── home_screen.dart     # 首页（书架/发现/我的）
│   ├── book_detail_screen.dart      # 书籍详情（全书概览）
│   ├── chapter_list_screen.dart     # 章节目录
│   ├── reader_screen.dart           # 原文章节阅读器
│   ├── section_reader_screen.dart   # AI摘要阅读器
│   ├── summary_screen.dart          # 章节摘要页
│   └── settings_screen.dart         # 设置
├── services/                 # 业务服务层（单例模式）
│   ├── book_service.dart    # 书籍管理（导入、解析）
│   ├── epub_service.dart    # EPUB文件解析（核心）
│   ├── ai_service.dart      # AI服务（智谱/通义千问API）
│   ├── summary_service.dart # 摘要生成与管理
│   ├── section_summary_service.dart # 小节摘要服务
│   ├── storage_service.dart # 本地存储（JSON文件）
│   └── export_service.dart  # Markdown导出
└── utils/
    └── app_theme.dart       # 主题配置
```

### Key Dependencies
- **PDF/EPUB**: `epub_plus`（EPUB解析）、`archive`、`xml`、`image`
- **UI**: `flutter_html`（HTML渲染）
- **文件**: `file_picker`（文件选择）、`path_provider`、`path`
- **网络**: `http`（AI API调用）
- **存储**: `shared_preferences`（轻量配置）
- **工具**: `uuid`（ID生成）、`intl`（国际化）

### Architecture Notes
- **状态管理**: 使用StatefulWidget + Service单例，无Riverpod/Provider
- **存储方案**: 基于文件的存储，非数据库，数据存储在项目根目录
  - `books.json` - 书籍列表
  - `/Summaries/` - 章节摘要Markdown文件
  - `/SectionSummaries/` - 小节摘要
  - `/Covers/` - 书籍封面缓存
- **Service初始化**: 所有Service在`main.dart`中顺序初始化
- **AI配置**: 读取项目根目录`ai_config.json`，支持智谱/通义千问

### AI Service Configuration
项目根目录`ai_config.json`格式：
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

### EPUB Parsing Strategy
- **按需提取**: 使用epub_plus库解析EPUB文件结构
- **目录解析**: 优先从OPF/Toc识别章节结构
- **内容提取**: 通过XML解析提取HTML正文

### Data Flow
```
文件导入 → 解析（EPUB/PDF） → AI分析（双轨制摘要） → 展示 → 存储（Markdown）
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

# 用户数据
books.json
/Summaries/
/SectionSummaries/
/Covers/
```

### Important Files
- `ai_config.json` - AI API配置（需手动创建，**不在版本控制中**）
- `books.json` - 本地书籍数据库
- `Summaries/` - 生成的章节摘要Markdown文件
- `Requirement.md` - 产品需求文档
- `Technical_Plan.md` - 技术方案文档

### Development Notes
- 修改Service后需重启应用（非热重载可完全生效）
- AI调用是异步的，注意处理loading状态
- 文件操作使用相对路径，基于`Directory.current.path`
- EPUB解析复杂，涉及XML命名空间处理

### Troubleshooting
- **EPUB无法解析**: 检查文件编码是否为UTF-8，尝试重新导入
- **AI无响应**: 检查`ai_config.json`格式是否正确，API Key是否有效
- **Service找不到**: 修改Service后需完全重启应用，热重载不生效
- **数据丢失**: 用户数据存储在项目根目录，请勿随意删除`books.json`或数据文件夹

### Lessons Learned (重要教训)

#### 2026-04-09: 章节摘要无法显示问题

**问题描述**：用户点击章节后显示"暂无章节摘要"，无法生成摘要。

**根本原因**：ChapterListScreen在`_chapterSummaries.isEmpty`时只显示"暂无章节摘要"文本，用户**根本无法进入阅读界面**。这是一个死循环：
1. 新书没有摘要
2. 界面显示"暂无章节摘要"
3. 用户无法点击章节进入阅读
4. 用户无法生成摘要
5. 永远卡在这里

**错误的方法**：
- 一直在修复摘要查找逻辑、日志系统、EPUB解析回退机制
- 没有从用户流程的全局视角检查问题
- 没有问：用户到底是怎么进入阅读界面的？
- 日志显示没有SectionReaderScreen调用时，没有立即检查为什么没有打开

**正确的分析方法**：
1. **从完整用户流程入手**：用户从首页 → 书籍详情 → 章节列表 → 阅读界面，每一步都要验证
2. **不要想当然**：不要假设某个界面/功能一定可用，要验证
3. **日志是最好的线索**：如果某段代码的日志没有出现，说明那段代码根本没执行，要立即追查原因
4. **全局观至关重要**：不要只盯着局部代码修复，要看整个流程是否通畅

**修复方案**：让ChapterListScreen始终显示章节列表，即使没有摘要。用户点击章节后可以进入阅读界面，在阅读界面生成摘要。

**教训总结**：
- 差错必须有全局观，要彻底
- 不要想当然，要验证每一步
- 用户流程分析是debug的第一步
- 当日志显示某个组件没有被调用时，要检查为什么没有被打开，而不是去修那个组件的内部逻辑
