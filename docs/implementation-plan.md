# 文件存储架构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将SQLite数据库架构改为基于文件的存储方案，所有数据保存在Documents/zhidu目录下

**Architecture:** 使用JSON存储元数据，Markdown存储摘要，按UUID分目录组织

**Tech Stack:** Flutter, path_provider, dart:io, dart:convert

---

## 文件结构规划

### 创建的新文件
1. `lib/services/file_storage_service.dart` - 文件操作基础服务
2. `lib/services/storage_config.dart` - 存储配置和路径管理

### 修改的现有文件
1. `lib/services/book_service.dart` - 重构为文件存储
2. `lib/services/summary_service.dart` - 重构为文件存储
3. `lib/main.dart` - 移除数据库初始化
4. `pubspec.yaml` - 移除数据库依赖

### 删除的文件
1. `lib/data/database/database.dart`
2. `lib/data/database/database.g.dart`
3. `lib/data/database/` 目录

---

## Task 1: 创建存储配置和路径管理

**Files:**
- Create: `lib/services/storage_config.dart`

**Description:** 创建存储配置类，管理应用数据目录路径

- [ ] **Step 1: 创建StorageConfig类**

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageConfig {
  static Directory? _appDir;
  
  /// 获取应用数据根目录: Documents/zhidu/
  static Future<Directory> getAppDirectory() async {
    if (_appDir != null) return _appDir!;
    
    final docsDir = await getApplicationDocumentsDirectory();
    _appDir = Directory(p.join(docsDir.path, 'zhidu'));
    
    if (!await _appDir!.exists()) {
      await _appDir!.create(recursive: true);
    }
    
    return _appDir!;
  }
  
  /// 获取书籍索引文件路径: Documents/zhidu/books.json
  static Future<String> getBooksIndexPath() async {
    final appDir = await getAppDirectory();
    return p.join(appDir.path, 'books.json');
  }
  
  /// 获取书籍目录: Documents/zhidu/books/{bookId}/
  static Future<Directory> getBookDirectory(String bookId) async {
    final appDir = await getAppDirectory();
    final bookDir = Directory(p.join(appDir.path, 'books', bookId));
    
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    
    return bookDir;
  }
  
  /// 获取书籍元数据文件路径
  static Future<String> getBookMetadataPath(String bookId) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(bookDir.path, 'metadata.json');
  }
  
  /// 获取书籍摘要文件路径
  static Future<String> getBookSummaryPath(String bookId) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(bookDir.path, 'summary.md');
  }
  
  /// 获取章节摘要文件路径
  static Future<String> getChapterSummaryPath(String bookId, int chapterIndex) async {
    final bookDir = await getBookDirectory(bookId);
    return p.join(bookDir.path, 'chapter-${chapterIndex.toString().padLeft(3, '0')}.md');
  }
}
```

- [ ] **Step 2: 验证代码编译**

Run: `flutter analyze lib/services/storage_config.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/storage_config.dart
git commit -m "feat: add storage config for file-based storage"
```

---

## Task 2: 创建文件存储基础服务

**Files:**
- Create: `lib/services/file_storage_service.dart`

**Description:** 创建文件操作基础服务，封装JSON和文件的读写操作

- [ ] **Step 1: 创建FileStorageService类**

```dart
import 'dart:convert';
import 'dart:io';
import 'log_service.dart';

class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();
  factory FileStorageService() => _instance;
  FileStorageService._internal();
  
  final _log = LogService();
  
  /// 读取JSON文件
  Future<Map<String, dynamic>?> readJson(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _log.v('FileStorageService', '文件不存在: $filePath');
        return null;
      }
      
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '读取JSON失败: $filePath', e, stackTrace);
      return null;
    }
  }
  
  /// 写入JSON文件
  Future<bool> writeJson(String filePath, Map<String, dynamic> data) async {
    try {
      final file = File(filePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      const encoder = JsonEncoder.withIndent('  ');
      final content = encoder.convert(data);
      await file.writeAsString(content, flush: true);
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '写入JSON失败: $filePath', e, stackTrace);
      return false;
    }
  }
  
  /// 读取文本文件（Markdown）
  Future<String?> readText(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '读取文本失败: $filePath', e, stackTrace);
      return null;
    }
  }
  
  /// 写入文本文件（Markdown）
  Future<bool> writeText(String filePath, String content) async {
    try {
      final file = File(filePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      await file.writeAsString(content, flush: true);
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '写入文本失败: $filePath', e, stackTrace);
      return false;
    }
  }
  
  /// 删除文件
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '删除文件失败: $filePath', e, stackTrace);
      return false;
    }
  }
  
  /// 删除目录及其内容
  Future<bool> deleteDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '删除目录失败: $dirPath', e, stackTrace);
      return false;
    }
  }
  
  /// 检查文件是否存在
  Future<bool> exists(String filePath) async {
    return await File(filePath).exists();
  }
  
  /// 列出目录下的文件
  Future<List<File>> listFiles(String dirPath, {String? extension}) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return [];
      }
      
      final files = await dir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      
      if (extension != null) {
        return files.where((f) => f.path.endsWith(extension)).toList();
      }
      
      return files;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '列出文件失败: $dirPath', e, stackTrace);
      return [];
    }
  }
}
```

- [ ] **Step 2: 验证代码编译**

Run: `flutter analyze lib/services/file_storage_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/file_storage_service.dart
git commit -m "feat: add file storage service"
```

---

## Task 3: 重构BookService为文件存储

**Files:**
- Modify: `lib/services/book_service.dart`

**Description:** 将BookService从SQLite改为文件存储

- [ ] **Step 1: 修改BookService类**

```dart
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/book.dart';
import 'epub_service.dart';
import 'pdf_service.dart';
import 'log_service.dart';
import 'storage_config.dart';
import 'file_storage_service.dart';

class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  final _epubService = EpubService();
  final _pdfService = PdfService();
  final _log = LogService();
  final _fileStorage = FileStorageService();

  List<Book> _books = [];
  List<Book> get books => _books;

  Future<void> init() async {
    _log.v('BookService', 'init 开始执行');
    await _loadBooks();
    _log.v('BookService', 'init 执行完成, 加载书籍数量: ${_books.length}');
  }

  Future<void> _loadBooks() async {
    final indexPath = await StorageConfig.getBooksIndexPath();
    final data = await _fileStorage.readJson(indexPath);
    
    if (data == null) {
      _books = [];
      return;
    }
    
    final booksList = data['books'] as List<dynamic>? ?? [];
    _books = [];
    
    for (final bookJson in booksList) {
      final bookId = bookJson['id'] as String?;
      if (bookId == null) continue;
      
      // 读取完整元数据
      final metadataPath = await StorageConfig.getBookMetadataPath(bookId);
      final metadata = await _fileStorage.readJson(metadataPath);
      
      if (metadata != null) {
        _books.add(_jsonToBook(metadata));
      }
    }
    
    _log.d('BookService', '从文件加载了 ${_books.length} 本书');
  }

  Future<void> _saveBooksIndex() async {
    final indexPath = await StorageConfig.getBooksIndexPath();
    final data = {
      'version': '1.0',
      'lastUpdated': DateTime.now().toIso8601String(),
      'books': _books.map((b) => {
        'id': b.id,
        'title': b.title,
        'author': b.author,
        'format': b.format.name,
        'originalFilePath': b.filePath,
        'addedAt': b.addedAt.toIso8601String(),
      }).toList(),
    };
    await _fileStorage.writeJson(indexPath, data);
  }

  Future<void> _saveBookMetadata(Book book) async {
    final metadataPath = await StorageConfig.getBookMetadataPath(book.id);
    final data = _bookToJson(book);
    await _fileStorage.writeJson(metadataPath, data);
  }

  Book _jsonToBook(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      filePath: json['originalFilePath'] as String,
      format: BookFormat.values.firstWhere(
        (f) => f.name == json['format'],
        orElse: () => BookFormat.epub,
      ),
      coverPath: json['coverPath'] as String?,
      currentChapter: json['currentChapterIndex'] as int? ?? 0,
      aiIntroduction: json['aiIntroduction'] as String?,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  Map<String, dynamic> _bookToJson(Book book) {
    return {
      'id': book.id,
      'title': book.title,
      'author': book.author,
      'format': book.format.name,
      'originalFilePath': book.filePath,
      'coverPath': book.coverPath,
      'currentChapterIndex': book.currentChapter,
      'aiIntroduction': book.aiIntroduction,
      'addedAt': book.addedAt.toIso8601String(),
    };
  }

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
        // 检查是否已存在
        final existingBook = _books
            .where((b) => b.title == book!.title && b.author == book.author)
            .firstOrNull;

        if (existingBook != null) {
          _log.i('BookService', '书籍已存在: ${book.title}');
          return existingBook;
        }

        // 保存书籍
        _books.add(book);
        await _saveBooksIndex();
        await _saveBookMetadata(book);
        
        _log.i('BookService', '书籍导入成功: ${book.title}');
        return book;
      }

      return null;
    } catch (e, stackTrace) {
      _log.e('BookService', '导入书籍失败', e, stackTrace);
      return null;
    }
  }

  Book? getBookById(String id) {
    return _books.where((b) => b.id == id).firstOrNull;
  }

  Future<bool> deleteBook(String id) async {
    _log.d('BookService', '删除书籍: $id');
    try {
      final book = getBookById(id);
      if (book == null) {
        _log.w('BookService', '要删除的书籍不存在: $id');
        return false;
      }

      // 删除书籍数据目录
      final bookDir = await StorageConfig.getBookDirectory(id);
      await _fileStorage.deleteDirectory(bookDir.path);

      // 从列表中移除
      _books.removeWhere((b) => b.id == id);
      await _saveBooksIndex();

      _log.i('BookService', '书籍删除成功: ${book.title}');
      return true;
    } catch (e, stackTrace) {
      _log.e('BookService', '删除书籍失败: $id', e, stackTrace);
      return false;
    }
  }

  Future<void> updateBook(Book book) async {
    _log.d('BookService', '更新书籍: ${book.title}');
    try {
      final index = _books.indexWhere((b) => b.id == book.id);
      if (index >= 0) {
        _books[index] = book;
        await _saveBooksIndex();
        await _saveBookMetadata(book);
        _log.d('BookService', '书籍更新成功: ${book.title}');
      }
    } catch (e, stackTrace) {
      _log.e('BookService', '更新书籍失败: ${book.id}', e, stackTrace);
    }
  }
}
```

- [ ] **Step 2: 验证代码编译**

Run: `flutter analyze lib/services/book_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/book_service.dart
git commit -m "refactor: migrate BookService from SQLite to file storage"
```

---

## Task 4: 重构SummaryService为文件存储

**Files:**
- Modify: `lib/services/summary_service.dart`

**Description:** 将SummaryService从SQLite改为文件存储

- [ ] **Step 1: 修改SummaryService类**

```dart
import 'dart:async';
import 'package:path/path.dart' as p;
import '../models/chapter_summary.dart';
import '../models/book.dart';
import 'ai_service.dart';
import 'book_service.dart';
import 'epub_service.dart';
import 'pdf_service.dart';
import 'log_service.dart';
import 'storage_config.dart';
import 'file_storage_service.dart';

class SummaryService {
  static final SummaryService _instance = SummaryService._internal();
  factory SummaryService() => _instance;
  SummaryService._internal();

  final _aiService = AIService();
  final _epubService = EpubService();
  final _pdfService = PdfService();
  final _bookService = BookService();
  final _log = LogService();
  final _fileStorage = FileStorageService();

  final Set<String> _generatingKeys = {};
  final Map<String, Future<void>> _generatingFutures = {};

  String _key(String bookId, int chapterIndex) => '${bookId}_$chapterIndex';

  bool isGenerating(String bookId, int chapterIndex) {
    return _generatingKeys.contains(_key(bookId, chapterIndex));
  }

  Future<void>? getGeneratingFuture(String bookId, int chapterIndex) {
    return _generatingFutures[_key(bookId, chapterIndex)];
  }

  Future<void> init() async {
    // 文件存储无需初始化
    _log.d('SummaryService', '文件存储模式，无需初始化');
  }

  Future<ChapterSummary?> getSummary(String bookId, int chapterIndex) async {
    _log.v('SummaryService',
        'getSummary 开始执行, bookId: $bookId, chapterIndex: $chapterIndex');

    try {
      final filePath = await StorageConfig.getChapterSummaryPath(bookId, chapterIndex);
      final content = await _fileStorage.readText(filePath);
      
      if (content == null || content.isEmpty) {
        _log.v('SummaryService', 'getSummary 加载完成, result: 空');
        return null;
      }

      final summary = ChapterSummary(
        bookId: bookId,
        chapterIndex: chapterIndex,
        objectiveSummary: content,
        createdAt: DateTime.now(),
      );
      
      _log.v('SummaryService', 'getSummary 加载完成, result: 有内容');
      return summary;
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'getSummary 失败', e, stackTrace);
      return null;
    }
  }

  Future<void> saveSummary(ChapterSummary summary) async {
    try {
      final filePath = await StorageConfig.getChapterSummaryPath(
          summary.bookId, summary.chapterIndex);
      await _fileStorage.writeText(filePath, summary.objectiveSummary);
      _log.d('SummaryService',
          '摘要已保存: ${summary.bookId}_${summary.chapterIndex}');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'saveSummary 失败', e, stackTrace);
    }
  }

  Future<void> deleteSummary(String bookId, int chapterIndex) async {
    try {
      final filePath = await StorageConfig.getChapterSummaryPath(bookId, chapterIndex);
      await _fileStorage.deleteFile(filePath);
      _log.d('SummaryService', '摘要已删除: ${bookId}_$chapterIndex');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'deleteSummary 失败', e, stackTrace);
    }
  }

  Future<List<ChapterSummary>> getSummariesForBook(String bookId) async {
    try {
      final bookDir = await StorageConfig.getBookDirectory(bookId);
      final files = await _fileStorage.listFiles(bookDir.path, extension: '.md');
      
      final summaries = <ChapterSummary>[];
      
      for (final file in files) {
        final filename = p.basename(file.path);
        if (filename.startsWith('chapter-') && filename.endsWith('.md')) {
          final indexStr = filename.substring(8, 11); // chapter-000.md -> 000
          final index = int.tryParse(indexStr);
          if (index != null) {
            final content = await _fileStorage.readText(file.path);
            if (content != null && content.isNotEmpty) {
              summaries.add(ChapterSummary(
                bookId: bookId,
                chapterIndex: index,
                objectiveSummary: content,
                createdAt: await file.lastModified(),
              ));
            }
          }
        }
      }
      
      // 按章节索引排序
      summaries.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
      return summaries;
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'getSummariesForBook 失败: $bookId', e, stackTrace);
      return [];
    }
  }

  Future<String?> getBookSummary(String bookId) async {
    try {
      final filePath = await StorageConfig.getBookSummaryPath(bookId);
      return await _fileStorage.readText(filePath);
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'getBookSummary 失败: $bookId', e, stackTrace);
      return null;
    }
  }

  Future<void> saveBookSummary(String bookId, String summary) async {
    try {
      final filePath = await StorageConfig.getBookSummaryPath(bookId);
      await _fileStorage.writeText(filePath, summary);
      _log.d('SummaryService', '书籍摘要已保存: $bookId');
      
      // 同时更新书籍元数据中的aiIntroduction
      final book = _bookService.getBookById(bookId);
      if (book != null) {
        final updatedBook = book.copyWith(aiIntroduction: summary);
        await _bookService.updateBook(updatedBook);
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'saveBookSummary 失败: $bookId', e, stackTrace);
    }
  }

  // 保留原有的生成逻辑，只修改存储部分...
  Future<bool> generateSingleSummary(
    String bookId,
    int chapterIndex,
    String chapterTitle,
    String content,
  ) async {
    final key = _key(bookId, chapterIndex);
    
    if (_generatingKeys.contains(key)) {
      _log.d('SummaryService', '摘要生成中，跳过重复请求: $key');
      return false;
    }

    _generatingKeys.add(key);
    
    final completer = Completer<void>();
    _generatingFutures[key] = completer.future;

    try {
      _log.d('SummaryService', '开始生成摘要: $key');
      
      final summary = await _aiService.generateFullChapterSummary(
        content: content,
        chapterTitle: chapterTitle,
      );

      if (summary != null && summary.isNotEmpty) {
        final chapterSummary = ChapterSummary(
          bookId: bookId,
          chapterIndex: chapterIndex,
          objectiveSummary: summary,
          createdAt: DateTime.now(),
        );
        
        await saveSummary(chapterSummary);
        _log.i('SummaryService', '摘要生成成功: $key');
        completer.complete();
        return true;
      } else {
        _log.w('SummaryService', 'AI返回空摘要: $key');
        completer.completeError('Empty summary');
        return false;
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '生成摘要失败: $key', e, stackTrace);
      completer.completeError(e);
      return false;
    } finally {
      _generatingKeys.remove(key);
      _generatingFutures.remove(key);
    }
  }

  // ... 保留其他生成方法（generateSummariesForBook等），修改存储部分即可
}
```

- [ ] **Step 2: 验证代码编译**

Run: `flutter analyze lib/services/summary_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/summary_service.dart
git commit -m "refactor: migrate SummaryService from SQLite to file storage"
```

---

## Task 5: 更新main.dart移除数据库初始化

**Files:**
- Modify: `lib/main.dart`

**Description:** 移除数据库相关初始化代码

- [ ] **Step 1: 修改main.dart**

```dart
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/book_service.dart';
import 'services/ai_service.dart';
import 'services/summary_service.dart';
import 'services/log_service.dart';
import 'services/parsers/format_registry.dart';
import 'services/parsers/epub_parser.dart';
import 'services/parsers/pdf_parser.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志服务
  await LogService().init(
    minLevel: LogLevel.verbose,
    writeToFile: true,
  );

  LogService().info('Main', '应用启动');

  // 初始化格式注册表
  _initializeFormatRegistry();

  // 初始化服务（文件存储模式，无需数据库）
  await BookService().init();
  await AIService().init();
  await SummaryService().init();

  LogService().info('Main', '所有服务初始化完成');

  runApp(
    const ZhiduApp(),
  );
}

/// 初始化格式注册表，注册所有支持的解析器
void _initializeFormatRegistry() {
  FormatRegistry.register('.epub', EpubParser());
  FormatRegistry.register('.pdf', PdfParser());
  LogService().info('Main', '格式注册表初始化完成，支持: epub, pdf');
}

class ZhiduApp extends StatelessWidget {
  const ZhiduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
```

- [ ] **Step 2: 验证代码编译**

Run: `flutter analyze lib/main.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "refactor: remove database initialization from main"
```

---

## Task 6: 更新pubspec.yaml移除数据库依赖

**Files:**
- Modify: `pubspec.yaml`

**Description:** 移除drift和sqlite依赖

- [ ] **Step 1: 修改pubspec.yaml**

找到dependencies部分，移除以下依赖：
```yaml
# 移除这些行
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.20
```

找到dev_dependencies部分，移除：
```yaml
# 移除这些行
  drift_dev: ^2.14.0
  build_runner: ^2.4.7
```

**注意**: 保留 `path_provider` 依赖，文件存储需要它！

- [ ] **Step 2: 运行flutter pub get**

Run: `flutter pub get`
Expected: 成功，没有drift相关警告

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: remove drift and sqlite dependencies"
```

---

## Task 7: 删除数据库相关文件

**Files:**
- Delete: `lib/data/database/database.dart`
- Delete: `lib/data/database/database.g.dart`
- Delete: `lib/data/database/` 目录（如果为空）

- [ ] **Step 1: 删除数据库文件**

```bash
# 先备份（可选）
mkdir -p backup/database
cp lib/data/database/* backup/database/

# 删除数据库文件
rm -rf lib/data/database/
```

- [ ] **Step 2: 验证项目结构**

确保 `lib/data/` 目录现在为空或已删除

- [ ] **Step 3: 验证编译**

Run: `flutter analyze`
Expected: 除了之前已有的警告（非数据库相关），没有新错误

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove database files and drift generated code"
```

---

## Task 8: 完整测试

**Files:**
- Test: 整个应用

**Description:** 验证所有功能正常工作

- [ ] **Step 1: 运行flutter analyze**

Run: `flutter analyze`
Expected: No critical errors

- [ ] **Step 2: 运行flutter build**

Run: `flutter build windows --release`
Expected: Build successful

- [ ] **Step 3: 手动测试**

1. 启动应用
2. 导入一本EPUB书籍
3. 验证书籍列表显示
4. 点击书籍进入详情
5. 验证目录显示
6. 点击章节进入阅读
7. 生成章节摘要
8. 验证摘要保存为.md文件
9. 验证书籍摘要保存为.md文件
10. 删除书籍
11. 验证文件被删除

- [ ] **Step 4: 验证文件结构**

检查 `Documents/zhidu/` 目录：
```
zhidu/
├── books.json
└── books/
    └── {uuid}/
        ├── metadata.json
        ├── summary.md
        ├── chapter-000.md
        └── chapter-001.md
```

- [ ] **Step 5: Commit**

```bash
git commit -m "test: verify file storage implementation works correctly"
```

---

## 总结

完成以上任务后，应用将从SQLite数据库架构完全迁移到文件存储架构：

1. ✅ 所有书籍数据保存在用户Documents目录下
2. ✅ 用户可以直接访问和编辑.md摘要文件
3. ✅ 无需数据库初始化和代码生成
4. ✅ 简化了依赖和构建流程
5. ✅ 保持了原有Service接口，UI层无需修改

**开始实施！**
