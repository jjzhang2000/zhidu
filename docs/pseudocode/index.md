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
- AI 章节摘要生成
- AI 全书摘要生成
- 分层阅读体验
- 多语言界面支持

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
│   ├── book.md                   # 书籍模型
│   ├── book_metadata.md          # 书籍元数据
│   ├── chapter.md                # 章节模型
│   ├── chapter_content.md        # 章节内容模型
│   ├── chapter_location.md       # 章节位置模型
│   └── chapter_summary.md        # 章节摘要模型
├── screens/
│   ├── ai_config_screen.md       # AI 配置页面
│   ├── book_detail_screen.md     # 书籍详情页面
│   ├── home_screen.md            # 首页
│   ├── language_settings_screen.md # 语言设置页面
│   ├── pdf_reader_screen.md      # PDF 阅读器页面
│   ├── settings_screen.md        # 设置主页面
│   ├── summary_screen.md         # 摘要显示页面
│   └── theme_settings_screen.md  # 主题设置页面
├── services/
│   ├── ai_prompts.md             # AI 提示词模板
│   ├── ai_service.md             # AI服务
│   ├── book_service.md           # 书籍管理服务
│   ├── log_service.md            # 日志服务
│   ├── settings_service.md       # 设置管理服务
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
- 初始化所有 Service
- 注册文件格式解析器
- 启动 Flutter 应用
- 管理全局主题和语言

**文档**: [main.md](main.md)

---

### 数据模型模块 (models/)

#### app_settings.dart
应用设置数据模型，包含：
- `AiSettings`: AI服务配置
- `ThemeSettings`: 主题配置
- `LanguageSettings`: 语言配置
- `AppSettings`: 完整设置聚合

**文档**: [models/app_settings.md](models/app_settings.md)

#### book.dart
书籍实体模型，包含：
- 书籍基本信息（标题、作者、封面）
- 阅读进度跟踪
- 章节映射
- 序列化支持

**文档**: [models/book.md](models/book.md)

#### book_metadata.dart
书籍元数据模型，用于：
- 文件解析阶段信息收集
- 导入预览
- 简化信息展示

**文档**: [models/book_metadata.md](models/book_metadata.md)

#### chapter.dart
统一章节模型，支持：
- EPUB 和 PDF 格式
- 多级目录结构
- 位置信息
- JSON序列化

**文档**: [models/chapter.md](models/chapter.md)

#### chapter_content.dart
章节内容模型，包含：
- 纯文本内容
- HTML 格式内容（可选）
- 序列化支持

**文档**: [models/chapter_content.md](models/chapter_content.md)

#### chapter_location.dart
章节位置模型，支持：
- EPUB href 定位
- PDF 页码定位
- 序列化支持

**文档**: [models/chapter_location.md](models/chapter_location.md)

#### chapter_summary.dart
章节摘要模型，包含：
- 客观摘要
- AI 见解
- 关键要点
- 时间戳

**文档**: [models/chapter_summary.md](models/chapter_summary.md)

---

### UI 模块 (screens/)

#### ai_config_screen.dart
AI 配置页面，提供：
- 提供商选择（智谱/通义千问/Ollama）
- API Key输入
- 模型选择
- Base URL 配置
- 连接测试

**文档**: [screens/ai_config_screen.md](screens/ai_config_screen.md)

#### book_detail_screen.dart
书籍详情页面，显示：
- 全书摘要
- 章节列表
- 阅读入口

**文档**: [screens/book_detail_screen.md](screens/book_detail_screen.md)

#### home_screen.dart
首页，包含：
- 底部导航栏
- 书架标签页
- 发现标签页
- 我的标签页

**文档**: [screens/home_screen.md](screens/home_screen.md)

#### language_settings_screen.dart
语言设置页面，配置：
- AI 输出语言
- 界面显示语言
- 语言模式（跟随/手动）

**文档**: [screens/language_settings_screen.md](screens/language_settings_screen.md)

#### pdf_reader_screen.dart
PDF 阅读器，提供：
- 分页阅读
- 章节导航
- 摘要生成

**文档**: [screens/pdf_reader_screen.md](screens/pdf_reader_screen.md)

#### settings_screen.dart
设置主页面，入口：
- AI 配置
- 主题设置
- 语言设置
- 存储设置
- 数据管理

**文档**: [screens/settings_screen.md](screens/settings_screen.md)

#### summary_screen.dart
摘要显示页面，展示：
- 章节摘要
- 原文跳转
- 摘要生成

**文档**: [screens/summary_screen.md](screens/summary_screen.md)

#### theme_settings_screen.dart
主题设置页面，配置：
- 主题模式（系统/浅色/深色）
- 实时预览

**文档**: [screens/theme_settings_screen.md](screens/theme_settings_screen.md)

---

### 服务模块 (services/)

#### log_service.dart
日志服务，提供：
- 分级别日志（verbose/debug/info/warning/error）
- 控制台输出
- 文件输出
- 统一格式化

**文档**: [services/log_service.md](services/log_service.md)

#### settings_service.dart
设置管理服务，负责：
- 统一管理所有设置
- ValueNotifier 响应式更新
- JSON 文件持久化
- 导入导出支持

**文档**: [services/settings_service.md](services/settings_service.md)

#### ai_service.dart
AI服务，封装：
- API 配置管理
- 章节摘要生成
- 全书摘要生成
- 语言检测
- HTTP 请求

**文档**: [services/ai_service.md](services/ai_service.md)

#### ai_prompts.dart
AI 提示词模板，包含：
- 章节摘要提示词
- 全书摘要提示词
- 语言指令
- 中英文模板

**文档**: [services/ai_prompts.md](services/ai_prompts.md)

#### book_service.dart
书籍管理服务，提供：
- 书籍导入（EPUB/PDF）
- 书籍存储
- 书籍查询
- 书籍删除
- 搜索功能

**文档**: [services/book_service.md](services/book_service.md)

#### summary_service.dart
摘要管理服务，负责：
- 摘要生成（并发控制）
- 摘要存储
- 摘要读取
- 全书摘要生成
- 导出支持

**文档**: [services/summary_service.md](services/summary_service.md)

---

### 解析器模块 (services/parsers/)

#### book_format_parser.dart
解析器接口，定义：
- `parseFile()`: 解析文件
- `getChapters()`: 获取章节列表
- `getChapterContent()`: 获取章节内容

**文档**: [services/parsers/book_format_parser.md](services/parsers/book_format_parser.md)

#### epub_parser.dart
EPUB解析器，实现：
- OPF 文件解析
- NCX/NAV 目录解析
- 章节内容提取
- 封面提取
- ZIP 解压
- XML 解析

**文档**: [services/parsers/epub_parser.md](services/parsers/epub_parser.md)

#### format_registry.dart
格式注册表，提供：
- 解析器注册
- 按扩展名查找解析器
- 单例模式

**文档**: [services/parsers/format_registry.md](services/parsers/format_registry.md)

#### pdf_parser.dart
PDF 解析器，实现：
- PDF 渲染
- 章节标题识别
- 封面页跳过
- 分页处理

**文档**: [services/parsers/pdf_parser.md](services/parsers/pdf_parser.md)

---

### 工具模块 (utils/)

#### app_theme.dart
应用主题配置，定义：
- 颜色方案
- 亮色主题
- 暗色主题
- 组件主题

**文档**: [utils/app_theme.md](utils/app_theme.md)

---

### 国际化模块 (l10n/)

#### app_localizations.dart
国际化基类，提供：
- 多语言接口定义
- 语言环境管理
- 翻译键常量
- 参数化消息

**文档**: [l10n/app_localizations.md](l10n/app_localizations.md)

---

## 核心数据流

```
用户导入书籍
    ↓
BookService.importBook()
    ↓
FormatRegistry.getParser()
    ↓
EpubParser/PdfParser.parseFile()
    ↓
提取书籍元数据 → BookMetadata
    ↓
保存书籍 → Book
    ↓
SummaryService.generateSummariesForBook()
    ↓
┌─────────────────────────────────────────────────────────┐
│ EPUB 格式                                                │
│ 1. 从前言生成全书摘要（流式）                           │
│    └─ generateBookSummaryFromPrefaceStream()            │
│       └─ 实时更新到 UI (registerBookStreamingCallback)  │
│ 2. 生成章节摘要（流式）                                 │
│    └─ generateSingleSummary()                           │
│       └─ 实时更新到 UI (registerStreamingCallback)      │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ PDF 格式                                                 │
│ 1. 生成章节摘要（流式）                                 │
│    └─ generateSingleSummary()                           │
│       └─ 实时更新到 UI (registerStreamingCallback)      │
│ 2. 从章节摘要生成全书摘要（流式）                       │
│    └─ generateBookSummaryStream()                       │
│       └─ 实时更新到 UI (registerBookStreamingCallback)  │
└─────────────────────────────────────────────────────────┘
    ↓
AIService.generateXxxSummaryStream()
    ↓
调用 AI API (SSE 流式响应)
    ↓
实时累积内容 → 触发流式回调 → UI 实时显示
    ↓
流结束 → 保存摘要到文件
    ↓
用户阅读摘要
```

---

## 设计模式

### 单例模式
所有 Service 使用单例模式：
- `LogService`
- `SettingsService`
- `AIService`
- `BookService`
- `SummaryService`
- `FormatRegistry`

### 工厂模式
- `FormatRegistry` 根据文件扩展名返回对应解析器

### 策略模式
- `BookFormatParser` 接口定义统一解析策略
- `EpubParser` 和 `PdfParser` 实现不同策略

### 响应式编程
- `ValueNotifier` 实现设置变更的实时响应
- UI 自动重建以应用新设置
- **流式回调机制**实现 AI 生成内容的实时更新

### 并发控制
- `Semaphore` 控制并发 AI 请求数
- 防止重复生成同一章节摘要

### 观察者模式（流式回调）
- **章节流式回调**: `registerStreamingCallback()` / `unregisterStreamingCallback()`
- **全书流式回调**: `registerBookStreamingCallback()` / `unregisterBookStreamingCallback()`
- UI 层注册回调，实时接收 AI 生成内容更新

---

## 存储架构

### 文件结构
```
Documents/zhidu/
├── settings.json               # 应用设置
├── books_index.json           # 书籍索引
└── books/
    └── {bookId}/
        ├── metadata.json      # 书籍元数据
        ├── book-summary.md    # 全书摘要
        ├── chapter-000.md     # 章节摘要 0
        ├── chapter-001.md     # 章节摘要 1
        └── cover.jpg          # 封面图片
```

### 设置存储
- `settings.json`: 所有应用设置（AI、主题、语言）
- JSON 格式，易于备份和恢复

### 摘要存储
- Markdown 格式
- 便于阅读和导出
- 按章节索引命名

---

## 国际化支持

### 支持语言
- 简体中文 (zh)
- 英语 (en)
- 日语 (ja)

### 实现方式
- Flutter `flutter_localizations`
- ARB 文件格式
- 自动生成本地化代码

---

## AI 集成

### 支持的 AI 提供商
- **智谱 AI**: glm-4-flash, glm-4, glm-4-plus
- **通义千问**: qwen-turbo, qwen-plus, qwen-max
- **Ollama**: 本地部署的开源模型

### 摘要生成
- **章节摘要**: 200-300 字，提取核心内容
- **全书摘要**: 400-600 字，综合各章节

### 语言检测
- 自动检测书籍内容语言
- 支持中、英、日、韩等语言
- AI 输出语言与书籍语言一致

---

## 开发指南

### 添加新文件格式
1. 实现 `BookFormatParser` 接口
2. 在 `main.dart` 中注册解析器
3. 更新支持格式列表

### 添加新语言
1. 创建 ARB 文件
2. 翻译所有键值
3. 运行 `flutter gen-l10n`
4. 更新支持语言列表

### 添加新 AI 提供商
1. 在 `AiSettings` 中添加配置
2. 更新 `AIConfig` 验证逻辑
3. 在 UI 中添加选项

---

## 文档维护

### 更新伪代码文档
当修改代码时，同步更新对应的伪代码文档：
1. 找到对应的 .md 文件
2. 更新受影响的函数伪代码
3. 更新数据流图（如有必要）
4. 更新设计说明

### 文档命名规范
- 文件名与源文件一致（.dart → .md）
- 目录结构与 lib/ 一致
- 使用小写和下划线

---

## 版本信息

- **文档更新时间**: 2026-04-24
- **项目版本**: v1.1
- **Flutter 版本**: >= 3.0.0

### 近期更新

#### 2026-04-24: 流式显示功能
- **新增**: 章节摘要流式生成
  - `SummaryService.registerStreamingCallback()` - 注册章节流式回调
  - `SummaryService.unregisterStreamingCallback()` - 取消章节流式回调
  - `AIService.generateFullChapterSummaryStream()` - 流式生成章节摘要
  
- **新增**: 全书摘要流式生成
  - `SummaryService.registerBookStreamingCallback()` - 注册全书流式回调
  - `SummaryService.unregisterBookStreamingCallback()` - 取消全书流式回调
  - `AIService.generateBookSummaryStream()` - 流式生成全书摘要
  - `AIService.generateBookSummaryFromPrefaceStream()` - 基于前言的流式生成

- **新增**: SSE 数据解析
  - `AIService._callAIStream()` - 内部流式 API 调用方法
  - 支持 Server-Sent Events 数据实时解析

- **更新**: 标题移除逻辑
  - `SummaryService.removeTitleLineFromSummary()` - 支持更多标题格式
  - 新增对 `第X章：xxx`、`前言`、`序言` 等格式的识别

---

## 贡献指南

欢迎提交文档改进建议：
1. 检查伪代码是否准确反映代码逻辑
2. 确保所有公开方法都有文档
3. 保持伪代码格式一致
4. 更新数据流图和设计说明
