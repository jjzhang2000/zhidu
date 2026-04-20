import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import '../models/chapter_summary.dart';
import 'book_service.dart';
import 'summary_service.dart';
import 'log_service.dart';
import 'file_storage_service.dart';
import 'package:uuid/uuid.dart';

/// 数据导出服务 - 负责导出书籍摘要等功能
///
/// 提供将书籍数据导出为各种格式的功能：
/// - Markdown格式书籍摘要导出
/// - 用于分享和离线阅读
///
/// 设计原则：
/// - 导出操作独立于核心服务，避免耦合
/// - 支持批量导出，提高效率
/// - 保持导出格式的一致性和可读性
class ExportService {
  /// 服务实例
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// 日志服务
  final _log = LogService();

  /// 文件存储服务
  final _fileStorage = FileStorageService();

  /// 书籍服务引用
  final _bookService = BookService();

  /// 摘要服务引用
  final _summaryService = SummaryService();

  /// 导出单本书籍摘要为Markdown格式
  ///
  /// 参数：
  /// - [book]: 要导出的书籍对象
  /// - [exportDirPath]: 可选的导出目录路径，如果为null则使用默认位置
  ///
  /// 返回值：
  /// - 成功时返回导出的文件路径，失败时返回null
  ///
  /// 输出格式：
  /// ```markdown
  /// # 书籍标题
  /// 
  /// ## 书籍摘要
  /// 书籍的整体AI分析摘要
  /// 
  /// ## 章节摘要
  /// 
  /// ### 第1章：章节标题
  /// 章节AI摘要内容
  /// 
  /// ### 第2章：章节标题
  /// 章节AI摘要内容
  /// ```
  Future<String?> exportBookSummaryToMarkdown(Book book, {String? exportDirPath}) async {
    _log.v('ExportService', '开始导出书籍: ${book.id} - ${book.title}');

    try {
      // 获取书籍摘要
      final summary = await _summaryService.getBookSummary(book.id);

      // 获取章节摘要
      final chapterSummaries = await _summaryService.getAllSummaries();

      // 构建Markdown内容
      final buffer = StringBuffer();

      // 书籍标题
      buffer.writeln('# ${book.title}');
      buffer.writeln('');
      
      // 作者信息
      if (book.author != null && book.author!.isNotEmpty) {
        buffer.writeln('**作者**：${book.author}');
        buffer.writeln('');
      }

      // 书籍摘要
      if (summary != null) {
        buffer.writeln('## 书籍摘要');
        buffer.writeln(summary);
        buffer.writeln('');
      } else {
        buffer.writeln('## 书籍摘要');
        buffer.writeln('（暂无摘要）');
        buffer.writeln('');
      }

      // 章节摘要
      if (chapterSummaries.any((cs) => cs.bookId == book.id)) {
        buffer.writeln('## 章节摘要');
        buffer.writeln('');

        for (final chapterSummary in chapterSummaries.where((cs) => cs.bookId == book.id)) {
          buffer.writeln('### ${chapterSummary.chapterTitle}');
          buffer.writeln(chapterSummary.objectiveSummary);
          buffer.writeln('');
        }
      }

      // 确定导出目录
      String exportDir;
      if (exportDirPath != null) {
        exportDir = exportDirPath;
      } else {
        // 使用默认导出目录
        final docsDir = await _getDocumentsDirectory();
        exportDir = p.join(docsDir.path, 'zhidu_exports');
      }

      // 确保导出目录存在
      final exportDirectory = Directory(exportDir);
      if (!await exportDirectory.exists()) {
        await exportDirectory.create(recursive: true);
      }

      // 生成文件名（使用书籍标题，移除非法字符）
      String fileName = _sanitizeFileName('${book.title}_${book.id.substring(0, 8)}.md');
      final filePath = p.join(exportDir, fileName);

      // 写入文件
      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      _log.d('ExportService', '书籍导出成功: $filePath');
      return filePath;
    } catch (e, stackTrace) {
      _log.e('ExportService', '导出书籍失败: ${book.id}', e, stackTrace);
      return null;
    }
  }

  /// 导出所有书籍（有摘要的导出摘要，没有摘要的导出基本信息）
  ///
  /// 弹出文件夹选择对话框，让用户选择导出目录
  /// 然后导出所有书籍到该目录
  ///
  /// 返回值：
  /// - 成功导出的文件数量
  Future<int> exportAllBookSummariesWithDialog() async {
    _log.v('ExportService', '开始导出所有书籍（带目录选择）');

    try {
      // 弹出文件夹选择对话框
      final exportPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择导出目录',
      );

      if (exportPath == null) {
        _log.d('ExportService', '用户取消了导出目录选择');
        return 0; // 用户取消了操作
      }

      // 获取所有书籍
      final books = _bookService.books;
      _log.d('ExportService', '发现书籍总数: ${books.length}');
      int successCount = 0;

      for (final book in books) {
        _log.v('ExportService', '导出书籍: ${book.title} (${book.id})');
        // 导出每本书，有摘要的导出完整内容，没有摘要的导出基本信息
        final result = await exportBookSummaryToMarkdown(book, exportDirPath: exportPath);
        if (result != null) {
          successCount++;
          _log.d('ExportService', '成功导出书籍: ${book.title}');
        } else {
          _log.w('ExportService', '导出书籍失败: ${book.title}');
        }
      }

      _log.d('ExportService', '全部书籍导出完成，成功: $successCount，总计: ${books.length}');
      return successCount;
    } catch (e, stackTrace) {
      _log.e('ExportService', '导出所有书籍失败', e, stackTrace);
      return 0;
    }
  }

  /// 导出所有书籍摘要（旧方法，保持向后兼容）
  ///
  /// 遍历所有书籍，逐个导出其摘要到默认目录
  ///
  /// 返回值：
  /// - 成功导出的文件数量
  @Deprecated('Use exportAllBookSummariesWithDialog() instead')
  Future<int> exportAllBookSummaries() async {
    _log.v('ExportService', '开始导出所有书籍摘要（旧方法）');
    
    final books = _bookService.books;
    int successCount = 0;

    for (final book in books) {
      final result = await exportBookSummaryToMarkdown(book);
      if (result != null) successCount++;
    }

    _log.d('ExportService', '全部书籍摘要导出完成，成功: $successCount / 总计: ${books.length}');
    return successCount;
  }

  /// 获取文档目录
  /// 
  /// 使用path_provider获取系统文档目录
  Future<Directory> _getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// 清理文件名中的非法字符
  /// 
  /// 参数：
  /// - [fileName]: 原始文件名
  /// 
  /// 返回值：
  /// - 清理后的合法文件名
  String _sanitizeFileName(String fileName) {
    // 替换Windows文件名中的非法字符
    return fileName
        .replaceAll(r'/','_')
        .replaceAll(r'\','_')
        .replaceAll('<','_')
        .replaceAll('>','_')
        .replaceAll(':','_')
        .replaceAll('"','_')
        .replaceAll('|','_')
        .replaceAll('?','_')
        .replaceAll('*','_')
        // 移除控制字符
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '_');
  }

  /// 备份所有数据
  ///
  /// 将所有应用数据导出为JSON文件
  /// 
  /// 返回值：
  /// - 成功时返回导出的文件路径，失败时返回null
  Future<String?> backupAllData() async {
    _log.v('ExportService', '开始备份所有数据');

    try {
      // 获取文档目录
      final docsDir = await _getDocumentsDirectory();
      final backupDir = Directory(p.join(docsDir.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // 生成备份文件名
      final timestamp = DateTime.now().toString().split('.').first.replaceAll(RegExp(r'[-: ]'), '');
      final fileName = 'backup_$timestamp.json';
      final filePath = p.join(backupDir.path, fileName);

      // 获取所有书籍数据
      final books = _bookService.books.map((book) => book.toJson()).toList();
      
      // 构建备份数据
      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'books': books,
        // 可以扩展备份其他数据（设置、摘要等）
      };

      // 写入文件
      final file = File(filePath);
      await file.writeAsString(jsonEncode(backupData));

      _log.d('ExportService', '数据备份成功: $filePath');
      return filePath;
    } catch (e, stackTrace) {
      _log.e('ExportService', '备份所有数据失败', e, stackTrace);
      return null;
    }
  }

  /// 从备份恢复数据
  ///
  /// 从JSON备份文件恢复所有数据
  /// 
  /// 返回值：
  /// - 成功时返回恢复的项目数量，失败时返回null
  Future<int?> restoreFromBackup() async {
    _log.v('ExportService', '开始从备份恢复数据');

    try {
      // 让用户选择备份文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: '选择备份文件',
      );

      if (result == null || result.files.single.path == null) {
        _log.d('ExportService', '用户取消了备份文件选择');
        return null;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);

      // 读取备份数据
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString);

      // 验证备份数据格式
      if (backupData['version'] == null || backupData['books'] == null) {
        _log.w('ExportService', '备份文件格式不正确');
        return null;
      }

      // 恢复书籍数据
      final booksData = backupData['books'] as List<dynamic>;
      int restoredCount = 0;

      for (final bookData in booksData) {
        try {
          // 尝试从备份数据创建书籍对象
          final book = Book.fromJson(bookData);
          
          // 恢复书籍文件（如果存在）
          final originalPath = bookData['originalPath'] as String?;
          if (originalPath != null && File(originalPath).existsSync()) {
            // 复制原书籍文件到当前目录
            final docsDir = await _getDocumentsDirectory();
            final destPath = p.join(docsDir.path, 'books', p.basename(originalPath));
            await File(originalPath).copy(destPath);
          }

          // 添加书籍到书架（如果不存在）
          final existingBook = _bookService.getBookById(book.id);
          if (existingBook == null) {
            _bookService.books.add(book);
            await _bookService.saveBooksIndex(); // 保存书籍索引
            restoredCount++;
          } else {
            _log.d('ExportService', '书籍已存在，跳过: ${book.title}');
          }
        } catch (e, stackTrace) {
          _log.e('ExportService', '恢复书籍失败: ${bookData['title'] as String? ?? 'Unknown'}', e, stackTrace);
          continue;
        }
      }

      _log.d('ExportService', '数据恢复完成，成功恢复: $restoredCount 个项目');
      return restoredCount;
    } catch (e, stackTrace) {
      _log.e('ExportService', '从备份恢复数据失败', e, stackTrace);
      return null;
    }
  }
}