import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/book.dart';

void main() {
  group('BookFormat', () {
    test('should have pdf and epub values', () {
      expect(BookFormat.values.length, 2);
      expect(BookFormat.values, contains(BookFormat.pdf));
      expect(BookFormat.values, contains(BookFormat.epub));
    });

    test('should have correct name property', () {
      expect(BookFormat.pdf.name, 'pdf');
      expect(BookFormat.epub.name, 'epub');
    });
  });

  group('Book', () {
    late DateTime testAddedAt;
    late DateTime testLastReadAt;

    setUp(() {
      testAddedAt = DateTime(2024, 1, 15, 10, 30);
      testLastReadAt = DateTime(2024, 2, 20, 15, 45);
    });

    group('constructor', () {
      test('should create Book with required parameters', () {
        final book = Book(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: BookFormat.epub,
          addedAt: testAddedAt,
        );

        expect(book.id, 'test-id');
        expect(book.title, 'Test Book');
        expect(book.author, 'Test Author');
        expect(book.filePath, '/path/to/book.epub');
        expect(book.format, BookFormat.epub);
        expect(book.addedAt, testAddedAt);
      });

      test('should create Book with default values', () {
        final book = Book(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.pdf',
          format: BookFormat.pdf,
          addedAt: testAddedAt,
        );

        expect(book.coverPath, isNull);
        expect(book.totalChapters, 0);
        expect(book.readingProgress, 0.0);
        expect(book.lastReadAt, isNull);
      });
    });

    group('copyWith', () {
      late Book originalBook;

      setUp(() {
        originalBook = Book(
          id: 'original-id',
          title: 'Original Title',
          author: 'Original Author',
          coverPath: '/original/cover.jpg',
          filePath: '/original/book.epub',
          format: BookFormat.epub,
          totalChapters: 10,
          readingProgress: 0.3,
          addedAt: testAddedAt,
          lastReadAt: testLastReadAt,
        );
      });

      test('should create copy with no changes', () {
        final copy = originalBook.copyWith();

        expect(copy.id, originalBook.id);
        expect(copy.title, originalBook.title);
        expect(copy.author, originalBook.author);
        expect(copy.coverPath, originalBook.coverPath);
        expect(copy.filePath, originalBook.filePath);
        expect(copy.format, originalBook.format);
        expect(copy.totalChapters, originalBook.totalChapters);
        expect(copy.readingProgress, originalBook.readingProgress);
        expect(copy.addedAt, originalBook.addedAt);
        expect(copy.lastReadAt, originalBook.lastReadAt);
      });

      test('should create copy with updated title', () {
        final copy = originalBook.copyWith(title: 'New Title');
        expect(copy.title, 'New Title');
        expect(copy.id, originalBook.id);
      });

      test('should create copy with updated readingProgress', () {
        final copy = originalBook.copyWith(readingProgress: 0.8);
        expect(copy.readingProgress, 0.8);
        expect(copy.totalChapters, originalBook.totalChapters);
      });

      test('should create copy with updated lastPageIndex', () {
        final copy = originalBook.copyWith(lastPageIndex: 7);
        expect(copy.lastPageIndex, 7);
        expect(copy.totalChapters, originalBook.totalChapters);
      });

      test('should keep original lastReadAt when not specified', () {
        final copy = originalBook.copyWith(title: 'New Title');
        expect(copy.lastReadAt, originalBook.lastReadAt);
      });

      test('should create copy with new readingProgress', () {
        final copy = originalBook.copyWith(readingProgress: 0.9);
        expect(copy.readingProgress, 0.9);
      });
    });

    group('toJson', () {
      test('should serialize all fields correctly', () {
        final book = Book(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          coverPath: '/path/to/cover.jpg',
          filePath: '/path/to/book.epub',
          format: BookFormat.epub,
          totalChapters: 10,
          readingProgress: 0.5,
          addedAt: testAddedAt,
          lastReadAt: testLastReadAt,
        );

        final json = book.toJson();

        expect(json['id'], 'test-id');
        expect(json['title'], 'Test Book');
        expect(json['author'], 'Test Author');
        expect(json['coverPath'], '/path/to/cover.jpg');
        expect(json['filePath'], '/path/to/book.epub');
        expect(json['format'], 'epub');
        expect(json['totalChapters'], 10);
        expect(json['readingProgress'], 0.5);
        expect(json['addedAt'], testAddedAt.toIso8601String());
        expect(json['lastReadAt'], testLastReadAt.toIso8601String());
      });

      test('should handle null fields correctly', () {
        final book = Book(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.pdf',
          format: BookFormat.pdf,
          addedAt: testAddedAt,
        );

        final json = book.toJson();

        expect(json['coverPath'], isNull);
        expect(json['lastReadAt'], isNull);
      });

      test('should handle language field correctly', () {
        final book = Book(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          filePath: '/path/to/book.epub',
          format: BookFormat.epub,
          addedAt: testAddedAt,
          language: 'en',
        );

        final json = book.toJson();

        expect(json['language'], 'en');
      });
    });

    group('fromJson', () {
      test('should deserialize all fields correctly', () {
        final json = {
          'id': 'test-id',
          'title': 'Test Book',
          'author': 'Test Author',
          'coverPath': '/path/to/cover.jpg',
          'filePath': '/path/to/book.epub',
          'format': 'epub',
          'totalChapters': 10,
          'readingProgress': 0.5,
          'addedAt': testAddedAt.toIso8601String(),
          'lastReadAt': testLastReadAt.toIso8601String(),
          'language': 'en',
        };

        final book = Book.fromJson(json);

        expect(book.id, 'test-id');
        expect(book.title, 'Test Book');
        expect(book.author, 'Test Author');
        expect(book.coverPath, '/path/to/cover.jpg');
        expect(book.filePath, '/path/to/book.epub');
        expect(book.format, BookFormat.epub);
        expect(book.totalChapters, 10);
        expect(book.readingProgress, 0.5);
        expect(book.addedAt, testAddedAt);
        expect(book.lastReadAt, testLastReadAt);
        expect(book.language, 'en');
      });

      test('should handle missing optional fields with defaults', () {
        final json = {
          'id': 'test-id',
          'title': 'Test Book',
          'author': 'Test Author',
          'filePath': '/path/to/book.pdf',
          'format': 'pdf',
          'addedAt': testAddedAt.toIso8601String(),
        };

        final book = Book.fromJson(json);

        expect(book.coverPath, isNull);
        expect(book.totalChapters, 0);
        expect(book.readingProgress, 0.0);
        expect(book.lastReadAt, isNull);
        expect(book.language, isNull);
      });

      test('should default to epub format for unknown format', () {
        final json = {
          'id': 'test-id',
          'title': 'Test Book',
          'author': 'Test Author',
          'filePath': '/path/to/book.xyz',
          'format': 'unknown_format',
          'addedAt': testAddedAt.toIso8601String(),
        };

        final book = Book.fromJson(json);

        expect(book.format, BookFormat.epub);
      });

      test('should parse pdf format correctly', () {
        final json = {
          'id': 'test-id',
          'title': 'Test Book',
          'author': 'Test Author',
          'filePath': '/path/to/book.pdf',
          'format': 'pdf',
          'addedAt': testAddedAt.toIso8601String(),
        };

        final book = Book.fromJson(json);

        expect(book.format, BookFormat.pdf);
      });

      test('should convert readingProgress to double', () {
        final json = {
          'id': 'test-id',
          'title': 'Test Book',
          'author': 'Test Author',
          'filePath': '/path/to/book.pdf',
          'format': 'pdf',
          'readingProgress': 0.75,
          'addedAt': testAddedAt.toIso8601String(),
        };

        final book = Book.fromJson(json);

        expect(book.readingProgress, 0.75);
        expect(book.readingProgress, isA<double>());
      });

      test('should handle integer readingProgress', () {
        final json = {
          'id': 'test-id',
          'title': 'Test Book',
          'author': 'Test Author',
          'filePath': '/path/to/book.pdf',
          'format': 'pdf',
          'readingProgress': 1,
          'addedAt': testAddedAt.toIso8601String(),
        };

        final book = Book.fromJson(json);

        expect(book.readingProgress, 1.0);
        expect(book.readingProgress, isA<double>());
      });

      test('should handle language field in JSON', () {
        final json = {
          'id': 'test-id',
          'title': 'Test Book',
          'author': 'Test Author',
          'filePath': '/path/to/book.epub',
          'format': 'epub',
          'addedAt': testAddedAt.toIso8601String(),
          'language': 'zh',
        };

        final book = Book.fromJson(json);

        expect(book.language, 'zh');
      });
    });

    group('toJson and fromJson round trip', () {
      test('should maintain data integrity through serialization cycle', () {
        final originalBook = Book(
          id: 'test-id',
          title: 'Test Book',
          author: 'Test Author',
          coverPath: '/path/to/cover.jpg',
          filePath: '/path/to/book.epub',
          format: BookFormat.epub,
          totalChapters: 10,
          readingProgress: 0.5,
          addedAt: testAddedAt,
          lastReadAt: testLastReadAt,
          language: 'en',
        );

        final json = originalBook.toJson();
        final restoredBook = Book.fromJson(json);

        expect(restoredBook.id, originalBook.id);
        expect(restoredBook.title, originalBook.title);
        expect(restoredBook.author, originalBook.author);
        expect(restoredBook.coverPath, originalBook.coverPath);
        expect(restoredBook.filePath, originalBook.filePath);
        expect(restoredBook.format, originalBook.format);
        expect(restoredBook.totalChapters, originalBook.totalChapters);
        expect(restoredBook.readingProgress, originalBook.readingProgress);
        expect(restoredBook.addedAt, originalBook.addedAt);
        expect(restoredBook.lastReadAt, originalBook.lastReadAt);
        expect(restoredBook.language, originalBook.language);
      });
    });
  });
}
