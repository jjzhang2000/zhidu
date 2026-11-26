import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/services/summary_service.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/services/storage_config.dart';
import 'package:path/path.dart' as p;

void main() {
  group('SummaryService', () {
    late SummaryService service;
    late Directory testDir;
    late String testBookId;

    setUpAll(() async {
      testDir = await Directory.systemTemp.createTemp('summary_test_');
    });

    setUp(() async {
      service = SummaryService();
      testBookId = 'test-book-${DateTime.now().millisecondsSinceEpoch}';

      StorageConfig.resetForTest();
      StorageConfig.setTestBaseDirectory(testDir);

      final bookDir =
          Directory(p.join(testDir.path, 'zhidu', 'books', testBookId));
      if (!await bookDir.exists()) {
        await bookDir.create(recursive: true);
      }
    });

    tearDown(() {
      StorageConfig.resetForTest();
    });

    tearDownAll(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    group('stripHtml', () {
      test('removes HTML tags', () {
        expect(service.stripHtml('<p>Hello</p>'), 'Hello');
      });

      test('decodes common HTML entities', () {
        expect(
          service.stripHtml('<p>a&nbsp;b &lt;c&gt; &amp; d</p>'),
          'a b <c> & d',
        );
      });
    });

    group('shouldAbbreviate', () {
      test('returns false for short content', () {
        expect(service.shouldAbbreviate('短内容'), isFalse);
      });

      test('returns true for content exceeding one page (2000 bytes)', () {
        final long = '字' * 700; // 700 个汉字约 2100 字节
        expect(service.shouldAbbreviate(long), isTrue);
      });
    });

    group('saveChapterAbbreviation', () {
      test('saves chapter abbreviation to file', () async {
        final chapter = Chapter(
          bookId: testBookId,
          index: 0,
          title: 'Chapter 1',
          location: ChapterLocation(),
          abbreviation: 'Test abbreviation content.',
        );

        await service.saveChapterAbbreviation(chapter);

        final filePath =
            await StorageConfig.getChapterAbbreviationPath(testBookId, 0);
        final file = File(filePath);
        expect(await file.exists(), isTrue);
        final content = await file.readAsString();
        expect(content, 'Test abbreviation content.');
      });

      test('saves multiple chapter abbreviations', () async {
        for (int i = 0; i < 3; i++) {
          final chapter = Chapter(
            bookId: testBookId,
            index: i,
            title: 'Chapter $i',
            location: ChapterLocation(),
            abbreviation: 'Abbreviation for chapter $i',
          );
          await service.saveChapterAbbreviation(chapter);
        }

        final file0 = File(
            await StorageConfig.getChapterAbbreviationPath(testBookId, 0));
        final file1 = File(
            await StorageConfig.getChapterAbbreviationPath(testBookId, 1));
        final file2 = File(
            await StorageConfig.getChapterAbbreviationPath(testBookId, 2));

        expect(await file0.exists(), isTrue);
        expect(await file1.exists(), isTrue);
        expect(await file2.exists(), isTrue);
        expect(await file0.readAsString(), 'Abbreviation for chapter 0');
        expect(await file1.readAsString(), 'Abbreviation for chapter 1');
        expect(await file2.readAsString(), 'Abbreviation for chapter 2');
      });
    });

    group('getChapterAbbreviation', () {
      test('returns null when abbreviation does not exist', () async {
        final result = await service.getChapterAbbreviation(testBookId, 0);
        expect(result, isNull);
      });

      test('returns saved abbreviation', () async {
        final chapter = Chapter(
          bookId: testBookId,
          index: 0,
          title: '',
          location: ChapterLocation(),
          abbreviation: 'Test content for retrieval.',
        );
        await service.saveChapterAbbreviation(chapter);

        final result = await service.getChapterAbbreviation(testBookId, 0);
        expect(result, isNotNull);
        expect(result!.abbreviation, 'Test content for retrieval.');
        expect(result.bookId, testBookId);
        expect(result.index, 0);
      });
    });
  });
}
