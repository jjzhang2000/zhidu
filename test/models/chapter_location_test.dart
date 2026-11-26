import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';

void main() {
  group('ChapterLocation', () {
    group('constructor', () {
      test('should create ChapterLocation with href for EPUB', () {
        final location = ChapterLocation(href: 'chapter1.xhtml');

        expect(location.href, 'chapter1.xhtml');
        expect(location.startPage, isNull);
        expect(location.endPage, isNull);
      });

      test('should create ChapterLocation with page range for PDF', () {
        final location = ChapterLocation(startPage: 10, endPage: 25);

        expect(location.href, isNull);
        expect(location.startPage, 10);
        expect(location.endPage, 25);
      });

      test('should create ChapterLocation with all fields', () {
        final location = ChapterLocation(
          href: 'chapter1.xhtml',
          startPage: 1,
          endPage: 10,
        );

        expect(location.href, 'chapter1.xhtml');
        expect(location.startPage, 1);
        expect(location.endPage, 10);
      });

      test('should create empty ChapterLocation', () {
        final location = ChapterLocation();

        expect(location.href, isNull);
        expect(location.startPage, isNull);
        expect(location.endPage, isNull);
      });

      test('should create ChapterLocation with href containing path', () {
        final location =
            ChapterLocation(href: 'OEBPS/chapters/chapter01.xhtml');

        expect(location.href, 'OEBPS/chapters/chapter01.xhtml');
      });

      test('should create ChapterLocation with href containing anchor', () {
        final location = ChapterLocation(href: 'chapter1.xhtml#section2');

        expect(location.href, 'chapter1.xhtml#section2');
      });
    });
  });
}
