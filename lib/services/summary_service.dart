import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/chapter_summary.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'ai_service.dart';
import 'book_service.dart';
import 'epub_service.dart';
import 'pdf_service.dart';
import 'log_service.dart';
import 'parsers/format_registry.dart';
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
      final filePath =
          await StorageConfig.getChapterSummaryPath(bookId, chapterIndex);
      final content = await _fileStorage.readText(filePath);

      if (content == null || content.isEmpty) {
        _log.v('SummaryService', 'getSummary 加载完成, result: 空');
        return null;
      }

      final summary = ChapterSummary(
        bookId: bookId,
        chapterIndex: chapterIndex,
        chapterTitle: '', // 章节标题在读取时会从章节列表获取
        objectiveSummary: content,
        aiInsight: '',
        keyPoints: [],
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
      _log.d(
          'SummaryService', '摘要已保存: ${summary.bookId}_${summary.chapterIndex}');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'saveSummary 失败', e, stackTrace);
    }
  }

  Future<void> deleteSummary(String bookId, int chapterIndex) async {
    try {
      final filePath =
          await StorageConfig.getChapterSummaryPath(bookId, chapterIndex);
      await _fileStorage.deleteFile(filePath);
      _log.d('SummaryService', '摘要已删除: ${bookId}_$chapterIndex');
    } catch (e, stackTrace) {
      _log.e('SummaryService', 'deleteSummary 失败', e, stackTrace);
    }
  }

  Future<List<ChapterSummary>> getSummariesForBook(String bookId) async {
    try {
      final bookDir = await StorageConfig.getBookDirectory(bookId);
      final files =
          await _fileStorage.listFiles(bookDir.path, extension: '.md');

      final summaries = <ChapterSummary>[];

      for (final file in files) {
        final filename = p.basename(file.path);
        if (filename.startsWith('chapter-') && filename.endsWith('.md')) {
          final indexStr = filename.substring(8, 11); // chapter-000.md -> 000
          final index = int.tryParse(indexStr);
          if (index != null) {
            final content = await _fileStorage.readText(file.path);
            if (content != null && content.isNotEmpty) {
              final lastModified = await file.lastModified();
              summaries.add(ChapterSummary(
                bookId: bookId,
                chapterIndex: index,
                chapterTitle: '',
                objectiveSummary: content,
                aiInsight: '',
                keyPoints: [],
                createdAt: lastModified,
              ));
            }
          }
        }
      }

      // 按章节索引排序
      summaries.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
      return summaries;
    } catch (e, stackTrace) {
      _log.e(
          'SummaryService', 'getSummariesForBook 失败: $bookId', e, stackTrace);
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
        content,
        chapterTitle: chapterTitle,
      );

      if (summary != null && summary.isNotEmpty) {
        final extractedTitle = extractTitleFromSummary(summary);
        final cleanSummary = removeTitleLineFromSummary(summary);

        if (extractedTitle != null && extractedTitle.isNotEmpty) {
          await _bookService.updateChapterTitle(
              bookId, chapterIndex, extractedTitle);
          _log.d('SummaryService', '提取并更新章节标题: $extractedTitle');
        }

        final chapterSummary = ChapterSummary(
          bookId: bookId,
          chapterIndex: chapterIndex,
          chapterTitle: extractedTitle ?? chapterTitle,
          objectiveSummary: cleanSummary,
          aiInsight: '',
          keyPoints: [],
          createdAt: DateTime.now(),
        );

        await saveSummary(chapterSummary);
        _log.info('SummaryService', '摘要生成成功: $key');
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

  Future<void> generateSummariesForBook(Book book) async {
    _log.d('SummaryService', '开始为书籍生成摘要: ${book.title}');

    try {
      // 使用FormatRegistry获取解析器
      final extension = book.format == BookFormat.epub ? '.epub' : '.pdf';
      final parser = FormatRegistry.getParser(extension);

      if (parser == null) {
        _log.w('SummaryService', '不支持的格式: ${book.format}');
        return;
      }

      // 获取章节列表
      final chapters = await parser.getChapters(book.filePath);
      _log.d('SummaryService', '获取到 ${chapters.length} 个章节');

      if (book.format == BookFormat.epub) {
        // EPUB文件：先生成全书摘要，再生成章节摘要
        _log.d('SummaryService', 'EPUB格式：先生成全书摘要');
        await _generateBookSummaryFromPreface(book, chapters, parser);

        // 再生成章节摘要
        await _generateChapterSummaries(book, chapters, parser);
      } else {
        // PDF文件：先生成章节摘要，再用章节摘要生成全书摘要
        _log.d('SummaryService', 'PDF格式：先生成章节摘要');
        await _generateChapterSummaries(book, chapters, parser);

        // 最后用章节摘要生成全书摘要
        await _generateBookSummaryFromChapters(book, chapters);
      }

      _log.info('SummaryService', '书籍摘要生成完成: ${book.title}');
    } catch (e, stackTrace) {
      _log.e('SummaryService', '生成书籍摘要失败: ${book.title}', e, stackTrace);
    }
  }

  /// 生成章节摘要（只为顶层章节生成）
  Future<void> _generateChapterSummaries(
    Book book,
    List<Chapter> chapters,
    dynamic parser,
  ) async {
    // 只为顶层章节（level==0）生成摘要
    final topLevelChapters = chapters.where((c) => c.level == 0).toList();
    _log.d('SummaryService', '开始生成章节摘要: 顶层章节 ${topLevelChapters.length} 章');

    for (final chapter in topLevelChapters) {
      // chapter.index 是专门为顶层章节计算的索引
      final chapterIndex = chapter.index;
      if (chapterIndex < 0) continue; // 跳过无效index

      final existingSummary = await getSummary(book.id, chapterIndex);
      if (existingSummary != null) {
        _log.d('SummaryService', '章节 $chapterIndex 已有摘要，跳过');
        continue;
      }

      // 获取章节内容并生成摘要
      final content = await parser.getChapterContent(book.filePath, chapter);
      final chapterContent = content.htmlContent;

      if (chapterContent != null && chapterContent.isNotEmpty) {
        await generateSingleSummary(
          book.id,
          chapterIndex,
          chapter.title,
          chapterContent,
        );
      }
    }
  }

  /// 从前言/目录生成全书摘要（用于EPUB等有目录结构的文件）
  Future<void> _generateBookSummaryFromPreface(
    Book book,
    List<Chapter> chapters,
    dynamic parser,
  ) async {
    _log.d('SummaryService', '从前言/目录生成全书摘要: ${book.title}');

    try {
      // 检查是否已有全书摘要
      final existingSummary = await getBookSummary(book.id);
      if (existingSummary != null && existingSummary.isNotEmpty) {
        _log.d('SummaryService', '已有全书摘要，跳过: ${book.title}');
        return;
      }

      // 收集目录信息作为前言内容
      final prefaceContent = StringBuffer();
      prefaceContent.writeln('本书目录结构：\n');

      for (int i = 0; i < chapters.length && i < 20; i++) {
        prefaceContent.writeln('第${i + 1}章：${chapters[i].title}');
      }

      if (chapters.length > 20) {
        prefaceContent.writeln('... 等共 ${chapters.length} 章');
      }

      // 生成全书摘要
      final bookSummary = await _aiService.generateBookSummaryFromPreface(
        title: book.title,
        author: book.author,
        prefaceContent: prefaceContent.toString(),
        totalChapters: chapters.length,
      );

      if (bookSummary != null && bookSummary.isNotEmpty) {
        await saveBookSummary(book.id, bookSummary);
        _log.info('SummaryService', '全书摘要生成成功: ${book.title}');
      } else {
        _log.w('SummaryService', 'AI返回空的全书摘要: ${book.title}');
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '从前言生成全书摘要失败: ${book.title}', e, stackTrace);
    }
  }

  /// 从章节摘要生成全书摘要（用于PDF等无目录结构的文件）
  Future<void> _generateBookSummaryFromChapters(
    Book book,
    List<Chapter> chapters,
  ) async {
    _log.d('SummaryService', '从章节摘要生成全书摘要: ${book.title}');

    try {
      // 检查是否已有全书摘要
      final existingSummary = await getBookSummary(book.id);
      if (existingSummary != null && existingSummary.isNotEmpty) {
        _log.d('SummaryService', '已有全书摘要，跳过: ${book.title}');
        return;
      }

      // 收集所有章节摘要
      final chapterSummaries = <String>[];
      for (int i = 0; i < chapters.length && i < 10; i++) {
        final summary = await getSummary(book.id, i);
        if (summary != null && summary.objectiveSummary.isNotEmpty) {
          final shortSummary = summary.objectiveSummary.length > 200
              ? summary.objectiveSummary.substring(0, 200)
              : summary.objectiveSummary;
          chapterSummaries.add('第${i + 1}章：$shortSummary...');
        }
      }

      if (chapterSummaries.isEmpty) {
        _log.w('SummaryService', '没有章节摘要，无法生成全书摘要: ${book.title}');
        return;
      }

      // 生成全书摘要
      final bookSummary = await _aiService.generateBookSummary(
        title: book.title,
        author: book.author,
        chapterSummaries: chapterSummaries.join('\n\n'),
        totalChapters: chapters.length,
      );

      if (bookSummary != null && bookSummary.isNotEmpty) {
        await saveBookSummary(book.id, bookSummary);
        _log.info('SummaryService', '全书摘要生成成功: ${book.title}');
      } else {
        _log.w('SummaryService', 'AI返回空的全书摘要: ${book.title}');
      }
    } catch (e, stackTrace) {
      _log.e('SummaryService', '从章节摘要生成全书摘要失败: ${book.title}', e, stackTrace);
    }
  }

  /// 获取所有摘要（用于导出）
  Future<List<ChapterSummary>> getAllSummaries() async {
    final allSummaries = <ChapterSummary>[];

    // 遍历所有书籍目录获取摘要
    final appDir = await StorageConfig.getAppDirectory();
    final booksDir = Directory('${appDir.path}/books');

    if (!await booksDir.exists()) {
      return [];
    }

    final bookDirs = await booksDir
        .list()
        .where((e) => e is Directory)
        .cast<Directory>()
        .toList();

    for (final bookDir in bookDirs) {
      final bookId = p.basename(bookDir.path);
      final summaries = await getSummariesForBook(bookId);
      allSummaries.addAll(summaries);
    }

    return allSummaries;
  }

  /// 删除书籍的所有摘要
  /// 注意：BookService.deleteBook已经删除了整个书籍目录，
  /// 所以这个方法在文件存储模式下实际上什么都不需要做
  Future<void> deleteAllSummariesForBook(String bookId) async {
    _log.d('SummaryService', '删除书籍所有摘要: $bookId');
    // 文件存储模式下，书籍目录的删除由BookService处理
    // 这里可以保留为兼容旧代码的接口
  }

  String? extractTitleFromSummary(String summary) {
    final lines = summary.split('\n');
    if (lines.isEmpty) return null;

    final firstLine = lines[0].trim();
    final titlePattern = RegExp(r'^##\s*章节标题[：:]\s*(.+)$');
    final match = titlePattern.firstMatch(firstLine);

    if (match != null) {
      final title = match.group(1)?.trim() ?? '';

      if (title.isEmpty || title.length > 50) {
        return null;
      }

      if (title.contains('#') || title.contains('**') || title.contains('*')) {
        return null;
      }

      return title;
    }

    return null;
  }

  String removeTitleLineFromSummary(String summary) {
    final lines = summary.split('\n');
    if (lines.isEmpty) return summary;

    final firstLine = lines[0].trim();
    final titlePattern = RegExp(r'^##\s*章节标题[：:]\s*.+$');

    if (titlePattern.hasMatch(firstLine)) {
      if (lines.length > 1 && lines[1].trim().isEmpty) {
        return lines.skip(2).join('\n').trim();
      }
      return lines.skip(1).join('\n').trim();
    }

    return summary;
  }
}
