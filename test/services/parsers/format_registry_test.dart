import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/services/parsers/book_format_parser.dart';
import 'package:zhidu/services/parsers/rendered_content.dart';
import 'package:zhidu/models/chapter.dart';

class MockParser implements BookFormatParser {
  final String name;

  MockParser([this.name = 'mock']);

  @override
  Future<BookMetadata?> parseMetadata(String filePath, String bookId) async {
    return BookMetadata(
      title: 'Test',
      author: 'Test',
      totalChapters: 0,
    );
  }

  @override
  Future<BookMetadata?> extractBasicMetadata(String filePath, String bookId) async {
    return BookMetadata(
      title: 'Test',
      author: 'Test',
      totalChapters: 0,
    );
  }

  @override
  Future<List<Chapter>> getChapters(String filePath) async => [];

  @override
  Future<Chapter> getChapterContent(
      String filePath, Chapter chapter) async {
    return Chapter(
      bookId: 'test',
      index: 0,
      title: 'test',
      location: ChapterLocation(),
      htmlContent: 'test content',
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
}

void main() {
  group('FormatRegistry', () {
    setUp(() {
      FormatRegistry.clear();
    });

    tearDown(() {
      FormatRegistry.clear();
    });

    group('register', () {
      test('registers a parser for a format', () {
        final parser = MockParser();
        FormatRegistry.register('.epub', parser);

        expect(FormatRegistry.getParser('.epub'), same(parser));
      });

      test('converts extension to lowercase', () {
        final parser = MockParser();
        FormatRegistry.register('.EPUB', parser);

        expect(FormatRegistry.getParser('.epub'), same(parser));
        expect(FormatRegistry.getParser('.EPUB'), same(parser));
        expect(FormatRegistry.getParser('.Epub'), same(parser));
      });

      test('overwrites existing parser', () {
        final parser1 = MockParser('first');
        final parser2 = MockParser('second');

        FormatRegistry.register('.epub', parser1);
        expect(FormatRegistry.getParser('.epub'), same(parser1));

        FormatRegistry.register('.epub', parser2);
        expect(FormatRegistry.getParser('.epub'), same(parser2));
      });

      test('can register multiple formats', () {
        final epubParser = MockParser('epub');
        final pdfParser = MockParser('pdf');

        FormatRegistry.register('.epub', epubParser);
        FormatRegistry.register('.pdf', pdfParser);

        expect(FormatRegistry.getParser('.epub'), same(epubParser));
        expect(FormatRegistry.getParser('.pdf'), same(pdfParser));
      });
    });

    group('getParser', () {
      test('returns parser for registered format', () {
        final parser = MockParser();
        FormatRegistry.register('.epub', parser);

        expect(FormatRegistry.getParser('.epub'), same(parser));
      });

      test('returns null for unregistered format', () {
        expect(FormatRegistry.getParser('.epub'), isNull);
        expect(FormatRegistry.getParser('.unknown'), isNull);
      });

      test('is case-insensitive', () {
        final parser = MockParser();
        FormatRegistry.register('.epub', parser);

        expect(FormatRegistry.getParser('.EPUB'), same(parser));
        expect(FormatRegistry.getParser('.Epub'), same(parser));
        expect(FormatRegistry.getParser('.EPUB'), same(parser));
      });
    });

    group('isSupported', () {
      test('returns true for registered format', () {
        FormatRegistry.register('.epub', MockParser());

        expect(FormatRegistry.isSupported('.epub'), isTrue);
      });

      test('returns false for unregistered format', () {
        expect(FormatRegistry.isSupported('.epub'), isFalse);
        expect(FormatRegistry.isSupported('.unknown'), isFalse);
      });

      test('is case-insensitive', () {
        FormatRegistry.register('.epub', MockParser());

        expect(FormatRegistry.isSupported('.EPUB'), isTrue);
        expect(FormatRegistry.isSupported('.Epub'), isTrue);
        expect(FormatRegistry.isSupported('.EPUB'), isTrue);
      });
    });

    group('getSupportedFormats', () {
      test('returns empty list when no formats registered', () {
        expect(FormatRegistry.getSupportedFormats(), isEmpty);
      });

      test('returns list of registered formats', () {
        FormatRegistry.register('.epub', MockParser());
        FormatRegistry.register('.pdf', MockParser());

        final formats = FormatRegistry.getSupportedFormats();
        expect(formats.length, equals(2));
        expect(formats, containsAll(['.epub', '.pdf']));
      });

      test('returns lowercase format extensions', () {
        FormatRegistry.register('.EPUB', MockParser());
        FormatRegistry.register('.PDF', MockParser());

        final formats = FormatRegistry.getSupportedFormats();
        expect(formats, containsAll(['.epub', '.pdf']));
        expect(formats, isNot(contains('.EPUB')));
        expect(formats, isNot(contains('.PDF')));
      });

      test('returns a new list instance', () {
        FormatRegistry.register('.epub', MockParser());

        final formats1 = FormatRegistry.getSupportedFormats();
        final formats2 = FormatRegistry.getSupportedFormats();

        expect(identical(formats1, formats2), isFalse);
      });
    });

    group('clear', () {
      test('removes all registered parsers', () {
        FormatRegistry.register('.epub', MockParser());
        FormatRegistry.register('.pdf', MockParser());

        expect(FormatRegistry.isSupported('.epub'), isTrue);
        expect(FormatRegistry.isSupported('.pdf'), isTrue);

        FormatRegistry.clear();

        expect(FormatRegistry.isSupported('.epub'), isFalse);
        expect(FormatRegistry.isSupported('.pdf'), isFalse);
        expect(FormatRegistry.getSupportedFormats(), isEmpty);
      });

      test('allows re-registration after clear', () {
        final parser1 = MockParser('first');
        final parser2 = MockParser('second');

        FormatRegistry.register('.epub', parser1);
        FormatRegistry.clear();
        FormatRegistry.register('.epub', parser2);

        expect(FormatRegistry.getParser('.epub'), same(parser2));
      });
    });
  });

  group('BookFormatParser Interface', () {
    test('MockParser implements all interface methods', () {
      final parser = MockParser();

      expect(parser.parseMetadata, isA<Function>());
      expect(parser.getChapters, isA<Function>());
      expect(parser.getChapterContent, isA<Function>());
    });
  });
}
