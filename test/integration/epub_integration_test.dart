import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/services/parsers/epub_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EPUB Integration Tests', () {
    final EpubParser parser = EpubParser();

    group('getChapters - Vibe Coding book (single-level structure)', () {
      final epubPath =
          'test/Vibe Coding AI Bian Cheng Wan Q - Tan Xing Xing.epub';
      late List<Chapter> chapters;

      setUpAll(() async {
        chapters = await parser.getChapters(epubPath);
      });

      test('returns non-empty chapter list', () {
        expect(chapters, isNotEmpty);
      });

      test('all chapters have valid titles', () {
        for (final chapter in chapters) {
          expect(chapter.title, isNotEmpty);
        }
      });

      test('all chapters have level 0 (flat structure)', () {
        for (final chapter in chapters) {
          expect(chapter.level, equals(0),
              reason: 'Chapter "${chapter.title}" should have level 0');
        }
      });

      test('top-level chapters have sequential index', () {
        final topLevelChapters = chapters.where((c) => c.level == 0).toList();
        for (var i = 0; i < topLevelChapters.length; i++) {
          expect(topLevelChapters[i].index, equals(i),
              reason: 'Top-level chapter at position $i should have index $i');
        }
      });

      test('chapters have valid href locations', () {
        for (final chapter in chapters) {
          expect(chapter.location.href, isNotNull);
          expect(chapter.location.href, isNotEmpty);
        }
      });
    });

    group('getChapters - Java to Kotlin book (multi-level structure)', () {
      final epubPath =
          'test/fixtures/test_book.epub';
      late List<Chapter> chapters;

      setUpAll(() async {
        chapters = await parser.getChapters(epubPath);
      });

      test('returns non-empty chapter list', () {
        expect(chapters, isNotEmpty);
      });

      test('all chapters have valid titles', () {
        for (final chapter in chapters) {
          expect(chapter.title, isNotEmpty);
        }
      });

      test('has multi-level structure (chapters with level > 0)', () {
        final hasSubChapters = chapters.any((c) => c.level > 0);
        expect(hasSubChapters, isTrue,
            reason: 'Multi-level book should have sub-chapters (level > 0)');
      });

      test('has both level 0 and level > 0 chapters', () {
        final hasTopLevel = chapters.any((c) => c.level == 0);
        final hasSubLevel = chapters.any((c) => c.level > 0);

        expect(hasTopLevel, isTrue, reason: 'Should have top-level chapters');
        expect(hasSubLevel, isTrue, reason: 'Should have sub-chapters');
      });

      test('only top-level chapters have valid index (sub-chapters have -1)',
          () {
        for (final chapter in chapters) {
          if (chapter.level == 0) {
            expect(chapter.index, greaterThanOrEqualTo(0),
                reason:
                    'Top-level chapter "${chapter.title}" should have non-negative index');
          } else {
            expect(chapter.index, equals(-1),
                reason:
                    'Sub-chapter "${chapter.title}" (level ${chapter.level}) should have index -1');
          }
        }
      });

      test('top-level chapter indexes are sequential', () {
        final topLevelChapters = chapters.where((c) => c.level == 0).toList();
        for (var i = 0; i < topLevelChapters.length; i++) {
          expect(topLevelChapters[i].index, equals(i),
              reason: 'Top-level chapter at position $i should have index $i');
        }
      });

      test('chapters have valid href locations', () {
        for (final chapter in chapters) {
          expect(chapter.location.href, isNotNull);
          expect(chapter.location.href, isNotEmpty);
        }
      });
    });

    group('getChapterContent - Vibe Coding book', () {
      final epubPath =
          'test/Vibe Coding AI Bian Cheng Wan Q - Tan Xing Xing.epub';
      late List<Chapter> chapters;

      setUpAll(() async {
        chapters = await parser.getChapters(epubPath);
      });

      test('extracts content from first chapter', () async {
        final firstChapter = chapters.firstWhere((c) => c.index == 0);
        final content = await parser.getChapterContent(epubPath, firstChapter);

        expect(content.htmlContent, isNotEmpty);
      });

      test('extracts HTML content', () async {
        final firstChapter = chapters.firstWhere((c) => c.index == 0);
        final content = await parser.getChapterContent(epubPath, firstChapter);

        expect(content.htmlContent, isNotNull);
        expect(content.htmlContent, isNotEmpty);
      });

      test('HTML content contains HTML tags', () async {
        final firstChapter = chapters.firstWhere((c) => c.index == 0);
        final content = await parser.getChapterContent(epubPath, firstChapter);

        expect(content.htmlContent, contains('<'));
        expect(content.htmlContent, contains('>'));
      });

      test('extracts content from multiple chapters', () async {
        final testChapters =
            chapters.where((c) => c.index >= 0).take(3).toList();

        for (final chapter in testChapters) {
          final content = await parser.getChapterContent(epubPath, chapter);
          expect(content.htmlContent!.length, greaterThan(0),
              reason: 'Chapter "${chapter.title}" should have content');
        }
      });
    });

    group('getChapterContent - Java to Kotlin book', () {
      final epubPath =
          'test/fixtures/test_book.epub';
      late List<Chapter> chapters;

      setUpAll(() async {
        chapters = await parser.getChapters(epubPath);
      });

      test('extracts content from first top-level chapter', () async {
        final firstTopChapter = chapters.firstWhere((c) => c.index == 0);
        final content =
            await parser.getChapterContent(epubPath, firstTopChapter);

        expect(content.htmlContent, isNotEmpty);
      });

      test('extracts HTML content', () async {
        final firstTopChapter = chapters.firstWhere((c) => c.index == 0);
        final content =
            await parser.getChapterContent(epubPath, firstTopChapter);

        expect(content.htmlContent, isNotNull);
        expect(content.htmlContent, isNotEmpty);
      });
    });

    group('getChapterContentMerged - image inlining', () {
      final epubPath =
          'test/Vibe Coding AI Bian Cheng Wan Q - Tan Xing Xing.epub';
      late List<Chapter> chapters;

      setUpAll(() async {
        chapters = await parser.getChapters(epubPath);
      });

      test('inlines images as base64 data URIs (no relative src left)',
          () async {
        final topLevel = chapters.where((c) => c.level == 0).toList();
        for (final chapter in topLevel) {
          final merged =
              await parser.getChapterContentMerged(epubPath, chapter, chapters);
          if (merged == null) continue;

          final hasRelativeSrc = RegExp(
            r'<img[^>]*\ssrc="(?!data:)[^"]*"',
            caseSensitive: false,
          ).hasMatch(merged.html);

          expect(hasRelativeSrc, isFalse,
              reason: '章节 "${chapter.title}" 的图片应内联为 data URI');
        }
      });

      test('inlines URL-encoded image path (space %20)', () async {
        final preface = chapters.firstWhere(
            (c) => c.level == 0 && c.title == '前言');
        final merged =
            await parser.getChapterContentMerged(epubPath, preface, chapters);

        expect(merged, isNotNull);
        expect(merged!.html, contains('data:image/jpeg;base64,'));
      });
    });

    group('getOpeningContent - first page', () {
      final epubPath =
          'test/Vibe Coding AI Bian Cheng Wan Q - Tan Xing Xing.epub';

      test('returns first spine document (cover) as inline image', () async {
        final opening = await parser.getOpeningContent(epubPath);

        expect(opening, isNotNull);
        expect(opening!.html, isNotEmpty);
        // 封面页（titlepage.xhtml）为 SVG 包裹的 cover.jpg，应转为可渲染的 <img> data URI
        expect(opening.html, contains('data:image/jpeg;base64,'));
      });
    });

    group('extractCover - Real EPUB files', () {
      test('extracts cover bytes from Vibe Coding book (no file saving)',
          () async {
        final epubPath =
            'test/Vibe Coding AI Bian Cheng Wan Q - Tan Xing Xing.epub';
        final file = File(epubPath);
        final bytes = await file.readAsBytes();

        final archive = ZipDecoder().decodeBytes(bytes);
        final hasCover = archive.files.any((f) =>
            f.name.toLowerCase().contains('cover') &&
            (f.name.toLowerCase().endsWith('.jpg') ||
                f.name.toLowerCase().endsWith('.png')));

        expect(hasCover, isTrue, reason: 'EPUB should contain cover image');
      });

    });

    group('Hierarchy structure verification', () {
      test('Vibe Coding: verifies single-level structure', () async {
        final epubPath =
            'test/Vibe Coding AI Bian Cheng Wan Q - Tan Xing Xing.epub';
        final chapters = await parser.getChapters(epubPath);

        final levels = chapters.map((c) => c.level).toSet();
        expect(levels, equals({0}),
            reason: 'Single-level book should only have level 0 chapters');

        final topLevelCount = chapters.where((c) => c.level == 0).length;
        expect(topLevelCount, equals(chapters.length),
            reason: 'All chapters should be top-level in single-level book');
      });

      test('Java to Kotlin: verifies multi-level structure', () async {
        final epubPath =
            'test/fixtures/test_book.epub';
        final chapters = await parser.getChapters(epubPath);

        final levels = chapters.map((c) => c.level).toSet();
        expect(levels.length, greaterThan(1),
            reason: 'Multi-level book should have more than one level');

        expect(levels.contains(0), isTrue,
            reason:
                'Multi-level book should have top-level chapters (level 0)');

        final topLevelCount = chapters.where((c) => c.level == 0).length;
        final subLevelCount = chapters.where((c) => c.level > 0).length;

        expect(topLevelCount, greaterThan(0),
            reason: 'Should have at least one top-level chapter');
        expect(subLevelCount, greaterThan(0),
            reason: 'Should have at least one sub-chapter');
      });

      test('index assignment is correct for both books', () async {
        final singleLevelPath =
            'test/Vibe Coding AI Bian Cheng Wan Q - Tan Xing Xing.epub';
        final multiLevelPath =
            'test/fixtures/test_book.epub';

        final singleLevelChapters = await parser.getChapters(singleLevelPath);
        final multiLevelChapters = await parser.getChapters(multiLevelPath);

        for (final chapter in singleLevelChapters) {
          expect(chapter.index, greaterThanOrEqualTo(0),
              reason:
                  'Single-level chapter "${chapter.title}" should have non-negative index');
        }

        final multiTopLevels =
            multiLevelChapters.where((c) => c.level == 0).toList();
        for (var i = 0; i < multiTopLevels.length; i++) {
          expect(multiTopLevels[i].index, equals(i),
              reason: 'Top-level chapter should have sequential index');
        }

        final subChapters =
            multiLevelChapters.where((c) => c.level > 0).toList();
        for (final subChapter in subChapters) {
          expect(subChapter.index, equals(-1),
              reason: 'Sub-chapter "${subChapter.title}" should have index -1');
        }
      });
    });
  });
}
