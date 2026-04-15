import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhidu/services/storage_config.dart';
import 'package:zhidu/services/storage_path_service.dart';

/// Mock LogService for testing
class _MockLogService {
  void v(String tag, String message) {}
  void d(String tag, String message) {}
  void info(String tag, String message) {}
  void w(String tag, String message) {}
  void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) {}
}

void main() {
  late Directory testBaseDir;
  late StoragePathService service;

  setUpAll(() async {
    testBaseDir =
        Directory('${Directory.systemTemp.path}/zhidu_storage_path_test');
    if (await testBaseDir.exists()) {
      await testBaseDir.delete(recursive: true);
    }
    await testBaseDir.create(recursive: true);
  });

  tearDownAll(() async {
    StorageConfig.resetForTest();
    if (await testBaseDir.exists()) {
      await testBaseDir.delete(recursive: true);
    }
  });

  group('StoragePathService', () {
    setUp(() async {
      StorageConfig.resetForTest();
      StorageConfig.setTestBaseDirectory(testBaseDir);
      service = StoragePathService();
      await service.init();
    });

    tearDown(() {
      // Reset to default after each test
      service.resetBooksDirectory();
      service.resetBackupDirectory();
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = StoragePathService();
        final instance2 = StoragePathService();

        expect(identical(instance1, instance2), isTrue);
      });

      test('should share state between instances', () async {
        final instance1 = StoragePathService();
        final instance2 = StoragePathService();

        final customPath = p.join(testBaseDir.path, 'custom_books');
        instance1.setBooksDirectory(customPath);

        // Both instances should see the same custom path
        final dir2 = await instance2.booksDirectory;
        expect(dir2.path, equals(customPath));
      });
    });

    group('Initialization', () {
      test('should initialize without errors', () async {
        final newService = StoragePathService();
        await newService.init();

        // Should be able to get directories after init
        final booksDir = await newService.booksDirectory;
        expect(booksDir, isNotNull);
      });

      test('should be idempotent - multiple init calls safe', () async {
        final newService = StoragePathService();
        await newService.init();
        await newService.init(); // Second init should be safe
        await newService.init(); // Third init should be safe

        final booksDir = await newService.booksDirectory;
        expect(booksDir, isNotNull);
      });
    });

    group('Directory Access - booksDirectory', () {
      test('should return default path when not set', () async {
        final dir = await service.booksDirectory;

        expect(dir.path, contains('zhidu'));
        expect(dir.path, contains('books'));
      });

      test('should return custom path when set', () async {
        final customPath = p.join(testBaseDir.path, 'my_custom_books');
        service.setBooksDirectory(customPath);

        final dir = await service.booksDirectory;
        expect(dir.path, equals(customPath));
      });

      test('should create directory if not exists', () async {
        final customPath = p.join(testBaseDir.path,
            'non_existent_${DateTime.now().millisecondsSinceEpoch}');
        service.setBooksDirectory(customPath);

        final dir = await service.booksDirectory;
        expect(await dir.exists(), isTrue);
      });

      test('should create directory recursively', () async {
        final customPath = p.join(testBaseDir.path, 'nested', 'deep', 'books');
        service.setBooksDirectory(customPath);

        final dir = await service.booksDirectory;
        expect(await dir.exists(), isTrue);
        expect(dir.path, equals(customPath));
      });

      test('should return same directory on multiple calls', () async {
        final dir1 = await service.booksDirectory;
        final dir2 = await service.booksDirectory;

        expect(dir1.path, equals(dir2.path));
      });
    });

    group('Directory Access - backupDirectory', () {
      test('should return default path when not set', () async {
        final dir = await service.backupDirectory;

        expect(dir.path, contains('zhidu'));
        expect(dir.path, contains('backups'));
      });

      test('should return custom path when set', () async {
        final customPath = p.join(testBaseDir.path, 'my_custom_backups');
        service.setBackupDirectory(customPath);

        final dir = await service.backupDirectory;
        expect(dir.path, equals(customPath));
      });

      test('should create directory if not exists', () async {
        final customPath = p.join(testBaseDir.path,
            'non_existent_backup_${DateTime.now().millisecondsSinceEpoch}');
        service.setBackupDirectory(customPath);

        final dir = await service.backupDirectory;
        expect(await dir.exists(), isTrue);
      });

      test('should create directory recursively', () async {
        final customPath =
            p.join(testBaseDir.path, 'nested', 'deep', 'backups');
        service.setBackupDirectory(customPath);

        final dir = await service.backupDirectory;
        expect(await dir.exists(), isTrue);
        expect(dir.path, equals(customPath));
      });

      test('should return same directory on multiple calls', () async {
        final dir1 = await service.backupDirectory;
        final dir2 = await service.backupDirectory;

        expect(dir1.path, equals(dir2.path));
      });
    });

    group('Path Management - setBooksDirectory', () {
      test('should update books directory', () async {
        final customPath = p.join(testBaseDir.path, 'new_books');
        service.setBooksDirectory(customPath);

        expect(service.isUsingCustomBooksDirectory, isTrue);
        final dir = await service.booksDirectory;
        expect(dir.path, equals(customPath));
      });

      test('should accept null to reset to default', () async {
        final customPath = p.join(testBaseDir.path, 'temp_books');
        service.setBooksDirectory(customPath);
        expect(service.isUsingCustomBooksDirectory, isTrue);

        service.setBooksDirectory(null);
        expect(service.isUsingCustomBooksDirectory, isFalse);

        final dir = await service.booksDirectory;
        expect(dir.path, isNot(contains('temp_books')));
        expect(dir.path, contains('books'));
      });

      test('should handle empty string path', () async {
        service.setBooksDirectory('');

        expect(service.isUsingCustomBooksDirectory, isTrue);
        // Empty string path will throw when trying to access directory
        // This documents the behavior that empty strings are treated as custom paths
        expect(() async => await service.booksDirectory,
            throwsA(isA<Exception>()));
      });
    });

    group('Path Management - setBackupDirectory', () {
      test('should update backup directory', () async {
        final customPath = p.join(testBaseDir.path, 'new_backups');
        service.setBackupDirectory(customPath);

        expect(service.isUsingCustomBackupDirectory, isTrue);
        final dir = await service.backupDirectory;
        expect(dir.path, equals(customPath));
      });

      test('should accept null to reset to default', () async {
        final customPath = p.join(testBaseDir.path, 'temp_backups');
        service.setBackupDirectory(customPath);
        expect(service.isUsingCustomBackupDirectory, isTrue);

        service.setBackupDirectory(null);
        expect(service.isUsingCustomBackupDirectory, isFalse);

        final dir = await service.backupDirectory;
        expect(dir.path, isNot(contains('temp_backups')));
        expect(dir.path, contains('backups'));
      });
    });

    group('Path Management - resetBooksDirectory', () {
      test('should revert to default path', () async {
        final customPath = p.join(testBaseDir.path, 'custom_books');
        service.setBooksDirectory(customPath);
        expect(service.isUsingCustomBooksDirectory, isTrue);

        service.resetBooksDirectory();
        expect(service.isUsingCustomBooksDirectory, isFalse);

        final dir = await service.booksDirectory;
        expect(dir.path, isNot(equals(customPath)));
        expect(dir.path, contains('books'));
      });

      test('should be safe to call when already using default', () {
        expect(service.isUsingCustomBooksDirectory, isFalse);

        service.resetBooksDirectory();

        expect(service.isUsingCustomBooksDirectory, isFalse);
      });

      test('should clear custom path', () async {
        final customPath = p.join(testBaseDir.path, 'custom_books');
        service.setBooksDirectory(customPath);
        final dir1 = await service.booksDirectory;
        expect(dir1.path, equals(customPath));

        service.resetBooksDirectory();
        final dir2 = await service.booksDirectory;
        expect(dir2.path, isNot(equals(customPath)));
      });
    });

    group('Path Management - resetBackupDirectory', () {
      test('should revert to default path', () async {
        final customPath = p.join(testBaseDir.path, 'custom_backups');
        service.setBackupDirectory(customPath);
        expect(service.isUsingCustomBackupDirectory, isTrue);

        service.resetBackupDirectory();
        expect(service.isUsingCustomBackupDirectory, isFalse);

        final dir = await service.backupDirectory;
        expect(dir.path, isNot(equals(customPath)));
        expect(dir.path, contains('backups'));
      });

      test('should be safe to call when already using default', () {
        expect(service.isUsingCustomBackupDirectory, isFalse);

        service.resetBackupDirectory();

        expect(service.isUsingCustomBackupDirectory, isFalse);
      });
    });

    group('Path String Getters - getBooksDirectoryPath', () {
      test('should return path as string', () async {
        final path = await service.getBooksDirectoryPath();

        expect(path, isA<String>());
        expect(path, isNotEmpty);
        expect(path, contains('books'));
      });

      test('should return custom path when set', () async {
        final customPath = p.join(testBaseDir.path, 'custom_books_path');
        service.setBooksDirectory(customPath);

        final path = await service.getBooksDirectoryPath();
        expect(path, equals(customPath));
      });
    });

    group('Path String Getters - getBackupDirectoryPath', () {
      test('should return path as string', () async {
        final path = await service.getBackupDirectoryPath();

        expect(path, isA<String>());
        expect(path, isNotEmpty);
        expect(path, contains('backups'));
      });

      test('should return custom path when set', () async {
        final customPath = p.join(testBaseDir.path, 'custom_backup_path');
        service.setBackupDirectory(customPath);

        final path = await service.getBackupDirectoryPath();
        expect(path, equals(customPath));
      });
    });

    group('Custom Path Checkers', () {
      test('isUsingCustomBooksDirectory returns false by default', () {
        expect(service.isUsingCustomBooksDirectory, isFalse);
      });

      test('isUsingCustomBooksDirectory returns true when set', () {
        service.setBooksDirectory(p.join(testBaseDir.path, 'custom'));
        expect(service.isUsingCustomBooksDirectory, isTrue);
      });

      test('isUsingCustomBackupDirectory returns false by default', () {
        expect(service.isUsingCustomBackupDirectory, isFalse);
      });

      test('isUsingCustomBackupDirectory returns true when set', () {
        service.setBackupDirectory(p.join(testBaseDir.path, 'custom'));
        expect(service.isUsingCustomBackupDirectory, isTrue);
      });
    });

    group('Default Path Getters', () {
      test('getDefaultBooksDirectoryPath returns default path', () async {
        final path = await service.getDefaultBooksDirectoryPath();

        expect(path, isA<String>());
        expect(path, contains('books'));
        expect(path, contains('zhidu'));
      });

      test('getDefaultBackupDirectoryPath returns default path', () async {
        final path = await service.getDefaultBackupDirectoryPath();

        expect(path, isA<String>());
        expect(path, contains('backups'));
        expect(path, contains('zhidu'));
      });

      test('default paths remain unchanged when custom path is set', () async {
        final defaultBooksPath = await service.getDefaultBooksDirectoryPath();
        final defaultBackupPath = await service.getDefaultBackupDirectoryPath();

        service.setBooksDirectory(p.join(testBaseDir.path, 'custom_books'));
        service.setBackupDirectory(p.join(testBaseDir.path, 'custom_backups'));

        // Default paths should remain the same
        expect(await service.getDefaultBooksDirectoryPath(),
            equals(defaultBooksPath));
        expect(await service.getDefaultBackupDirectoryPath(),
            equals(defaultBackupPath));
      });
    });

    group('Edge Cases - Non-existent Directories', () {
      test('should handle deeply nested non-existent path', () async {
        final customPath = p.join(
          testBaseDir.path,
          'level1',
          'level2',
          'level3',
          'level4',
          'books',
        );
        service.setBooksDirectory(customPath);

        final dir = await service.booksDirectory;
        expect(await dir.exists(), isTrue);
        expect(dir.path, equals(customPath));
      });

      test('should handle path with special characters', () async {
        final customPath = p.join(testBaseDir.path, 'books-test_123.456');
        service.setBooksDirectory(customPath);

        final dir = await service.booksDirectory;
        expect(await dir.exists(), isTrue);
        expect(dir.path, equals(customPath));
      });

      test('should handle path with spaces', () async {
        final customPath = p.join(testBaseDir.path, 'My Books Directory');
        service.setBooksDirectory(customPath);

        final dir = await service.booksDirectory;
        expect(await dir.exists(), isTrue);
        expect(dir.path, equals(customPath));
      });
    });

    group('Edge Cases - Directory State Changes', () {
      test('should handle directory deleted after being set', () async {
        final customPath = p.join(
            testBaseDir.path, 'temp_${DateTime.now().millisecondsSinceEpoch}');
        service.setBooksDirectory(customPath);

        // First access creates directory
        final dir1 = await service.booksDirectory;
        expect(await dir1.exists(), isTrue);

        // Delete the directory
        await dir1.delete(recursive: true);
        expect(await dir1.exists(), isFalse);

        // Second access should recreate directory
        final dir2 = await service.booksDirectory;
        expect(await dir2.exists(), isTrue);
      });

      test('should switch between custom and default paths', () async {
        final customPath = p.join(testBaseDir.path, 'switch_test');

        // Default
        final defaultDir = await service.booksDirectory;
        expect(service.isUsingCustomBooksDirectory, isFalse);

        // Custom
        service.setBooksDirectory(customPath);
        final customDir = await service.booksDirectory;
        expect(customDir.path, equals(customPath));

        // Back to default
        service.resetBooksDirectory();
        final backToDefault = await service.booksDirectory;
        expect(backToDefault.path, equals(defaultDir.path));
      });
    });

    group('Path Consistency', () {
      test('books and backups should have same base directory by default',
          () async {
        final booksDir = await service.booksDirectory;
        final backupDir = await service.backupDirectory;

        // Both should be under zhidu
        expect(booksDir.path, contains('zhidu'));
        expect(backupDir.path, contains('zhidu'));

        // Extract base directory (parent of books/backups)
        final booksParent = p.dirname(booksDir.path);
        final backupParent = p.dirname(backupDir.path);
        expect(booksParent, equals(backupParent));
      });

      test('custom paths can be completely independent', () async {
        final customBooks = p.join(testBaseDir.path, 'mybooks');
        final customBackups = p.join(testBaseDir.path, 'mybackups');

        service.setBooksDirectory(customBooks);
        service.setBackupDirectory(customBackups);

        final booksDir = await service.booksDirectory;
        final backupDir = await service.backupDirectory;

        expect(booksDir.path, equals(customBooks));
        expect(backupDir.path, equals(customBackups));
        expect(booksDir.path, isNot(equals(backupDir.path)));
      });
    });

    group('Concurrent Access', () {
      test('should handle concurrent directory access', () async {
        final futures = List.generate(
          10,
          (_) => service.booksDirectory,
        );

        final dirs = await Future.wait(futures);

        // All should return the same path
        final firstPath = dirs.first.path;
        for (final dir in dirs) {
          expect(dir.path, equals(firstPath));
        }
      });

      test('should handle rapid setting and getting', () async {
        final paths = <String>[];

        for (var i = 0; i < 5; i++) {
          final customPath = p.join(testBaseDir.path, 'rapid_$i');
          service.setBooksDirectory(customPath);
          final dir = await service.booksDirectory;
          paths.add(dir.path);
        }

        // Last path should be the final custom path
        expect(paths.last, equals(p.join(testBaseDir.path, 'rapid_4')));
      });
    });
  });
}
