import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../data/database/database.dart';
import '../models/chapter_summary.dart';
import '../models/book.dart';
import 'ai_service.dart';
import 'book_service.dart';
import 'epub_service.dart';
import 'log_service.dart';

class SummaryService {
  static final SummaryService _instance = SummaryService._internal();
  factory SummaryService() => _instance;
  SummaryService._internal();

  late final AppDatabase _db;
  final _aiService = AIService();
  final _epubService = EpubService();
  final _bookService = BookService();
  final _log = LogService();

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
    _db = AppDatabase();
  }

  Future<ChapterSummary?> getSummary(String bookId, int chapterIndex) async {
    _log.v('SummaryService',
        'getSummary 开始执行, bookId: $bookId, chapterIndex: $chapterIndex');

    final tables = await (_db.select(_db.chapterSummaries)
          ..where((s) =>
              s.bookId.equals(bookId) & s.chapterIndex.equals(chapterIndex)))
        .get();

    if (tables.isEmpty) {
      _log.v('SummaryService', 'getSummary 加载完成, result: 空');
      return null;
    }

    if (tables.length > 1) {
      _log.w('SummaryService', '发现重复记录: ${tables.length}条，保留最新');
      final latest = tables.reduce((a, b) => a.createdAt > b.createdAt ? a : b);
      final result = _tableToChapterSummary(latest);
      return result;
    }

    final result = _tableToChapterSummary(tables.first);
    _log.v('SummaryService', 'getSummary 加载完成, result: 有内容');
    return result;
  }

  Future<void> saveSummary(ChapterSummary summary) async {
    await _db.into(_db.chapterSummaries).insert(
          _chapterSummaryToCompanion(summary),
          mode: InsertMode.insertOrReplace,
        );
    _log.d(
        'SummaryService', '摘要已保存: ${summary.bookId}_${summary.chapterIndex}');
  }

  Future<void> deleteSummary(String bookId, int chapterIndex) async {
    await (_db.delete(_db.chapterSummaries)
          ..where((s) =>
              s.bookId.equals(bookId) & s.chapterIndex.equals(chapterIndex)))
        .go();
  }

  Future<void> deleteAllSummariesForBook(String bookId) async {
    await (_db.delete(_db.chapterSummaries)
          ..where((s) => s.bookId.equals(bookId)))
        .go();
    await (_db.delete(_db.bookSummaries)..where((s) => s.bookId.equals(bookId)))
        .go();
  }

  Future<bool> hasSummary(String bookId, int chapterIndex) async {
    final summary = await getSummary(bookId, chapterIndex);
    return summary != null;
  }

  Future<int> getSummaryCount(String bookId) async {
    final summaries = await (_db.select(_db.chapterSummaries)
          ..where((s) => s.bookId.equals(bookId)))
        .get();
    return summaries.length;
  }

  Future<List<ChapterSummary>> getSummariesForBook(String bookId) async {
    final tables = await (_db.select(_db.chapterSummaries)
          ..where((s) => s.bookId.equals(bookId))
          ..orderBy([(s) => OrderingTerm(expression: s.chapterIndex)]))
        .get();
    return tables.map(_tableToChapterSummary).toList();
  }

  Future<List<ChapterSummary>> getAllSummaries() async {
    final tables = await _db.select(_db.chapterSummaries).get();
    return tables.map(_tableToChapterSummary).toList();
  }

  ChapterSummary _tableToChapterSummary(ChapterSummaryTable table) {
    return ChapterSummary(
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

  ChapterSummariesCompanion _chapterSummaryToCompanion(ChapterSummary model) {
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

  int? _findPrefaceChapter(List<ChapterInfo> chapters) {
    final prefaceKeywords = [
      '前言',
      '序言',
      '序',
      '自序',
      '代序',
      '引言',
      '导言',
      '导读',
      'preface',
      'foreword',
      'introduction',
      'prologue',
    ];

    for (int i = 0; i < chapters.length; i++) {
      final title = chapters[i].title.toLowerCase();
      for (final keyword in prefaceKeywords) {
        if (title.contains(keyword.toLowerCase())) {
          return i;
        }
      }
    }
    return null;
  }

  Future<void> generateSummariesForBook(Book book) async {
    if (!_aiService.isConfigured) {
      _log.w('SummaryService', 'AI服务未配置，跳过章节摘要生成');
      return;
    }

    final existingCount = await getSummaryCount(book.id);
    _log.d(
        'SummaryService', '开始为书籍生成章节摘要: ${book.title}, 已有摘要: $existingCount');

    try {
      final hierarchicalChapters =
          await _epubService.getHierarchicalChapterList(book.filePath);

      // 只取第一级章节
      final topLevelChapters =
          hierarchicalChapters.where((c) => c.level == 0).toList();
      _log.d('SummaryService',
          '全部章节 ${hierarchicalChapters.length} 个，第一级章节 ${topLevelChapters.length} 个');
      for (int i = 0; i < hierarchicalChapters.length; i++) {
        _log.d('SummaryService',
            '  章节[$i] level=${hierarchicalChapters[i].level} title="${hierarchicalChapters[i].title}"');
      }

      // 检测是否有前言章节（在全部章节中搜索，不仅限第一级）
      final prefaceIndex = _findPrefaceChapter(topLevelChapters);
      _log.d('SummaryService', '第一级章节中前言检测结果: prefaceIndex=$prefaceIndex');

      // 如果第一级没找到，在全部章节中搜索
      final prefaceIndexAll =
          prefaceIndex ?? _findPrefaceChapter(hierarchicalChapters);
      _log.d('SummaryService', '全部章节中前言检测结果: prefaceIndexAll=$prefaceIndexAll');

      // 如果有前言且书籍没有介绍，直接从前言生成全书摘要
      if (prefaceIndexAll != null &&
          (book.aiIntroduction == null || book.aiIntroduction!.isEmpty)) {
        _log.d('SummaryService', '发现前言章节 $prefaceIndexAll，直接生成全书摘要');
        await _generateBookSummaryFromPreface(
            book, hierarchicalChapters[prefaceIndexAll]);
      }

      for (int i = 0; i < topLevelChapters.length; i++) {
        final chapter = topLevelChapters[i];

        if (await hasSummary(book.id, i)) {
          _log.d('SummaryService', '章节 $i 已有摘要，跳过');
          continue;
        }

        final key = _key(book.id, i);
        if (_generatingKeys.contains(key)) {
          _log.d('SummaryService', '章节 $i 正在生成中，跳过');
          continue;
        }

        _generatingKeys.add(key);
        final future = _doGenerateChapterSummary(book, chapter, i);
        _generatingFutures[key] = future;
        try {
          await future;
        } finally {
          _generatingKeys.remove(key);
          _generatingFutures.remove(key);
        }

        await Future.delayed(const Duration(seconds: 1));
      }

      // 如果没有前言，所有章节摘要生成完成后，生成全书摘要
      if (prefaceIndexAll == null &&
          (book.aiIntroduction == null || book.aiIntroduction!.isEmpty)) {
        final topLevelWithIndex = topLevelChapters
            .asMap()
            .entries
            .map((e) => _ChapterWithIndex(e.value, e.key))
            .toList();
        await _generateBookSummary(book, topLevelWithIndex);
      }

      _log.d('SummaryService', '书籍所有摘要生成完成: ${book.title}');
    } catch (e) {
      _log.e('SummaryService', '生成章节摘要失败', e);
    }
  }

  Future<bool> generateSingleSummary(String bookId, int chapterIndex,
      String chapterTitle, String content) async {
    if (!_aiService.isConfigured) {
      _log.w('SummaryService', 'AI服务未配置，无法生成摘要');
      return false;
    }

    final key = _key(bookId, chapterIndex);
    if (_generatingKeys.contains(key)) {
      _log.d('SummaryService', '章节 $chapterIndex 正在生成中，跳过');
      return false;
    }

    if (await hasSummary(bookId, chapterIndex)) {
      _log.d('SummaryService', '章节 $chapterIndex 已有摘要，跳过');
      return true;
    }

    _generatingKeys.add(key);
    final completer = Completer<void>();
    _generatingFutures[key] = completer.future;

    try {
      final markdownSummary = await _aiService.generateFullChapterSummary(
        content,
        chapterTitle: chapterTitle,
      );

      if (markdownSummary != null) {
        final chapterSummary = ChapterSummary(
          bookId: bookId,
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle,
          objectiveSummary: markdownSummary,
          aiInsight: '',
          keyPoints: [],
          createdAt: DateTime.now(),
        );
        await saveSummary(chapterSummary);
        _log.d('SummaryService', '章节 $chapterIndex 摘要已保存');
        completer.complete();
        return true;
      }
      completer.complete();
      return false;
    } catch (e) {
      completer.complete();
      rethrow;
    } finally {
      _generatingKeys.remove(key);
      _generatingFutures.remove(key);
    }
  }

  Future<void> _doGenerateChapterSummary(
      Book book, ChapterInfo chapter, int chapterIndex) async {
    if (chapter.href == null) {
      _log.w('SummaryService', '章节 $chapterIndex 无href，跳过');
      return;
    }

    final content = await _epubService.getChapterContentFromHref(
        book.filePath, chapter.href!);
    if (content == null || content.isEmpty) {
      _log.w('SummaryService', '章节 $chapterIndex 内容为空或无法读取，跳过');
      return;
    }

    final markdownSummary = await _aiService.generateFullChapterSummary(
      content,
      chapterTitle: chapter.title,
    );

    if (markdownSummary != null) {
      final chapterSummary = ChapterSummary(
        bookId: book.id,
        chapterIndex: chapterIndex,
        chapterTitle: chapter.title,
        objectiveSummary: markdownSummary,
        aiInsight: '',
        keyPoints: [],
        createdAt: DateTime.now(),
      );
      await saveSummary(chapterSummary);
      _log.d('SummaryService', '章节 $chapterIndex 摘要已保存');
    }
  }

  Future<void> _generateBookSummaryFromPreface(
    Book book,
    ChapterInfo prefaceChapter,
  ) async {
    if (prefaceChapter.href == null) {
      _log.w('SummaryService', '前言章节无href，跳过');
      return;
    }

    final prefaceContent = await _epubService.getChapterContentFromHref(
        book.filePath, prefaceChapter.href!);
    if (prefaceContent == null || prefaceContent.isEmpty) {
      _log.w('SummaryService', '前言内容为空，跳过');
      return;
    }

    final bookSummary = await _aiService.generateBookSummaryFromPreface(
      title: book.title,
      author: book.author,
      prefaceContent: prefaceContent,
      totalChapters: book.totalChapters,
    );

    if (bookSummary != null && bookSummary.isNotEmpty) {
      final updatedBook = book.copyWith(aiIntroduction: bookSummary);
      await _bookService.updateBook(updatedBook);
      _log.d('SummaryService', '基于前言的全书摘要已生成并保存');
    }
  }

  Future<void> _generateBookSummary(
    Book book,
    List<_ChapterWithIndex> flatChapters,
  ) async {
    final summaries = await _getAllSummariesForBook(book.id);
    if (summaries.isEmpty) {
      _log.w('SummaryService', '无章节摘要，跳过早书摘要生成');
      return;
    }

    final buffer = StringBuffer();
    for (final summary in summaries) {
      buffer.writeln('### ${summary.chapterTitle}');
      buffer.writeln(summary.objectiveSummary);
      buffer.writeln();
    }

    final bookSummary = await _aiService.generateBookSummary(
      title: book.title,
      author: book.author,
      chapterSummaries: buffer.toString(),
      totalChapters: book.totalChapters,
    );

    if (bookSummary != null && bookSummary.isNotEmpty) {
      final updatedBook = book.copyWith(aiIntroduction: bookSummary);
      await _bookService.updateBook(updatedBook);
      _log.d('SummaryService', '全书摘要已生成并保存到书籍');
    }
  }

  Future<List<ChapterSummary>> _getAllSummariesForBook(String bookId) async {
    final tables = await (_db.select(_db.chapterSummaries)
          ..where((s) => s.bookId.equals(bookId))
          ..orderBy([(s) => OrderingTerm.asc(s.chapterIndex)]))
        .get();
    return tables.map(_tableToChapterSummary).toList();
  }
}

class _ChapterWithIndex {
  final ChapterInfo chapter;
  final int index;
  _ChapterWithIndex(this.chapter, this.index);
}
