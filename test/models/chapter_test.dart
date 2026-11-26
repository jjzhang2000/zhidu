import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';

void main() {
  group('Chapter', () {
    late ChapterLocation testLocation;

    setUp(() {
      testLocation = ChapterLocation(href: 'chapter1.xhtml');
    });

    group('constructor', () {
      test('should create Chapter with required parameters', () {
        final chapter = Chapter(
          bookId: 'test-book',
          index: 0,
          title: 'Chapter 1',
          location: testLocation,
        );

        expect(chapter.bookId, 'test-book');
        expect(chapter.index, 0);
        expect(chapter.title, 'Chapter 1');
        expect(chapter.location, testLocation);
      });

      test('should create Chapter with default level', () {
        final chapter = Chapter(
          bookId: 'test-book',
          index: 0,
          title: 'Chapter 1',
          location: testLocation,
        );

        expect(chapter.level, 0);
      });

      test('should create Chapter with custom level', () {
        final chapter = Chapter(
          bookId: 'test-book',
          index: 0,
          title: 'Chapter 1',
          location: testLocation,
          level: 2,
        );

        expect(chapter.level, 2);
      });

      test('should create Chapter with PDF location', () {
        final pdfLocation = ChapterLocation(startPage: 10, endPage: 25);
        final chapter = Chapter(
          bookId: 'test-book',
          index: 5,
          title: 'PDF Chapter',
          location: pdfLocation,
        );

        expect(chapter.bookId, 'test-book');
        expect(chapter.location.startPage, 10);
        expect(chapter.location.endPage, 25);
      });

      test('should create Chapter with htmlContent', () {
        final chapter = Chapter(
          bookId: 'test-book',
          index: 0,
          title: 'HTML Chapter',
          location: testLocation,
          htmlContent: '<p>Content</p>',
        );

        expect(chapter.htmlContent, '<p>Content</p>');
      });

      test('should create Chapter with abbreviation', () {
        final chapter = Chapter(
          bookId: 'test-book',
          index: 0,
          title: 'Abbreviation Chapter',
          location: testLocation,
          abbreviation: 'Test content.',
        );

        expect(chapter.abbreviation, 'Test content.');
      });
    });
  });
}
