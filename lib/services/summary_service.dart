import 'dart:convert';
import 'package:drift/drift.dart';
import '../data/database/database.dart';
import '../models/chapter_summary.dart';
import '../models/section_summary.dart';
import '../models/book.dart';
import 'ai_service.dart';
import 'epub_service.dart';
import 'log_service.dart';

class SummaryService {
  static final SummaryService _instance = SummaryService._internal();
  factory SummaryService() => _instance;
  SummaryService._internal();

  late final AppDatabase _db;
  final _aiService = AIService();
  final _epubService = EpubService();
  final _log = LogService();

  Future<void> init() async {
    _db = AppDatabase();
  }

  Future<ChapterSummary?> getSummary(String bookId, int chapterIndex) async {
    _log.v('SummaryService',
        'getSummary 开始执行, bookId: $bookId, chapterIndex: $chapterIndex');

    final table = await (_db.select(_db.chapterSummaries)
          ..where((s) =>
              s.bookId.equals(bookId) & s.chapterIndex.equals(chapterIndex)))
        .getSingleOrNull();

    final result = table != null ? _tableToChapterSummary(table) : null;

    _log.v('SummaryService',
        'getSummary 加载完成, result: ${result != null ? "有内容" : "空"}');
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
      final flatChapters = _flattenWithIndex(hierarchicalChapters);
      _log.d('SummaryService', '扁平化后共 ${flatChapters.length} 个章节');

      final chaptersByLevel = <int, List<_ChapterWithIndex>>{};
      for (final chapterInfo in flatChapters) {
        final level = chapterInfo.chapter.level;
        chaptersByLevel.putIfAbsent(level, () => []).add(chapterInfo);
      }

      final prefaceIndices =
          _findPrefaceChapters(flatChapters.map((e) => e.chapter).toList());
      if (prefaceIndices.isNotEmpty) {
        _log.d('SummaryService', '发现前置章节: $prefaceIndices');
        await _generatePrefaceSummary(book, flatChapters, prefaceIndices);
      }

      final sortedLevels = chaptersByLevel.keys.toList()..sort();
      for (final level in sortedLevels) {
        if (level >= 2) {
          _log.d('SummaryService', '=== 跳过层级 $level 及更深层的章节 ===');
          continue;
        }

        final levelChapters = chaptersByLevel[level]!;
        _log.d('SummaryService',
            '=== 处理层级 $level，共 ${levelChapters.length} 个章节 ===');

        for (final chapterInfo in levelChapters) {
          final i = chapterInfo.index;

          if (prefaceIndices.contains(i)) continue;

          if (await hasSummary(book.id, i)) {
            _log.d('SummaryService', '章节 $i 已有摘要，跳过');
            continue;
          }

          _log.d(
              'SummaryService', '正在生成章节 $i 的摘要: ${chapterInfo.chapter.title}');

          final content =
              await _epubService.getChapterContent(book.filePath, i);
          if (content == null || content.isEmpty) {
            _log.w('SummaryService', '章节 $i 内容为空或无法读取，跳过');
            continue;
          }

          final fullSummary = await _aiService.generateFullChapterSummary(
            content,
            chapterTitle: chapterInfo.chapter.title,
          );

          if (fullSummary != null) {
            final chapterSummary = ChapterSummary(
              bookId: book.id,
              chapterIndex: i,
              chapterTitle: chapterInfo.chapter.title,
              objectiveSummary: fullSummary['objectiveSummary'] ?? '',
              aiInsight: fullSummary['aiInsight'] ?? '',
              keyPoints: List<String>.from(fullSummary['keyPoints'] ?? []),
              createdAt: DateTime.now(),
            );
            await saveSummary(chapterSummary);
            _log.d('SummaryService', '章节 $i 摘要已保存');
          }

          await Future.delayed(const Duration(seconds: 1));
        }
      }

      _log.d('SummaryService', '书籍所有摘要生成完成: ${book.title}');
    } catch (e) {
      _log.e('SummaryService', '生成章节摘要失败', e);
    }
  }

  List<_ChapterWithIndex> _flattenWithIndex(
      List<dynamic> hierarchicalChapters) {
    final result = <_ChapterWithIndex>[];
    var index = 0;

    void flatten(List<dynamic> chapters) {
      for (final chapter in chapters) {
        result.add(_ChapterWithIndex(chapter, index++));
        if (chapter.children.isNotEmpty) {
          flatten(chapter.children);
        }
      }
    }

    flatten(hierarchicalChapters);
    return result;
  }

  List<int> _findPrefaceChapters(List<dynamic> chapters) {
    final prefaceKeywords = [
      '前言',
      '序言',
      '序',
      '致谢',
      '感谢',
      '献词',
      '引言',
      '导言',
      '导读',
      'preface',
      'foreword',
      'introduction',
      'acknowledgements',
      'dedication',
    ];

    final indices = <int>[];
    for (int i = 0; i < chapters.length; i++) {
      final title = chapters[i].title.toString().toLowerCase();
      for (final keyword in prefaceKeywords) {
        if (title.contains(keyword.toLowerCase())) {
          indices.add(i);
          break;
        }
      }
    }
    return indices;
  }

  Future<void> _generatePrefaceSummary(
    Book book,
    List<_ChapterWithIndex> chapters,
    List<int> indices,
  ) async {
    if (await hasSummary(book.id, indices.first)) {
      _log.d('SummaryService', '前置章节摘要已存在，跳过');
      return;
    }

    final combinedContent = StringBuffer();
    final combinedTitle = StringBuffer('前言与导读');

    for (int i = 0; i < indices.length; i++) {
      final index = indices[i];
      final content =
          await _epubService.getChapterContent(book.filePath, index);
      if (content != null && content.isNotEmpty) {
        if (i > 0) combinedContent.write('\n\n---\n\n');
        combinedContent.write('<h2>${chapters[index].chapter.title}</h2>');
        combinedContent.write(content);
      }
    }

    if (combinedContent.isEmpty) {
      _log.w('SummaryService', '前置章节内容为空，跳过');
      return;
    }

    final fullSummary = await _aiService.generateFullChapterSummary(
      combinedContent.toString(),
      chapterTitle: combinedTitle.toString(),
    );

    if (fullSummary != null) {
      final chapterSummary = ChapterSummary(
        bookId: book.id,
        chapterIndex: indices.first,
        chapterTitle: combinedTitle.toString(),
        objectiveSummary: fullSummary['objectiveSummary'] ?? '',
        aiInsight: fullSummary['aiInsight'] ?? '',
        keyPoints: List<String>.from(fullSummary['keyPoints'] ?? []),
        createdAt: DateTime.now(),
      );
      await saveSummary(chapterSummary);
      _log.d('SummaryService', '前置章节合并摘要已保存');
    }

    await Future.delayed(const Duration(seconds: 1));
  }
}

class _ChapterWithIndex {
  final dynamic chapter;
  final int index;
  _ChapterWithIndex(this.chapter, this.index);
}
