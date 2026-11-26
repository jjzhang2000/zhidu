import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/services/parsers/epub_parser.dart';

void main() {
  group('EpubParser', () {
    late EpubParser parser;
    late String testFilePath;
    late String nonExistentPath;

    setUpAll(() {
      parser = EpubParser();
      testFilePath = 'test/fixtures/test_book.epub';
      nonExistentPath = '/non/existent/path/book.epub';
    });

    group('getChapters', () {
      test('returns empty list when file does not exist', () async {
        final chapters = await parser.getChapters(nonExistentPath);
        expect(chapters, isEmpty);
      });

      test('returns chapters with valid structure', () async {
        final chapters = await parser.getChapters(testFilePath);
        for (final chapter in chapters) {
          expect(chapter.title, isNotEmpty);
          expect(chapter.location, isNotNull);
          expect(chapter.level, isNonNegative);
        }
      });

      test('top-level chapters have sequential indices', () async {
        final chapters = await parser.getChapters(testFilePath);
        final topLevelChapters = chapters.where((c) => c.level == 0).toList();

        for (int i = 0; i < topLevelChapters.length; i++) {
          expect(topLevelChapters[i].index, equals(i));
        }
      });

      test('sub-chapters have index -1', () async {
        final chapters = await parser.getChapters(testFilePath);
        final subChapters = chapters.where((c) => c.level > 0).toList();

        for (final chapter in subChapters) {
          expect(chapter.index, equals(-1));
        }
      });
    });

    group('getChapterContent', () {
      test('throws Exception when file does not exist', () async {
        final chapter = Chapter(
          bookId: 'test',
          index: 0,
          title: 'Test Chapter',
          location: ChapterLocation(href: 'chapter1.xhtml'),
        );

        expect(
          () => parser.getChapterContent(nonExistentPath, chapter),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('EPUB file not found'),
          )),
        );
      });

      test('returns empty content when chapter has no href', () async {
        final chapter = Chapter(
          bookId: 'test',
          index: 0,
          title: 'Test Chapter',
          location: ChapterLocation(href: null),
        );

        final content = await parser.getChapterContent(testFilePath, chapter);
        expect(content.htmlContent, isNull);
      });

      test('returns empty content when href is empty string', () async {
        final chapter = Chapter(
          bookId: 'test',
          index: 0,
          title: 'Test Chapter',
          location: ChapterLocation(href: ''),
        );

        final content = await parser.getChapterContent(testFilePath, chapter);
        expect(content.htmlContent, isNull);
      });

      test('returns content when chapter has valid href', () async {
        final chapter = Chapter(
          bookId: 'test',
          index: 0,
          title: 'Test',
          location: ChapterLocation(href: 'OEBPS/chapter1.xhtml'),
        );

        final content = await parser.getChapterContent(testFilePath, chapter);
        expect(content.htmlContent, isNotEmpty);
      });
    });

    group('getOpeningContent', () {
      test('merges front matter pages before first chapter', () async {
        final path = _buildOpeningEpub();
        addTearDown(() {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        });

        final content = await parser.getOpeningContent(path);

        expect(content, isNotNull);
        // 封面页（spine 首文件）在返回内容中
        expect(content!.html, contains('COVER_PAGE'));
        // 第一章节正文不在开头内容中
        expect(content.html, isNot(contains('CHAPTER_ONE_BODY')));
      });

      test('falls back to first spine file when no front matter', () async {
        final content = await parser.getOpeningContent(testFilePath);

        expect(content, isNotNull);
        expect(content!.html, isNotEmpty);
      });
    });

  });
}

/// 构造一个含前置页（封面 titlepage）的临时 EPUB，返回其文件路径。
///
/// spine 顺序为 titlepage → chapter1，toc.ncx 只含 chapter1，因此
/// [EpubParser.getOpeningContent] 应只返回 titlepage（封面），不含 chapter1。
String _buildOpeningEpub() {
  final archive = Archive()
    ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'))
    ..addFile(ArchiveFile.string(
      'META-INF/container.xml',
      '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
    ))
    ..addFile(ArchiveFile.string(
      'OEBPS/content.opf',
      '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Test</dc:title>
    <dc:identifier id="uid">test-opening-id</dc:identifier>
  </metadata>
  <manifest>
    <item href="titlepage.xhtml" id="title" media-type="application/xhtml+xml"/>
    <item href="chapter1.xhtml" id="c1" media-type="application/xhtml+xml"/>
    <item href="toc.ncx" id="ncx" media-type="application/x-dtbncx+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="title"/>
    <itemref idref="c1"/>
  </spine>
</package>''',
    ))
    ..addFile(ArchiveFile.string(
      'OEBPS/toc.ncx',
      '''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="test-opening-id"/></head>
  <docTitle><text>Test</text></docTitle>
  <navMap>
    <navPoint id="n1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''',
    ))
    ..addFile(ArchiveFile.string(
      'OEBPS/titlepage.xhtml',
      '<html><head><title>Title</title></head><body><p>COVER_PAGE</p></body></html>',
    ))
    ..addFile(ArchiveFile.string(
      'OEBPS/chapter1.xhtml',
      '<html><head><title>Chapter</title></head><body><p>CHAPTER_ONE_BODY</p></body></html>',
    ));

  final bytes = ZipEncoder().encode(archive);
  final file = File('${Directory.systemTemp.path}/test_opening.epub');
  file.writeAsBytesSync(Uint8List.fromList(bytes));
  return file.path;
}
