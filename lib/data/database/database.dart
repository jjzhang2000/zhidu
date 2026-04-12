import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@DataClassName('BookTable')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get coverPath => text().named('cover_path').nullable()();
  TextColumn get format =>
      text().withDefault(const Constant('epub'))(); // 添加format字段
  IntColumn get currentChapter =>
      integer().named('current_chapter').withDefault(const Constant(0))();
  RealColumn get readingProgress =>
      real().named('reading_progress').withDefault(const Constant(0.0))();
  IntColumn get lastReadAt => integer().named('last_read_at').nullable()();
  TextColumn get aiIntroduction => text().named('ai_introduction').nullable()();
  IntColumn get totalChapters =>
      integer().named('total_chapters').withDefault(const Constant(0))();
  IntColumn get addedAt => integer()
      .named('added_at')
      .withDefault(const Constant(0))(); // 添加addedAt字段

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChapterSummaryTable')
class ChapterSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().named('book_id')();
  IntColumn get chapterIndex => integer().named('chapter_index')();
  TextColumn get chapterTitle => text().named('chapter_title')();
  TextColumn get objectiveSummary => text().named('objective_summary')();
  TextColumn get aiInsight => text().named('ai_insight').nullable()();
  TextColumn get keyPoints => text().named('key_points').nullable()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {bookId, chapterIndex},
      ];
}

@DataClassName('BookSummaryTable')
class BookSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().named('book_id')();
  TextColumn get summary => text()();
  IntColumn get createdAt => integer().named('created_at')();
}

@DriftDatabase(tables: [Books, ChapterSummaries, BookSummaries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // 增加版本号

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_chapter_summary_unique ON chapter_summaries(book_id, chapter_index)');
        }
        if (from < 3) {
          // 添加format和addedAt字段
          await customStatement(
              'ALTER TABLE books ADD COLUMN format TEXT DEFAULT \'epub\'');
          await customStatement(
              'ALTER TABLE books ADD COLUMN added_at INTEGER DEFAULT 0');
        }
      },
    );
  }

  Future<void> close() async {
    await executor.close();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'zhidu.db'));
    return NativeDatabase.createInBackground(file);
  });
}
