import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';

void main() {
  group('Chapter htmlContent', () {
    group('constructor', () {
      test('should create Chapter with htmlContent only', () {
        final chapter = Chapter(
          bookId: 'test-book',
          index: 0,
          title: 'Test Chapter',
          location: ChapterLocation(),
          htmlContent: 'This is the plain text content.',
        );

        expect(chapter.htmlContent, 'This is the plain text content.');
        expect(chapter.bookId, 'test-book');
        expect(chapter.index, 0);
        expect(chapter.title, 'Test Chapter');
      });

      test('should create Chapter with htmlContent', () {
        final chapter = Chapter(
          bookId: 'test-book',
          index: 1,
          title: 'HTML Chapter',
          location: ChapterLocation(href: 'chapter1.xhtml'),
          htmlContent: '<p>This is the <strong>HTML</strong> content.</p>',
        );

        expect(chapter.htmlContent,
            '<p>This is the <strong>HTML</strong> content.</p>');
      });

      test('should create Chapter with empty htmlContent', () {
        final chapter = Chapter(
          bookId: 'test-book',
          index: 0,
          title: 'Empty',
          location: ChapterLocation(),
          htmlContent: '',
        );

        expect(chapter.htmlContent, isEmpty);
      });

      test('should create Chapter with complex HTML', () {
        final htmlContent = '''
          <h1>Chapter 1</h1>
          <p>First paragraph with <em>emphasis</em>.</p>
          <ul>
            <li>Item 1</li>
            <li>Item 2</li>
          </ul>
        ''';
        final chapter = Chapter(
          bookId: 'test-book',
          index: 2,
          title: 'Complex',
          location: ChapterLocation(href: 'chapter2.xhtml'),
          htmlContent: htmlContent,
        );

        expect(chapter.htmlContent, contains('<h1>'));
        expect(chapter.htmlContent, contains('<ul>'));
        expect(chapter.htmlContent, contains('<li>'));
      });

      test('should create Chapter with long htmlContent', () {
        final longText = 'Test content. ' * 1000;
        final chapter = Chapter(
          bookId: 'test-book',
          index: 0,
          title: 'Long',
          location: ChapterLocation(),
          htmlContent: longText,
        );

        expect(chapter.htmlContent, longText);
        expect(chapter.htmlContent!.length, 14000);
      });

      test('should create Chapter with null htmlContent', () {
        final chapter = Chapter(
          bookId: 'test-book',
          index: 0,
          title: 'No Content',
          location: ChapterLocation(),
        );

        expect(chapter.htmlContent, isNull);
      });
    });
  });
}
