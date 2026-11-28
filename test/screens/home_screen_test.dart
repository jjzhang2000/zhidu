import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/screens/home_screen.dart';
import 'package:zhidu/models/book.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/services/parsers/book_format_parser.dart';
import 'package:zhidu/models/reader_typography.dart';
import 'package:zhidu/services/parsers/rendered_content.dart';

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
  Future<BookMetadata?> extractBasicMetadata(String filePath, String bookId) async {
    return BookMetadata(
      title: 'Test Book',
      author: 'Test Author',
      totalChapters: _chapters.length,
    );
  }

  @override
  Future<List<Chapter>> getChapters(String filePath) async => _chapters;

  @override
  Future<Chapter> getChapterContent(
      String filePath, Chapter chapter) async {
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
  double readingProgress = 0.0,
  BookFormat format = BookFormat.epub,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    filePath: '/test/path/book.epub',
    format: format,
    totalChapters: 10,
    readingProgress: readingProgress,
    addedAt: DateTime(2024, 1, 1),
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('renders FloatingActionButton for adding books',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('has correct AppBar title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.text('智读'), findsOneWidget);
    });
  });

  group('HomeScreen bookshelf section', () {
    setUp(() {
      FormatRegistry.clear();
      FormatRegistry.register('.epub', MockBookFormatParser());
      FormatRegistry.register('.pdf', MockBookFormatParser());
    });

    tearDown(() {
      FormatRegistry.clear();
    });

    testWidgets('shows empty state when no books', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.byIcon(Icons.library_books), findsOneWidget);
      expect(find.text('书架空空如也'), findsOneWidget);
      expect(find.text('点击右下角按钮添加书籍'), findsOneWidget);
    });

    testWidgets('shows search field in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('搜索'), findsOneWidget);
    });

    testWidgets('shows settings button in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('empty state shows search_off icon when searching',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'nonexistent');
      await tester.pump();

      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('未找到相关书籍'), findsOneWidget);
      expect(find.text('请尝试其他关键词'), findsOneWidget);
    });
  });

  group('BookCard', () {
    testWidgets('renders book title and author', (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(book: book),
          ),
        ),
      );

      expect(find.text('Test Book'), findsOneWidget);
      expect(find.text('Test Author'), findsOneWidget);
    });

    testWidgets('shows default cover when no coverPath',
        (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(book: book),
          ),
        ),
      );

      expect(find.byIcon(Icons.book), findsOneWidget);
    });

    testWidgets('shows reading progress when progress > 0',
        (WidgetTester tester) async {
      final book = _createTestBook(readingProgress: 0.5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(book: book),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('hides reading progress when progress == 0',
        (WidgetTester tester) async {
      final book = _createTestBook(readingProgress: 0.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(book: book),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows Card widget', (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(book: book),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('truncates long title with ellipsis',
        (WidgetTester tester) async {
      final book = _createTestBook(
        title: 'This is a very long book title that should be truncated',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: BookCard(book: book),
            ),
          ),
        ),
      );

      final titleWidget = tester.widget<Text>(find.textContaining('This'));
      expect(titleWidget.maxLines, equals(2));
      expect(titleWidget.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets('has MouseRegion for hover detection',
        (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(book: book),
          ),
        ),
      );

      expect(find.byType(MouseRegion), findsWidgets);
    });

    testWidgets('has GestureDetector for tap handling',
        (WidgetTester tester) async {
      final book = _createTestBook();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookCard(book: book),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);
    });
  });
}
