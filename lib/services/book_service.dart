import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../data/database/database.dart';
import '../models/book.dart';
import 'epub_service.dart';
import 'log_service.dart';

class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  late final AppDatabase _db;
  final _epubService = EpubService();
  final _log = LogService();

  List<Book> _books = [];
  List<Book> get books => _books;

  Future<void> init() async {
    _log.v('BookService', 'init 开始执行');
    _db = AppDatabase();
    await _loadBooks();
    _log.v('BookService', 'init 执行完成, 加载书籍数量: ${_books.length}');
  }

  Future<void> _loadBooks() async {
    final bookTables = await _db.select(_db.books).get();
    _books = bookTables.map(_tableToModel).toList();
  }

  Future<Book?> importBook() async {
    _log.v('BookService', 'importBook 开始执行');
    try {
      _log.d('BookService', '开始导入书籍...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        dialogTitle: '选择EPUB电子书',
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

  Future<void> updateBook(Book book) async {
    _log.v('BookService',
        'updateBook 开始执行, bookId: ${book.id}, title: ${book.title}');

    await (_db.update(_db.books)..where((b) => b.id.equals(book.id))).write(
      BooksCompanion(
        title: Value(book.title),
        author: Value(book.author),
        filePath: Value(book.filePath),
        coverPath: Value(book.coverPath),
        currentChapter: Value(book.currentChapter),
        readingProgress: Value(book.readingProgress),
        lastReadAt: Value(book.lastReadAt?.millisecondsSinceEpoch),
        aiIntroduction: Value(book.aiIntroduction),
        totalChapters: Value(book.totalChapters),
      ),
    );

    final index = _books.indexWhere((b) => b.id == book.id);
    if (index != -1) {
      _books[index] = book;
      _log.v('BookService', 'updateBook 书籍已在内存中更新');
    } else {
      _log.v('BookService', 'updateBook 书籍不在内存中，添加到列表');
      _books.add(book);
    }
  }

  Future<void> deleteBook(String bookId) async {
    _log.v('BookService', 'deleteBook 开始执行, bookId: $bookId');

    await (_db.delete(_db.books)..where((b) => b.id.equals(bookId))).go();
    await (_db.delete(_db.chapterSummaries)
          ..where((s) => s.bookId.equals(bookId)))
        .go();
    await (_db.delete(_db.bookSummaries)..where((s) => s.bookId.equals(bookId)))
        .go();

    _books.removeWhere((b) => b.id == bookId);
    _log.v('BookService', 'deleteBook 执行完成, 书籍已从内存和数据库中删除');
  }

  Book? getBookById(String id) {
    _log.v('BookService', 'getBookById 开始执行, id: $id');
    final result = _books.where((b) => b.id == id).firstOrNull;
    _log.v('BookService',
        'getBookById 执行完成, result: ${result != null ? "找到了" : "未找到"}');
    return result;
  }

  List<Book> searchBooks(String query) {
    _log.v('BookService', 'searchBooks 开始执行, query: $query');
    if (query.isEmpty) {
      _log.v('BookService', 'searchBooks 查询为空，返回全部书籍');
      return _books;
    }

    final lowerQuery = query.toLowerCase();
    final result = _books.where((book) {
      return book.title.toLowerCase().contains(lowerQuery) ||
          book.author.toLowerCase().contains(lowerQuery);
    }).toList();
    _log.v('BookService', 'searchBooks 执行完成, 匹配结果数量: ${result.length}');
    return result;
  }

  Future<void> updateReadingProgress(
      String bookId, int chapter, double progress) async {
    _log.v('BookService',
        'updateReadingProgress 开始执行, bookId: $bookId, chapter: $chapter, progress: $progress');
    final book = getBookById(bookId);
    if (book != null) {
      final updatedBook = book.copyWith(
        currentChapter: chapter,
        readingProgress: progress,
        lastReadAt: DateTime.now(),
      );
      await updateBook(updatedBook);
      _log.v('BookService', 'updateReadingProgress 更新完成, 书籍进度已保存');
    } else {
      _log.v('BookService', 'updateReadingProgress 书籍未找到, bookId: $bookId');
    }
  }

  Book _tableToModel(BookTable table) {
    return Book(
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

  BooksCompanion _modelToCompanion(Book model) {
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
