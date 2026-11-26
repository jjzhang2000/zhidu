import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/book.dart';
import 'package:zhidu/services/book_service.dart';
import 'package:zhidu/services/storage_config.dart';

void main() {
  final testEpubPath =
      'D:\\Projects\\zhidu\\test\\Vibe Coding AI Bian Cheng Wan Q - Tan Xing Xing.epub';
  final testEpub2Path =
      'D:\\Projects\\zhidu\\test\\fixtures\\test_book.epub';

  group('BookService real file import', () {
    late Directory testDir;
    late BookService service;

    setUp(() async {
      testDir = Directory(
          '${Directory.systemTemp.path}/zhidu_book_test_${DateTime.now().millisecondsSinceEpoch}');
      await testDir.create(recursive: true);
      StorageConfig.resetForTest();
      StorageConfig.setTestBaseDirectory(testDir);
      service = BookService();
      service.resetForTest();
      await service.init();
    });

    tearDown(() async {
      StorageConfig.resetForTest();
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    group('importBookFromPath', () {
      test('imports EPUB file successfully', () async {
        final book = await service.importBookFromPath(testEpubPath);

        expect(book, isNotNull);
        expect(book!.format, BookFormat.epub);
        expect(book.title, isNotEmpty);
        expect(book.author, isNotEmpty);
        expect(book.filePath, testEpubPath);
      });

      test('imports second EPUB file successfully', () async {
        final book = await service.importBookFromPath(testEpub2Path);

        expect(book, isNotNull);
        expect(book!.format, BookFormat.epub);
        expect(book.title, isNotEmpty);
        expect(book.author, isNotEmpty);
      });

      test('returns existing book on duplicate import', () async {
        final book1 = await service.importBookFromPath(testEpubPath);
        expect(book1, isNotNull);
        expect(service.books.length, 1);

        final book2 = await service.importBookFromPath(testEpubPath);
        expect(book2, isNotNull);
        expect(book2!.id, book1!.id);
        expect(service.books.length, 1);
      });

      test('returns null for unsupported format', () async {
        final invalidPath = 'D:\\Projects\\zhidu\\test\\test_invalid.txt';
        final result = await service.importBookFromPath(invalidPath);

        expect(result, isNull);
      });

      test('returns null for non-existent file', () async {
        final nonExistentPath = 'D:\\Projects\\zhidu\\test\\non_existent.epub';
        final result = await service.importBookFromPath(nonExistentPath);

        expect(result, isNull);
      });

      test('adds book to books list', () async {
        await service.importBookFromPath(testEpubPath);

        expect(service.books.length, 1);
        expect(service.books.first.filePath, testEpubPath);
      });

      test('saves book metadata to file', () async {
        final book = await service.importBookFromPath(testEpubPath);
        expect(book, isNotNull);

        final metadataPath = await StorageConfig.getBookMetadataPath(book!.id);
        final metadataFile = File(metadataPath);
        expect(await metadataFile.exists(), isTrue);
      });

      test('saves books index to file', () async {
        await service.importBookFromPath(testEpubPath);

        final indexPath = await StorageConfig.getBooksIndexPath();
        final indexFile = File(indexPath);
        expect(await indexFile.exists(), isTrue);
      });
    });

    group('getBookById', () {
      test('returns book after import', () async {
        final importedBook = await service.importBookFromPath(testEpubPath);
        expect(importedBook, isNotNull);

        final book = service.getBookById(importedBook!.id);

        expect(book, isNotNull);
        expect(book!.id, importedBook.id);
        expect(book.title, importedBook.title);
      });

      test('returns null for non-existent id', () async {
        final book = service.getBookById('non-existent-id');

        expect(book, isNull);
      });

      test('returns correct book after multiple imports', () async {
        final epubBook = await service.importBookFromPath(testEpubPath);
        final epubBook2 = await service.importBookFromPath(testEpub2Path);
        expect(epubBook, isNotNull);
        expect(epubBook2, isNotNull);

        final foundEpub = service.getBookById(epubBook!.id);
        final foundEpub2 = service.getBookById(epubBook2!.id);

        expect(foundEpub!.format, BookFormat.epub);
        expect(foundEpub2!.format, BookFormat.epub);
      });
    });

    group('updateBook', () {
      test('updates book reading progress', () async {
        final book = await service.importBookFromPath(testEpubPath);
        expect(book, isNotNull);

        final updatedBook = book!.copyWith(
          readingProgress: 0.5,
          lastPageIndex: 3,
        );
        await service.updateBook(updatedBook);

        final retrievedBook = service.getBookById(book.id);
        expect(retrievedBook!.readingProgress, 0.5);
        expect(retrievedBook.lastPageIndex, 3);
      });

      test('book can be updated with readingProgress', () async {
        final book = await service.importBookFromPath(testEpubPath);
        expect(book, isNotNull);

        final updatedBook = book!.copyWith(readingProgress: 0.5);
        await service.updateBook(updatedBook);

        final retrievedBook = service.getBookById(book.id);
        expect(retrievedBook!.readingProgress, 0.5);
      });

      test('persists update to metadata file', () async {
        final book = await service.importBookFromPath(testEpubPath);
        expect(book, isNotNull);

        final updatedBook = book!.copyWith(lastReadAt: DateTime.now());
        await service.updateBook(updatedBook);

        final metadataPath = await StorageConfig.getBookMetadataPath(book.id);
        final metadataContent = await File(metadataPath).readAsString();
        expect(metadataContent, contains('lastReadAt'));
      });

      test('does not affect other books', () async {
        final epubBook = await service.importBookFromPath(testEpubPath);
        final epubBook2 = await service.importBookFromPath(testEpub2Path);
        expect(epubBook, isNotNull);
        expect(epubBook2, isNotNull);

        final updatedEpub = epubBook!.copyWith(readingProgress: 0.8);
        await service.updateBook(updatedEpub);

        final unchangedEpub2 = service.getBookById(epubBook2!.id);
        expect(unchangedEpub2!.readingProgress, 0.0);
      });
    });

    group('deleteBook', () {
      test('deletes book successfully', () async {
        final book = await service.importBookFromPath(testEpubPath);
        expect(book, isNotNull);
        expect(service.books.length, 1);

        final result = await service.deleteBook(book!.id);

        expect(result, isTrue);
        expect(service.books.length, 0);
        expect(service.getBookById(book.id), isNull);
      });

      test('deletes book metadata directory', () async {
        final book = await service.importBookFromPath(testEpubPath);
        expect(book, isNotNull);

        final bookDir = await StorageConfig.getBookDirectory(book!.id);
        expect(await bookDir.exists(), isTrue);

        await service.deleteBook(book.id);

        expect(await bookDir.exists(), isFalse);
      });

      test('returns false for non-existent book', () async {
        final result = await service.deleteBook('non-existent-id');

        expect(result, isFalse);
      });

      test('does not affect other books', () async {
        final epubBook = await service.importBookFromPath(testEpubPath);
        final epubBook2 = await service.importBookFromPath(testEpub2Path);
        expect(epubBook, isNotNull);
        expect(epubBook2, isNotNull);

        await service.deleteBook(epubBook!.id);

        expect(service.books.length, 1);
        expect(service.getBookById(epubBook2!.id), isNotNull);
      });

      test('updates books index after deletion', () async {
        final book = await service.importBookFromPath(testEpubPath);
        expect(book, isNotNull);

        await service.deleteBook(book!.id);

        final indexPath = await StorageConfig.getBooksIndexPath();
        final indexFile = File(indexPath);
        if (await indexFile.exists()) {
          final indexContent = await indexFile.readAsString();
          expect(indexContent, isNot(contains(book.id)));
        }
      });
    });

    group('searchBooks', () {
      test('searches by title', () async {
        final book = await service.importBookFromPath(testEpubPath);
        expect(book, isNotNull);

        final results = service.searchBooks('Vibe');

        expect(results.length, greaterThan(0));
        expect(results.any((b) => b.title.contains('Vibe')), isTrue);
      });

      test('searches by author', () async {
        final book = await service.importBookFromPath(testEpub2Path);
        expect(book, isNotNull);

        final results = service.searchBooks(book!.author);

        expect(results.length, greaterThan(0));
      });

      test('searches case-insensitively', () async {
        await service.importBookFromPath(testEpubPath);

        final results1 = service.searchBooks('vibe');
        final results2 = service.searchBooks('VIBE');
        final results3 = service.searchBooks('Vibe');

        expect(results1.length, greaterThan(0));
        expect(results2.length, greaterThan(0));
        expect(results3.length, greaterThan(0));
      });

      test('returns empty list when no match', () async {
        await service.importBookFromPath(testEpubPath);

        final results = service.searchBooks('Nonexistent');

        expect(results, isEmpty);
      });

      test('returns all books matching query', () async {
        await service.importBookFromPath(testEpubPath);
        await service.importBookFromPath(testEpub2Path);

        final results = service.searchBooks('Test');

        expect(results.length, greaterThan(0));
      });
    });

    group('complete import-read-delete workflow', () {
      test('imports, updates, and deletes book', () async {
        final book = await service.importBookFromPath(testEpubPath);
        expect(book, isNotNull);
        expect(service.books.length, 1);

        final updatedBook = book!.copyWith(
          readingProgress: 0.75,
          lastChapterIndex: 5,
          lastReadAt: DateTime.now(),
        );
        await service.updateBook(updatedBook);

        final retrievedBook = service.getBookById(book.id);
        expect(retrievedBook!.readingProgress, 0.75);
        expect(retrievedBook.lastChapterIndex, 5);

        final deleted = await service.deleteBook(book.id);
        expect(deleted, isTrue);
        expect(service.books.length, 0);
      });

      test('imports multiple books, searches, and deletes', () async {
        await service.importBookFromPath(testEpubPath);
        await service.importBookFromPath(testEpub2Path);

        expect(service.books.length, 2);

        final searchResults = service.searchBooks('AI');
        expect(searchResults.length, greaterThan(0));

        final booksCopy = List<Book>.from(service.books);
        for (final book in booksCopy) {
          await service.deleteBook(book.id);
        }

        expect(service.books.length, 0);
      });
    });
  });

  group('BookService persistence', () {
    late Directory testDir;

    setUp(() async {
      testDir = Directory(
          '${Directory.systemTemp.path}/zhidu_persistence_test_${DateTime.now().millisecondsSinceEpoch}');
      await testDir.create(recursive: true);
      StorageConfig.resetForTest();
      StorageConfig.setTestBaseDirectory(testDir);
      BookService().resetForTest();
    });

    tearDown(() async {
      StorageConfig.resetForTest();
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('persists books across service restarts', () async {
      final service1 = BookService();
      await service1.init();

      final book = await service1.importBookFromPath(testEpubPath);
      expect(book, isNotNull);
      expect(service1.books.length, 1);

      BookService().resetForTest();
      StorageConfig.resetForTest();
      StorageConfig.setTestBaseDirectory(testDir);

      final service2 = BookService();
      await service2.init();

      expect(service2.books.length, 1);
      expect(service2.books.first.id, book!.id);
      expect(service2.books.first.title, book.title);
    });

    test('persists book updates across restarts', () async {
      final service1 = BookService();
      await service1.init();

      final book = await service1.importBookFromPath(testEpubPath);
      expect(book, isNotNull);

      final updatedBook = book!.copyWith(
        readingProgress: 0.42,
      );
      await service1.updateBook(updatedBook);

      BookService().resetForTest();
      StorageConfig.resetForTest();
      StorageConfig.setTestBaseDirectory(testDir);

      final service2 = BookService();
      await service2.init();

      final restoredBook = service2.getBookById(book.id);
      expect(restoredBook!.readingProgress, 0.42);
    });

    test('handles empty storage on first init', () async {
      final service = BookService();
      await service.init();

      expect(service.books, isEmpty);
    });
  });
}
