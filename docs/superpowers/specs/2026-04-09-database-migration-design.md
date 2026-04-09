# Database Migration Design

## Overview

Migrate from JSON file-based storage to SQLite database using drift ORM for better data management, type safety, and query performance.

## Requirements

### Must Have
- Replace JSON file storage with SQLite database
- Store all books and summaries in database
- Use drift ORM for type-safe database operations
- Store database in application-specific directory
- No data migration (fresh start)

### Nice to Have
- Reactive queries using Streams
- Database migration support for future schema changes

## Technology Stack

**Database**: SQLite via drift ORM

**Key Dependencies**:
- `drift: ^2.14.0` - Type-safe ORM
- `sqlite3_flutter_libs: ^0.5.0` - SQLite native libraries
- `drift_dev: ^2.14.0` - Code generation (dev)
- `build_runner: ^2.4.0` - Code generation runner (dev)

**Storage Location**: Application-specific directory (via path_provider)

## Database Schema

### books table

```sql
CREATE TABLE books (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  file_path TEXT NOT NULL,
  cover_path TEXT,
  current_chapter INTEGER DEFAULT 0,
  reading_progress REAL DEFAULT 0.0,
  last_read_at INTEGER,
  ai_introduction TEXT,
  total_chapters INTEGER DEFAULT 0
)
```

### chapter_summaries table

```sql
CREATE TABLE chapter_summaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id TEXT NOT NULL,
  chapter_index INTEGER NOT NULL,
  chapter_title TEXT NOT NULL,
  objective_summary TEXT NOT NULL,
  ai_insight TEXT,
  key_points TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
  UNIQUE(book_id, chapter_index)
)
```

### book_summaries table

```sql
CREATE TABLE book_summaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id TEXT NOT NULL UNIQUE,
  summary TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
)
```

## Project Structure

```
lib/
├── data/
│   ├── database/
│   │   ├── database.dart          # drift数据库定义
│   │   ├── tables.dart            # 表定义
│   │   └── database.g.dart        # 生成的代码
│   ├── daos/
│   │   ├── books_dao.dart         # 书籍数据访问对象
│   │   └── summaries_dao.dart     # 摘要数据访问对象
│   └── converters/
│       └── date_time_converter.dart # DateTime类型转换器
├── models/                          # 现有模型保持不变
│   ├── book.dart
│   ├── chapter_summary.dart
│   └── book_summary.dart
├── services/                        # 现有服务需修改
│   ├── book_service.dart           # 改用DAO操作
│   └── summary_service.dart        # 改用DAO操作
└── main.dart                        # 初始化数据库
```

## Data Access Objects (DAOs)

### BooksDao

```dart
class BooksDao {
  Future<List<Book>> getAllBooks();
  Future<Book?> getBookById(String id);
  Future<void> insertBook(Book book);
  Future<void> updateBook(Book book);
  Future<void> deleteBook(String id);
  Stream<List<Book>> watchAllBooks();  // Reactive query
}
```

### SummariesDao

```dart
class SummariesDao {
  Future<ChapterSummary?> getChapterSummary(String bookId, int chapterIndex);
  Future<void> saveChapterSummary(ChapterSummary summary);
  Future<void> deleteChapterSummaries(String bookId);
  Future<List<ChapterSummary>> getSummariesForBook(String bookId);
  Future<BookSummary?> getBookSummary(String bookId);
  Future<void> saveBookSummary(BookSummary summary);
}
```

## Service Layer Changes

### StorageService (DELETE)

Completely remove `lib/services/storage_service.dart` as database replaces all functionality.

### BookService Changes

**Before:**
```dart
class BookService {
  final _storageService = StorageService.instance;
  // Uses _storageService.getBooks(), saveBooks(), etc.
}
```

**After:**
```dart
class BookService {
  final _database = AppDatabase();
  final BooksDao _booksDao;
  
  BookService() : _booksDao = BooksDao(_database);
  // Uses _booksDao.getAllBooks(), insertBook(), etc.
}
```

### SummaryService Changes

**Before:**
- Uses JSON files in `Summaries/` directory
- File names: `{bookId}_{chapterIndex}.json`
- Manual JSON serialization

**After:**
- Uses database via `SummariesDao`
- Automatic type-safe serialization
- Reactive queries available

## Database Initialization

### Initialization Flow

1. App startup calls `await AppDatabase.init()`
2. Get application-specific directory via `path_provider`
3. Create/open database file `zhidu.db`
4. Create tables if not exist
5. Database ready for use

### Database File Locations

- **Windows**: `C:\Users\{username}\AppData\Local\{app_name}\zhidu.db`
- **Android**: `/data/data/{package_name}/databases/zhidu.db`
- **iOS**: `Documents/zhidu.db`
- **macOS**: `~/Library/Application Support/{app_name}/zhidu.db`
- **Linux**: `~/.local/share/{app_name}/zhidu.db`

### Initialization Code

```dart
// In main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  final database = AppDatabase();
  await database.initialize();
  
  // Initialize services with database
  await BookService().init();
  await SummaryService().init();
  
  runApp(MyApp());
}
```

## Error Handling

### Database Errors

- **Open failure**: Show fatal error dialog, app cannot start
- **Query failure**: Log error, return empty/default value
- **Write failure**: Throw exception, caller handles
- **Foreign key violation**: Log error, rollback transaction

### Error Recovery

- Database corrupted: Delete and recreate (fresh start)
- Migration failure: Show error, offer reset option

## Migration Strategy

### No Data Migration

Per requirements, no migration from existing JSON files. Users will:
1. Lose existing data after update
2. Re-import books
3. Regenerate summaries

### Future Schema Migrations

Drift supports schema migrations via versioning:

```dart
@DriftDatabase(tables: [Books, ChapterSummaries, BookSummaries])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 1;
  
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations
      },
    );
  }
}
```

## Testing Strategy

### Unit Tests

- DAO CRUD operations
- Type conversions (DateTime)
- Foreign key constraints
- Unique constraints

### Integration Tests

- Service layer with database
- Database initialization
- Error handling

## Performance Considerations

### Indexes

- Primary keys automatically indexed
- Consider adding index on `chapter_summaries(book_id)` for faster lookups

### Query Optimization

- Use Streams for reactive UI updates
- Batch inserts for summaries
- Lazy loading of large text fields (ai_introduction, summary)

## Rollback Plan

If database approach fails:
1. Revert to StorageService
2. Restore JSON file handling
3. No data loss (fresh start means no existing data)

## Implementation Phases

### Phase 1: Setup & Schema
- Add dependencies
- Create database schema (tables.dart)
- Generate database code
- Initialize database in main.dart

### Phase 2: DAOs
- Implement BooksDao
- Implement SummariesDao
- Add type converters

### Phase 3: Service Migration
- Modify BookService to use BooksDao
- Modify SummaryService to use SummariesDao
- Delete StorageService

### Phase 4: Testing & Cleanup
- Test all CRUD operations
- Remove JSON file references
- Update AGENTS.md

## Files to Create

1. `lib/data/database/database.dart`
2. `lib/data/database/tables.dart`
3. `lib/data/daos/books_dao.dart`
4. `lib/data/daos/summaries_dao.dart`
5. `lib/data/converters/date_time_converter.dart`

## Files to Modify

1. `pubspec.yaml` - Add dependencies
2. `lib/main.dart` - Initialize database
3. `lib/services/book_service.dart` - Use BooksDao
4. `lib/services/summary_service.dart` - Use SummariesDao
5. `AGENTS.md` - Update architecture docs

## Files to Delete

1. `lib/services/storage_service.dart`
2. JSON data files (books.json, Summaries/, etc.)