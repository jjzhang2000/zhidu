import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import 'opf_reader_service.dart';
import 'parsers/book_format_parser.dart';
import 'log_service.dart';
import 'storage_config.dart';
import 'file_storage_service.dart';

/// 书籍管理服务 - 导入、存储、查询和删除
class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  final _uuid = const Uuid();
  final _log = LogService();
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

  /// 从文件路径导入书籍，支持 EPUB/PDF
  ///
  /// 优先读取同目录 OPF 元数据；无 OPF 时读取书籍内部的基本信息
  /// （书名/作者/封面），不解析章节与正文，章节与 AI 摘要懒加载。
  Future<Book?> importBookFromPath(String filePath) async {
    try {
      final extension = p.extension(filePath).toLowerCase();
      if (extension != '.epub' && extension != '.pdf') {
        _log.w('BookService', '不支持的文件格式: $extension');
        return null;
      }

      final bookId = _uuid.v4();
      final bookDir = p.dirname(filePath);

      // 1. 外部 OPF（同目录 metadata.opf / .opf），轻量
      OpfMetadata? opfMetadata;
      try {
        opfMetadata = await OpfReaderService.readFromSameDirectory(filePath);
      } catch (e) {
        _log.w('BookService', '读取外部OPF元数据失败: $e');
      }

      // 2. 书籍内部基本信息（书名/作者/封面），轻量
      BookMetadata? basicInfo;
      try {
        final parser = FormatRegistry.getParser(extension);
        basicInfo = await parser?.extractBasicMetadata(filePath, bookId);
      } catch (e) {
        _log.w('BookService', '提取内部基本信息失败: $e');
      }

      // 3. 合并：外部 OPF 优先，内部信息兜底
      final title = opfMetadata?.title?.isNotEmpty == true
          ? opfMetadata!.title!
          : (basicInfo?.title.isNotEmpty == true
              ? basicInfo!.title
              : _extractTitleFromFileName(filePath));
      final author = opfMetadata?.author?.isNotEmpty == true
          ? opfMetadata!.author!
          : (basicInfo?.author.isNotEmpty == true ? basicInfo!.author : '未知作者');
      final language = opfMetadata?.language ?? basicInfo?.language;

      // 封面：外部 OPF 封面优先，其次内部封面
      String? coverPath;
      final opfCover = opfMetadata?.coverPath;
      if (opfCover != null && opfCover.isNotEmpty) {
        final coverAbsolutePath = p.join(bookDir, opfCover);
        if (await File(coverAbsolutePath).exists()) {
          final coverDestPath = await StorageConfig.getCoverSavePath(
            bookId,
            p.extension(coverAbsolutePath).replaceFirst('.', ''),
          );
          try {
            await File(coverAbsolutePath).copy(coverDestPath);
            coverPath = coverDestPath;
          } catch (e) {
            _log.w('BookService', '复制外部OPF封面文件失败: $e');
          }
        }
      }
      coverPath ??= basicInfo?.coverPath;

      final book = Book(
        id: bookId,
        title: title,
        author: author,
        coverPath: coverPath,
        filePath: filePath,
        format: extension == '.epub' ? BookFormat.epub : BookFormat.pdf,
        addedAt: DateTime.now(),
        language: language,
      );

      final existingBook = _books
          .where((b) => b.title == book.title && b.author == book.author)
          .firstOrNull;

      if (existingBook != null) {
        _log.info('BookService', '书籍已存在: ${book.title}');
        return existingBook;
      }

      _books.add(book);
      await _saveBooksIndex();
      await _saveBookMetadata(book);

      _log.info('BookService', '书籍导入成功: ${book.title}');
      return book;
    } catch (e, stackTrace) {
      _log.e('BookService', '导入书籍失败: $filePath', e, stackTrace);
      return null;
    }
  }

  /// 从文件名提取标题（去掉扩展名与 "标题 - 作者" 形式的后缀）
  String _extractTitleFromFileName(String filePath) {
    final name = p.basenameWithoutExtension(filePath).trim();
    if (name.isEmpty) return name;
    final idx = name.lastIndexOf(' - ');
    if (idx > 0) return name.substring(0, idx).trim();
    return name;
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
        _log.w('BookService', '文件路径为空');
        return null;
      }

      return await importBookFromPath(filePath);
    } catch (e, stackTrace) {
      _log.e('BookService', '导入书籍失败', e, stackTrace);
      return null;
    }
  }

  Book? getBookById(String id) {
    return _books.where((b) => b.id == id).firstOrNull;
  }

  /// 扫描 Calibre 书库目录，收集所有书籍的 metadata.opf 路径（只读）
  ///
  /// Calibre 每本书一个文件夹，每个文件夹含 metadata.opf。
  /// 供后台导入任务使用，仅返回待导入的 OPF 文件路径列表。
  Future<List<String>> scanCalibreOpfFiles(String libraryPath) async {
    final opfFiles = <String>[];
    try {
      final dir = Directory(libraryPath);
      if (!await dir.exists()) {
        _log.w('BookService', '书库目录不存在: $libraryPath');
        return opfFiles;
      }

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File &&
            p.basename(entity.path).toLowerCase() == 'metadata.opf') {
          // 跳过隐藏目录（Calibre 的回收站 .caltrash、笔记 .calnotes 等）
          final relativePath = p.relative(entity.path, from: libraryPath);
          if (p.split(relativePath).any((seg) => seg.startsWith('.'))) {
            continue;
          }
          opfFiles.add(entity.path);
        }
      }

      _log.info('BookService', '书库扫描到 ${opfFiles.length} 个书籍条目: $libraryPath');
    } catch (e, stackTrace) {
      _log.e('BookService', '扫描书库失败: $libraryPath', e, stackTrace);
    }
    return opfFiles;
  }

  /// 从单本书的 metadata.opf 建立索引（不解析电子书内容）
  ///
  /// 供后台导入任务逐本调用；已存在（标题+作者相同）时返回已有书籍并跳过。
  Future<Book?> importOpfFile(String opfPath) async {
    final opf = await OpfReaderService.readFromOpfFile(opfPath);
    final bookDir = p.dirname(opfPath);

    final bookFile = await _findBookFile(bookDir);
    if (bookFile == null) {
      _log.w('BookService', '书籍文件夹内无 EPUB/PDF 文件: $bookDir');
      return null;
    }

    final bookId = _uuid.v4();
    final extension = p.extension(bookFile).toLowerCase();

    // 封面：从 OPF 引用复制到应用目录（只读第三方文件）
    String? coverPath;
    final opfCover = opf?.coverPath;
    if (opfCover != null && opfCover.isNotEmpty) {
      final coverAbsolute = p.join(bookDir, opfCover);
      if (await File(coverAbsolute).exists()) {
        final ext = p.extension(coverAbsolute).replaceFirst('.', '');
        final coverDest = await StorageConfig.getCoverSavePath(bookId, ext);
        try {
          await File(coverAbsolute).copy(coverDest);
          coverPath = coverDest;
        } catch (e) {
          _log.w('BookService', '复制封面失败: $e');
        }
      }
    }

    final title = (opf?.title?.isNotEmpty ?? false)
        ? opf!.title!
        : _titleFromFolder(bookDir);
    final author = (opf?.author?.isNotEmpty ?? false) ? opf!.author! : '未知作者';

    final book = Book(
      id: bookId,
      title: title,
      author: author,
      coverPath: coverPath,
      filePath: bookFile,
      format: extension == '.epub' ? BookFormat.epub : BookFormat.pdf,
      addedAt: DateTime.now(),
      language: opf?.language,
    );

    final existing =
        _books.where((b) => b.title == book.title && b.author == book.author).firstOrNull;
    if (existing != null) {
      _log.info('BookService', '书籍已存在: ${book.title}');
      return existing;
    }

    _books.add(book);
    await _saveBooksIndex();
    await _saveBookMetadata(book);
    _log.info('BookService', '书籍导入成功: ${book.title}');
    return book;
  }

  /// 在目录下查找电子书文件（.epub 优先，其次 .pdf）
  Future<String?> _findBookFile(String dirPath) async {
    String? pdfPath;
    await for (final entity in Directory(dirPath).list()) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (ext == '.epub') return entity.path;
        if (ext == '.pdf') pdfPath ??= entity.path;
      }
    }
    return pdfPath;
  }

  /// 从文件夹名提取标题（回退方案，去掉 Calibre 的 "(id)" 后缀）
  String _titleFromFolder(String dirPath) {
    final name = p.basename(dirPath);
    final cleaned = name.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '').trim();
    return cleaned.isNotEmpty ? cleaned : name;
  }

  /// 删除书籍及其所有数据（不可逆）
  Future<bool> deleteBook(String id) async {
    _log.d('BookService', '删除书籍: $id');
    try {
      final book = getBookById(id);
      if (book == null) {
        _log.w('BookService', '要删除的书籍不存在: $id');
        return false;
      }

      final bookDirPath = await StorageConfig.getBookDirectoryPath(id);
      final bookDir = Directory(bookDirPath);
      
      if (await bookDir.exists()) {
        final deleted = await _fileStorage.deleteDirectory(bookDirPath);
        if (!deleted) {
          _log.e('BookService', '删除书籍目录失败: ${book.title} ($id)');
          return false;
        }
      }

      _books.removeWhere((b) => b.id == id);
      await _saveBooksIndex();

      _log.info('BookService', '书籍删除成功: ${book.title}');
      return true;
    } catch (e, stackTrace) {
      _log.e('BookService', '删除书籍失败: $id', e, stackTrace);
      return false;
    }
  }

  /// 清空书架：删除所有书籍及其数据文件
  Future<int> clearAllBooks() async {
    _log.d('BookService', '清空书架');
    try {
      var deletedCount = 0;
      final books = List<Book>.from(_books);
      for (final book in books) {
        final bookDirPath = await StorageConfig.getBookDirectoryPath(book.id);
        final bookDir = Directory(bookDirPath);
        if (await bookDir.exists()) {
          await _fileStorage.deleteDirectory(bookDirPath);
        }
        deletedCount++;
      }
      _books.clear();
      await _saveBooksIndex();
      _log.info('BookService', '书架已清空: $deletedCount 本');
      return deletedCount;
    } catch (e, stackTrace) {
      _log.e('BookService', '清空书架失败', e, stackTrace);
      return 0;
    }
  }

  /// 替换内存中的书并同步持久化
  Future<void> updateBook(Book book) async {
    _log.d('BookService', '更新书籍: ${book.title}');
    try {
      final index = _books.indexWhere((b) => b.id == book.id);
      if (index >= 0) {
        _books[index] = book;
        await _saveBooksIndex();
        await _saveBookMetadata(book);
      }
    } catch (e, stackTrace) {
      _log.e('BookService', '更新书籍失败: ${book.id}', e, stackTrace);
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


