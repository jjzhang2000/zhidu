import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/book.dart';
import 'epub_service.dart';
import 'pdf_service.dart';
import 'log_service.dart';
import 'storage_config.dart';
import 'file_storage_service.dart';

/// 书籍管理服务 - 负责书籍的导入、存储、查询和删除
///
/// 单例模式实现：
/// - 使用工厂构造函数返回静态实例 `_instance`
/// - 私有命名构造函数 `_internal()` 确保外部无法直接创建实例
/// - 所有服务层（EpubService、PdfService、LogService、FileStorageService）均通过单例访问
///
/// 数据存储结构：
/// - 索引文件：`books_index.json` - 存储所有书籍的基本信息列表
/// - 元数据文件：`{book_id}/metadata.json` - 每本书的完整元数据
///
/// 存储优势：
/// - 索引文件小，加载快速
/// - 元数据独立存储，修改单个书籍不影响索引
/// - 支持增量更新，避免重写整个数据文件
class BookService {
  /// 单例实例 - 应用生命周期内唯一
  static final BookService _instance = BookService._internal();

  /// 工厂构造函数 - 始终返回单例实例
  factory BookService() => _instance;

  /// 私有命名构造函数 - 防止外部直接实例化
  BookService._internal();

  /// EPUB解析服务 - 处理.epub格式电子书
  final _epubService = EpubService();

  /// PDF解析服务 - 处理.pdf格式电子书
  final _pdfService = PdfService();

  /// 日志服务 - 统一日志输出
  final _log = LogService();

  /// 文件存储服务 - JSON/文本文件的读写
  final _fileStorage = FileStorageService();

  /// 内存中的书籍列表 - 应用启动时从文件加载
  List<Book> _books = [];

  /// 只读访问书籍列表 - 外部不能直接修改
  List<Book> get books => _books;

  /// 初始化书籍服务 - 应用启动时调用
  ///
  /// 加载流程：
  /// 1. 读取索引文件 `books_index.json`
  /// 2. 根据索引中的书籍ID，逐个加载元数据文件
  /// 3. 将解析后的Book对象存入内存列表
  ///
  /// 错误处理：
  /// - 索引文件不存在：返回空列表
  /// - 单个元数据解析失败：跳过该书，记录错误日志
  Future<void> init() async {
    _log.v('BookService', 'init 开始执行');
    await _loadBooks();
    _log.v('BookService', 'init 执行完成, 加载书籍数量: ${_books.length}');
  }

  /// 从文件加载所有书籍数据
  ///
  /// 存储结构说明：
  /// ```
  /// {storage_path}/
  /// ├── books_index.json          # 索引文件（书籍ID列表）
  /// └── books/
  ///     ├── {book_id_1}/
  ///     │   └── metadata.json      # 书籍1的完整元数据
  ///     └── {book_id_2}/
  ///         └── metadata.json      # 书籍2的完整元数据
  /// ```
  ///
  /// 加载流程：
  /// 1. 读取索引文件获取书籍ID列表
  /// 2. 遍历每个ID，读取对应的元数据文件
  /// 3. 使用Book.fromJson()解析元数据
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

  /// 保存书籍索引文件
  ///
  /// 索引文件内容：
  /// - version: 数据格式版本号
  /// - lastUpdated: 最后更新时间（ISO8601格式）
  /// - books: 书籍基本信息列表（仅包含ID、标题、作者等关键字段）
  ///
  /// 设计考量：
  /// - 索引文件仅存储概要信息，体积小
  /// - 完整元数据存储在独立文件中
  /// - 支持快速扫描和增量加载
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

  /// 保存单个书籍的完整元数据
  ///
  /// 元数据文件路径：`{storage_path}/books/{book_id}/metadata.json`
  /// 内容：Book对象的完整JSON序列化（包含章节、位置等所有信息）
  Future<void> _saveBookMetadata(Book book) async {
    final metadataPath = await StorageConfig.getBookMetadataPath(book.id);
    final data = book.toJson();
    await _fileStorage.writeJson(metadataPath, data);
  }

  /// 从指定路径导入书籍 - 支持测试和直接导入
  ///
  /// 导入流程：
  /// 1. 根据文件扩展名选择对应的解析服务
  /// 2. 解析文件，提取书籍信息（标题、作者、章节等）
  /// 3. 检查是否已存在相同书籍（标题+作者去重）
  /// 4. 保存到内存列表和文件系统
  ///
  /// 返回值：
  /// - 成功：返回新导入或已存在的Book对象
  /// - 失败：返回null（格式不支持、解析错误等）
  ///
  /// 去重策略：
  /// - 使用标题+作者组合判断是否重复
  /// - 重复时返回已存在的书籍，不创建新记录
  Future<Book?> importBookFromPath(String filePath) async {
    _log.v('BookService', 'importBookFromPath 开始执行: $filePath');
    try {
      _log.d('BookService', '开始导入书籍: $filePath');

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
          _log.info('BookService', '书籍已存在: ${book.title}');
          return existingBook;
        }

        _books.add(book);
        await _saveBooksIndex();
        await _saveBookMetadata(book);

        _log.info('BookService', '书籍导入成功: ${book.title}');
        return book;
      }

      return null;
    } catch (e, stackTrace) {
      _log.e('BookService', '导入书籍失败: $filePath', e, stackTrace);
      return null;
    }
  }

  /// 导入新书籍 - 核心导入流程（通过文件选择器）
  ///
  /// 导入流程：
  /// 1. 打开文件选择器，支持EPUB和PDF格式
  /// 2. 获取文件路径后调用 importBookFromPath
  ///
  /// 返回值：
  /// - 成功：返回新导入或已存在的Book对象
  /// - 失败：返回null（用户取消、格式不支持、解析错误等）
  Future<Book?> importBook() async {
    _log.v('BookService', 'importBook 开始执行');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf'],
        dialogTitle: '选择电子书',
      );

      if (result == null || result.files.isEmpty) {
        _log.d('BookService', '用户取消选择');
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

  /// 根据ID获取书籍 - O(n)线性查找
  Book? getBookById(String id) {
    return _books.where((b) => b.id == id).firstOrNull;
  }

  /// 删除书籍 - 完整删除流程
  ///
  /// 删除流程：
  /// 1. 查找书籍，不存在则返回false
  /// 2. 删除书籍数据目录（包含元数据、摘要等所有文件）
  /// 3. 从内存列表中移除
  /// 4. 更新索引文件
  ///
  /// 注意事项：
  /// - 删除操作不可逆
  /// - 会同时删除该书籍的所有摘要数据
  /// - 磁盘空间会立即释放
  Future<bool> deleteBook(String id) async {
    _log.d('BookService', '删除书籍: $id');
    try {
      final book = getBookById(id);
      if (book == null) {
        _log.w('BookService', '要删除的书籍不存在: $id');
        return false;
      }

      final bookDir = await StorageConfig.getBookDirectory(id);
      await _fileStorage.deleteDirectory(bookDir.path);

      _books.removeWhere((b) => b.id == id);
      await _saveBooksIndex();

      _log.info('BookService', '书籍删除成功: ${book.title}');
      return true;
    } catch (e, stackTrace) {
      _log.e('BookService', '删除书籍失败: $id', e, stackTrace);
      return false;
    }
  }

  /// 更新书籍信息 - 增量更新
  ///
  /// 更新流程：
  /// 1. 根据ID在内存列表中查找书籍
  /// 2. 替换内存中的Book对象
  /// 3. 同步更新索引文件和元数据文件
  ///
  /// 使用场景：
  /// - 更新阅读位置
  /// - 更新章节标题映射
  /// - 修改书籍元数据
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

  /// 搜索书籍 - 模糊匹配标题和作者
  ///
  /// 搜索逻辑：
  /// - 不区分大小写
  /// - 匹配标题或作者中包含搜索词的书籍
  List<Book> searchBooks(String query) {
    final lowerQuery = query.toLowerCase();
    return _books.where((book) {
      return book.title.toLowerCase().contains(lowerQuery) ||
          book.author.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 更新章节标题映射 - 用于修正EPUB解析错误的章节标题
  ///
  /// 使用场景：
  /// - 用户手动修正错误的章节标题
  /// - AI生成的章节标题替换
  ///
  /// 实现逻辑：
  /// 1. 获取当前章节标题映射（chapterTitles）
  /// 2. 更新或添加指定索引的标题
  /// 3. 使用copyWith创建新的Book对象
  /// 4. 调用updateBook持久化更改
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
