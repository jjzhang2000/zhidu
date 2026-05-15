# TranslationService - 翻译服务

## 概述

AI翻译服务，负责将 EPUB 章节内容翻译为目标语言，保留 HTML 格式（标签、样式），支持流式输出和译文缓存。

## 源文件

`lib/services/translation_service.dart`

## 类定义

### TranslationService

单例模式翻译服务，管理翻译流程、进度追踪和译文文件缓存。

```dart
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();
  
  final _log = LogService();
  bool _isTranslating = false;
  double _progress = 0.0;
}
```

## 核心属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `_instance` | `TranslationService` | 单例实例 |
| `_isTranslating` | `bool` | 是否正在翻译 |
| `_progress` | `double` | 翻译进度（0.0 ~ 1.0） |

## 方法列表

### get isTranslating → bool

获取当前翻译状态。

### get progress → double

获取当前翻译进度（0.0 ~ 1.0）。

### translateEpubContent({bookId, chapterIndex, chapters, language, isRegenerating}) → Future<bool>

翻译指定章节的 EPUB HTML 内容。

```
参数:
  bookId (required):      书籍ID
  chapterIndex (required): 章节索引
  chapters (required):    章节列表（获取标题和内容）
  language (required):    目标语言代码（如 'en', 'ja'）
  isRegenerating:         是否重新生成

返回:
  true:  翻译成功
  false: 翻译失败（正在翻译中、未配置AI、网络错误等）

处理流程:
  1. 检查是否正在翻译（防止重复）
  2. 获取目标语言名称
  3. 检查是否已有译文缓存文件
     → 如果存在且非重新生成，直接返回 true
  4. 获取章节 HTML 内容
  5. 设置 _isTranslating = true, _progress = 0.0
  6. 调用 AIService.translateHtmlStream()
     → 传入流式回调: _onTranslationChunk()
  7. 保存译文到 chapter-{index}-{lang}.html
  8. 通知 UI 翻译完成
  9. 设置 _isTranslating = false, _progress = 1.0
```

### _onTranslationChunk(String chunk, int currentIndex, int totalChapters)

流式翻译内容回调，更新进度并通知 UI。

```
参数:
  chunk: 流式返回的翻译内容片段
  currentIndex: 当前章节索引
  totalChapters: 总章节数

处理:
  更新 _progress = currentIndex / totalChapters
  通知 UI 回调
```

### getTranslatedFilePath(String bookId, int chapterIndex, String language) → Future<String>

获取译文文件路径。

```
格式: {booksDir}/{bookId}/chapter-{index:3d}-{lang}.html
示例: chapter-000-en.html
```

### isTranslated(String bookId, int chapterIndex, String language) → Future<bool>

检查章节是否已有译文。

### saveTranslatedContent(bookId, chapterIndex, language, htmlContent) → Future<String>

保存翻译结果到 HTML 文件。

### getTranslatedContent(bookId, chapterIndex, language) → Future<String?>

读取已保存的译文内容。

### deleteTranslation(bookId, chapterIndex, language) → Future<bool>

删除指定章节的译文文件。

### deleteAllTranslations(bookId) → Future<void>

删除书籍的所有译文文件。

## 数据流

```
ChapterScreen 用户点击"翻译"
    ↓
TranslationService.translateEpubContent()
    ↓
AIService.translateHtmlStream()
    ↓ SSE 流式响应
    ↓
_onTranslationChunk() 回调 → UI 实时显示
    ↓ 完成
保存 chapter-XXX-{lang}.html
    ↓
BookService 更新书籍翻译状态
```

## 依赖

- `AIService`: AI API 流式翻译调用
- `BookService`: 获取章节路径、更新翻译状态
- `LogService`: 日志记录
- `FileStorageService`: 文件读写
- `File`: 文件操作
- `AiSettings`: 翻译语言配置

## 译文缓存规则

- 文件命名: `chapter-{index:3d}-{lang}.html`
- 存储位置: `books/{bookId}/`
- 格式: HTML（保留原始格式和标签）
- 已存在且非重新生成时跳过翻译