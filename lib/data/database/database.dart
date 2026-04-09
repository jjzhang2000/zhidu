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
  IntColumn get currentChapter =>
      integer().named('current_chapter').withDefault(const Constant(0))();
  RealColumn get readingProgress =>
      real().named('reading_progress').withDefault(const Constant(0.0))();
  IntColumn get lastReadAt => integer().named('last_read_at').nullable()();
  TextColumn get aiIntroduction => text().named('ai_introduction').nullable()();
  IntColumn get totalChapters =>
      integer().named('total_chapters').withDefault(const Constant(0))();

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

  AppDatabase.connect(DatabaseConnection connection)
      : super.connect(connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations will be handled here
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
