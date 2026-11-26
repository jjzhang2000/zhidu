import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/book.dart';

void main() {
  group('Book Model', () {
    test('defaults to epub format when not specified', () {
      final json = {
        'id': 'test',
        'title': 'Test',
        'author': 'Author',
        'filePath': '/path/to/book',
        'addedAt': DateTime.now().toIso8601String(),
      };

      final book = Book.fromJson(json);
      expect(book.format, BookFormat.epub);
    });

    test('parses epub format correctly', () {
      final json = {
        'id': 'test',
        'title': 'Test',
        'author': 'Author',
        'filePath': '/path/to/book',
        'format': 'epub',
        'addedAt': DateTime.now().toIso8601String(),
      };

      final book = Book.fromJson(json);
      expect(book.format, BookFormat.epub);
    });

    test('parses pdf format correctly', () {
      final json = {
        'id': 'test',
        'title': 'Test',
        'author': 'Author',
        'filePath': '/path/to/book',
        'format': 'pdf',
        'addedAt': DateTime.now().toIso8601String(),
      };

      final book = Book.fromJson(json);
      expect(book.format, BookFormat.pdf);
    });

    test('toJson includes format and addedAt', () {
      final now = DateTime.now();
      final book = Book(
        id: 'test',
        title: 'Test',
        author: 'Author',
        filePath: '/path/to/book',
        format: BookFormat.pdf,
        addedAt: now,
      );

      final json = book.toJson();
      expect(json['format'], 'pdf');
      expect(json['addedAt'], isA<String>());
    });
  });
}
