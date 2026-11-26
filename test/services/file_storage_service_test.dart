import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/services/file_storage_service.dart';

void main() {
  late FileStorageService service;
  late Directory testDir;
  late Directory contentDir;

  setUpAll(() async {
    testDir = Directory('${Directory.systemTemp.path}/zhidu_file_storage_test');
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    await testDir.create(recursive: true);
  });

  setUp(() async {
    service = FileStorageService();
    contentDir = Directory(
        '${testDir.path}/content_${DateTime.now().millisecondsSinceEpoch}');
    await contentDir.create(recursive: true);
  });

  tearDown(() async {
    if (await contentDir.exists()) {
      await contentDir.delete(recursive: true);
    }
  });

  tearDownAll(() async {
    final baseTestDir =
        Directory('${Directory.systemTemp.path}/zhidu_file_storage_test');
    if (await baseTestDir.exists()) {
      await baseTestDir.delete(recursive: true);
    }
  });

  group('FileStorageService', () {
    group('singleton', () {
      test('should return same instance', () {
        final instance1 = FileStorageService();
        final instance2 = FileStorageService();

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('readJson', () {
      test('should read valid JSON file', () async {
        final filePath = '${contentDir.path}/test.json';
        final testData = {
          'name': 'test',
          'value': 123,
          'nested': {'key': 'value'}
        };
        await File(filePath).writeAsString(jsonEncode(testData));

        final result = await service.readJson(filePath);

        expect(result, isNotNull);
        expect(result!['name'], 'test');
        expect(result['value'], 123);
        expect(result['nested']['key'], 'value');
      });

      test('should return null for non-existent file', () async {
        final result =
            await service.readJson('${contentDir.path}/non_existent.json');

        expect(result, isNull);
      });

      test('should return null for invalid JSON', () async {
        final filePath = '${contentDir.path}/invalid.json';
        await File(filePath).writeAsString('not a valid json');

        final result = await service.readJson(filePath);

        expect(result, isNull);
      });

      test('should return null for JSON that is not an object', () async {
        final filePath = '${contentDir.path}/array.json';
        await File(filePath).writeAsString('[1, 2, 3]');

        final result = await service.readJson(filePath);

        expect(result, isNull);
      });

      test('should handle empty file', () async {
        final filePath = '${contentDir.path}/empty.json';
        await File(filePath).writeAsString('');

        final result = await service.readJson(filePath);

        expect(result, isNull);
      });

      test('should handle file with whitespace', () async {
        final filePath = '${contentDir.path}/whitespace.json';
        await File(filePath).writeAsString('  {"key": "value"}  ');

        final result = await service.readJson(filePath);

        expect(result, isNotNull);
        expect(result!['key'], 'value');
      });

      test('should handle unicode content', () async {
        final filePath = '${contentDir.path}/unicode.json';
        final testData = {'中文': '测试', 'emoji': '📚', 'japanese': 'テスト'};
        await File(filePath).writeAsString(jsonEncode(testData));

        final result = await service.readJson(filePath);

        expect(result, isNotNull);
        expect(result!['中文'], '测试');
        expect(result['emoji'], '📚');
        expect(result['japanese'], 'テスト');
      });
    });

    group('writeJson', () {
      test('should write JSON file successfully', () async {
        final filePath = '${contentDir.path}/write_test.json';
        final testData = {'name': 'write_test', 'value': 456};

        final result = await service.writeJson(filePath, testData);

        expect(result, isTrue);
        expect(await File(filePath).exists(), isTrue);

        final content = await File(filePath).readAsString();
        final decoded = jsonDecode(content);
        expect(decoded['name'], 'write_test');
        expect(decoded['value'], 456);
      });

      test('should create parent directory if not exists', () async {
        final filePath = '${contentDir.path}/deep/nested/dir/test.json';
        final testData = {'key': 'value'};

        final result = await service.writeJson(filePath, testData);

        expect(result, isTrue);
        expect(await File(filePath).exists(), isTrue);
      });

      test('should format JSON with 2-space indent', () async {
        final filePath = '${contentDir.path}/formatted.json';
        final testData = {
          'a': 1,
          'b': {'c': 2}
        };

        await service.writeJson(filePath, testData);

        final content = await File(filePath).readAsString();
        expect(content, contains('  "a"'));
        expect(content, contains('  "b"'));
      });

      test('should overwrite existing file', () async {
        final filePath = '${contentDir.path}/overwrite.json';
        await File(filePath).writeAsString('{"old": "data"}');

        final result = await service.writeJson(filePath, {'new': 'data'});

        expect(result, isTrue);
        final content = await File(filePath).readAsString();
        final decoded = jsonDecode(content);
        expect(decoded['new'], 'data');
        expect(decoded.containsKey('old'), isFalse);
      });

      test('should handle empty map', () async {
        final filePath = '${contentDir.path}/empty.json';

        final result = await service.writeJson(filePath, {});

        expect(result, isTrue);
        final content = await File(filePath).readAsString();
        expect(content, '{}');
      });

      test('should handle complex nested data', () async {
        final filePath = '${contentDir.path}/complex.json';
        final testData = {
          'level1': {
            'level2': {
              'level3': ['a', 'b', 'c'],
            },
          },
          'numbers': [1, 2, 3],
          'booleans': [true, false],
        };

        final result = await service.writeJson(filePath, testData);

        expect(result, isTrue);
        final decoded = jsonDecode(await File(filePath).readAsString());
        expect(decoded['level1']['level2']['level3'], ['a', 'b', 'c']);
      });
    });

    group('readText', () {
      test('should read text file successfully', () async {
        final filePath = '${contentDir.path}/test.txt';
        const content = 'Hello, World!';
        await File(filePath).writeAsString(content);

        final result = await service.readText(filePath);

        expect(result, content);
      });

      test('should return null for non-existent file', () async {
        final result =
            await service.readText('${contentDir.path}/not_exist.txt');

        expect(result, isNull);
      });

      test('should read markdown file', () async {
        final filePath = '${contentDir.path}/test.md';
        const content = '''# Title

## Section 1
Content here.

- Item 1
- Item 2
''';
        await File(filePath).writeAsString(content);

        final result = await service.readText(filePath);

        expect(result, content);
      });

      test('should handle unicode content', () async {
        final filePath = '${contentDir.path}/unicode.txt';
        const content = '中文测试 📚 日本語テスト';
        await File(filePath).writeAsString(content);

        final result = await service.readText(filePath);

        expect(result, content);
      });

      test('should read empty file', () async {
        final filePath = '${contentDir.path}/empty.txt';
        await File(filePath).writeAsString('');

        final result = await service.readText(filePath);

        expect(result, '');
      });

      test('should read large file', () async {
        final filePath = '${contentDir.path}/large.txt';
        final content = 'Line\n' * 10000;
        await File(filePath).writeAsString(content);

        final result = await service.readText(filePath);

        expect(result, content);
      });
    });

    group('writeText', () {
      test('should write text file successfully', () async {
        final filePath = '${contentDir.path}/write_text.txt';
        const content = 'Test content';

        final result = await service.writeText(filePath, content);

        expect(result, isTrue);
        expect(await File(filePath).readAsString(), content);
      });

      test('should create parent directory if not exists', () async {
        final filePath = '${contentDir.path}/deep/nested/text.txt';
        const content = 'nested content';

        final result = await service.writeText(filePath, content);

        expect(result, isTrue);
        expect(await File(filePath).exists(), isTrue);
      });

      test('should overwrite existing file', () async {
        final filePath = '${contentDir.path}/overwrite.txt';
        await File(filePath).writeAsString('old content');

        final result = await service.writeText(filePath, 'new content');

        expect(result, isTrue);
        expect(await File(filePath).readAsString(), 'new content');
      });

      test('should handle empty content', () async {
        final filePath = '${contentDir.path}/empty.txt';

        final result = await service.writeText(filePath, '');

        expect(result, isTrue);
        expect(await File(filePath).readAsString(), '');
      });

      test('should handle markdown content', () async {
        final filePath = '${contentDir.path}/test.md';
        const content = '''# Chapter 1

## Summary
This is a summary.

## Key Points
- Point 1
- Point 2
''';

        final result = await service.writeText(filePath, content);

        expect(result, isTrue);
        expect(await File(filePath).readAsString(), content);
      });
    });

    group('deleteFile', () {
      test('should delete existing file', () async {
        final filePath = '${contentDir.path}/to_delete.txt';
        await File(filePath).writeAsString('content');
        expect(await File(filePath).exists(), isTrue);

        final result = await service.deleteFile(filePath);

        expect(result, isTrue);
        expect(await File(filePath).exists(), isFalse);
      });

      test('should return true for non-existent file', () async {
        final result =
            await service.deleteFile('${contentDir.path}/not_exist.txt');

        expect(result, isTrue);
      });

      test('should delete file in nested directory', () async {
        final filePath = '${contentDir.path}/nested/deep/file.txt';
        await File(filePath).create(recursive: true);
        await File(filePath).writeAsString('nested');

        final result = await service.deleteFile(filePath);

        expect(result, isTrue);
        expect(await File(filePath).exists(), isFalse);
      });
    });

    group('deleteDirectory', () {
      test('should delete existing directory with contents', () async {
        final dirPath = '${contentDir.path}/dir_to_delete';
        await Directory(dirPath).create(recursive: true);
        await File('$dirPath/file1.txt').writeAsString('content1');
        await File('$dirPath/file2.txt').writeAsString('content2');
        await Directory('$dirPath/subdir').create();
        await File('$dirPath/subdir/file3.txt').writeAsString('content3');

        final result = await service.deleteDirectory(dirPath);

        expect(result, isTrue);
        expect(await Directory(dirPath).exists(), isFalse);
      });

      test('should return true for non-existent directory', () async {
        final result =
            await service.deleteDirectory('${contentDir.path}/not_exist_dir');

        expect(result, isTrue);
      });

      test('should delete empty directory', () async {
        final dirPath = '${contentDir.path}/empty_dir';
        await Directory(dirPath).create();

        final result = await service.deleteDirectory(dirPath);

        expect(result, isTrue);
        expect(await Directory(dirPath).exists(), isFalse);
      });

      test('should delete deeply nested directory', () async {
        final dirPath = '${contentDir.path}/deep/nested/dir';
        await Directory(dirPath).create(recursive: true);
        await File('$dirPath/file.txt').writeAsString('content');

        final result = await service.deleteDirectory('${contentDir.path}/deep');

        expect(result, isTrue);
        expect(await Directory('${contentDir.path}/deep').exists(), isFalse);
      });
    });

    group('listFiles', () {
      test('should list all files in directory', () async {
        await File('${contentDir.path}/file1.txt').writeAsString('content1');
        await File('${contentDir.path}/file2.json')
            .writeAsString('{"key":"value"}');
        await File('${contentDir.path}/file3.md').writeAsString('# title');

        final result = await service.listFiles(contentDir.path);

        expect(result.length, 3);
        expect(result.any((f) => f.path.endsWith('file1.txt')), isTrue);
        expect(result.any((f) => f.path.endsWith('file2.json')), isTrue);
        expect(result.any((f) => f.path.endsWith('file3.md')), isTrue);
      });

      test('should filter files by extension', () async {
        await File('${contentDir.path}/file1.md').writeAsString('content1');
        await File('${contentDir.path}/file2.md').writeAsString('content2');
        await File('${contentDir.path}/file3.txt').writeAsString('content3');

        final result =
            await service.listFiles(contentDir.path, extension: '.md');

        expect(result.length, 2);
        expect(result.every((f) => f.path.endsWith('.md')), isTrue);
      });

      test('should return empty list for non-existent directory', () async {
        final result = await service.listFiles('${contentDir.path}/not_exist');

        expect(result, isEmpty);
      });

      test('should return empty list for empty directory', () async {
        final emptyDirPath = '${contentDir.path}/empty';
        await Directory(emptyDirPath).create();

        final result = await service.listFiles(emptyDirPath);

        expect(result, isEmpty);
      });

      test('should not include directories', () async {
        await File('${contentDir.path}/file.txt').writeAsString('content');
        await Directory('${contentDir.path}/subdir').create();

        final result = await service.listFiles(contentDir.path);

        expect(result.length, 1);
        expect(result.first.path.endsWith('file.txt'), isTrue);
      });

      test('should be case-sensitive for extension', () async {
        await File('${contentDir.path}/lower.md').writeAsString('content');
        await File('${contentDir.path}/upper.MD').writeAsString('content');

        final mdResult =
            await service.listFiles(contentDir.path, extension: '.md');
        final upperMdResult =
            await service.listFiles(contentDir.path, extension: '.MD');

        expect(mdResult.length, 1);
        expect(mdResult.first.path.endsWith('lower.md'), isTrue);
        expect(upperMdResult.length, 1);
        expect(upperMdResult.first.path.endsWith('upper.MD'), isTrue);
      });

      test('should not list files in subdirectories', () async {
        await File('${contentDir.path}/root.txt').writeAsString('root');
        await Directory('${contentDir.path}/subdir').create();
        await File('${contentDir.path}/subdir/nested.txt')
            .writeAsString('nested');

        final result = await service.listFiles(contentDir.path);

        expect(result.length, 1);
        expect(result.first.path.endsWith('root.txt'), isTrue);
      });
    });
  });
}
