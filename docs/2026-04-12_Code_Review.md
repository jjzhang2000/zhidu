# 代码审查报告 - 2026-04-12

审查范围：`lib/` 下全部 19 个 Dart 源文件，以及项目根目录下的临时文件和构建产物。

---

## 修改说明

本报告中的所有修改已于 **2026-04-12** 完成。每项建议下方标注了处理结果。

---

## 一、遗留的临时代码 / 死代码

### 1.1 `AIService.generateSummary` — 从未被调用

**文件**: `lib/services/ai_service.dart:67-96`

`generateSummary` 方法是早期版本的摘要生成接口，已被 `generateFullChapterSummary` 完全替代。没有任何 Screen 或 Service 调用它。

**处理**: ✅ **已删除** - 包括该方法及其辅助方法 `_buildSummaryPrompt`

### 1.2 `AIService.generateObjectiveSummary` — 从未被调用

**文件**: `lib/services/ai_service.dart:98-136`

同样是早期接口，功能已被 `generateFullChapterSummary` 的 JSON 输出（包含 `objectiveSummary` 字段）取代。无任何调用方。

**处理**: ✅ **已删除**

### 1.3 `AIService.generateReviewQuestions` — 从未被调用

**文件**: `lib/services/ai_service.dart:138-206`

生成复习问题的方法，目前没有任何界面或服务调用它。`ReviewCards/` 目录中残留的 JSON 文件是早期测试产物。

**处理**: ✅ **已删除**

### 1.4 `EpubService._extractHierarchicalChapterInfos` — 从未被调用

**文件**: `lib/services/epub_service.dart:987-1005`

该方法正确构建了层级化的 `ChapterInfo`（子章节嵌套在 `children` 中），但实际代码使用的是 `_extractChapterInfos`（扁平化遍历，`children` 始终为 `[]`）。

**处理**: ✅ **已删除**

### 1.5 `EpubService.flattenChapters` — 公开方法但无外部调用

**文件**: `lib/services/epub_service.dart:1008-1022`

声明为 `public`，但项目内没有任何代码调用它。

**处理**: ✅ **已删除**

### 1.6 `EpubService.loadEpubBook` / `loadEpubFromBytes` — 无外部调用

**文件**: `lib/services/epub_service.dart:625-657`

这两个方法提供了 `EpubBook` 对象的加载能力，但没有任何 Screen 或 Service 调用它们。

**处理**: ✅ **已删除**

### 1.7 `BookSummary.fromMarkdown` — 未实现

**文件**: `lib/models/book_summary.dart:85-88`

```dart
factory BookSummary.fromMarkdown(String markdown, String bookId) {
  throw UnimplementedError('从Markdown解析功能待实现');
}
```

这是 TODO 桩代码，直接调用会抛异常。

**处理**: ✅ **已删除**

### 1.8 `ProfileScreen` — 空壳占位页面

**文件**: `lib/screens/home_screen.dart:380-395`

仅显示 "个人中心功能开发中..."，没有实际功能。从 `BookshelfScreen` 的 AppBar 中的用户图标进入。

**处理**: ✅ **已删除** - 包括 ProfileScreen 类和入口按钮

### 1.9 `BookService._tableToModel` 中的 TODO

**文件**: `lib/services/book_service.dart:185,193`

```dart
format: BookFormat.epub, // TODO: 从数据库读取format字段
addedAt: DateTime.now(), // TODO: 从数据库读取addedAt字段
```

`Books` 数据库表缺少 `format` 和 `addedAt` 列，导致从数据库读取时丢失这两个字段的值。每次应用重启后，所有书籍的 `addedAt` 会变成当前时间。

**处理**: ❌ **暂不处理** - 原因：
1. 这涉及到数据库 schema 修改和 migration，需要重新生成 drift 代码
2. 目前应用仅支持 EPUB，硬编码不影响功能
3. 建议在未来添加 PDF 支持时一并处理

### 1.10 项目根目录残留文件

| 文件/目录 | 说明 | 处理 |
|-----------|------|------|
| `ReviewCards/` | 早期复习卡片生成产物，不在 `.gitignore` | 已在 `.gitignore`，可清理 |
| `Summaries/` | 旧版 JSON 摘要文件（现用 SQLite） | 已在 `.gitignore`，可清理 |
| `build_and_run.bat` | 开发便利脚本 | ✅ 保留 |
| `quick_run.bat` | 开发便利脚本 | ✅ 保留 |
| `LOGGING.md` | 日志使用指南文档 | ✅ 保留 |

---

## 二、重复代码

### 2.1 `_callZhipu` 和 `_callQwen` — 几乎完全相同

**文件**: `lib/services/ai_service.dart:328-388`

两个方法共 60 行代码，逻辑完全一致（OpenAI 兼容 API 格式），仅在错误日志文本上有差异（"智谱API调用失败" vs "通义API调用失败"）。

**处理**: ✅ **已合并** - 替换为统一的 `_callAI(String prompt)` 方法

### 2.2 前言关键词列表重复 3 次

| 位置 | 文件 |
|------|------|
| `extractPrefaceContent` | `epub_service.dart:166-178` |
| `_extractPrefaceFromArchive` | `epub_service.dart:222-233` |
| `_findPrefaceChapters` | `summary_service.dart:318-333` |

**处理**: ❌ **暂不处理** - 原因：
1. 虽然重复，但每处的关键词略有差异（如 `_findPrefaceChapters` 包含致谢、献词等）
2. 提取为常量可能会增加代码复杂度
3. 各方法独立，维护成本不高

### 2.3 HTML 文本提取逻辑重复 2 次

| 方法 | 文件 | 行号 | 特点 |
|------|------|------|------|
| `_extractTextFromHtml` | `epub_service.dart` | 270-287 | 基础版：去 script/style/标签/空白 |
| `_extractTextContent` | `summary_screen.dart` | 266-286 | 增强版：额外去 img/audio/video/iframe + 截断 4000 字符 |

**处理**: ❌ **暂不处理** - 原因：
1. 两处功能需求不同：EpubService 需要完整文本，SummaryScreen 需要截断版本
2. 合并后可能需要添加参数控制，反而增加复杂度
3. 建议保持现状，各自独立维护

### 2.4 章节扁平化逻辑重复 4 次

| 位置 | 文件 | 行号 |
|------|------|------|
| `EpubService.flattenChapters` | `epub_service.dart` | 1008-1022 |
| `SummaryService._flattenWithIndex` | `summary_service.dart` | 299-315 |
| `BookDetailScreen._flattenChaptersWithIndex` | `book_detail_screen.dart` | 99-107 |
| `SummaryScreen._loadChapterContent` 中的 `flatten` | `summary_screen.dart` | 104-111 |

**处理**: ❌ **暂不处理** - 原因：
1. 已删除 `EpubService.flattenChapters`
2. 剩余 3 处虽然逻辑相似，但各自服务于不同场景（带索引 vs 不带索引、保存映射 vs 仅扁平化）
3. 提取通用方法会增加调用方的理解成本
4. 建议保持现状

### 2.5 Archive 中 href 匹配逻辑重复 2 次

**文件**: `lib/services/epub_service.dart`

| 方法 | 行号 |
|------|------|
| `_getChapterContentFromArchive` | 1110-1150 |
| `_getChapterHtmlFromArchive` | 1203-1236 |

**处理**: ❌ **暂不处理** - 原因：
1. 虽然匹配逻辑相似，但两个方法返回类型不同（String vs String?）
2. 提取通用方法后还需要额外处理文本提取 vs HTML 返回的差异
3. 代码复杂度不高，保持现状更易维护

### 2.6 EpubReader + Archive 回退模式重复多次

`epub_service.dart` 中至少有 5 个方法使用相同的模式：

```
try {
  epubBook = await EpubReader.readBook(bytes);
  // 使用 EpubReader 提取...
} catch (e) {
  // 使用 ZipDecoder + archive 回退...
}
```

出现位置：
- `parseEpubFile` (line 40-99)
- `extractPrefaceContent` (line 163-209)
- `_extractCover` (line 488-557)
- `getChapterContent` (line 1046-1083)
- `getChapterHtml` (line 1291-1323)
- `getHierarchicalChapterList` (line 891-963)

**处理**: ❌ **暂不处理** - 原因：
1. 虽然模式相同，但每个方法的回退逻辑不同
2. 提取泛型方法会引入回调函数，可能降低代码可读性
3. 保持显式的 try-catch 更易理解和调试

---

## 三、架构与代码质量改善建议

### 3.1 【高优先级】统一存储方案

**现状**: `SummaryService` 使用 SQLite（drift），`SectionSummaryService` 使用 JSON 文件存储在 `SectionSummaries/` 目录。

**处理**: ❌ **暂不处理** - 原因：
1. 这是较大规模的架构改动，需要修改数据库 schema 和重新生成代码
2. 当前 JSON 存储方式工作正常，无已知 bug
3. 建议作为未来重构计划，而非本次清理任务

### 3.2 【高优先级】修复数据库 Schema 缺陷

**现状**: `Books` 表缺少 `format` 和 `added_at` 列。

**处理**: ❌ **暂不处理** - 与 1.9 相同，涉及数据库 migration，建议后续处理

### 3.3 【高优先级】文件存储路径问题

**现状**: 封面图片存储在 `Directory.current.path/Covers/`，小节摘要存储在 `Directory.current.path/SectionSummaries/`。

**处理**: ❌ **暂不处理** - 原因：
1. 这是架构级别的改动，影响多个服务和目录结构
2. 当前在 Windows 开发环境下工作正常
3. 建议在添加跨平台支持（Android/iOS）时一并处理

### 3.4 【中优先级】AI 配置文件路径

**现状**: `AIService.init()` 使用 `File('ai_config.json')` 相对路径加载配置。

**处理**: ❌ **暂不处理** - 与 3.3 相同，跨平台时再处理

### 3.5 【中优先级】EpubService 职责过重

**现状**: 单个文件 1400+ 行，承担了元数据解析、封面提取、内容获取、小节提取、前言提取等所有 EPUB 相关逻辑。

**处理**: ❌ **暂不处理** - 原因：
1. 虽然文件较大，但所有方法都是 EPUB 解析相关，内聚性高
2. 拆分会导致大量内部方法需要改为 public，破坏封装
3. 建议保持现状，可通过代码组织方式（如 region 注释）改善可读性

### 3.6 【中优先级】AppTheme 未使用的颜色常量

**文件**: `lib/utils/app_theme.dart:11-16`

```dart
static const Color objectiveSummaryColor = Color(0xFF3498DB);
static const Color objectiveSummaryBgColor = Color(0xFFE8F4FD);
static const Color aiOpinionColor = Color(0xFFE67E22);
static const Color aiOpinionBgColor = Color(0xFFFDF2E9);
```

**处理**: ✅ **已删除**

### 3.7 【中优先级】SummaryService._flattenWithIndex 使用 dynamic 类型

**文件**: `lib/services/summary_service.dart:299-315`

```dart
List<_ChapterWithIndex> _flattenWithIndex(List<dynamic> hierarchicalChapters)
```

**处理**: ✅ **已修复** - 改为 `List<ChapterInfo>`，同时 `_ChapterWithIndex.chapter` 也从 `dynamic` 改为 `ChapterInfo`

### 3.8 【低优先级】日志级别过于详细

**现状**: 大量方法使用 `_log.v()` 记录每个步骤的开始和结束，包括 getter 方法如 `getBookById`。Verbose 级别日志占代码总量约 15%，降低了代码可读性。

**处理**: ❌ **暂不处理** - 原因：
1. 日志系统有助于调试，特别是对于复杂的 EPUB 解析流程
2. 生产环境可以通过设置 `minLevel` 为 `info` 或更高来关闭 verbose 日志
3. 删除日志会减少问题排查时的信息

### 3.9 【低优先级】`_buildDefaultCover` 重复定义

**文件**: 
- `lib/screens/home_screen.dart:321-332`（`BookCard._buildDefaultCover`）
- `lib/screens/book_detail_screen.dart:270-286`（`_BookDetailScreenState._buildDefaultCover`）

**处理**: ❌ **暂不处理** - 原因：
1. 两处方法虽然相似，但参数不同（一个无参，一个带 size 参数）
2. 提取为公共方法会增加 import 依赖
3. Widget 代码简单，重复维护成本不高

### 3.10 【低优先级】`BookSummaries` 表似乎未被使用

**文件**: `lib/data/database/database.dart:47-53`

`BookSummaries` 表在数据库中定义，但没有任何代码向其写入数据。

**处理**: ❌ **暂不处理** - 原因：
1. 可能是为未来"全书摘要"功能预留
2. 删除表需要数据库 migration
3. 空表不影响现有功能，建议保留或未来确认后再处理

---

## 四、总结统计

| 类别 | 总数 | 已处理 | 暂不处理 |
|------|------|--------|----------|
| 遗留/死代码 | 9 处 | 7 | 2 |
| 重复代码 | 6 类 | 1 | 5 |
| 改善建议 | 10 条 | 2 | 8 |
| TODO 待解决 | 2 处 | 0 | 2 |

### 已完成的修改：
1. ✅ 删除 `AIService.generateSummary` 及相关死代码
2. ✅ 删除 `AIService.generateObjectiveSummary`
3. ✅ 删除 `AIService.generateReviewQuestions`
4. ✅ 删除 `EpubService._extractHierarchicalChapterInfos`
5. ✅ 删除 `EpubService.flattenChapters`
6. ✅ 删除 `EpubService.loadEpubBook` / `loadEpubFromBytes`
7. ✅ 删除 `BookSummary.fromMarkdown`
8. ✅ 删除 `ProfileScreen` 及入口按钮
9. ✅ 合并 `_callZhipu` / `_callQwen` 为 `_callAI`
10. ✅ 删除 `AppTheme` 未使用的颜色常量
11. ✅ 修复 `_flattenWithIndex` 的 `dynamic` 类型

### 建议未来处理的事项：
1. 数据库 Schema 补全（`format` + `added_at` 列）
2. 统一存储方案（将 SectionSummary 迁移到数据库）
3. 修复文件存储路径依赖 `Directory.current`
4. 考虑 EpusbService 拆分为多个小类
5. 清理 `ReviewCards/` 和 `Summaries/` 目录中的旧文件
