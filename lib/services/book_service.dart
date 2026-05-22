import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import '../models/book.dart';
import 'opf_reader_service.dart';
import 'parsers/book_format_parser.dart';
import 'storage_config.dart';
import 'file_storage_service.dart';

class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  final _uuid = const Uuid();
  final _log = Logger();
  final _fileStorage = FileStorageService();

  final List<Book> _books = [];

  List<Book> get books => _books;

  Future<void> init() async {
    await _loadBooks();
  }

  /// 从索引文件加载所有书籍元数据
  Future<void> _loadBooks() async {
    final indexPath = await StorageConfig.getBooksIndexPath();
    final data = await _fileStorage.readJson(indexPath);

    if (data == null) {
      return;
    }

    final booksList = data['books'] as List<dynamic>? ?? [];

    for (final bookJson in booksList) {
      final bookId = bookJson['id'] as String?;
      if (bookId == null) continue;

      final metadataPath = await StorageConfig.getBookMetadataPath(bookId);
      final metadata = await _fileStorage.readJson(metadataPath);

      if (metadata != null) {
        try {
          _books.add(Book.fromJson(metadata));
        } catch (e, stackTrace) {
          _log.e('解析书籍元数据失败: $bookId', error: e, stackTrace: stackTrace);
        }
      }
    }

    _log.i('从文件加载了 ${_books.length} 本书');
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

  /// 从文件路径导入书籍，支持 EPUB/PDF
  ///
  /// 优先读取同目录 OPF 元数据；标题+作者去重，重复返回已有书籍
  Future<Book?> importBookFromPath(String filePath) async {
    try {
      OpfMetadata? opfMetadata;
      try {
        opfMetadata = await OpfReaderService.readFromSameDirectory(filePath);
      } catch (e) {
        _log.w('读取外部OPF元数据失败，继续使用原解析逻辑: $e');
      }

      final extension = p.extension(filePath).toLowerCase();
      final bookId = _uuid.v4();

      final parser = FormatRegistry.getParser(extension);
      if (parser == null) {
        _log.w('不支持的文件格式: $extension');
        return null;
      }

      final metadata = await parser.parseMetadata(filePath, bookId);
      if (metadata == null) {
        _log.w('元数据解析失败: $filePath');
        return null;
      }

      Book? book = Book(
        id: bookId,
        title: metadata.title,
        author: metadata.author,
        coverPath: metadata.coverPath,
        filePath: filePath,
        format: extension == '.epub' ? BookFormat.epub : BookFormat.pdf,
        totalChapters: metadata.totalChapters,
        addedAt: DateTime.now(),
        language: metadata.language,
      );

      if (book != null && opfMetadata != null) {
        String? finalCoverPath = book.coverPath;
        if (opfMetadata.coverPath != null) {
          final bookDir = p.dirname(filePath);
          final coverAbsolutePath = p.join(bookDir, opfMetadata.coverPath!);
          if (await File(coverAbsolutePath).exists()) {
            final coverDestPath = await StorageConfig.getCoverSavePath(
              book.id,
              p.extension(coverAbsolutePath).replaceFirst('.', ''),
            );
            
            try {
              await File(coverAbsolutePath).copy(coverDestPath);
              finalCoverPath = coverDestPath;
            } catch (e) {
              _log.w('复制外部OPF封面文件失败: $e，使用原封面');
            }
          }
        }
        
        book = book.copyWith(
          title: opfMetadata.title ?? book.title,
          author: opfMetadata.author ?? book.author,
          language: opfMetadata.language ?? book.language,
          coverPath: finalCoverPath,
        );
      }

      if (book != null) {
        final existingBook = _books
            .where((b) => b.title == book!.title && b.author == book.author)
            .firstOrNull;

        if (existingBook != null) {
          _log.i('书籍已存在: ${book.title}');
          return existingBook;
        }

        _books.add(book);
        await _saveBooksIndex();
        await _saveBookMetadata(book);

        _log.i('书籍导入成功: ${book.title}');
        return book;
      }

      return null;
    } catch (e, stackTrace) {
      _log.e('导入书籍失败: $filePath', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 通过文件选择器导入书籍
  Future<Book?> importBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf'],
        dialogTitle: '选择电子书',
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        _log.w('文件路径为空');
        return null;
      }

      return await importBookFromPath(filePath);
    } catch (e, stackTrace) {
      _log.e('导入书籍失败', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Book? getBookById(String id) {
    return _books.where((b) => b.id == id).firstOrNull;
  }

  /// 删除书籍及其所有数据（不可逆）
  Future<bool> deleteBook(String id) async {
    _log.i('删除书籍: $id');
    try {
      final book = getBookById(id);
      if (book == null) {
        _log.w('要删除的书籍不存在: $id');
        return false;
      }

      final bookDirPath = await StorageConfig.getBookDirectoryPath(id);
      final bookDir = Directory(bookDirPath);
      
      if (await bookDir.exists()) {
        final deleted = await _fileStorage.deleteDirectory(bookDirPath);
        if (!deleted) {
          _log.e('删除书籍目录失败: ${book.title} ($id)');
          return false;
        }
      }

      _books.removeWhere((b) => b.id == id);
      await _saveBooksIndex();

      _log.i('书籍删除成功: ${book.title}');
      return true;
    } catch (e, stackTrace) {
      _log.e('删除书籍失败: $id', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 替换内存中的书并同步持久化
  Future<void> updateBook(Book book) async {
    _log.i('更新书籍: ${book.title}');
    try {
      final index = _books.indexWhere((b) => b.id == book.id);
      if (index >= 0) {
        _books[index] = book;
        await _saveBooksIndex();
        await _saveBookMetadata(book);
      }
    } catch (e, stackTrace) {
      _log.e('更新书籍失败: ${book.id}', error: e, stackTrace: stackTrace);
    }
  }

  /// 按标题或作者模糊搜索（不区分大小写）
  List<Book> searchBooks(String query) {
    final lowerQuery = query.toLowerCase();
    return _books.where((book) {
      return book.title.toLowerCase().contains(lowerQuery) ||
          book.author.toLowerCase().contains(lowerQuery);
    }).toList();
  }

}
