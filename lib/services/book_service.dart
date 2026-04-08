import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/book.dart';
import 'storage_service.dart';
import 'epub_service.dart';
import 'ai_service.dart';
import 'log_service.dart';

class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  final _storageService = StorageService.instance;
  final _epubService = EpubService();
  final _aiService = AIService();
  final _log = LogService();

  List<Book> _books = [];
  List<Book> get books => _books;

  Future<void> init() async {
    _log.v('BookService', 'init 开始执行');
    await _storageService.init();
    _books = await _storageService.getBooks();
    _log.v('BookService', 'init 执行完成, 加载书籍数量: ${_books.length}');
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

        await _storageService.addBook(book);
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
    await _storageService.updateBook(book);
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
    await _storageService.deleteBook(bookId);
    _books.removeWhere((b) => b.id == bookId);
    _log.v('BookService', 'deleteBook 执行完成, 书籍已从内存和存储中删除');
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
}
