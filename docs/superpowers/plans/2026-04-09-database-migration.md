# Database Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate from JSON file storage to SQLite database using drift ORM

**Architecture:** Create data layer with drift ORM (database, tables, DAOs), modify services to use DAOs instead of JSON files, delete StorageService

**Tech Stack:** Flutter, drift ORM, SQLite, build_runner

---

## File Structure

```
lib/
├── data/
│   ├── database/
│   │   ├── database.dart          # NEW
│   │   ├── tables.dart            # NEW
│   │   └── database.g.dart        # GENERATED
│   ├── daos/
│   │   ├── books_dao.dart         # NEW
│   │   ├── summaries_dao.dart     # NEW
│   │   ├── books_dao.g.dart       # GENERATED
│   │   └── summaries_dao.g.dart   # GENERATED
│   └── converters/
│       └── date_time_converter.dart # NEW
├── models/                          # UNCHANGED
├── services/
│   ├── book_service.dart           # MODIFY
│   ├── summary_service.dart        # MODIFY
│   └── storage_service.dart        # DELETE
└── main.dart                        # MODIFY
```

---

### Task 1: Add Drift Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Add to `dependencies` section (after line 32):

```yaml
  # Database
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
```

Add to `dev_dependencies` section (after line 37):

```yaml
  # Database code generation
  drift_dev: ^2.14.0
  build_runner: ^2.4.0
```

- [ ] **Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: All dependencies installed successfully

- [ ] **Step 3: Commit dependency changes**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add drift database dependencies"
```

---

### Task 2: Create Database Tables Definition

**Files:**
- Create: `lib/data/database/tables.dart`

- [ ] **Step 1: Create data directory structure**

```bash
mkdir -p lib/data/database lib/data/daos lib/data/converters
```

- [ ] **Step 2: Create tables.dart with table definitions**

Create file `lib/data/database/tables.dart`:

```dart
import 'package:drift/drift.dart';

@DataClassName('BookTable')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get coverPath => text().named('cover_path').nullable()();
  IntColumn get currentChapter => integer().named('current_chapter').withDefault(const Constant(0))();
  RealColumn get readingProgress => real().named('reading_progress').withDefault(const Constant(0.0))();
  IntColumn get lastReadAt => integer().named('last_read_at').nullable()();
  TextColumn get aiIntroduction => text().named('ai_introduction').nullable()();
  IntColumn get totalChapters => integer().named('total_chapters').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChapterSummaryTable')
class ChapterSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().named('book_id')();
  IntColumn get chapterIndex => integer().named('chapter_index')();
  TextColumn get chapterTitle => text().named('chapter_title')();
  TextColumn get objectiveSummary => text().named('objective_summary')();
  TextColumn get aiInsight => text().named('ai_insight').nullable()();
  TextColumn get keyPoints => text().named('key_points').nullable()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BookSummaryTable')
class BookSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().named('book_id')();
  TextColumn get summary => text()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 3: Commit tables definition**

```bash
git add lib/data/database/tables.dart
git commit -m "feat: add database table definitions for drift"
```

---

### Task 3: Create DateTime Type Converter

**Files:**
- Create: `lib/data/converters/date_time_converter.dart`

- [ ] **Step 1: Create DateTime converter for database**

Create file `lib/data/converters/date_time_converter.dart`:

```dart
import 'package:drift/drift.dart';

class DateTimeConverter extends TypeConverter<DateTime, int> {
  const DateTimeConverter();

  @override
  DateTime fromSql(int fromDb) {
    return DateTime.fromMillisecondsSinceEpoch(fromDb);
  }

  @override
  int toSql(DateTime value) {
    return value.millisecondsSinceEpoch;
  }
}
```

- [ ] **Step 2: Commit converter**

```bash
git add lib/data/converters/date_time_converter.dart
git commit -m "feat: add DateTime type converter for drift"
```

---

### Task 4: Create Database Configuration

**Files:**
- Create: `lib/data/database/database.dart`

- [ ] **Step 1: Create database.dart**

Create file `lib/data/database/database.dart`:

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Books, ChapterSummaries, BookSummaries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.connect(DatabaseConnection connection) : super.connect(connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations will be handled here
      },
    );
  }

  Future<void> close() async {
    await executor.close();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'zhidu.db'));
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 2: Run build_runner to generate code**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` generated successfully

- [ ] **Step 3: Commit database configuration**

```bash
git add lib/data/database/
git commit -m "feat: add drift database configuration"
```

---

### Task 5: Create BooksDao

**Files:**
- Create: `lib/data/daos/books_dao.dart`

- [ ] **Step 1: Create BooksDao**

Create file `lib/data/daos/books_dao.dart`:

```dart
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../models/book.dart' as model;

part 'books_dao.g.dart';

@DriftAccessor(tables: [Books])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(AppDatabase db) : super(db);

  Future<List<model.Book>> getAllBooks() async {
    final books = await select(books).get();
    return books.map(_tableToModel).toList();
  }

  Future<model.Book?> getBookById(String id) async {
    final book = await (select(books)..where((b) => b.id.equals(id))).getSingleOrNull();
    return book != null ? _tableToModel(book) : null;
  }

  Future<void> insertBook(model.Book book) async {
    await into(books).insert(_modelToTable(book));
  }

  Future<void> updateBook(model.Book bookModel) async {
    await (update(books)..where((b) => b.id.equals(bookModel.id))).write(
      BooksCompanion(
        title: Value(bookModel.title),
        author: Value(bookModel.author),
        filePath: Value(bookModel.filePath),
        coverPath: Value(bookModel.coverPath),
        currentChapter: Value(bookModel.currentChapter),
        readingProgress: Value(bookModel.readingProgress),
        lastReadAt: Value(bookModel.lastReadAt?.millisecondsSinceEpoch),
        aiIntroduction: Value(bookModel.aiIntroduction),
        totalChapters: Value(bookModel.totalChapters),
      ),
    );
  }

  Future<void> deleteBook(String id) async {
    await (delete(books)..where((b) => b.id.equals(id))).go();
  }

  Stream<List<model.Book>> watchAllBooks() {
    return select(books).watch().map(
      (books) => books.map(_tableToModel).toList(),
    );
  }

  model.Book _tableToModel(BookTable table) {
    return model.Book(
      id: table.id,
      title: table.title,
      author: table.author,
      filePath: table.filePath,
      coverPath: table.coverPath,
      currentChapter: table.currentChapter,
      readingProgress: table.readingProgress,
      lastReadAt: table.lastReadAt != null 
          ? DateTime.fromMillisecondsSinceEpoch(table.lastReadAt!)
          : null,
      aiIntroduction: table.aiIntroduction,
      totalChapters: table.totalChapters,
    );
  }

  BooksCompanion _modelToTable(model.Book model) {
    return BooksCompanion(
      id: Value(model.id),
      title: Value(model.title),
      author: Value(model.author),
      filePath: Value(model.filePath),
      coverPath: Value(model.coverPath),
      currentChapter: Value(model.currentChapter),
      readingProgress: Value(model.readingProgress),
      lastReadAt: Value(model.lastReadAt?.millisecondsSinceEpoch),
      aiIntroduction: Value(model.aiIntroduction),
      totalChapters: Value(model.totalChapters),
    );
  }
}
```

- [ ] **Step 2: Run build_runner again**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: `books_dao.g.dart` generated successfully

- [ ] **Step 3: Commit BooksDao**

```bash
git add lib/data/daos/
git commit -m "feat: add BooksDao for database operations"
```

---

### Task 6: Create SummariesDao

**Files:**
- Create: `lib/data/daos/summaries_dao.dart`

- [ ] **Step 1: Create SummariesDao**

Create file `lib/data/daos/summaries_dao.dart`:

```dart
import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../models/chapter_summary.dart' as model;
import '../../models/book_summary.dart' as book_model;

part 'summaries_dao.g.dart';

@DriftAccessor(tables: [ChapterSummaries, BookSummaries])
class SummariesDao extends DatabaseAccessor<AppDatabase> with _$SummariesDaoMixin {
  SummariesDao(AppDatabase db) : super(db);

  // Chapter Summaries
  Future<model.ChapterSummary?> getChapterSummary(String bookId, int chapterIndex) async {
    final summary = await (select(chapterSummaries)
      ..where((s) => s.bookId.equals(bookId) & s.chapterIndex.equals(chapterIndex)))
      .getSingleOrNull();
    return summary != null ? _chapterTableToModel(summary) : null;
  }

  Future<void> saveChapterSummary(model.ChapterSummary summaryModel) async {
    await into(chapterSummaries).insert(
      _chapterModelToCompanion(summaryModel),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteChapterSummaries(String bookId) async {
    await (delete(chapterSummaries)..where((s) => s.bookId.equals(bookId))).go();
  }

  Future<List<model.ChapterSummary>> getSummariesForBook(String bookId) async {
    final summaries = await (select(chapterSummaries)
      ..where((s) => s.bookId.equals(bookId))
      ..orderBy([(s) => OrderingTerm(expression: s.chapterIndex)]))
      .get();
    return summaries.map(_chapterTableToModel).toList();
  }

  // Book Summaries
  Future<book_model.BookSummary?> getBookSummary(String bookId) async {
    final summary = await (select(bookSummaries)
      ..where((s) => s.bookId.equals(bookId)))
      .getSingleOrNull();
    return summary != null ? _bookTableToModel(summary) : null;
  }

  Future<void> saveBookSummary(book_model.BookSummary summaryModel) async {
    await into(bookSummaries).insert(
      _bookModelToCompanion(summaryModel),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteBookSummary(String bookId) async {
    await (delete(bookSummaries)..where((s) => s.bookId.equals(bookId))).go();
  }

  // Conversions
  model.ChapterSummary _chapterTableToModel(ChapterSummaryTable table) {
    return model.ChapterSummary(
      bookId: table.bookId,
      chapterIndex: table.chapterIndex,
      chapterTitle: table.chapterTitle,
      objectiveSummary: table.objectiveSummary,
      aiInsight: table.aiInsight ?? '',
      keyPoints: table.keyPoints != null 
          ? List<String>.from(jsonDecode(table.keyPoints!))
          : [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(table.createdAt),
    );
  }

  ChapterSummariesCompanion _chapterModelToCompanion(model.ChapterSummary model) {
    return ChapterSummariesCompanion(
      bookId: Value(model.bookId),
      chapterIndex: Value(model.chapterIndex),
      chapterTitle: Value(model.chapterTitle),
      objectiveSummary: Value(model.objectiveSummary),
      aiInsight: Value(model.aiInsight),
      keyPoints: Value(jsonEncode(model.keyPoints)),
      createdAt: Value(model.createdAt.millisecondsSinceEpoch),
    );
  }

  book_model.BookSummary _bookTableToModel(BookSummaryTable table) {
    return book_model.BookSummary(
      bookId: table.bookId,
      summary: table.summary,
      createdAt: DateTime.fromMillisecondsSinceEpoch(table.createdAt),
    );
  }

  BookSummariesCompanion _bookModelToCompanion(book_model.BookSummary model) {
    return BookSummariesCompanion(
      bookId: Value(model.bookId),
      summary: Value(model.summary),
      createdAt: Value(model.createdAt.millisecondsSinceEpoch),
    );
  }
}
```

- [ ] **Step 2: Run build_runner**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: `summaries_dao.g.dart` generated successfully

- [ ] **Step 3: Commit SummariesDao**

```bash
git add lib/data/daos/
git commit -m "feat: add SummariesDao for database operations"
```

---

### Task 7: Modify BookService to Use Database

**Files:**
- Modify: `lib/services/book_service.dart`
- Delete: `lib/services/storage_service.dart`

- [ ] **Step 1: Modify BookService imports and constructor**

Replace the beginning of `lib/services/book_service.dart` (lines 1-17):

```dart
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/book.dart';
import '../data/database/database.dart';
import '../data/daos/books_dao.dart';
import '../data/daos/summaries_dao.dart';
import 'epub_service.dart';
import 'ai_service.dart';
import 'log_service.dart';

class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  late final AppDatabase _database;
  late final BooksDao _booksDao;
  late final SummariesDao _summariesDao;
  final _epubService = EpubService();
  final _aiService = AIService();
  final _log = LogService();

  List<Book> _books = [];
  List<Book> get books => _books;
```

- [ ] **Step 2: Modify init method**

Replace the `init` method (lines 22-27):

```dart
  Future<void> init() async {
    _log.v('BookService', 'init 开始执行');
    _database = AppDatabase();
    _booksDao = BooksDao(_database);
    _summariesDao = SummariesDao(_database);
    _books = await _booksDao.getAllBooks();
    _log.v('BookService', 'init 执行完成, 加载书籍数量: ${_books.length}');
  }
```

- [ ] **Step 3: Modify importBook method to use database**

Replace the part after `if (book != null)` in `importBook` method (lines 66-80):

```dart
      if (book != null) {
        final existingBook = _books
            .where((b) => b.title == book!.title && b.author == book.author)
            .firstOrNull;

        if (existingBook != null) {
          _log.d('BookService', '书籍已存在: ${book.title}');
          return existingBook;
        }

        await _booksDao.insertBook(book);
        _books.add(book);
        _log.d('BookService', '书籍已添加到列表，当前书籍数量: ${_books.length}');

        return book;
      }
```

- [ ] **Step 4: Modify updateBook method**

Replace `updateBook` method (lines 90-102):

```dart
  Future<void> updateBook(Book book) async {
    _log.v('BookService',
        'updateBook 开始执行, bookId: ${book.id}, title: ${book.title}');
    await _booksDao.updateBook(book);
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index != -1) {
      _books[index] = book;
      _log.v('BookService', 'updateBook 书籍已在内存中更新');
    } else {
      _log.v('BookService', 'updateBook 书籍不在内存中，添加到列表');
      _books.add(book);
    }
  }
```

- [ ] **Step 5: Modify deleteBook method**

Replace `deleteBook` method (lines 104-109):

```dart
  Future<void> deleteBook(String bookId) async {
    _log.v('BookService', 'deleteBook 开始执行, bookId: $bookId');
    await _summariesDao.deleteChapterSummaries(bookId);
    await _summariesDao.deleteBookSummary(bookId);
    await _booksDao.deleteBook(bookId);
    _books.removeWhere((b) => b.id == bookId);
    _log.v('BookService', 'deleteBook 执行完成, 书籍已从内存和数据库中删除');
  }
```

- [ ] **Step 6: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 7: Delete StorageService**

```bash
rm lib/services/storage_service.dart
```

- [ ] **Step 8: Commit BookService changes**

```bash
git add lib/services/book_service.dart
git rm lib/services/storage_service.dart
git commit -m "refactor: modify BookService to use database, remove StorageService"
```

---

### Task 8: Modify SummaryService to Use Database

**Files:**
- Modify: `lib/services/summary_service.dart`

- [ ] **Step 1: Modify SummaryService imports and constructor**

Replace the beginning of `lib/services/summary_service.dart` (lines 1-23):

```dart
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import '../models/chapter_summary.dart';
import '../models/section_summary.dart';
import '../models/book.dart';
import '../data/database/database.dart';
import '../data/daos/summaries_dao.dart';
import 'ai_service.dart';
import 'epub_service.dart';
import 'log_service.dart';

class SummaryService {
  static final SummaryService _instance = SummaryService._internal();
  factory SummaryService() => _instance;
  SummaryService._internal();

  late final AppDatabase _database;
  late final SummariesDao _summariesDao;
  final _aiService = AIService();
  final _epubService = EpubService();
  final _log = LogService();
```

- [ ] **Step 2: Modify init method**

Replace `init` method (lines 25-39):

```dart
  Future<void> init() async {
    _database = AppDatabase();
    _summariesDao = SummariesDao(_database);
  }
```

- [ ] **Step 3: Modify getSummary method**

Replace `getSummary` method (lines 63-79):

```dart
  Future<ChapterSummary?> getSummary(String bookId, int chapterIndex) async {
    _log.v('SummaryService',
        'getSummary 开始执行, bookId: $bookId, chapterIndex: $chapterIndex');
    final result = await _summariesDao.getChapterSummary(bookId, chapterIndex);
    _log.v('SummaryService',
        'getSummary 加载完成, result: ${result != null ? "有内容" : "空"}');
    return result;
  }
```

- [ ] **Step 4: Modify saveSummary method**

Replace `saveSummary` method (lines 183-195):

```dart
  Future<void> saveSummary(ChapterSummary summary) async {
    await _summariesDao.saveChapterSummary(summary);
    _log.d('SummaryService', '摘要已保存: ${summary.bookId}_${summary.chapterIndex}');
  }
```

- [ ] **Step 5: Modify deleteSummary and deleteAllSummariesForBook methods**

Replace these methods (lines 197-225):

```dart
  Future<void> deleteSummary(String bookId, int chapterIndex) async {
    final summary = await getSummary(bookId, chapterIndex);
    if (summary != null) {
      await _summariesDao.deleteChapterSummaries(bookId);
    }
  }

  Future<void> deleteAllSummariesForBook(String bookId) async {
    await _summariesDao.deleteChapterSummaries(bookId);
    await _summariesDao.deleteBookSummary(bookId);
  }
```

- [ ] **Step 6: Modify hasSummary and getSummaryCount methods**

Replace these methods (lines 227-233):

```dart
  Future<bool> hasSummary(String bookId, int chapterIndex) async {
    final summary = await _summariesDao.getChapterSummary(bookId, chapterIndex);
    return summary != null;
  }

  Future<int> getSummaryCount(String bookId) async {
    final summaries = await _summariesDao.getSummariesForBook(bookId);
    return summaries.length;
  }
```

- [ ] **Step 7: Remove old file-based methods**

Delete the following methods that are no longer needed:
- `_loadSummaryFromFile` (lines 42-61)
- `getSummaryByTitle` (lines 81-106)
- `getSummarySync` (lines 108-116)
- `getSummariesForBook` (lines 118-153)
- `getAllSummaries` (lines 155-181)

- [ ] **Step 8: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 9: Commit SummaryService changes**

```bash
git add lib/services/summary_service.dart
git commit -m "refactor: modify SummaryService to use database"
```

---

### Task 9: Update main.dart to Initialize Database

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Update main.dart imports and initialization**

Replace the beginning of `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/book_service.dart';
import 'services/epub_service.dart';
import 'services/ai_service.dart';
import 'services/summary_service.dart';
import 'services/export_service.dart';
import 'services/log_service.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final _log = LogService();

  try {
    _log.d('main', '开始初始化应用...');
    
    await AIService().init();
    _log.d('main', 'AI服务初始化完成');

    await EpubService().init();
    _log.d('main', 'EPUB服务初始化完成');

    await SummaryService().init();
    _log.d('main', '摘要服务初始化完成');

    await BookService().init();
    _log.d('main', '书籍服务初始化完成');

    await ExportService().init();
    _log.d('main', '导出服务初始化完成');

    _log.d('main', '应用初始化完成，启动UI');
  } catch (e, stackTrace) {
    _log.e('main', '应用初始化失败', e, stackTrace);
  }

  runApp(const MyApp());
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit main.dart changes**

```bash
git add lib/main.dart
git commit -m "refactor: update main.dart to initialize database services"
```

---

### Task 10: Update AGENTS.md

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Update architecture section in AGENTS.md**

Replace the "Architecture Notes" section:

```markdown
### Architecture Notes
- **状态管理**: 使用StatefulWidget + Service单例，无Riverpod/Provider
- **存储方案**: SQLite数据库（drift ORM），数据存储在应用专用目录
  - Windows: `C:\Users\{username}\AppData\Local\zhidu\zhidu.db`
  - Android: `/data/data/{package_name}/databases/zhidu.db`
  - iOS: `Documents/zhidu.db`
- **数据库结构**:
  - `books` 表：书籍信息
  - `chapter_summaries` 表：章节摘要
  - `book_summaries` 表：全书摘要
- **Service初始化**: 所有Service在`main.dart`中顺序初始化
- **AI配置**: 读取项目根目录`ai_config.json`，支持智谱/通义千问
```

- [ ] **Step 2: Update project structure in AGENTS.md**

Update the Project Structure section:

```markdown
### Project Structure
```
lib/
├── main.dart                 # 应用入口，初始化所有Service
├── data/                     # 数据层
│   ├── database/             # 数据库定义
│   │   ├── database.dart     # drift数据库配置
│   │   ├── tables.dart       # 表定义
│   │   └── database.g.dart   # 生成的代码
│   ├── daos/                 # 数据访问对象
│   │   ├── books_dao.dart    # 书籍DAO
│   │   └── summaries_dao.dart # 摘要DAO
│   └── converters/           # 类型转换器
│       └── date_time_converter.dart
├── models/                   # 数据模型
├── screens/                  # UI页面
├── services/                 # 业务服务层
│   ├── book_service.dart     # 书籍管理
│   ├── epub_service.dart     # EPUB解析
│   ├── ai_service.dart       # AI服务
│   ├── summary_service.dart  # 摘要生成
│   ├── export_service.dart   # 导出
│   └── log_service.dart      # 日志
└── utils/
    └── app_theme.dart        # 主题配置
```
```

- [ ] **Step 3: Remove old storage references**

Remove or update sections about JSON files:
- Delete the reference to `books.json`
- Delete the reference to `/Summaries/` directory
- Delete the reference to `/SectionSummaries/` directory

- [ ] **Step 4: Commit AGENTS.md changes**

```bash
git add AGENTS.md
git commit -m "docs: update AGENTS.md with database architecture"
```

---

### Task 11: Final Verification

- [ ] **Step 1: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 2: Run flutter pub run build_runner build**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: All generated files created successfully

- [ ] **Step 3: Test manual run**

Run: `flutter run`
Test:
1. App starts without errors
2. Import a book
3. Verify book is saved in database
4. Generate a chapter summary
5. Verify summary is saved in database
6. Close and reopen app
7. Verify data persists

- [ ] **Step 4: Create final commit if needed**

If any fixes were made:

```bash
git add -A
git commit -m "fix: resolve issues found during testing"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** All requirements from spec implemented
  - Database schema created ✓
  - DAOs implemented ✓
  - Services migrated ✓
  - StorageService deleted ✓
  
- [x] **Placeholder scan:** No TBD, TODO, or vague descriptions
  
- [x] **Type consistency:** All method signatures and variable names consistent across tasks