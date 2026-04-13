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
        try {
          _books.add(Book.fromJson(metadata));
        } catch (e) {
          _log.e('BookService', '解析书籍元数据失败: $bookId', e);
        }
      }
    }

    _log.d('BookService', '从文件加载了 ${_books.length} 本书');
  }

  Future<void> _saveBooksIndex() async {
    final indexPath = await StorageConfig.getBooksIndexPath();
    final data = {
      'version': '1.0',
      'lastUpdated': DateTime.now().toIso8601String(),
      'books': _books
          .map((b) => {
                'id': b.id,
                'title': b.title,
                'author': b.author,
                'format': b.format.name,
                'originalFilePath': b.filePath,
                'addedAt': b.addedAt.toIso8601String(),
              })
          .toList(),
    };
    await _fileStorage.writeJson(indexPath, data);
  }

  Future<void> _saveBookMetadata(Book book) async {
    final metadataPath = await StorageConfig.getBookMetadataPath(book.id);
    final data = book.toJson();
    await _fileStorage.writeJson(metadataPath, data);
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
          _log.info('BookService', '书籍已存在: ${book.title}');
          return existingBook;
        }

        // 保存书籍
        _books.add(book);
        await _saveBooksIndex();
        await _saveBookMetadata(book);

        _log.info('BookService', '书籍导入成功: ${book.title}');
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

      _log.info('BookService', '书籍删除成功: ${book.title}');
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

  /// 搜索书籍
  List<Book> searchBooks(String query) {
    final lowerQuery = query.toLowerCase();
    return _books.where((book) {
      return book.title.toLowerCase().contains(lowerQuery) ||
          book.author.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  Future<void> updateChapterTitle(
    String bookId,
    int chapterIndex,
    String title,
  ) async {
    _log.d('BookService',
        '更新章节标题: bookId=$bookId, index=$chapterIndex, title=$title');

    final book = getBookById(bookId);
    if (book == null) {
      _log.w('BookService', '书籍不存在: $bookId');
      return;
    }

    final updatedTitles = Map<int, String>.from(book.chapterTitles ?? {});
    updatedTitles[chapterIndex] = title;

    final updatedBook = book.copyWith(chapterTitles: updatedTitles);
    await updateBook(updatedBook);

    _log.d('BookService', '章节标题更新成功: $title');
  }
}
