// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, BookTable> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverPathMeta =
      const VerificationMeta('coverPath');
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
      'cover_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _currentChapterMeta =
      const VerificationMeta('currentChapter');
  @override
  late final GeneratedColumn<int> currentChapter = GeneratedColumn<int>(
      'current_chapter', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _readingProgressMeta =
      const VerificationMeta('readingProgress');
  @override
  late final GeneratedColumn<double> readingProgress = GeneratedColumn<double>(
      'reading_progress', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _lastReadAtMeta =
      const VerificationMeta('lastReadAt');
  @override
  late final GeneratedColumn<int> lastReadAt = GeneratedColumn<int>(
      'last_read_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _aiIntroductionMeta =
      const VerificationMeta('aiIntroduction');
  @override
  late final GeneratedColumn<String> aiIntroduction = GeneratedColumn<String>(
      'ai_introduction', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _totalChaptersMeta =
      const VerificationMeta('totalChapters');
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
      'total_chapters', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        author,
        filePath,
        coverPath,
        currentChapter,
        readingProgress,
        lastReadAt,
        aiIntroduction,
        totalChapters
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(Insertable<BookTable> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(_coverPathMeta,
          coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta));
    }
    if (data.containsKey('current_chapter')) {
      context.handle(
          _currentChapterMeta,
          currentChapter.isAcceptableOrUnknown(
              data['current_chapter']!, _currentChapterMeta));
    }
    if (data.containsKey('reading_progress')) {
      context.handle(
          _readingProgressMeta,
          readingProgress.isAcceptableOrUnknown(
              data['reading_progress']!, _readingProgressMeta));
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
          _lastReadAtMeta,
          lastReadAt.isAcceptableOrUnknown(
              data['last_read_at']!, _lastReadAtMeta));
    }
    if (data.containsKey('ai_introduction')) {
      context.handle(
          _aiIntroductionMeta,
          aiIntroduction.isAcceptableOrUnknown(
              data['ai_introduction']!, _aiIntroductionMeta));
    }
    if (data.containsKey('total_chapters')) {
      context.handle(
          _totalChaptersMeta,
          totalChapters.isAcceptableOrUnknown(
              data['total_chapters']!, _totalChaptersMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookTable map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookTable(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      coverPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_path']),
      currentChapter: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_chapter'])!,
      readingProgress: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}reading_progress'])!,
      lastReadAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_read_at']),
      aiIntroduction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ai_introduction']),
      totalChapters: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_chapters'])!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class BookTable extends DataClass implements Insertable<BookTable> {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverPath;
  final int currentChapter;
  final double readingProgress;
  final int? lastReadAt;
  final String? aiIntroduction;
  final int totalChapters;
  const BookTable(
      {required this.id,
      required this.title,
      required this.author,
      required this.filePath,
      this.coverPath,
      required this.currentChapter,
      required this.readingProgress,
      this.lastReadAt,
      this.aiIntroduction,
      required this.totalChapters});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['current_chapter'] = Variable<int>(currentChapter);
    map['reading_progress'] = Variable<double>(readingProgress);
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<int>(lastReadAt);
    }
    if (!nullToAbsent || aiIntroduction != null) {
      map['ai_introduction'] = Variable<String>(aiIntroduction);
    }
    map['total_chapters'] = Variable<int>(totalChapters);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      filePath: Value(filePath),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      currentChapter: Value(currentChapter),
      readingProgress: Value(readingProgress),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
      aiIntroduction: aiIntroduction == null && nullToAbsent
          ? const Value.absent()
          : Value(aiIntroduction),
      totalChapters: Value(totalChapters),
    );
  }

  factory BookTable.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookTable(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      filePath: serializer.fromJson<String>(json['filePath']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      currentChapter: serializer.fromJson<int>(json['currentChapter']),
      readingProgress: serializer.fromJson<double>(json['readingProgress']),
      lastReadAt: serializer.fromJson<int?>(json['lastReadAt']),
      aiIntroduction: serializer.fromJson<String?>(json['aiIntroduction']),
      totalChapters: serializer.fromJson<int>(json['totalChapters']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'filePath': serializer.toJson<String>(filePath),
      'coverPath': serializer.toJson<String?>(coverPath),
      'currentChapter': serializer.toJson<int>(currentChapter),
      'readingProgress': serializer.toJson<double>(readingProgress),
      'lastReadAt': serializer.toJson<int?>(lastReadAt),
      'aiIntroduction': serializer.toJson<String?>(aiIntroduction),
      'totalChapters': serializer.toJson<int>(totalChapters),
    };
  }

  BookTable copyWith(
          {String? id,
          String? title,
          String? author,
          String? filePath,
          Value<String?> coverPath = const Value.absent(),
          int? currentChapter,
          double? readingProgress,
          Value<int?> lastReadAt = const Value.absent(),
          Value<String?> aiIntroduction = const Value.absent(),
          int? totalChapters}) =>
      BookTable(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        filePath: filePath ?? this.filePath,
        coverPath: coverPath.present ? coverPath.value : this.coverPath,
        currentChapter: currentChapter ?? this.currentChapter,
        readingProgress: readingProgress ?? this.readingProgress,
        lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
        aiIntroduction:
            aiIntroduction.present ? aiIntroduction.value : this.aiIntroduction,
        totalChapters: totalChapters ?? this.totalChapters,
      );
  BookTable copyWithCompanion(BooksCompanion data) {
    return BookTable(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      currentChapter: data.currentChapter.present
          ? data.currentChapter.value
          : this.currentChapter,
      readingProgress: data.readingProgress.present
          ? data.readingProgress.value
          : this.readingProgress,
      lastReadAt:
          data.lastReadAt.present ? data.lastReadAt.value : this.lastReadAt,
      aiIntroduction: data.aiIntroduction.present
          ? data.aiIntroduction.value
          : this.aiIntroduction,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookTable(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('filePath: $filePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('currentChapter: $currentChapter, ')
          ..write('readingProgress: $readingProgress, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('aiIntroduction: $aiIntroduction, ')
          ..write('totalChapters: $totalChapters')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      author,
      filePath,
      coverPath,
      currentChapter,
      readingProgress,
      lastReadAt,
      aiIntroduction,
      totalChapters);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookTable &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.filePath == this.filePath &&
          other.coverPath == this.coverPath &&
          other.currentChapter == this.currentChapter &&
          other.readingProgress == this.readingProgress &&
          other.lastReadAt == this.lastReadAt &&
          other.aiIntroduction == this.aiIntroduction &&
          other.totalChapters == this.totalChapters);
}

class BooksCompanion extends UpdateCompanion<BookTable> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String> filePath;
  final Value<String?> coverPath;
  final Value<int> currentChapter;
  final Value<double> readingProgress;
  final Value<int?> lastReadAt;
  final Value<String?> aiIntroduction;
  final Value<int> totalChapters;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.filePath = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.currentChapter = const Value.absent(),
    this.readingProgress = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.aiIntroduction = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String title,
    required String author,
    required String filePath,
    this.coverPath = const Value.absent(),
    this.currentChapter = const Value.absent(),
    this.readingProgress = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.aiIntroduction = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        author = Value(author),
        filePath = Value(filePath);
  static Insertable<BookTable> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? filePath,
    Expression<String>? coverPath,
    Expression<int>? currentChapter,
    Expression<double>? readingProgress,
    Expression<int>? lastReadAt,
    Expression<String>? aiIntroduction,
    Expression<int>? totalChapters,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (filePath != null) 'file_path': filePath,
      if (coverPath != null) 'cover_path': coverPath,
      if (currentChapter != null) 'current_chapter': currentChapter,
      if (readingProgress != null) 'reading_progress': readingProgress,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (aiIntroduction != null) 'ai_introduction': aiIntroduction,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? author,
      Value<String>? filePath,
      Value<String?>? coverPath,
      Value<int>? currentChapter,
      Value<double>? readingProgress,
      Value<int?>? lastReadAt,
      Value<String?>? aiIntroduction,
      Value<int>? totalChapters,
      Value<int>? rowid}) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      currentChapter: currentChapter ?? this.currentChapter,
      readingProgress: readingProgress ?? this.readingProgress,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      aiIntroduction: aiIntroduction ?? this.aiIntroduction,
      totalChapters: totalChapters ?? this.totalChapters,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (currentChapter.present) {
      map['current_chapter'] = Variable<int>(currentChapter.value);
    }
    if (readingProgress.present) {
      map['reading_progress'] = Variable<double>(readingProgress.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<int>(lastReadAt.value);
    }
    if (aiIntroduction.present) {
      map['ai_introduction'] = Variable<String>(aiIntroduction.value);
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('filePath: $filePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('currentChapter: $currentChapter, ')
          ..write('readingProgress: $readingProgress, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('aiIntroduction: $aiIntroduction, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChapterSummariesTable extends ChapterSummaries
    with TableInfo<$ChapterSummariesTable, ChapterSummaryTable> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _chapterTitleMeta =
      const VerificationMeta('chapterTitle');
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
      'chapter_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _objectiveSummaryMeta =
      const VerificationMeta('objectiveSummary');
  @override
  late final GeneratedColumn<String> objectiveSummary = GeneratedColumn<String>(
      'objective_summary', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aiInsightMeta =
      const VerificationMeta('aiInsight');
  @override
  late final GeneratedColumn<String> aiInsight = GeneratedColumn<String>(
      'ai_insight', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _keyPointsMeta =
      const VerificationMeta('keyPoints');
  @override
  late final GeneratedColumn<String> keyPoints = GeneratedColumn<String>(
      'key_points', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bookId,
        chapterIndex,
        chapterTitle,
        objectiveSummary,
        aiInsight,
        keyPoints,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_summaries';
  @override
  VerificationContext validateIntegrity(
      Insertable<ChapterSummaryTable> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
          _chapterTitleMeta,
          chapterTitle.isAcceptableOrUnknown(
              data['chapter_title']!, _chapterTitleMeta));
    } else if (isInserting) {
      context.missing(_chapterTitleMeta);
    }
    if (data.containsKey('objective_summary')) {
      context.handle(
          _objectiveSummaryMeta,
          objectiveSummary.isAcceptableOrUnknown(
              data['objective_summary']!, _objectiveSummaryMeta));
    } else if (isInserting) {
      context.missing(_objectiveSummaryMeta);
    }
    if (data.containsKey('ai_insight')) {
      context.handle(_aiInsightMeta,
          aiInsight.isAcceptableOrUnknown(data['ai_insight']!, _aiInsightMeta));
    }
    if (data.containsKey('key_points')) {
      context.handle(_keyPointsMeta,
          keyPoints.isAcceptableOrUnknown(data['key_points']!, _keyPointsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChapterSummaryTable map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterSummaryTable(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      chapterTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapter_title'])!,
      objectiveSummary: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}objective_summary'])!,
      aiInsight: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ai_insight']),
      keyPoints: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key_points']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ChapterSummariesTable createAlias(String alias) {
    return $ChapterSummariesTable(attachedDatabase, alias);
  }
}

class ChapterSummaryTable extends DataClass
    implements Insertable<ChapterSummaryTable> {
  final int id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String objectiveSummary;
  final String? aiInsight;
  final String? keyPoints;
  final int createdAt;
  const ChapterSummaryTable(
      {required this.id,
      required this.bookId,
      required this.chapterIndex,
      required this.chapterTitle,
      required this.objectiveSummary,
      this.aiInsight,
      this.keyPoints,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['chapter_title'] = Variable<String>(chapterTitle);
    map['objective_summary'] = Variable<String>(objectiveSummary);
    if (!nullToAbsent || aiInsight != null) {
      map['ai_insight'] = Variable<String>(aiInsight);
    }
    if (!nullToAbsent || keyPoints != null) {
      map['key_points'] = Variable<String>(keyPoints);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ChapterSummariesCompanion toCompanion(bool nullToAbsent) {
    return ChapterSummariesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      chapterTitle: Value(chapterTitle),
      objectiveSummary: Value(objectiveSummary),
      aiInsight: aiInsight == null && nullToAbsent
          ? const Value.absent()
          : Value(aiInsight),
      keyPoints: keyPoints == null && nullToAbsent
          ? const Value.absent()
          : Value(keyPoints),
      createdAt: Value(createdAt),
    );
  }

  factory ChapterSummaryTable.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterSummaryTable(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      chapterTitle: serializer.fromJson<String>(json['chapterTitle']),
      objectiveSummary: serializer.fromJson<String>(json['objectiveSummary']),
      aiInsight: serializer.fromJson<String?>(json['aiInsight']),
      keyPoints: serializer.fromJson<String?>(json['keyPoints']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'chapterTitle': serializer.toJson<String>(chapterTitle),
      'objectiveSummary': serializer.toJson<String>(objectiveSummary),
      'aiInsight': serializer.toJson<String?>(aiInsight),
      'keyPoints': serializer.toJson<String?>(keyPoints),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ChapterSummaryTable copyWith(
          {int? id,
          String? bookId,
          int? chapterIndex,
          String? chapterTitle,
          String? objectiveSummary,
          Value<String?> aiInsight = const Value.absent(),
          Value<String?> keyPoints = const Value.absent(),
          int? createdAt}) =>
      ChapterSummaryTable(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        objectiveSummary: objectiveSummary ?? this.objectiveSummary,
        aiInsight: aiInsight.present ? aiInsight.value : this.aiInsight,
        keyPoints: keyPoints.present ? keyPoints.value : this.keyPoints,
        createdAt: createdAt ?? this.createdAt,
      );
  ChapterSummaryTable copyWithCompanion(ChapterSummariesCompanion data) {
    return ChapterSummaryTable(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      chapterTitle: data.chapterTitle.present
          ? data.chapterTitle.value
          : this.chapterTitle,
      objectiveSummary: data.objectiveSummary.present
          ? data.objectiveSummary.value
          : this.objectiveSummary,
      aiInsight: data.aiInsight.present ? data.aiInsight.value : this.aiInsight,
      keyPoints: data.keyPoints.present ? data.keyPoints.value : this.keyPoints,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterSummaryTable(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('objectiveSummary: $objectiveSummary, ')
          ..write('aiInsight: $aiInsight, ')
          ..write('keyPoints: $keyPoints, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, chapterIndex, chapterTitle,
      objectiveSummary, aiInsight, keyPoints, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterSummaryTable &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterTitle == this.chapterTitle &&
          other.objectiveSummary == this.objectiveSummary &&
          other.aiInsight == this.aiInsight &&
          other.keyPoints == this.keyPoints &&
          other.createdAt == this.createdAt);
}

class ChapterSummariesCompanion extends UpdateCompanion<ChapterSummaryTable> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<String> chapterTitle;
  final Value<String> objectiveSummary;
  final Value<String?> aiInsight;
  final Value<String?> keyPoints;
  final Value<int> createdAt;
  const ChapterSummariesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.objectiveSummary = const Value.absent(),
    this.aiInsight = const Value.absent(),
    this.keyPoints = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ChapterSummariesCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required String objectiveSummary,
    this.aiInsight = const Value.absent(),
    this.keyPoints = const Value.absent(),
    required int createdAt,
  })  : bookId = Value(bookId),
        chapterIndex = Value(chapterIndex),
        chapterTitle = Value(chapterTitle),
        objectiveSummary = Value(objectiveSummary),
        createdAt = Value(createdAt);
  static Insertable<ChapterSummaryTable> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<String>? chapterTitle,
    Expression<String>? objectiveSummary,
    Expression<String>? aiInsight,
    Expression<String>? keyPoints,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (objectiveSummary != null) 'objective_summary': objectiveSummary,
      if (aiInsight != null) 'ai_insight': aiInsight,
      if (keyPoints != null) 'key_points': keyPoints,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ChapterSummariesCompanion copyWith(
      {Value<int>? id,
      Value<String>? bookId,
      Value<int>? chapterIndex,
      Value<String>? chapterTitle,
      Value<String>? objectiveSummary,
      Value<String?>? aiInsight,
      Value<String?>? keyPoints,
      Value<int>? createdAt}) {
    return ChapterSummariesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      objectiveSummary: objectiveSummary ?? this.objectiveSummary,
      aiInsight: aiInsight ?? this.aiInsight,
      keyPoints: keyPoints ?? this.keyPoints,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (objectiveSummary.present) {
      map['objective_summary'] = Variable<String>(objectiveSummary.value);
    }
    if (aiInsight.present) {
      map['ai_insight'] = Variable<String>(aiInsight.value);
    }
    if (keyPoints.present) {
      map['key_points'] = Variable<String>(keyPoints.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChapterSummariesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('objectiveSummary: $objectiveSummary, ')
          ..write('aiInsight: $aiInsight, ')
          ..write('keyPoints: $keyPoints, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BookSummariesTable extends BookSummaries
    with TableInfo<$BookSummariesTable, BookSummaryTable> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, bookId, summary, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_summaries';
  @override
  VerificationContext validateIntegrity(Insertable<BookSummaryTable> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookSummaryTable map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookSummaryTable(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BookSummariesTable createAlias(String alias) {
    return $BookSummariesTable(attachedDatabase, alias);
  }
}

class BookSummaryTable extends DataClass
    implements Insertable<BookSummaryTable> {
  final int id;
  final String bookId;
  final String summary;
  final int createdAt;
  const BookSummaryTable(
      {required this.id,
      required this.bookId,
      required this.summary,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['summary'] = Variable<String>(summary);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  BookSummariesCompanion toCompanion(bool nullToAbsent) {
    return BookSummariesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      summary: Value(summary),
      createdAt: Value(createdAt),
    );
  }

  factory BookSummaryTable.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookSummaryTable(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      summary: serializer.fromJson<String>(json['summary']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'summary': serializer.toJson<String>(summary),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  BookSummaryTable copyWith(
          {int? id, String? bookId, String? summary, int? createdAt}) =>
      BookSummaryTable(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        summary: summary ?? this.summary,
        createdAt: createdAt ?? this.createdAt,
      );
  BookSummaryTable copyWithCompanion(BookSummariesCompanion data) {
    return BookSummaryTable(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      summary: data.summary.present ? data.summary.value : this.summary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookSummaryTable(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('summary: $summary, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, summary, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookSummaryTable &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.summary == this.summary &&
          other.createdAt == this.createdAt);
}

class BookSummariesCompanion extends UpdateCompanion<BookSummaryTable> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String> summary;
  final Value<int> createdAt;
  const BookSummariesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.summary = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookSummariesCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required String summary,
    required int createdAt,
  })  : bookId = Value(bookId),
        summary = Value(summary),
        createdAt = Value(createdAt);
  static Insertable<BookSummaryTable> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? summary,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (summary != null) 'summary': summary,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookSummariesCompanion copyWith(
      {Value<int>? id,
      Value<String>? bookId,
      Value<String>? summary,
      Value<int>? createdAt}) {
    return BookSummariesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookSummariesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('summary: $summary, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ChapterSummariesTable chapterSummaries =
      $ChapterSummariesTable(this);
  late final $BookSummariesTable bookSummaries = $BookSummariesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [books, chapterSummaries, bookSummaries];
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  required String id,
  required String title,
  required String author,
  required String filePath,
  Value<String?> coverPath,
  Value<int> currentChapter,
  Value<double> readingProgress,
  Value<int?> lastReadAt,
  Value<String?> aiIntroduction,
  Value<int> totalChapters,
  Value<int> rowid,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> author,
  Value<String> filePath,
  Value<String?> coverPath,
  Value<int> currentChapter,
  Value<double> readingProgress,
  Value<int?> lastReadAt,
  Value<String?> aiIntroduction,
  Value<int> totalChapters,
  Value<int> rowid,
});

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverPath => $composableBuilder(
      column: $table.coverPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentChapter => $composableBuilder(
      column: $table.currentChapter,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get readingProgress => $composableBuilder(
      column: $table.readingProgress,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aiIntroduction => $composableBuilder(
      column: $table.aiIntroduction,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalChapters => $composableBuilder(
      column: $table.totalChapters, builder: (column) => ColumnFilters(column));
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverPath => $composableBuilder(
      column: $table.coverPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentChapter => $composableBuilder(
      column: $table.currentChapter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get readingProgress => $composableBuilder(
      column: $table.readingProgress,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aiIntroduction => $composableBuilder(
      column: $table.aiIntroduction,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalChapters => $composableBuilder(
      column: $table.totalChapters,
      builder: (column) => ColumnOrderings(column));
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get currentChapter => $composableBuilder(
      column: $table.currentChapter, builder: (column) => column);

  GeneratedColumn<double> get readingProgress => $composableBuilder(
      column: $table.readingProgress, builder: (column) => column);

  GeneratedColumn<int> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => column);

  GeneratedColumn<String> get aiIntroduction => $composableBuilder(
      column: $table.aiIntroduction, builder: (column) => column);

  GeneratedColumn<int> get totalChapters => $composableBuilder(
      column: $table.totalChapters, builder: (column) => column);
}

class $$BooksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BooksTable,
    BookTable,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (BookTable, BaseReferences<_$AppDatabase, $BooksTable, BookTable>),
    BookTable,
    PrefetchHooks Function()> {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String?> coverPath = const Value.absent(),
            Value<int> currentChapter = const Value.absent(),
            Value<double> readingProgress = const Value.absent(),
            Value<int?> lastReadAt = const Value.absent(),
            Value<String?> aiIntroduction = const Value.absent(),
            Value<int> totalChapters = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BooksCompanion(
            id: id,
            title: title,
            author: author,
            filePath: filePath,
            coverPath: coverPath,
            currentChapter: currentChapter,
            readingProgress: readingProgress,
            lastReadAt: lastReadAt,
            aiIntroduction: aiIntroduction,
            totalChapters: totalChapters,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String author,
            required String filePath,
            Value<String?> coverPath = const Value.absent(),
            Value<int> currentChapter = const Value.absent(),
            Value<double> readingProgress = const Value.absent(),
            Value<int?> lastReadAt = const Value.absent(),
            Value<String?> aiIntroduction = const Value.absent(),
            Value<int> totalChapters = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BooksCompanion.insert(
            id: id,
            title: title,
            author: author,
            filePath: filePath,
            coverPath: coverPath,
            currentChapter: currentChapter,
            readingProgress: readingProgress,
            lastReadAt: lastReadAt,
            aiIntroduction: aiIntroduction,
            totalChapters: totalChapters,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BooksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BooksTable,
    BookTable,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (BookTable, BaseReferences<_$AppDatabase, $BooksTable, BookTable>),
    BookTable,
    PrefetchHooks Function()>;
typedef $$ChapterSummariesTableCreateCompanionBuilder
    = ChapterSummariesCompanion Function({
  Value<int> id,
  required String bookId,
  required int chapterIndex,
  required String chapterTitle,
  required String objectiveSummary,
  Value<String?> aiInsight,
  Value<String?> keyPoints,
  required int createdAt,
});
typedef $$ChapterSummariesTableUpdateCompanionBuilder
    = ChapterSummariesCompanion Function({
  Value<int> id,
  Value<String> bookId,
  Value<int> chapterIndex,
  Value<String> chapterTitle,
  Value<String> objectiveSummary,
  Value<String?> aiInsight,
  Value<String?> keyPoints,
  Value<int> createdAt,
});

class $$ChapterSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $ChapterSummariesTable> {
  $$ChapterSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chapterTitle => $composableBuilder(
      column: $table.chapterTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get objectiveSummary => $composableBuilder(
      column: $table.objectiveSummary,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aiInsight => $composableBuilder(
      column: $table.aiInsight, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get keyPoints => $composableBuilder(
      column: $table.keyPoints, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ChapterSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChapterSummariesTable> {
  $$ChapterSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
      column: $table.chapterTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get objectiveSummary => $composableBuilder(
      column: $table.objectiveSummary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aiInsight => $composableBuilder(
      column: $table.aiInsight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get keyPoints => $composableBuilder(
      column: $table.keyPoints, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ChapterSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChapterSummariesTable> {
  $$ChapterSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
      column: $table.chapterTitle, builder: (column) => column);

  GeneratedColumn<String> get objectiveSummary => $composableBuilder(
      column: $table.objectiveSummary, builder: (column) => column);

  GeneratedColumn<String> get aiInsight =>
      $composableBuilder(column: $table.aiInsight, builder: (column) => column);

  GeneratedColumn<String> get keyPoints =>
      $composableBuilder(column: $table.keyPoints, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChapterSummariesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChapterSummariesTable,
    ChapterSummaryTable,
    $$ChapterSummariesTableFilterComposer,
    $$ChapterSummariesTableOrderingComposer,
    $$ChapterSummariesTableAnnotationComposer,
    $$ChapterSummariesTableCreateCompanionBuilder,
    $$ChapterSummariesTableUpdateCompanionBuilder,
    (
      ChapterSummaryTable,
      BaseReferences<_$AppDatabase, $ChapterSummariesTable, ChapterSummaryTable>
    ),
    ChapterSummaryTable,
    PrefetchHooks Function()> {
  $$ChapterSummariesTableTableManager(
      _$AppDatabase db, $ChapterSummariesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChapterSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChapterSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChapterSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<String> chapterTitle = const Value.absent(),
            Value<String> objectiveSummary = const Value.absent(),
            Value<String?> aiInsight = const Value.absent(),
            Value<String?> keyPoints = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
          }) =>
              ChapterSummariesCompanion(
            id: id,
            bookId: bookId,
            chapterIndex: chapterIndex,
            chapterTitle: chapterTitle,
            objectiveSummary: objectiveSummary,
            aiInsight: aiInsight,
            keyPoints: keyPoints,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String bookId,
            required int chapterIndex,
            required String chapterTitle,
            required String objectiveSummary,
            Value<String?> aiInsight = const Value.absent(),
            Value<String?> keyPoints = const Value.absent(),
            required int createdAt,
          }) =>
              ChapterSummariesCompanion.insert(
            id: id,
            bookId: bookId,
            chapterIndex: chapterIndex,
            chapterTitle: chapterTitle,
            objectiveSummary: objectiveSummary,
            aiInsight: aiInsight,
            keyPoints: keyPoints,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChapterSummariesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChapterSummariesTable,
    ChapterSummaryTable,
    $$ChapterSummariesTableFilterComposer,
    $$ChapterSummariesTableOrderingComposer,
    $$ChapterSummariesTableAnnotationComposer,
    $$ChapterSummariesTableCreateCompanionBuilder,
    $$ChapterSummariesTableUpdateCompanionBuilder,
    (
      ChapterSummaryTable,
      BaseReferences<_$AppDatabase, $ChapterSummariesTable, ChapterSummaryTable>
    ),
    ChapterSummaryTable,
    PrefetchHooks Function()>;
typedef $$BookSummariesTableCreateCompanionBuilder = BookSummariesCompanion
    Function({
  Value<int> id,
  required String bookId,
  required String summary,
  required int createdAt,
});
typedef $$BookSummariesTableUpdateCompanionBuilder = BookSummariesCompanion
    Function({
  Value<int> id,
  Value<String> bookId,
  Value<String> summary,
  Value<int> createdAt,
});

class $$BookSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $BookSummariesTable> {
  $$BookSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$BookSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $BookSummariesTable> {
  $$BookSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$BookSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookSummariesTable> {
  $$BookSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookSummariesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BookSummariesTable,
    BookSummaryTable,
    $$BookSummariesTableFilterComposer,
    $$BookSummariesTableOrderingComposer,
    $$BookSummariesTableAnnotationComposer,
    $$BookSummariesTableCreateCompanionBuilder,
    $$BookSummariesTableUpdateCompanionBuilder,
    (
      BookSummaryTable,
      BaseReferences<_$AppDatabase, $BookSummariesTable, BookSummaryTable>
    ),
    BookSummaryTable,
    PrefetchHooks Function()> {
  $$BookSummariesTableTableManager(_$AppDatabase db, $BookSummariesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> summary = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
          }) =>
              BookSummariesCompanion(
            id: id,
            bookId: bookId,
            summary: summary,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String bookId,
            required String summary,
            required int createdAt,
          }) =>
              BookSummariesCompanion.insert(
            id: id,
            bookId: bookId,
            summary: summary,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BookSummariesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BookSummariesTable,
    BookSummaryTable,
    $$BookSummariesTableFilterComposer,
    $$BookSummariesTableOrderingComposer,
    $$BookSummariesTableAnnotationComposer,
    $$BookSummariesTableCreateCompanionBuilder,
    $$BookSummariesTableUpdateCompanionBuilder,
    (
      BookSummaryTable,
      BaseReferences<_$AppDatabase, $BookSummariesTable, BookSummaryTable>
    ),
    BookSummaryTable,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ChapterSummariesTableTableManager get chapterSummaries =>
      $$ChapterSummariesTableTableManager(_db, _db.chapterSummaries);
  $$BookSummariesTableTableManager get bookSummaries =>
      $$BookSummariesTableTableManager(_db, _db.bookSummaries);
}
