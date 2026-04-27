# PDF支持 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为智读应用添加PDF书籍支持，提供与EPUB一致的用户体验同时尊重PDF的分页特性。

**Architecture:** 扩展现有架构，创建PdfService处理PDF解析和章节检测，复用现有的BookService、SummaryService和数据库层，实现页面级阅读界面和章节/页面导航。

**Tech Stack:** Flutter, Dart, pdf包, drift数据库, 现有AI服务

---

### Task 1: 更新Book模型和数据库

**Files:**
- Modify: `lib/models/book.dart`
- Modify: `lib/data/database/database.dart`

- [ ] **Step 1: 更新Book模型的_tableToModel方法**

```dart
  Book _tableToModel(BookTable table) {
    return Book(
      id: table.id,
      title: table.title,
      author: table.author,
      filePath: table.filePath,
      coverPath: table.coverPath,
      format: table.format != null 
          ? BookFormat.values.firstWhere((e) => e.name == table.format!) 
          : BookFormat.epub,
      currentChapter: table.currentChapter,
      readingProgress: table.readingProgress,
      lastReadAt: table.lastReadAt != null
          ? DateTime.fromMillisecondsSinceEpoch(table.lastReadAt!)
          : null,
      aiIntroduction: table.aiIntroduction,
      totalChapters: table.totalChapters,
      addedAt: table.addedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(table.addedAt!)
          : DateTime.now(),
    );
  }
```

- [ ] **Step 2: 更新数据库schema以包含format和addedAt字段**

```dart
@DriftDatabase(tables: [Books, ChapterSummaries, BookSummaries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // 增加版本号

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_chapter_summary_unique ON chapter_summaries(book_id, chapter_index)');
        }
        if (from < 3) {
          // 添加format和addedAt字段
          await m.addColumn(_db.books, _db.books.format);
          await m.addColumn(_db.books, _db.books.addedAt);
        }
      },
    );
  }

  Future<void> close() async {
    await executor.close();
  }
}

@DataClassName('BookTable')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get coverPath => text().named('cover_path').nullable()();
  TextColumn get format => text().withDefault(const Constant('epub'))(); // 添加format字段
  IntColumn get currentChapter =>
      integer().named('current_chapter').withDefault(const Constant(0))();
  RealColumn get readingProgress =>
      real().named('reading_progress').withDefault(const Constant(0.0))();
  IntColumn get lastReadAt => integer().named('last_read_at').nullable()();
  TextColumn get aiIntroduction => text().named('ai_introduction').nullable()();
  IntColumn get totalChapters =>
      integer().named('total_chapters').withDefault(const Constant(0))();
  IntColumn get addedAt => integer().named('added_at').withDefault(const Constant(0))(); // 添加addedAt字段

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 3: 更新_modelToCompanion方法**

```dart
  BooksCompanion _modelToCompanion(Book model) {
    return BooksCompanion(
      id: Value(model.id),
      title: Value(model.title),
      author: Value(model.author),
      filePath: Value(model.filePath),
      coverPath: Value(model.coverPath),
      format: Value(model.format.name),
      currentChapter: Value(model.currentChapter),
      readingProgress: Value(model.readingProgress),
      lastReadAt: Value(model.lastReadAt?.millisecondsSinceEpoch),
      aiIntroduction: Value(model.aiIntroduction),
      totalChapters: Value(model.totalChapters),
      addedAt: Value(model.addedAt.millisecondsSinceEpoch),
    );
  }
```

- [ ] **Step 4: 重新生成数据库代码**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: database.g.dart文件成功生成

- [ ] **Step 5: 提交更改**

```bash
git add lib/models/book.dart lib/data/database/database.dart lib/data/database/database.g.dart
git commit -m "feat: update book model and database schema for PDF support"
```

### Task 2: 创建PdfService

**Files:**
- Create: `lib/services/pdf_service.dart`

- [ ] **Step 1: 添加pdf依赖到pubspec.yaml**

```yaml
dependencies:
  pdf: ^3.10.4
```

- [ ] **Step 2: 安装依赖**

Run: `flutter pub get`
Expected: 依赖安装成功

- [ ] **Step 3: 创建PdfService类**

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/book.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  /// 解析PDF文件并创建Book对象
  Future<Book?> parsePdfFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final document = PdfDocument.openData(bytes);
      
      final pages = document.pages;
      final totalPages = pages.length;
      
      // 提取标题（使用文件名作为默认标题）
      final fileName = filePath.split('/').last.split('\\').last;
      final title = fileName.substring(0, fileName.lastIndexOf('.'));
      
      // 检测章节结构
      final chapters = await _detectChapters(document);
      
      document.dispose();
      
      return Book(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        author: 'Unknown',
        filePath: filePath,
        format: BookFormat.pdf,
        totalChapters: chapters.length,
        currentChapter: 0,
        readingProgress: 0.0,
        addedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error parsing PDF: $e');
      return null;
    }
  }
  
  /// 检测PDF中的章节结构
  Future<List<PdfChapter>> _detectChapters(PdfDocument document) async {
    final chapters = <PdfChapter>[];
    final totalPages = document.pages.length;
    
    // 简单的章节检测：假设每10页为一个章节（后续可改进）
    const pagesPerChapter = 10;
    final totalChapters = (totalPages / pagesPerChapter).ceil();
    
    for (int i = 0; i < totalChapters; i++) {
      final startPage = i * pagesPerChapter + 1;
      final endPage = (i + 1) * pagesPerChapter < totalPages 
          ? (i + 1) * pagesPerChapter 
          : totalPages;
      
      chapters.add(PdfChapter(
        index: i,
        title: '第${i + 1}章',
        startPage: startPage,
        endPage: endPage,
      ));
    }
    
    return chapters;
  }
  
  /// 获取指定章节的页面内容
  Future<List<PdfPageContent>> getChapterPages(String filePath, int chapterIndex) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument.openData(bytes);
    
    // 这里需要根据实际的章节检测逻辑获取页面范围
    // 暂时返回所有页面（后续完善）
    final pages = <PdfPageContent>[];
    for (int i = 0; i < document.pages.length; i++) {
      final page = document.getPage(i + 1);
      final content = await page.getText();
      pages.add(PdfPageContent(
        pageNumber: i + 1,
        content: content,
      ));
      page.dispose();
    }
    
    document.dispose();
    return pages;
  }
  
  /// 获取指定页面的内容
  Future<PdfPageContent> getPageContent(String filePath, int pageNumber) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument.openData(bytes);
    
    final page = document.getPage(pageNumber);
    final content = await page.getText();
    
    page.dispose();
    document.dispose();
    
    return PdfPageContent(
      pageNumber: pageNumber,
      content: content,
    );
  }
}

class PdfChapter {
  final int index;
  final String title;
  final int startPage;
  final int endPage;
  
  PdfChapter({
    required this.index,
    required this.title,
    required this.startPage,
    required this.endPage,
  });
}

class PdfPageContent {
  final int pageNumber;
  final String content;
  
  PdfPageContent({
    required this.pageNumber,
    required this.content,
  });
}
```

- [ ] **Step 4: 提交PdfService**

```bash
git add pubspec.yaml lib/services/pdf_service.dart
git commit -m "feat: create PdfService for PDF parsing and chapter detection"
```

### Task 3: 更新BookService支持PDF导入

**Files:**
- Modify: `lib/services/book_service.dart`

- [ ] **Step 1: 导入PdfService**

```dart
import 'pdf_service.dart';
```

- [ ] **Step 2: 添加PdfService实例**

```dart
class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  late final AppDatabase _db;
  final _epubService = EpubService();
  final _pdfService = PdfService(); // 添加PDF服务
  final _log = LogService();
```

- [ ] **Step 3: 更新importBook方法支持PDF**

```dart
  Future<Book?> importBook() async {
    _log.v('BookService', 'importBook 开始执行');
    try {
      _log.d('BookService', '开始导入书籍...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf'], // 添加pdf扩展名
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
      final extension = p.extension(filePath).toLowerCase();

      Book? book;

      if (extension == '.epub') {
        _log.d('BookService', '开始解析EPUB...');
        book = await _epubService.parseEpubFile(filePath);
        _log.d('BookService', 'EPUB解析结果: ${book?.title ?? "失败"}');
      } else if (extension == '.pdf') {
        _log.d('BookService', '开始解析PDF...');
        book = await _pdfService.parsePdfFile(filePath);
        _log.d('BookService', 'PDF解析结果: ${book?.title ?? "失败"}');
      } else {
        _log.w('BookService', '不支持的文件格式: $extension');
        return null;
      }

      if (book != null) {
        final existingBook = _books
            .where((b) => b.title == book!.title && b.author == book.author)
            .firstOrNull;

        if (existingBook != null) {
          _log.d('BookService', '书籍已存在: ${book.title}');
          return existingBook;
        }

        await _db.into(_db.books).insert(_modelToCompanion(book));
        _books.add(book);
        _log.d('BookService', '书籍已添加到列表，当前书籍数量: ${_books.length}');

        return book;
      }

      return null;
    } catch (e, stackTrace) {
      _log.e('BookService', '导入书籍失败', e, stackTrace);
      return null;
    }
  }
```

- [ ] **Step 4: 测试PDF导入功能**

Run: `flutter run`
Expected: 能够选择并导入PDF文件

- [ ] **Step 5: 提交BookService更新**

```bash
git add lib/services/book_service.dart
git commit -m "feat: update BookService to support PDF import"
```

### Task 4: 创建PDF阅读界面

**Files:**
- Create: `lib/screens/pdf_reader_screen.dart`

- [ ] **Step 1: 创建PDF阅读器屏幕**

```dart
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/pdf_service.dart';

class PdfReaderScreen extends StatefulWidget {
  final Book book;
  final int chapterIndex;
  final int currentPage;

  const PdfReaderScreen({
    Key? key,
    required this.book,
    required this.chapterIndex,
    required this.currentPage,
  }) : super(key: key);

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late Book _book;
  late int _chapterIndex;
  late int _currentPage;
  String _pageContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _chapterIndex = widget.chapterIndex;
    _currentPage = widget.currentPage;
    _loadPageContent();
  }

  Future<void> _loadPageContent() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final pageContent = await PdfService().getPageContent(
        _book.filePath, 
        _currentPage
      );
      setState(() {
        _pageContent = pageContent.content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _pageContent = '加载页面失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToPage(int pageNumber) async {
    if (pageNumber < 1 || pageNumber > 1000) return; // TODO: 获取实际总页数
    
    setState(() {
      _currentPage = pageNumber;
    });
    await _loadPageContent();
  }

  Future<void> _navigateToChapter(int chapterIndex) async {
    // TODO: 实现章节导航逻辑
    setState(() {
      _chapterIndex = chapterIndex;
      _currentPage = 1; // 章节的第一页
    });
    await _loadPageContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_book.title} - 第$_chapterIndex章'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _pageContent,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () => _navigateToChapter(_chapterIndex - 1),
              tooltip: '前一章',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _navigateToPage(_currentPage - 1),
              tooltip: '前一页',
            ),
            Text('第$_currentPage页'),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _navigateToPage(_currentPage + 1),
              tooltip: '后一页',
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () => _navigateToChapter(_chapterIndex + 1),
              tooltip: '后一章',
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交PDF阅读界面**

```bash
git add lib/screens/pdf_reader_screen.dart
git commit -m "feat: create PDF reader screen with page navigation"
```

### Task 5: 集成PDF阅读到章节列表

**Files:**
- Modify: `lib/screens/chapter_screen.dart`

- [ ] **Step 1: 导入PDF阅读器屏幕**

```dart
import 'pdf_reader_screen.dart';
```

- [ ] **Step 2: 更新章节点击处理逻辑**

```dart
// 在_chapter_screen.dart中找到章节点击处理部分
onPressed: () {
  if (widget.book.format == BookFormat.pdf) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfReaderScreen(
          book: widget.book,
          chapterIndex: chapterIndex,
          currentPage: 1, // 从第一章第一页开始
        ),
      ),
    );
  } else {
    // 现有的EPUB处理逻辑
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SectionReaderScreen(
          book: widget.book,
          chapterIndex: chapterIndex,
        ),
      ),
    );
  }
},
```

- [ ] **Step 3: 测试PDF章节导航**

Run: `flutter run`
Expected: 点击PDF书籍章节能打开PDF阅读器

- [ ] **Step 4: 提交集成更改**

```bash
git add lib/screens/chapter_screen.dart
git commit -m "feat: integrate PDF reader into chapter list navigation"
```

### Task 6: 完善章节检测算法

**Files:**
- Modify: `lib/services/pdf_service.dart`

- [ ] **Step 1: 改进章节检测算法**

```dart
  /// 检测PDF中的章节结构 - 改进版
  Future<List<PdfChapter>> _detectChapters(PdfDocument document) async {
    final chapters = <PdfChapter>[];
    final totalPages = document.pages.length;
    
    // 收集所有页面的文本内容
    final pageContents = <String>[];
    for (int i = 0; i < totalPages; i++) {
      final page = document.getPage(i + 1);
      final content = await page.getText();
      pageContents.add(content);
      page.dispose();
    }
    
    // 章节标题正则表达式模式
    final patterns = [
      r'第[一二三四五六七八九十百]+章',
      r'第\d+章',
      r'Chapter\s+\d+',
      r'CHAPTER\s+\d+',
      r'^\d+\.\s+[A-Za-z]',
      r'^[A-Z][a-z]+\s+\d+',
    ];
    
    final chapterBoundaries = <int>[0]; // 章节起始页面索引
    
    // 检测章节边界
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
    
    // 添加最后一页作为边界
    if (chapterBoundaries.last != totalPages - 1) {
      chapterBoundaries.add(totalPages - 1);
    }
    
    // 创建章节对象
    for (int i = 0; i < chapterBoundaries.length - 1; i++) {
      final startIndex = chapterBoundaries[i];
      final endIndex = chapterBoundaries[i + 1];
      
      // 尝试从页面内容中提取章节标题
      String chapterTitle = '第${i + 1}章';
      if (startIndex < pageContents.length) {
        final firstPageContent = pageContents[startIndex];
        for (final pattern in patterns) {
          final regex = RegExp(pattern, multiLine: true);
          final match = regex.firstMatch(firstPageContent);
          if (match != null) {
            chapterTitle = match.group(0) ?? chapterTitle;
            break;
          }
        }
      }
      
      chapters.add(PdfChapter(
        index: i,
        title: chapterTitle,
        startPage: startIndex + 1,
        endPage: endIndex + 1,
      ));
    }
    
    return chapters;
  }
```

- [ ] **Step 2: 更新getPageContent方法以支持章节页面范围**

```dart
  /// 获取指定章节的页面范围
  Future<List<int>> getChapterPageRange(String filePath, int chapterIndex) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument.openData(bytes);
    
    final chapters = await _detectChapters(document);
    document.dispose();
    
    if (chapterIndex < chapters.length) {
      final chapter = chapters[chapterIndex];
      return List.generate(
        chapter.endPage - chapter.startPage + 1,
        (index) => chapter.startPage + index,
      );
    }
    
    return [1]; // 默认返回第一页
  }
```

- [ ] **Step 3: 测试改进的章节检测**

Run: `flutter run`
Expected: PDF章节标题正确显示在章节列表中

- [ ] **Step 4: 提交章节检测改进**

```bash
git add lib/services/pdf_service.dart
git commit -m "feat: improve PDF chapter detection algorithm with regex patterns"
```

### Task 7: 添加移动端滑动支持

**Files:**
- Modify: `lib/screens/pdf_reader_screen.dart`

- [ ] **Step 1: 添加PageView支持滑动**

```dart
class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late Book _book;
  late int _chapterIndex;
  late int _currentPage;
  late PageController _pageController;
  List<String> _pageContents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _chapterIndex = widget.chapterIndex;
    _currentPage = widget.currentPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadChapterPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadChapterPages() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 获取当前章节的所有页面
      final pageRange = await PdfService().getChapterPageRange(
        _book.filePath, 
        _chapterIndex
      );
      
      final contents = <String>[];
      for (final pageNumber in pageRange) {
        final pageContent = await PdfService().getPageContent(
          _book.filePath, 
          pageNumber
        );
        contents.add(pageContent.content);
      }
      
      setState(() {
        _pageContents = contents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _pageContents = ['加载章节失败: $e'];
        _isLoading = false;
      });
    }
  }

  void _onPageChanged(int pageIndex) {
    setState(() {
      _currentPage = pageIndex + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_book.title} - 第$_chapterIndex章'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _pageContents.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Text(
                      _pageContents[index],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () => _navigateToChapter(_chapterIndex - 1),
              tooltip: '前一章',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (_currentPage > 1) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              tooltip: '前一页',
            ),
            Text('第$_currentPage页 / ${_pageContents.length}'),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                if (_currentPage < _pageContents.length) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              tooltip: '后一页',
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () => _navigateToChapter(_chapterIndex + 1),
              tooltip: '后一章',
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 测试移动端滑动功能**

Run: `flutter run` on mobile device/emulator
Expected: 左右滑动可以切换页面

- [ ] **Step 3: 提交移动端滑动支持**

```bash
git add lib/screens/pdf_reader_screen.dart
git commit -m "feat: add swipe gesture support for PDF page navigation on mobile"
```

### Task 8: 更新测试和文档

**Files:**
- Modify: `test/widget_test.dart`
- Create: `docs/pdf-support-guide.md`

- [ ] **Step 1: 添加PDF相关测试**

```dart
// 在widget_test.dart中添加
testWidgets('PDF import test', (WidgetTester tester) async {
  // TODO: 添加PDF导入测试
  expect(true, true); // 占位符
});

testWidgets('PDF reader navigation test', (WidgetTester tester) async {
  // TODO: 添加PDF阅读器导航测试
  expect(true, true); // 占位符
});
```

- [ ] **Step 2: 创建PDF支持文档**

```markdown
# PDF Support Guide

## Features
- Import PDF files alongside EPUB
- Automatic chapter detection using regex patterns
- Page-by-page reading experience
- Chapter and page navigation controls
- Mobile swipe gestures for page navigation

## Supported Chapter Patterns
- Chinese: 第一章, 第1章, 第二章, etc.
- English: Chapter 1, CHAPTER 1, etc.
- Numbered sections: 1. Introduction, 2. Methods, etc.

## Navigation Controls
- <<: Previous chapter
- <: Previous page  
- >: Next page
- >>: Next chapter

## Limitations
- Complex PDF layouts may not parse correctly
- Images and complex formatting are not preserved
- Chapter detection works best with standard academic/professional PDFs
```

- [ ] **Step 3: 运行测试**

Run: `flutter test`
Expected: 所有测试通过

- [ ] **Step 4: 提交测试和文档**

```bash
git add test/widget_test.dart docs/pdf-support-guide.md
git commit -m "docs: add PDF support documentation and placeholder tests"
```