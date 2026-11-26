import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/services/parsers/pdf_parser.dart';

void main() {
  group('PdfParser', () {
    late PdfParser parser;
    late String nonExistentPath;

    setUpAll(() {
      parser = PdfParser();
      nonExistentPath = '/non/existent/path/book.pdf';
    });

    group('getChapters', () {
      test('returns empty list when file does not exist', () async {
        final chapters = await parser.getChapters(nonExistentPath);
        expect(chapters, isEmpty);
      });
    });

    group('getChapterContent', () {
      test('throws Exception when file does not exist', () async {
        final chapter = Chapter(
          bookId: 'test',
          index: 0,
          title: 'Test Chapter',
          location: ChapterLocation(startPage: 1, endPage: 10),
        );

        expect(
          () => parser.getChapterContent(nonExistentPath, chapter),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('PDF file not found'),
          )),
        );
      });
    });

    group('ChapterLocation', () {
      test('ChapterLocation with null pages', () {
        final location = ChapterLocation();
        expect(location.href, isNull);
        expect(location.startPage, isNull);
        expect(location.endPage, isNull);
      });

      test('ChapterLocation with href', () {
        final location = ChapterLocation(href: 'chapter1.xhtml');
        expect(location.href, equals('chapter1.xhtml'));
        expect(location.startPage, isNull);
        expect(location.endPage, isNull);
      });

      test('ChapterLocation with page range', () {
        final location = ChapterLocation(startPage: 1, endPage: 10);
        expect(location.href, isNull);
        expect(location.startPage, equals(1));
        expect(location.endPage, equals(10));
      });
    });
  });
}
