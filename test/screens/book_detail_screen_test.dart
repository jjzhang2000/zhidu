import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:zhidu/screens/book_screen.dart';
import 'package:zhidu/models/book.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/services/parsers/book_format_parser.dart';
import 'package:zhidu/models/reader_typography.dart';
import 'package:zhidu/services/parsers/rendered_content.dart';

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

class MockBookFormatParser implements BookFormatParser {
  List<Chapter> _chapters = [];

  void setChapters(List<Chapter> chapters) {
    _chapters = chapters;
  }

  @override
  Future<BookMetadata?> parseMetadata(String filePath, String bookId) async {
    return BookMetadata(
      title: 'Test Book',
      author: 'Test Author',
      totalChapters: _chapters.length,
    );
  }

  @override
  Future<BookMetadata?> extractBasicMetadata(
      String filePath, String bookId) async {
    return BookMetadata(
      title: 'Test Book',
      author: 'Test Author',
      totalChapters: _chapters.length,
    );
  }

  @override
  Future<List<Chapter>> getChapters(String filePath) async => _chapters;

  @override
  Future<Chapter> getChapterContent(String filePath, Chapter chapter) async {
    return Chapter(
      bookId: 'test',
      index: 0,
      title: 'test',
      location: ChapterLocation(),
      htmlContent: 'Mock chapter content',
    );
  }

  @override
  Future<RenderedContent?> getChapterContentMerged(
      String filePath, Chapter chapter, List<Chapter> allChapters) async {
    final c = await getChapterContent(filePath, chapter);
    return RenderedContent(c.htmlContent ?? '');
  }

  @override
  Future<RenderedContent?> getOpeningContent(String filePath) async => null;

  @override
  Future<ReaderTypography?> getReaderTypography(String filePath) async => null;
}

Book _createTestBook({
  String id = 'test-book-1',
  String title = 'Test Book',
  String author = 'Test Author',
  BookFormat format = BookFormat.epub,
  int totalChapters = 10,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    filePath: '/test/path/book.epub',
    format: format,
    totalChapters: totalChapters,
    readingProgress: 0.0,
    addedAt: DateTime(2024, 1, 1),
  );
}

List<Chapter> _createTestChapters(int count) {
  return List.generate(count, (index) {
    return Chapter(
      bookId: 'test-book-1',
      index: index,
      title: 'Chapter $index',
      location: ChapterLocation(href: 'chapter$index.xhtml'),
      level: index % 3,
    );
  });
}

void main() {
  group('BookScreen', () {
    setUp(() {
      FormatRegistry.clear();
      FormatRegistry.register('.epub', MockBookFormatParser());
      FormatRegistry.register('.pdf', MockBookFormatParser());
      PathProviderPlatform.instance = _FakePathProvider();
      BookScreen.clearChapterCacheForTest();
    });

    tearDown(() {
      FormatRegistry.clear();
    });

    testWidgets('renders AppBar with correct title',
        (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      expect(find.text('书籍详情'), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows book title in header', (WidgetTester tester) async {
      final book = _createTestBook(title: 'My Test Book');

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      expect(find.text('My Test Book'), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows book author in header', (WidgetTester tester) async {
      final book = _createTestBook(author: 'John Doe');

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      expect(find.text('John Doe'), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows default cover icon when no coverPath',
        (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      expect(find.byIcon(Icons.book), findsWidgets);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows Scaffold structure', (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows chapter list directly', (WidgetTester tester) async {
      final mockParser = MockBookFormatParser();
      mockParser.setChapters(_createTestChapters(3));
      FormatRegistry.clear();
      FormatRegistry.register('.epub', mockParser);

      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chapter 0'), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows chapter list', (WidgetTester tester) async {
      final mockParser = MockBookFormatParser();
      mockParser.setChapters(_createTestChapters(5));
      FormatRegistry.clear();
      FormatRegistry.register('.epub', mockParser);

      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows empty chapters message when no chapters',
        (WidgetTester tester) async {
      final mockParser = MockBookFormatParser();
      mockParser.setChapters([]);
      FormatRegistry.clear();
      FormatRegistry.register('.epub', mockParser);

      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('暂无章节信息'), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows chapter titles in list', (WidgetTester tester) async {
      final mockParser = MockBookFormatParser();
      final chapters = [
        Chapter(
          bookId: 'test-book-1',
          index: 0,
          title: 'Introduction',
          location: ChapterLocation(href: 'intro.xhtml'),
          level: 0,
        ),
        Chapter(
          bookId: 'test-book-1',
          index: 1,
          title: 'Chapter One',
          location: ChapterLocation(href: 'ch1.xhtml'),
          level: 0,
        ),
      ];
      mockParser.setChapters(chapters);
      FormatRegistry.clear();
      FormatRegistry.register('.epub', mockParser);

      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Chapter One'), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows Divider between header and content',
        (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      expect(find.byType(Divider), findsWidgets);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows Card for content area', (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      expect(find.byType(Card), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows Row layout for book header',
        (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      expect(find.byType(Row), findsWidgets);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows Column layout in header', (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: BookScreen(book: book),
        ),
      );

      expect(find.byType(Column), findsWidgets);

      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
