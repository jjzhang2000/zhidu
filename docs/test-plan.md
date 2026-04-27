# 智读（Zhidu）项目测试计划

## 一、项目概述

### 1.1 项目分析

**项目类型**: Flutter跨平台AI智能阅读器应用
**核心功能**: 分层阅读、AI摘要生成、EPUB/PDF解析
**目标覆盖率**: ≥95%

### 1.2 源代码统计

| 目录 | 文件数 | 代码行数 | 主要职责 |
|------|--------|----------|----------|
| lib/models/ | 6 | ~845 | 数据模型定义 |
| lib/services/ | 11 | ~4,400 | 业务逻辑服务 |
| lib/services/parsers/ | 4 | ~2,030 | 格式解析器 |
| lib/screens/ | 5 | ~2,850 | UI页面 |
| lib/utils/ | 1 | ~163 | 工具类 |
| lib/ | 1 | ~59 | 应用入口 |
| **总计** | **27** | **~8,347** | |

### 1.3 测试现状（更新：2026-04-15）

- **当前测试文件**: 29个测试文件
- **当前覆盖率**: 55.79% (1566/2807行)
- **测试用例数**: 660个通过，13个跳过（FFI限制），1个失败
- **测试文件位置**: test/

### 1.4 覆盖率详情

| 文件 | 行数 | 覆盖 | 覆盖率 |
|------|------|------|--------|
| log_service.dart | 37 | 37 | 100% |
| ai_prompts.dart | 9 | 9 | 100% |
| storage_config.dart | 35 | 35 | 100% |
| chapter_summary.dart | 19 | 19 | 100% |
| chapter_content.dart | 9 | 9 | 100% |
| book.dart | 51 | 51 | 100% |
| chapter.dart | 15 | 15 | 100% |
| ai_service.dart | 70 | 68 | 97.1% |
| file_storage_service.dart | 53 | 46 | 86.8% |
| book_service.dart | 108 | 81 | 75% |
| epub_service.dart | 604 | 294 | 48.7% |
| export_service.dart | 79 | 37 | 46.8% |
| summary_service.dart | 201 | 87 | 43.3% |
| pdf_parser.dart | 123 | 31 | 25.2% (FFI限制) |
| main.dart | 19 | 5 | 26.3% |
| pdf_service.dart | 120 | 17 | 14.2% (FFI限制) |

### 1.5 测试限制说明

以下文件因技术限制无法在单元测试环境中完全覆盖：
1. **PDF相关文件**: pdf_parser.dart、pdf_service.dart、pdf_reader_screen.dart
   - 原因：pdfrx依赖FFI调用pdfium动态库，纯Dart测试环境无法加载
   - 解决方案：需要使用Flutter集成测试或Widget测试在真实平台运行

2. **UI界面文件**: screens/*.dart
   - 原因：需要Widget测试环境，需要模拟用户交互
   - 当前覆盖率：30-50%

3. **main.dart**: 应用入口点
   - 原因：初始化所有Service，难以隔离测试

---

## 二、测试策略

### 2.1 测试层次

```
┌─────────────────────────────────────────────────────────────┐
│                    E2E测试 (Widget测试)                       │
│    - 用户流程测试：导入→阅读→生成摘要→导出                    │
├─────────────────────────────────────────────────────────────┤
│                    集成测试                                   │
│    - Service之间交互测试                                      │
│    - Parser与文件系统交互测试                                  │
│    - AI API调用测试（Mock）                                   │
├─────────────────────────────────────────────────────────────┤
│                    单元测试                                   │
│    - Model序列化/反序列化测试                                  │
│    - Service方法测试                                          │
│    - Parser解析逻辑测试                                       │
│    - 工具函数测试                                              │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 测试工具

| 工具 | 用途 | 版本要求 |
|------|------|----------|
| flutter_test | 单元测试、Widget测试 | SDK内置 |
| mockito | Mock依赖对象 | ^5.4.4（已配置） |
| build_runner | 生成Mock代码 | dev依赖 |

### 2.3 测试原则

1. **TDD优先**: 先写测试，后写代码（新增功能）
2. **隔离原则**: 每个测试独立，不依赖执行顺序
3. **Mock外部依赖**: 文件系统、网络API、平台API
4. **覆盖率驱动**: 按模块重要性分配测试优先级

---

## 三、覆盖率目标分解

### 3.1 目标覆盖率分布

| 模块 | 目标覆盖率 | 优先级 | 理由 |
|------|------------|--------|------|
| models/ | **100%** | P0 | 数据模型是核心基础，必须完全可靠 |
| services/parsers/ | **98%** | P0 | 解析器是核心功能，复杂度高 |
| services/ (非parsers) | **95%** | P0 | 业务逻辑核心，必须有充分测试 |
| screens/ | **85%** | P1 | UI测试成本高，覆盖关键交互即可 |
| utils/ | **100%** | P0 | 工具类逻辑简单，容易全覆盖 |

### 3.2 总体目标

- **总体代码覆盖率**: ≥95%
- **核心业务逻辑覆盖率**: ≥98%
- **数据模型覆盖率**: 100%

---

## 四、分模块测试规划

### 4.1 Models模块测试（目标100%）

#### 4.1.1 Book模型测试

**文件**: `test/models/book_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 构造函数测试 | 正常参数创建、默认值验证 | P0 |
| toJson测试 | 所有字段序列化、null字段处理 | P0 |
| fromJson测试 | 正常JSON解析、缺失字段处理、格式兼容 | P0 |
| copyWith测试 | 各字段独立更新、多字段同时更新 | P0 |
| BookFormat枚举测试 | 枚举值、name属性 | P0 |

**测试用例数**: ~15个

#### 4.1.2 Chapter模型测试

**文件**: `test/models/chapter_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 构造函数测试 | 必填参数、可选参数默认值 | P0 |
| toJson测试 | 序列化验证、level字段 | P0 |
| fromJson测试 | 反序列化验证、兼容旧数据(level缺失) | P0 |
| location嵌套测试 | ChapterLocation正确解析 | P0 |

**测试用例数**: ~10个

#### 4.1.3 ChapterSummary模型测试

**文件**: `test/models/chapter_summary_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 构造函数测试 | 所有参数创建 | P0 |
| toJson测试 | 序列化验证 | P0 |
| fromJson测试 | 反序列化验证、默认值处理 | P0 |
| createdAt测试 | DateTime序列化/反序列化 | P0 |

**测试用例数**: ~10个

#### 4.1.4 ChapterLocation模型测试

**文件**: `test/models/chapter_location_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 构造函数测试 | href模式、页码模式 | P0 |
| toJson测试 | 所有字段序列化 | P0 |
| fromJson测试 | 反序列化验证 | P0 |

**测试用例数**: ~8个

#### 4.1.5 ChapterContent模型测试

**文件**: `test/models/chapter_content_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 构造函数测试 | plainText必填、htmlContent可选 | P0 |
| toJson测试 | 序列化验证 | P0 |
| fromJson测试 | 反序列化验证 | P0 |

**测试用例数**: ~8个

#### 4.1.6 BookMetadata模型测试

**文件**: `test/models/book_metadata_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 构造函数测试 | 所有参数创建 | P0 |
| 字段验证测试 | title/author/format等 | P0 |

**测试用例数**: ~5个

---

### 4.2 Services/Parsers模块测试（目标98%）

#### 4.2.1 FormatRegistry测试

**文件**: `test/services/parsers/format_registry_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| register测试 | 注册解析器、覆盖已存在解析器 | P0 |
| getParser测试 | 获取已注册解析器、获取未注册格式 | P0 |
| isSupported测试 | 支持格式判断、大小写不敏感 | P0 |
| getSupportedFormats测试 | 获取所有支持格式 | P0 |
| clear测试 | 清空注册表 | P0 |

**测试用例数**: ~12个

**Mock策略**: 无需Mock，直接测试静态方法

#### 4.2.2 EpubParser测试

**文件**: `test/services/parsers/epub_parser_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| parse测试 | 正常EPUB解析、文件不存在异常 | P0 |
| parse元数据测试 | title/author提取、回退策略 | P0 |
| getChapters测试 | NCX解析、NAV解析、回退解析 | P0 |
| getChapters层级测试 | 多层级目录结构、index分配 | P0 |
| getChapterContent测试 | HTML内容提取、纯文本提取 | P0 |
| extractCover测试 | 封面提取、无封面情况 | P0 |
| _extractTextFromHtml测试 | HTML标签移除、实体解码 | P0 |
| _extractTitleFromHtmlContent测试 | title/h1/h2标签提取 | P0 |

**测试用例数**: ~25个

**Mock策略**: 
- Mock文件系统（File、Directory）
- Mock epub_plus库返回值
- 使用内存中的测试EPUB数据

#### 4.2.3 PdfParser测试

**文件**: `test/services/parsers/pdf_parser_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| parse测试 | 正常PDF解析、文件不存在异常 | P0 |
| parse元数据测试 | title提取（文件名）、页数统计 | P0 |
| getChapters测试 | 章节边界检测、封面跳过逻辑 | P0 |
| getChapters章节标题测试 | 中文/英文/数字章节标题匹配 | P0 |
| getChapterContent测试 | 页面范围提取、HTML转换 | P0 |
| extractCover测试 | 返回null（当前不支持） | P1 |

**测试用例数**: ~20个

**Mock策略**:
- Mock pdfrx库（PdfDocument、PdfPage）
- Mock文件系统

#### 4.2.4 BookFormatParser接口测试

**文件**: `test/services/parsers/book_format_parser_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 接口契约测试 | 所有实现类遵循接口定义 | P0 |

**测试用例数**: ~5个（契约验证）

---

### 4.3 Services模块测试（目标95%）

#### 4.3.1 BookService测试

**文件**: `test/services/book_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| init测试 | 索引文件加载、空文件处理 | P0 |
| _loadBooks测试 | 正常加载、元数据解析失败处理 | P0 |
| _saveBooksIndex测试 | 序列化验证 | P0 |
| _saveBookMetadata测试 | 单本书籍保存 | P0 |
| importBook测试 | EPUB导入、PDF导入、用户取消 | P1 |
| importBook去重测试 | 相同书籍检测 | P0 |
| getBookById测试 | 存在的书籍、不存在的书籍 | P0 |
| deleteBook测试 | 正常删除、不存在书籍 | P0 |
| updateBook测试 | 正常更新、不存在书籍 | P0 |
| searchBooks测试 | 标题搜索、作者搜索、空结果 | P0 |
| updateChapterTitle测试 | 标题更新、书籍不存在 | P0 |

**测试用例数**: ~25个

**Mock策略**:
- Mock FileStorageService
- Mock EpubService/PdfService
- Mock FilePicker（文件选择器）

#### 4.3.2 AIService测试

**文件**: `test/services/ai_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| init测试 | 配置文件加载、文件不存在 | P0 |
| AIConfig.fromJson测试 | 正常解析、缺失字段默认值 | P0 |
| AIConfig.isValid测试 | 有效配置、占位符检测 | P0 |
| isConfigured测试 | 已配置、未配置 | P0 |
| generateFullChapterSummary测试 | 正常生成、未配置返回null | P0 |
| generateBookSummaryFromPreface测试 | 正常生成、未配置返回null | P0 |
| generateBookSummary测试 | 正常生成、未配置返回null | P0 |
| _callAI测试 | HTTP请求构造、响应解析 | P0 |
| _callAI错误测试 | 非200状态码处理 | P0 |

**测试用例数**: ~20个

**Mock策略**:
- Mock http包（HTTP响应）
- Mock File（配置文件）
- Mock LogService

#### 4.3.3 SummaryService测试

**文件**: `test/services/summary_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| init测试 | 初始化验证 | P0 |
| getSummary测试 | 存在的摘要、不存在摘要 | P0 |
| saveSummary测试 | 正常保存 | P0 |
| deleteSummary测试 | 正常删除 | P0 |
| getSummariesForBook测试 | 多章节摘要、空列表 | P0 |
| getBookSummary测试 | 全书摘要获取 | P0 |
| saveBookSummary测试 | 全书摘要保存、Book元数据更新 | P0 |
| generateSingleSummary测试 | 正常生成、并发控制 | P0 |
| generateSingleSummary并发测试 | 重复请求拒绝 | P0 |
| generateSummariesForBook测试 | EPUB流程、PDF流程 | P0 |
| extractTitleFromSummary测试 | 标题提取、无效格式 | P0 |
| removeTitleLineFromSummary测试 | 标题行移除 | P0 |
| isGenerating测试 | 状态检查 | P0 |

**测试用例数**: ~30个

**Mock策略**:
- Mock AIService
- Mock BookService
- Mock FileStorageService
- Mock FormatRegistry

#### 4.3.4 FileStorageService测试

**文件**: `test/services/file_storage_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| readJson测试 | 正常读取、文件不存在、解析失败 | P0 |
| writeJson测试 | 正常写入、父目录创建、格式化 | P0 |
| readText测试 | 正常读取、文件不存在 | P0 |
| writeText测试 | 正常写入、父目录创建 | P0 |
| deleteFile测试 | 正常删除、文件不存在 | P0 |
| deleteDirectory测试 | 正常删除、目录不存在 | P0 |
| exists测试 | 存在、不存在 | P0 |
| listFiles测试 | 正常列表、扩展名过滤 | P0 |

**测试用例数**: ~20个

**Mock策略**:
- Mock File、Directory（dart:io）

#### 4.3.5 StorageConfig测试

**文件**: `test/services/storage_config_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| getAppDirectory测试 | 目录创建、路径正确性 | P0 |
| getBooksIndexPath测试 | 路径生成 | P0 |
| getBookDirectory测试 | 目录创建 | P0 |
| getBookMetadataPath测试 | 路径生成 | P0 |
| getBookSummaryPath测试 | 路径生成 | P0 |
| getChapterSummaryPath测试 | 零填充格式验证 | P0 |
| getCoverPath测试 | jpg/png查找 | P0 |
| getCoverSavePath测试 | MIME类型扩展名 | P0 |

**测试用例数**: ~15个

**Mock策略**:
- Mock getApplicationDocumentsDirectory（path_provider）

#### 4.3.6 LogService测试

**文件**: `test/services/log_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| init测试 | 文件日志初始化、控制台模式 | P0 |
| v/d/info/w/e测试 | 各级别日志输出 | P0 |
| 级别过滤测试 | minLevel过滤 | P0 |
| dispose测试 | 资源释放 | P0 |
| _formatMessage测试 | 格式化输出 | P0 |

**测试用例数**: ~15个

**Mock策略**:
- Mock File、IOSink
- Mock print函数（测试输出）

#### 4.3.7 ExportService测试

**文件**: `test/services/export_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| exportBookSummaryToMarkdown测试 | Markdown格式验证 | P0 |
| exportAllDataToJson测试 | JSON结构验证 | P0 |
| importFromJson测试 | 正常导入、文件不存在 | P0 |
| importFromJson数据验证测试 | Book/Summary解析 | P0 |
| pickAndImportBackup测试 | 文件选择流程 | P1 |

**测试用例数**: ~15个

**Mock策略**:
- Mock BookService、SummaryService
- Mock FilePicker
- Mock File

#### 4.3.8 AiPrompts测试

**文件**: `test/services/ai_prompts_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| bookSummaryFromPreface测试 | 提示词格式验证 | P0 |
| bookSummary测试 | 提示词格式验证 | P0 |
| chapterSummary测试 | 提示词格式验证 | P0 |
| 参数嵌入测试 | title/author/content正确嵌入 | P0 |

**测试用例数**: ~10个

**Mock策略**: 无需Mock，纯函数测试

#### 4.3.9 EpubService测试

**文件**: `test/services/epub_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| parseEpubFile测试 | 正常解析、文件不存在 | P0 |
| extractPrefaceContent测试 | 前言提取、回退策略 | P0 |
| getChapterList测试 | 章节列表获取 | P0 |
| getChapterContent测试 | 章节内容获取 | P0 |
| getChapterHtml测试 | HTML获取 | P0 |
| getSectionsInChapter测试 | 小节提取 | P1 |

**测试用例数**: ~20个

**Mock策略**:
- Mock EpubReader（epub_plus）
- Mock File、Archive

#### 4.3.10 PdfService测试

**文件**: `test/services/pdf_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| parsePdfFile测试 | 正常解析、文件不存在 | P0 |
| _extractCover测试 | 封面渲染（或跳过） | P1 |
| _detectChapters测试 | 章节检测、封面跳过 | P0 |
| getChapterPages测试 | 页面内容获取 | P0 |
| getChapterPageRange测试 | 页码范围 | P0 |
| getPageContent测试 | 单页内容 | P0 |

**测试用例数**: ~15个

**Mock策略**:
- Mock PdfDocument（pdfrx）
- Mock File

---

### 4.4 Screens模块测试（目标85%）

#### 4.4.1 HomeScreen/BookshelfScreen测试

**文件**: `test/screens/home_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | 空书架状态、书籍列表显示 | P0 |
| 搜索功能测试 | 搜索框、过滤结果 | P0 |
| 导入按钮测试 | FAB点击触发 | P1 |
| 书籍卡片测试 | 卡片渲染、封面显示 | P0 |
| 删除功能测试 | 删除确认对话框 | P1 |
| 设置导航测试 | 设置页面跳转 | P1 |

**测试用例数**: ~15个

**Mock策略**:
- Mock BookService
- Widget测试使用testWidgets

#### 4.4.2 BookScreen测试

**文件**: `test/screens/book_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | 书籍信息显示、封面显示 | P0 |
| 章节列表测试 | 加载状态、列表显示 | P0 |
| 视图切换测试 | 摘要/目录切换 | P0 |
| 全书摘要测试 | Markdown渲染 | P0 |
| 章节点击测试 | 导航到ChapterScreen | P1 |
| 预生成测试 | 后台任务启动 | P1 |

**测试用例数**: ~15个

**Mock策略**:
- Mock BookService、SummaryService、AIService
- Mock FormatRegistry

#### 4.4.3 ChapterScreen测试

**文件**: `test/screens/chapter_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | 加载状态、摘要显示 | P0 |
| 摘要生成测试 | 按钮触发、生成状态 | P0 |
| 视图切换测试 | 摘要/原文切换 | P0 |
| 原文显示测试 | HTML渲染、PDF页面 | P0 |
| 章节导航测试 | 上一章/下一章 | P0 |
| PDF翻页测试 | 页码控制 | P1 |
| 内容过短处理测试 | 按钮禁用、默认原文 | P0 |

**测试用例数**: ~20个

**Mock策略**:
- Mock SummaryService、BookService、AIService
- Mock FormatRegistry
- Mock PdfDocument（pdfrx）

#### 4.4.4 SettingsScreen测试

**文件**: `test/screens/settings_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | 设置项显示 | P1 |
| AI状态测试 | 配置状态显示 | P1 |

**测试用例数**: ~5个

#### 4.4.5 新增Settings页面测试

**说明**: 为Settings Page Features新增的功能测试

**文件**: `test/screens/ai_config_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | 表单字段显示、下拉选项 | P0 |
| 交互测试 | 提供商切换、模型更新、API Key显示切换 | P0 |
| 验证测试 | 空API Key错误、无效配置提示 | P0 |
| 保存测试 | 配置保存、AIService重载 | P0 |

**测试用例数**: ~15个

**文件**: `test/screens/theme_settings_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | 三个选项显示、当前选中状态 | P0 |
| 交互测试 | 选项切换、立即生效 | P0 |
| 持久化测试 | 重启后主题保持 | P0 |

**测试用例数**: ~10个

**文件**: `test/screens/language_settings_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | 选项显示、下拉菜单显隐 | P0 |
| 交互测试 | 模式切换、语言选择 | P0 |
| 持久化测试 | 设置保存 | P0 |

**测试用例数**: ~10个

**文件**: `test/screens/backup_settings_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | 目录显示、时间显示、开关状态 | P0 |
| 交互测试 | 目录选择、开关切换、频率选择 | P0 |
| 备份测试 | 手动备份触发、进度显示 | P0 |
| 恢复测试 | 文件选择、确认对话框、恢复执行 | P0 |

**测试用例数**: ~15个

**文件**: `test/screens/storage_settings_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | 当前目录显示、警告信息 | P0 |
| 交互测试 | 目录选择、更新显示 | P0 |

**测试用例数**: ~8个

---

### 4.5 Settings模块测试（新增）

#### 4.5.1 AppSettings模型测试

**文件**: `test/models/app_settings_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| AiSettings测试 | 默认值、有效性验证、序列化 | P0 |
| ThemeSettings测试 | 默认值、模式解析、序列化 | P0 |
| StorageSettings测试 | 默认路径、自动备份配置、序列化 | P0 |
| LanguageSettings测试 | 默认模式、语言选择、序列化 | P0 |
| AppSettings测试 | 完整序列化/反序列化、版本兼容 | P0 |

**测试用例数**: ~25个

#### 4.5.2 SettingsService测试

**文件**: `test/services/settings_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 初始化测试 | 默认配置创建、现有配置加载、损坏处理 | P0 |
| 更新测试 | AI/主题/存储/语言配置更新 | P0 |
| 通知测试 | ValueNotifier正确触发、多监听器 | P0 |
| 持久化测试 | 文件保存/加载、并发处理 | P0 |
| 导入导出测试 | 完整配置导入导出、重置默认 | P0 |

**测试用例数**: ~30个

#### 4.5.3 StoragePathService测试

**文件**: `test/services/storage_path_service_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 目录访问测试 | 自定义路径、默认路径返回 | P0 |
| 目录选择测试 | 选择流程、可写性验证 | P0 |
| 路径管理测试 | 设置更新、重置默认 | P0 |
| 边界测试 | 不存在目录、只读目录、权限错误 | P0 |

**测试用例数**: ~20个

#### 4.5.4 AIService更新测试

**文件**: `test/services/ai_service_test.dart`（更新现有文件）

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 配置加载测试 | 从SettingsService加载、重载配置 | P0 |
| 语言注入测试 | 提示词语言指令注入、各模式验证 | P0 |

**测试用例数**: ~15个（新增）

#### 4.5.5 AiPrompts更新测试

**文件**: `test/services/ai_prompts_test.dart`（更新现有文件）

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 语言指令测试 | 各模式指令生成、无效语言处理 | P0 |
| 提示词注入测试 | 指令正确附加到提示词 | P0 |

**测试用例数**: ~10个（新增）

#### 4.5.6 ExportService更新测试

**文件**: `test/services/export_service_test.dart`（更新现有文件）

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 设置备份测试 | 备份包含设置、结构正确 | P0 |
| 设置恢复测试 | 设置正确恢复、Service重载 | P0 |
| 自动备份测试 | 文件创建、覆盖更新 | P0 |

**测试用例数**: ~10个（新增）

---

### 4.6 Screens模块测试（目标85%）

**文件**: `test/screens/pdf_reader_screen_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| 渲染测试 | PDF页面显示 | P1 |
| 翻页测试 | 页面导航 | P1 |

**测试用例数**: ~5个

---

### 4.7 Utils模块测试（目标100%）

#### 4.7.1 AppTheme测试

**文件**: `test/utils/app_theme_test.dart`

| 测试项 | 测试内容 | 优先级 |
|--------|----------|--------|
| lightTheme测试 | 主题配置验证、颜色正确性 | P0 |
| darkTheme测试 | 主题配置验证 | P0 |
| 颜色常量测试 | primaryColor/accentColor值 | P0 |

**测试用例数**: ~10个

**Mock策略**: 无需Mock，纯静态配置测试

---

## 五、测试用例统计

### 5.1 总体统计

| 模块 | 测试文件数 | 测试用例数 | 预估工作量 |
|------|------------|------------|------------|
| models/ | 7 | ~83 | 3天 |
| services/parsers/ | 4 | ~62 | 3天 |
| services/ (非parsers) | 11 | ~235 | 7天 |
| screens/ | 10 | ~108 | 4天 |
| utils/ | 1 | ~10 | 0.5天 |
| **总计** | **33** | **~498** | **17.5天** |

### 5.2 Settings功能专项统计

| 模块 | 测试文件数 | 新增用例数 | 优先级 |
|------|------------|------------|--------|
| Models | 1 | ~25 | P0 |
| Services | 3 | ~75 | P0 |
| Screens | 5 | ~58 | P0 |
| **小计** | **9** | **~158** | - |

### 5.3 优先级分布

- **P0用例**: ~200个（核心功能，必须覆盖）
- **P1用例**: ~80个（重要功能，尽力覆盖）

---

## 六、Mock策略详解

### 6.1 文件系统Mock

```dart
// 使用mockito生成Mock类
@GenerateMocks([File, Directory, IOSink])
// 测试中使用内存数据替代真实文件
```

### 6.2 第三方库Mock

| 库 | Mock策略 | Mock类 |
|-----|----------|--------|
| epub_plus | Mock返回值 | MockEpubBook |
| pdfrx | Mock返回值 | MockPdfDocument |
| path_provider | Mock路径 | Mock函数 |
| file_picker | Mock选择结果 | Mock函数 |
| http | Mock响应 | MockClient |

### 6.3 Service Mock

```dart
@GenerateMocks([
  BookService,
  AIService,
  SummaryService,
  FileStorageService,
  LogService,
])
```

---

## 七、特殊测试场景

### 7.1 EPUB解析回退策略测试

测试当EpubReader解析失败时，archive回退方案的正确性：
- container.xml解析失败 → 尝试OPF
- NCX解析失败 → 尝试NAV
- 所有方法失败 → 使用文件名排序

### 7.2 PDF章节检测算法测试

测试不同章节标题格式的识别：
- 中文数字：第一章、第十二、第一百二十
- 阿拉伯数字：第1章、第12章
- 英文：Chapter 1、CHAPTER 1
- 编号：1. Title

### 7.3 AI并发控制测试

测试SummaryService的并发控制机制：
- 同一章节重复生成请求 → 应拒绝
- 正在生成时等待机制
- Completer正确完成/错误处理

### 7.4 数据迁移兼容测试

测试旧数据格式的兼容性：
- ChapterSummary.fromJson缺失字段默认值
- Chapter.fromJson缺失level字段

---

## 八、实施计划

### 8.1 Phase 1: 基础测试（1周）

**目标**: Models模块100%覆盖

1. 创建测试目录结构
2. 配置mockito代码生成
3. 完成所有Model测试
4. 验证序列化/反序列化逻辑

**里程碑**: Models模块测试覆盖率100%

### 8.2 Phase 2: 解析器测试（1周）

**目标**: Parsers模块98%覆盖

1. 完成FormatRegistry测试
2. 完成EpubParser测试（含回退策略）
3. 完成PdfParser测试（含章节检测）
4. 验证接口契约

**里程碑**: Parsers模块测试覆盖率≥98%

### 8.3 Phase 3: 服务层测试（2周）

**目标**: Services模块95%覆盖

1. 完成FileStorageService测试
2. 完成StorageConfig测试
3. 完成AIService测试（含Mock HTTP）
4. 完成BookService测试
5. 完成SummaryService测试（含并发控制）
6. 完成LogService、ExportService测试

**里程碑**: Services模块测试覆盖率≥95%

### 8.4 Phase 4: UI测试（1周）

**目标**: Screens模块85%覆盖

1. 完成HomeScreen测试
2. 完成BookScreen测试
3. 完成ChapterScreen测试
4. 完成其他Screen基础测试

**里程碑**: Screens模块测试覆盖率≥85%

### 8.5 Phase 5: 集成与优化（0.5周）

**目标**: 整体覆盖率达标

1. 运行全部测试
2. 分析覆盖率报告
3. 补充遗漏测试
4. 优化测试性能

**里程碑**: 整体测试覆盖率≥95%

---

## 九、测试命令

### 9.1 运行全部测试

```bash
flutter test
```

### 9.2 运行带覆盖率报告

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### 9.3 运行指定测试文件

```bash
flutter test test/models/book_test.dart
```

### 9.4 运行指定测试用例

```bash
flutter test test/models/book_test.dart --name "toJson"
```

---

## 十、质量保证

### 10.1 测试代码规范

1. 测试文件命名：`*_test.dart`
2. 测试函数命名：`test('描述', () {});`
3. 使用`group()`组织相关测试
4. 每个测试独立，使用`setUp()`/`tearDown()`

### 10.2 Mock代码生成

```bash
# 生成Mock类
flutter pub run build_runner build

# 清理并重新生成
flutter pub run build_runner clean && flutter pub run build_runner build
```

### 10.3 覆盖率验证

- 每个Phase结束后验证覆盖率
- 未达标模块需补充测试
- 关注边界条件和异常处理

---

## 十一、风险与应对

### 11.1 技术风险

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| Flutter Widget测试复杂 | UI测试覆盖率低 | 优先测试关键交互，使用pumpWidget简化 |
| Mock第三方库困难 | 解析器测试受限 | 封装解析器调用，测试封装层 |
| 异步测试难以控制 | 测试不稳定 | 使用async/await，避免假阳性 |

### 11.2 时间风险

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| 测试工作量超预期 | 实施延期 | 优先P0用例，P1用例可后续补充 |
| Mock代码生成问题 | 开发受阻 | 预先研究mockito最佳实践 |

---

## 十二、附录

### 12.1 测试文件清单

```
test/
├── models/
│   ├── book_test.dart
│   ├── chapter_test.dart
│   ├── chapter_summary_test.dart
│   ├── chapter_location_test.dart
│   ├── chapter_content_test.dart
│   ├── book_metadata_test.dart
│   └── app_settings_test.dart                    [新增]
├── services/
│   ├── book_service_test.dart
│   ├── ai_service_test.dart
│   ├── summary_service_test.dart
│   ├── file_storage_service_test.dart
│   ├── storage_config_test.dart
│   ├── log_service_test.dart
│   ├── export_service_test.dart
│   ├── ai_prompts_test.dart
│   ├── epub_service_test.dart
│   ├── pdf_service_test.dart
│   ├── settings_service_test.dart                [新增]
│   └── storage_path_service_test.dart            [新增]
│   └── parsers/
│       ├── format_registry_test.dart
│       ├── epub_parser_test.dart
│       ├── pdf_parser_test.dart
│       └── book_format_parser_test.dart
├── screens/
│   ├── home_screen_test.dart
│   ├── book_screen_test.dart
│   ├── chapter_screen_test.dart
│   ├── settings_screen_test.dart
│   ├── pdf_reader_screen_test.dart
│   ├── ai_config_screen_test.dart                [新增]
│   ├── theme_settings_screen_test.dart           [新增]
│   ├── language_settings_screen_test.dart        [新增]
│   ├── backup_settings_screen_test.dart          [新增]
│   └── storage_settings_screen_test.dart         [新增]
├── utils/
│   └── app_theme_test.dart
├── mocks/
│   └── generated_mocks.dart（build_runner生成）
└── test_helper.dart（测试辅助函数）
```

### 12.2 参考文档

- Flutter测试文档: https://docs.flutter.dev/testing
- mockito文档: https://pub.dev/packages/mockito
- 测试最佳实践: https://docs.flutter.dev/testing/best-practices

---

**文档版本**: v1.1
**更新日期**: 2026-04-15
**创建日期**: 2026-04-14
**预计完成**: 约2.5周工作量