import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../models/chapter_summary.dart' as model;
import '../../models/book_summary.dart' as book_model;

part 'summaries_dao.g.dart';

@DriftAccessor(tables: [ChapterSummaries, BookSummaries])
class SummariesDao extends DatabaseAccessor<AppDatabase>
    with _$SummariesDaoMixin {
  SummariesDao(AppDatabase db) : super(db);

  // Chapter Summaries
  Future<model.ChapterSummary?> getChapterSummary(
      String bookId, int chapterIndex) async {
    final summary = await (select(chapterSummaries)
          ..where((s) =>
              s.bookId.equals(bookId) & s.chapterIndex.equals(chapterIndex)))
        .getSingleOrNull();
    return summary != null ? _chapterTableToModel(summary) : null;
  }

  Future<void> saveChapterSummary(model.ChapterSummary summaryModel) async {
    await into(chapterSummaries).insert(
      _chapterModelToCompanion(summaryModel),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteChapterSummaries(String bookId) async {
    await (delete(chapterSummaries)..where((s) => s.bookId.equals(bookId)))
        .go();
  }

  Future<List<model.ChapterSummary>> getSummariesForBook(String bookId) async {
    final summaries = await (select(chapterSummaries)
          ..where((s) => s.bookId.equals(bookId))
          ..orderBy([(s) => OrderingTerm(expression: s.chapterIndex)]))
        .get();
    return summaries.map(_chapterTableToModel).toList();
  }

  // Book Summaries
  Future<book_model.BookSummary?> getBookSummary(String bookId) async {
    final summary = await (select(bookSummaries)
          ..where((s) => s.bookId.equals(bookId)))
        .getSingleOrNull();
    return summary != null ? _bookTableToModel(summary) : null;
  }

  Future<void> saveBookSummary(book_model.BookSummary summaryModel) async {
    await into(bookSummaries).insert(
      _bookModelToCompanion(summaryModel),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteBookSummary(String bookId) async {
    await (delete(bookSummaries)..where((s) => s.bookId.equals(bookId))).go();
  }

  // Conversions
  model.ChapterSummary _chapterTableToModel(ChapterSummaryTable table) {
    return model.ChapterSummary(
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

  ChapterSummariesCompanion _chapterModelToCompanion(
      model.ChapterSummary model) {
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

  book_model.BookSummary _bookTableToModel(BookSummaryTable table) {
    return book_model.BookSummary(
      bookId: table.bookId,
      summary: table.summary,
      createdAt: DateTime.fromMillisecondsSinceEpoch(table.createdAt),
    );
  }

  BookSummariesCompanion _bookModelToCompanion(book_model.BookSummary model) {
    return BookSummariesCompanion(
      bookId: Value(model.bookId),
      summary: Value(model.summary),
      createdAt: Value(model.createdAt.millisecondsSinceEpoch),
    );
  }
}
