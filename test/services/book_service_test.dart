import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/book.dart';
import 'package:zhidu/services/book_service.dart';

void main() {
  group('BookService', () {
    late BookService service;
    late DateTime testAddedAt;

    setUp(() {
      service = BookService();
      testAddedAt = DateTime(2024, 1, 15, 10, 30);
    });

    Book createTestBook({
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
        filePath: '/path/to/book.${format.name}',
        format: format,
        totalChapters: totalChapters,
        addedAt: testAddedAt,
      );
    }

    group('getBookById', () {
      test('returns null when books list is empty', () {
        expect(service.getBookById('non-existent'), isNull);
      });

      test('returns null for non-existent book id', () {
        expect(service.getBookById('book-not-in-list'), isNull);
      });
    });

    group('searchBooks', () {
      test('returns empty list when no books match query', () {
        final results = service.searchBooks('nonexistent');
        expect(results, isEmpty);
      });

      test('returns empty list for empty query with no books', () {
        final results = service.searchBooks('');
        expect(results, isEmpty);
      });
    });

    group('books getter', () {
      test('returns empty list initially', () {
        expect(service.books, isEmpty);
      });

      test('returns unmodifiable list view', () {
        final books = service.books;
        expect(books, isA<List<Book>>());
      });
    });

    group('Book model integration', () {
      test('Book copyWith preserves format', () {
        final book = createTestBook(format: BookFormat.pdf);
        final updated = book.copyWith(title: 'Updated Title');
        expect(updated.format, BookFormat.pdf);
      });

      test('Book toJson/fromJson preserves format', () {
        final book = createTestBook(format: BookFormat.epub);
        final json = book.toJson();
        final restored = Book.fromJson(json);
        expect(restored.format, BookFormat.epub);
      });
    });
  });
}
