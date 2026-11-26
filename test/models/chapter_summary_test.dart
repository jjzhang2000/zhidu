import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';

void main() {
  group('Chapter abbreviation', () {
    group('constructor', () {
      test('should create Chapter with all required parameters and abbreviation', () {
        final chapter = Chapter(
          bookId: 'book-123',
          index: 5,
          title: 'Chapter 5: Deep Learning',
          location: ChapterLocation(href: 'ch5.xhtml'),
          abbreviation: 'This chapter introduces deep learning concepts.',
        );

        expect(chapter.bookId, 'book-123');
        expect(chapter.index, 5);
        expect(chapter.title, 'Chapter 5: Deep Learning');
        expect(chapter.abbreviation,
            'This chapter introduces deep learning concepts.');
      });

      test('should create Chapter with empty title and abbreviation', () {
        final chapter = Chapter(
          bookId: 'book-123',
          index: 0,
          title: '',
          location: ChapterLocation(),
          abbreviation: 'Abbreviation',
        );

        expect(chapter.title, isEmpty);
      });
    });
  });
}
