# 多格式架构重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构智读应用的书籍格式处理架构，实现EPUB、PDF等格式通过统一接口与阅读器和AI服务交互，所有格式统一使用扁平化章节列表。

**Architecture:** 采用适配器模式，定义BookFormatParser接口，每种格式实现该接口；通过FormatRegistry注册和获取解析器；统一的数据模型（Chapter, ChapterContent）使阅读流程和AI流程与格式完全解耦。

**Tech Stack:** Flutter, Dart, epub_plus, pdfrx, drift

---

## File Structure Overview

**New Files:**
- `lib/models/chapter.dart` - 统一章节模型
- `lib/models/chapter_location.dart` - 章节位置模型
- `lib/models/chapter_content.dart` - 章节内容模型
- `lib/models/book_metadata.dart` - 书籍元数据模型
- `lib/services/parsers/book_format_parser.dart` - 解析器接口
- `lib/services/parsers/format_registry.dart` - 格式注册表
- `lib/services/parsers/epub_parser.dart` - EPUB解析器
- `lib/services/parsers/pdf_parser.dart` - PDF解析器

**Modified Files:**
- `lib/services/book_service.dart` - 使用FormatRegistry
- `lib/services/summary_service.dart` - 统一处理所有格式
- `lib/screens/book_detail_screen.dart` - 使用新的Chapter模型
- `lib/screens/summary_screen.dart` - 移除level过滤

---

### Task 1: 创建统一数据模型

**Files:**
- Create: `lib/models/chapter.dart`
- Create: `lib/models/chapter_location.dart`
- Create: `lib/models/chapter_content.dart`
- Create: `lib/models/book_metadata.dart`

- [ ] **Step 1: Create Chapter model**

```dart
class Chapter {
  final String id;
  final int index;
  final String title;
  final ChapterLocation location;
  
  Chapter({
    required this.id,
    required this.index,
    required this.title,
    required this.location,
  });
}
```

- [ ] **Step 2: Create ChapterLocation model**

```dart
class ChapterLocation {
  final String? href;
  final int? startPage;
  final int? endPage;
  
  ChapterLocation({
    this.href,
    this.startPage,
    this.endPage,
  });
}
```

- [ ] **Step 3: Create ChapterContent model**

```dart
class ChapterContent {
  final String plainText;
  final String? htmlContent;
  
  ChapterContent({
    required this.plainText,
    this.htmlContent,
  });
}
```

- [ ] **Step 4: Create BookMetadata model**

```dart
import '../models/book.dart';

class BookMetadata {
  final String title;
  final String author;
  final String? coverPath;
  final int totalChapters;
  final BookFormat format;
  
  BookMetadata({
    required this.title,
    required this.author,
    this.coverPath,
    required this.totalChapters,
    required this.format,
  });
}
```

- [ ] **Step 5: Commit new models**

```bash
git add lib/models/chapter.dart lib/models/chapter_location.dart lib/models/chapter_content.dart lib/models/book_metadata.dart
git commit -m "feat: create unified data models for multi-format architecture"
```

---

### Task 2: 创建解析器接口和注册表

**Files:**
- Create: `lib/services/parsers/book_format_parser.dart`
- Create: `lib/services/parsers/format_registry.dart`

- [ ] **Step 1: Create BookFormatParser interface**

```dart
import '../../models/book_metadata.dart';
import '../../models/chapter.dart';
import '../../models/chapter_content.dart';

abstract class BookFormatParser {
  Future<BookMetadata> parse(String filePath);
  Future<List<Chapter>> getChapters(String filePath);
  Future<ChapterContent> getChapterContent(String filePath, Chapter chapter);
  Future<String?> extractCover(String filePath);
}
```

- [ ] **Step 2: Create FormatRegistry**

```dart
import 'book_format_parser.dart';

class FormatRegistry {
  static final Map<String, BookFormatParser> _parsers = {};
  
  static void register(String extension, BookFormatParser parser) {
    _parsers[extension.toLowerCase()] = parser;
  }
  
  static BookFormatParser? getParser(String extension) {
    return _parsers[extension.toLowerCase()];
  }
  
  static void initialize() {
    // 将在后续task中注册解析器
  }
}
```

- [ ] **Step 3: Commit parser interface and registry**

```bash
git add lib/services/parsers/book_format_parser.dart lib/services/parsers/format_registry.dart
git commit -m "feat: create BookFormatParser interface and FormatRegistry"
```

---

### Task 3: 重构EpubService为EpubParser

**Files:**
- Create: `lib/services/parsers/epub_parser.dart`
- Reference: `lib/services/epub_service.dart` (existing implementation)

- [ ] **Step 1: Create EpubParser class implementing BookFormatParser**

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/book.dart';
import '../../models/book_metadata.dart';
import '../../models/chapter.dart';
import '../../models/chapter_content.dart';
import '../../models/chapter_location.dart';
import 'book_format_parser.dart';
import '../log_service.dart';

class EpubParser implements BookFormatParser {
  final _log = LogService();
  final _uuid = const Uuid();

  @override
  Future<BookMetadata> parse(String filePath) async {
    _log.v('EpubParser', 'parse 开始执行, filePath: $filePath');
    
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _log.w('EpubParser', '文件不存在: $filePath');
        throw Exception('文件不存在');
      }

      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);
      
      final title = epubBook.title ?? 'Unknown Title';
      final author = epubBook.authors?.join(', ') ?? 'Unknown Author';
      
      // 提取封面
      final coverPath = await _extractCover(filePath);
      
      // 计算章节数（只取第一级）
      final chapters = await getChapters(filePath);
      
      return BookMetadata(
        title: title,
        author: author,
        coverPath: coverPath,
        totalChapters: chapters.length,
        format: BookFormat.epub,
      );
    } catch (e) {
      _log.e('EpubParser', '解析失败', e);
      rethrow;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    _log.v('EpubParser', 'getChapters 开始执行');
    
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);
      
      List<EpubChapter> epubChapters = [];
      
      // 优先从导航获取章节
      if (epubBook.schema?.navigation?.navPoints != null) {
        epubChapters = epubBook.schema!.navigation!.navPoints!;
      } else if (epubBook.chapters != null) {
        epubChapters = epubBook.chapters!;
      }
      
      // 只取第一级章节，映射为统一Chapter
      final topLevelChapters = <Chapter>[];
      int index = 0;
      
      for (final epubChapter in epubChapters) {
        // 跳过嵌套章节（只取第一级）
        if (epubChapter is EpubNavigationPoint) {
          // 这是顶层章节
          topLevelChapters.add(Chapter(
            id: epubChapter.content?.source ?? 'chapter_$index',
            index: index,
            title: epubChapter.text ?? '第${index + 1}章',
            location: ChapterLocation(
              href: epubChapter.content?.source,
            ),
          ));
          index++;
        }
      }
      
      // 如果没找到章节，从内容文件生成
      if (topLevelChapters.isEmpty && epubBook.content?.html != null) {
        final htmlFiles = epubBook.content!.html!.keys.toList();
        for (int i = 0; i < htmlFiles.length; i++) {
          topLevelChapters.add(Chapter(
            id: htmlFiles[i],
            index: i,
            title: '第${i + 1}章',
            location: ChapterLocation(
              href: htmlFiles[i],
            ),
          ));
        }
      }
      
      return topLevelChapters;
    } catch (e) {
      _log.e('EpubParser', '获取章节失败', e);
      return [];
    }
  }

  @override
  Future<ChapterContent> getChapterContent(String filePath, Chapter chapter) async {
    _log.v('EpubParser', 'getChapterContent 开始执行, chapter: ${chapter.title}');
    
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);
      
      if (chapter.location.href == null) {
        throw Exception('章节href为空');
      }
      
      // 获取章节HTML内容
      final htmlContent = epubBook.content?.html?[chapter.location.href!];
      
      if (htmlContent == null) {
        throw Exception('章节内容不存在: ${chapter.location.href}');
      }
      
      // 提取纯文本（简单的HTML标签去除）
      final plainText = _htmlToPlainText(htmlContent);
      
      return ChapterContent(
        plainText: plainText,
        htmlContent: htmlContent,
      );
    } catch (e) {
      _log.e('EpubParser', '获取章节内容失败', e);
      rethrow;
    }
  }

  @override
  Future<String?> extractCover(String filePath) async {
    _log.v('EpubParser', 'extractCover 开始执行');
    
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);
      
      // 获取封面图片
      if (epubBook.coverImage != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final coversDir = Directory('${appDir.path}/covers');
        if (!coversDir.existsSync()) {
          coversDir.createSync(recursive: true);
        }
        
        final bookId = _uuid.v4();
        final coverPath = '${coversDir.path}/${bookId}.png';
        final coverFile = File(coverPath);
        
        await coverFile.writeAsBytes(epubBook.coverImage!);
        return coverPath;
      }
      
      return null;
    } catch (e) {
      _log.e('EpubParser', '提取封面失败', e);
      return null;
    }
  }
  
  String _htmlToPlainText(String html) {
    // 简单的HTML到文本转换
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
```

- [ ] **Step 2: Commit EpubParser**

```bash
git add lib/services/parsers/epub_parser.dart
git commit -m "feat: create EpubParser implementing BookFormatParser"
```

---

### Task 4: 重构PdfService为PdfParser

**Files:**
- Create: `lib/services/parsers/pdf_parser.dart`
- Reference: `lib/services/pdf_service.dart` (existing implementation)

- [ ] **Step 1: Create PdfParser class implementing BookFormatParser**

```dart
import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import '../../models/book.dart';
import '../../models/book_metadata.dart';
import '../../models/chapter.dart';
import '../../models/chapter_content.dart';
import '../../models/chapter_location.dart';
import 'book_format_parser.dart';
import '../log_service.dart';

class PdfParser implements BookFormatParser {
  final _log = LogService();

  @override
  Future<BookMetadata> parse(String filePath) async {
    _log.v('PdfParser', 'parse 开始执行, filePath: $filePath');
    
    try {
      final document = await PdfDocument.openFile(filePath);
      
      // 从文件名提取标题
      final fileName = filePath.split('/').last.split('\\').last;
      final title = fileName.substring(0, fileName.lastIndexOf('.'));
      
      // 获取章节数
      final chapters = await getChapters(filePath);
      
      await document.dispose();
      
      return BookMetadata(
        title: title,
        author: 'Unknown',
        coverPath: null, // PDF通常没有封面
        totalChapters: chapters.length,
        format: BookFormat.pdf,
      );
    } catch (e) {
      _log.e('PdfParser', '解析失败', e);
      rethrow;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    _log.v('PdfParser', 'getChapters 开始执行');
    
    try {
      final document = await PdfDocument.openFile(filePath);
      final totalPages = document.pages.length;
      
      // 收集所有页面的文本内容
      final pageContents = <String>[];
      for (int i = 0; i < totalPages; i++) {
        final page = document.pages[i];
        final pageText = await page.loadText();
        pageContents.add(pageText.fullText);
      }
      
      await document.dispose();
      
      // 检测章节边界
      final chapterBoundaries = <int>[0];
      final patterns = [
        r'第[一二三四五六七八九十百]+章',
        r'第\d+章',
        r'Chapter\s+\d+',
        r'CHAPTER\s+\d+',
      ];
      
      for (int i = 0; i < pageContents.length; i++) {
        final content = pageContents[i];
        for (final pattern in patterns) {
          final regex = RegExp(pattern, multiLine: true);
          if (regex.hasMatch(content)) {
            chapterBoundaries.add(i);
            break;
          }
        }
      }
      
      // 添加最后一页
      if (chapterBoundaries.last != totalPages - 1) {
        chapterBoundaries.add(totalPages - 1);
      }
      
      // 创建章节列表
      final chapters = <Chapter>[];
      for (int i = 0; i < chapterBoundaries.length - 1; i++) {
        final startPage = chapterBoundaries[i];
        final endPage = chapterBoundaries[i + 1];
        
        // 尝试从第一页提取章节标题
        String title = '第${i + 1}章';
        final firstPageContent = pageContents[startPage];
        for (final pattern in patterns) {
          final regex = RegExp(pattern, multiLine: true);
          final match = regex.firstMatch(firstPageContent);
          if (match != null) {
            title = match.group(0) ?? title;
            break;
          }
        }
        
        chapters.add(Chapter(
          id: 'pdf_chapter_$i',
          index: i,
          title: title,
          location: ChapterLocation(
            startPage: startPage + 1, // PDF页码从1开始
            endPage: endPage + 1,
          ),
        ));
      }
      
      return chapters;
    } catch (e) {
      _log.e('PdfParser', '获取章节失败', e);
      return [];
    }
  }

  @override
  Future<ChapterContent> getChapterContent(String filePath, Chapter chapter) async {
    _log.v('PdfParser', 'getChapterContent 开始执行, chapter: ${chapter.title}');
    
    try {
      final document = await PdfDocument.openFile(filePath);
      
      if (chapter.location.startPage == null) {
        throw Exception('章节startPage为空');
      }
      
      final startPage = chapter.location.startPage! - 1; // 转换为0-based
      final endPage = chapter.location.endPage != null 
          ? chapter.location.endPage! - 1 
          : startPage;
      
      // 收集章节内所有页面的文本
      final contents = <String>[];
      for (int i = startPage; i <= endPage && i < document.pages.length; i++) {
        final page = document.pages[i];
        final pageText = await page.loadText();
        contents.add(pageText.fullText);
      }
      
      await document.dispose();
      
      final plainText = contents.join('\n\n');
      
      return ChapterContent(
        plainText: plainText,
        htmlContent: null, // PDF不返回HTML
      );
    } catch (e) {
      _log.e('PdfParser', '获取章节内容失败', e);
      rethrow;
    }
  }

  @override
  Future<String?> extractCover(String filePath) async {
    // PDF通常没有独立封面图片
    return null;
  }
}
```

- [ ] **Step 2: Commit PdfParser**

```bash
git add lib/services/parsers/pdf_parser.dart
git commit -m "feat: create PdfParser implementing BookFormatParser"
```

---

### Task 5: 初始化FormatRegistry并修改BookService

**Files:**
- Modify: `lib/services/parsers/format_registry.dart`
- Modify: `lib/services/book_service.dart`

- [ ] **Step 1: Update FormatRegistry.initialize()**

```dart
import 'book_format_parser.dart';
import 'epub_parser.dart';
import 'pdf_parser.dart';

class FormatRegistry {
  static final Map<String, BookFormatParser> _parsers = {};
  
  static void register(String extension, BookFormatParser parser) {
    _parsers[extension.toLowerCase()] = parser;
  }
  
  static BookFormatParser? getParser(String extension) {
    return _parsers[extension.toLowerCase()];
  }
  
  static void initialize() {
    register('epub', EpubParser());
    register('pdf', PdfParser());
    // 未来格式在这里注册
  }
}
```

- [ ] **Step 2: Update BookService to use FormatRegistry**

```dart
// 在BookService类中添加
import 'parsers/format_registry.dart';

// 修改importBook方法
Future<Book?> importBook() async {
  _log.v('BookService', 'importBook 开始执行');
  try {
    _log.d('BookService', '开始导入书籍...');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf'],
      dialogTitle: '选择电子书',
    );

    if (result == null || result.files.isEmpty) {
      _log.d('BookService', '用户取消选择');
      return null;
    }

    final platformFile = result.files.first;
    final filePath = platformFile.path;

    if (filePath == null) {
      _log.w('BookService', '文件路径为空');
      return null;
    }

    _log.d('BookService', '选择的文件: $filePath');
    final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');

    // 使用FormatRegistry获取解析器
    final parser = FormatRegistry.getParser(extension);
    if (parser == null) {
      _log.w('BookService', '不支持的文件格式: $extension');
      return null;
    }

    _log.d('BookService', '开始解析${extension.toUpperCase()}...');
    final metadata = await parser.parse(filePath);
    _log.d('BookService', '解析结果: ${metadata.title}');

    // 创建Book对象
    final book = Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: metadata.title,
      author: metadata.author,
      filePath: filePath,
      coverPath: metadata.coverPath,
      format: metadata.format,
      totalChapters: metadata.totalChapters,
      currentChapter: 0,
      readingProgress: 0.0,
      addedAt: DateTime.now(),
    );

    // 检查是否已存在
    final existingBook = _books
        .where((b) => b.title == book.title && b.author == book.author)
        .firstOrNull;

    if (existingBook != null) {
      _log.d('BookService', '书籍已存在: ${book.title}');
      return existingBook;
    }

    // 保存到数据库
    await _db.into(_db.books).insert(_modelToCompanion(book));
    _books.add(book);
    _log.d('BookService', '书籍已添加到列表，当前书籍数量: ${_books.length}');

    return book;
  } catch (e, stackTrace) {
    _log.e('BookService', '导入书籍失败', e, stackTrace);
    return null;
  }
}

// 在init方法中初始化FormatRegistry
Future<void> init() async {
  _db = AppDatabase();
  FormatRegistry.initialize(); // 添加这一行
  _books = await _loadBooks();
  _log.d('BookService', '初始化完成，加载书籍数量: ${_books.length}');
}
```

- [ ] **Step 3: Commit BookService changes**

```bash
git add lib/services/parsers/format_registry.dart lib/services/book_service.dart
git commit -m "feat: integrate FormatRegistry into BookService"
```

---

### Task 6: 修改SummaryService统一处理所有格式

**Files:**
- Modify: `lib/services/summary_service.dart`

- [ ] **Step 1: Add import for FormatRegistry and new models**

```dart
import 'parsers/format_registry.dart';
import '../models/chapter.dart';
import '../models/chapter_content.dart';
```

- [ ] **Step 2: Remove old PDF-specific method and update generateSummariesForBook**

```dart
// 删除 _generateSummariesForPdf 方法

// 修改 generateSummariesForBook 方法
Future<void> generateSummariesForBook(Book book) async {
  if (!_aiService.isConfigured) {
    _log.w('SummaryService', 'AI服务未配置，跳过章节摘要生成');
    return;
  }

  final existingCount = await getSummaryCount(book.id);
  _log.d('SummaryService', '开始为书籍生成章节摘要: ${book.title}, 已有摘要: $existingCount');

  try {
    // 使用FormatRegistry获取解析器
    final extension = book.format.name.toLowerCase();
    final parser = FormatRegistry.getParser(extension);
    
    if (parser == null) {
      _log.w('SummaryService', '不支持的格式: $extension');
      return;
    }
    
    // 获取章节列表（所有格式统一处理）
    final chapters = await parser.getChapters(book.filePath);
    _log.d('SummaryService', '获取到 ${chapters.length} 个章节');

    // 检测是否有前言章节
    final prefaceIndex = _findPrefaceChapter(chapters);
    _log.d('SummaryService', '前言检测结果: prefaceIndex=$prefaceIndex');

    // 如果有前言且书籍没有介绍，直接从前言生成全书摘要
    if (prefaceIndex != null &&
        (book.aiIntroduction == null || book.aiIntroduction!.isEmpty)) {
      _log.d('SummaryService', '发现前言章节 $prefaceIndex，直接生成全书摘要');
      await _generateBookSummaryFromPreface(book, chapters[prefaceIndex], parser);
    }

    // 为每个章节生成摘要
    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];

      if (await hasSummary(book.id, i)) {
        _log.d('SummaryService', '章节 $i 已有摘要，跳过');
        continue;
      }

      final key = _key(book.id, i);
      if (_generatingKeys.contains(key)) {
        _log.d('SummaryService', '章节 $i 正在生成中，跳过');
        continue;
      }

      _generatingKeys.add(key);
      final future = _doGenerateChapterSummary(book, chapter, i, parser);
      _generatingFutures[key] = future;
      try {
        await future;
      } finally {
        _generatingKeys.remove(key);
        _generatingFutures.remove(key);
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    // 如果没有前言，生成全书摘要
    if (prefaceIndex == null &&
        (book.aiIntroduction == null || book.aiIntroduction!.isEmpty)) {
      await _generateBookSummary(book, chapters, parser);
    }

    _log.d('SummaryService', '书籍所有摘要生成完成: ${book.title}');
  } catch (e) {
    _log.e('SummaryService', '生成章节摘要失败', e);
  }
}
```

- [ ] **Step 3: Update helper methods to use parser**

```dart
// 修改 _findPrefaceChapter 参数类型
int? _findPrefaceChapter(List<Chapter> chapters) {
  final prefaceKeywords = [
    '前言', '序言', '序', '自序', '代序', '引言', '导言', '导读',
    'preface', 'foreword', 'introduction', 'prologue',
  ];

  for (int i = 0; i < chapters.length; i++) {
    final title = chapters[i].title.toLowerCase();
    for (final keyword in prefaceKeywords) {
      if (title.contains(keyword.toLowerCase())) {
        return i;
      }
    }
  }
  return null;
}

// 修改 _doGenerateChapterSummary 使用parser
Future<void> _doGenerateChapterSummary(
    Book book, Chapter chapter, int chapterIndex, BookFormatParser parser) async {
  try {
    final content = await parser.getChapterContent(book.filePath, chapter);
    
    if (content.plainText.isEmpty) {
      _log.w('SummaryService', '章节 $chapterIndex 内容为空，跳过');
      return;
    }

    final markdownSummary = await _aiService.generateFullChapterSummary(
      content.plainText,
      chapterTitle: chapter.title,
    );

    if (markdownSummary != null) {
      final chapterSummary = ChapterSummary(
        bookId: book.id,
        chapterIndex: chapterIndex,
        chapterTitle: chapter.title,
        objectiveSummary: markdownSummary,
        aiInsight: '',
        keyPoints: [],
        createdAt: DateTime.now(),
      );
      await saveSummary(chapterSummary);
      _log.d('SummaryService', '章节 $chapterIndex 摘要已保存');
    }
  } catch (e) {
    _log.e('SummaryService', '生成章节 $chapterIndex 摘要失败', e);
  }
}

// 修改 _generateBookSummaryFromPreface 使用parser
Future<void> _generateBookSummaryFromPreface(
    Book book, Chapter prefaceChapter, BookFormatParser parser) async {
  try {
    final content = await parser.getChapterContent(book.filePath, prefaceChapter);
    
    if (content.plainText.isEmpty) {
      _log.w('SummaryService', '前言内容为空，跳过');
      return;
    }

    final bookSummary = await _aiService.generateBookSummaryFromPreface(
      title: book.title,
      author: book.author,
      prefaceContent: content.plainText,
    );

    if (bookSummary != null) {
      final updatedBook = book.copyWith(aiIntroduction: bookSummary);
      await _bookService.updateBook(updatedBook);
      _log.d('SummaryService', '书籍全文摘要已从前言生成: ${book.title}');
    }
  } catch (e) {
    _log.e('SummaryService', '从前言生成全书摘要失败', e);
  }
}

// 修改 _generateBookSummary 使用parser
Future<void> _generateBookSummary(
    Book book, List<Chapter> chapters, BookFormatParser parser) async {
  try {
    // 收集前3章的摘要
    final summaries = <String>[];
    for (int i = 0; i < chapters.length && i < 3; i++) {
      final summary = await getSummary(book.id, i);
      if (summary != null) {
        summaries.add('${summary.chapterTitle}: ${summary.objectiveSummary}');
      }
    }

    if (summaries.isEmpty) {
      _log.w('SummaryService', '没有可用的章节摘要，无法生成全书摘要');
      return;
    }

    final bookSummary = await _aiService.generateBookSummary(
      title: book.title,
      author: book.author,
      chapterSummaries: summaries.join('\n\n'),
      totalChapters: chapters.length,
    );

    if (bookSummary != null) {
      final updatedBook = book.copyWith(aiIntroduction: bookSummary);
      await _bookService.updateBook(updatedBook);
      _log.d('SummaryService', '书籍全文摘要已生成: ${book.title}');
    }
  } catch (e) {
    _log.e('SummaryService', '生成全书摘要失败', e);
  }
}
```

- [ ] **Step 4: Remove old EpubService dependency from SummaryService**

```dart
// 删除这行
// final _epubService = EpubService();
```

- [ ] **Step 5: Commit SummaryService changes**

```bash
git add lib/services/summary_service.dart
git commit -m "refactor: unify summary generation for all formats using FormatRegistry"
```

---

### Task 7: 修改BookDetailScreen使用新的Chapter模型

**Files:**
- Modify: `lib/screens/book_detail_screen.dart`

- [ ] **Step 1: Update imports and ChapterInfo usage**

```dart
// 添加import
import '../models/chapter.dart';

// 修改 ChapterInfo 为 Chapter
List<Chapter> _flatChapters = [];
```

- [ ] **Step 2: Update _loadChapters method**

```dart
Future<void> _loadChapters() async {
  _log.v('BookDetailScreen', '_loadChapters 开始执行');
  try {
    // 使用FormatRegistry获取解析器
    final parser = FormatRegistry.getParser(_book.format.name);
    if (parser == null) {
      _log.e('BookDetailScreen', '不支持的格式: ${_book.format}');
      return;
    }
    
    final chapters = await parser.getChapters(_book.filePath);
    
    setState(() {
      _flatChapters = chapters;
      _isLoading = false;
    });
    
    _log.d('BookDetailScreen', '章节加载完成: ${chapters.length} 个章节');
  } catch (e) {
    _log.e('BookDetailScreen', '加载章节失败', e);
    setState(() {
      _isLoading = false;
    });
  }
}
```

- [ ] **Step 3: Update _buildChapterTree method**

```dart
List<Widget> _buildChapterTree(List<Chapter> chapters, [int depth = 0]) {
  final widgets = <Widget>[];
  for (int i = 0; i < chapters.length; i++) {
    final chapter = chapters[i];
    widgets.add(
      ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 16.0, right: 16.0),
        title: Text(
          chapter.title,
          style: TextStyle(
            fontWeight: depth == 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SummaryScreen(
                bookId: _book.id,
                chapterIndex: chapter.index, // 使用chapter.index
                chapterTitle: chapter.title,
                filePath: _book.filePath,
                chapters: _flatChapters, // 传递Chapter列表
                book: _book,
              ),
            ),
          );
        },
      ),
    );
  }
  return widgets;
}
```

- [ ] **Step 4: Commit BookDetailScreen changes**

```bash
git add lib/screens/book_detail_screen.dart
git commit -m "refactor: update BookDetailScreen to use new Chapter model"
```

---

### Task 8: 修改SummaryScreen使用新的Chapter模型

**Files:**
- Modify: `lib/screens/summary_screen.dart`

- [ ] **Step 1: Update imports and ChapterInfo to Chapter**

```dart
// 添加import
import '../models/chapter.dart';

// 修改参数类型
final List<Chapter>? chapters;
List<Chapter> _chapters = [];
```

- [ ] **Step 2: Update initState to remove level filtering**

```dart
@override
void initState() {
  super.initState();
  // 直接使用所有章节（已经是扁平化的）
  if (widget.chapters != null) {
    _chapters = widget.chapters!;
  }
  
  _title = widget.chapterTitle;
  _loadSummary();
  _loadContent();
}
```

- [ ] **Step 3: Update _loadContent method**

```dart
Future<void> _loadContent() async {
  setState(() {
    _isLoadingContent = true;
  });

  try {
    if (widget.book != null) {
      // 使用FormatRegistry获取解析器
      final parser = FormatRegistry.getParser(widget.book!.format.name);
      if (parser != null && widget.chapterIndex < _chapters.length) {
        final chapter = _chapters[widget.chapterIndex];
        final content = await parser.getChapterContent(
          widget.filePath ?? widget.book!.filePath,
          chapter,
        );
        
        setState(() {
          _content = content.htmlContent ?? content.plainText;
          _contentTooShort = content.plainText.length < 100;
        });
      }
    }
  } catch (e) {
    _log.e('SummaryScreen', '加载内容失败', e);
    setState(() {
      _error = '加载内容失败: $e';
    });
  } finally {
    setState(() {
      _isLoadingContent = false;
    });
  }
}
```

- [ ] **Step 4: Commit SummaryScreen changes**

```bash
git add lib/screens/summary_screen.dart
git commit -m "refactor: update SummaryScreen to use new Chapter model"
```

---

### Task 9: 清理旧代码和运行测试

**Files:**
- Reference: `lib/services/epub_service.dart` (keep for now, deprecate later)
- Reference: `lib/services/pdf_service.dart` (keep for now, deprecate later)

- [ ] **Step 1: Run flutter analyze to check for errors**

```bash
flutter analyze
```
Expected: No critical errors

- [ ] **Step 2: Test the application**

```bash
flutter run -d windows
```

- [ ] **Step 3: Verify functionality**
- Import EPUB book - should work as before
- Import PDF book - should work with new architecture
- Navigate chapters - should show flat list
- Generate AI summaries - should work for both formats

- [ ] **Step 4: Commit any final fixes**

```bash
git add .
git commit -m "fix: address any issues found during testing"
```

---

### Task 10: 添加导出和文档

**Files:**
- Modify: `lib/services/parsers/parsers.dart` (create barrel export)

- [ ] **Step 1: Create barrel export file**

```dart
export 'book_format_parser.dart';
export 'format_registry.dart';
export 'epub_parser.dart';
export 'pdf_parser.dart';
```

- [ ] **Step 2: Update main.dart to initialize FormatRegistry**

```dart
// 在main()函数中确保FormatRegistry已初始化
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化格式注册表
  FormatRegistry.initialize();
  
  // 初始化其他服务...
  await BookService().init();
  await SummaryService().init();
  
  runApp(const MyApp());
}
```

- [ ] **Step 3: Final commit**

```bash
git add lib/services/parsers/parsers.dart lib/main.dart
git commit -m "feat: add barrel exports and ensure FormatRegistry initialization"
```

---

## Summary

This refactoring achieves:

1. **Unified Architecture**: All formats implement BookFormatParser interface
2. **Format Decoupling**: Reading and AI flows are completely format-agnostic
3. **Simplified Model**: Flat chapter list for all formats
4. **Backward Compatibility**: EPUB functionality preserved
5. **Future Extensibility**: New formats only need to implement the interface

## Testing Checklist

- [ ] EPUB import works correctly
- [ ] PDF import works correctly  
- [ ] Chapter navigation works for both formats
- [ ] AI summary generation works for both formats
- [ ] Cover extraction works for EPUB
- [ ] No errors in flutter analyze
- [ ] Application builds successfully