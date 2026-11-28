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

    test('getReaderTypography 读取书籍 CSS 中的原始排版', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.string(
          'OEBPS/style.css',
          'body { font-size: 1em; line-height: 1.5; } '
              'p { margin: 0 0 1em; }',
        ));
      final bytes = ZipEncoder().encode(archive);
      final file = File('${Directory.systemTemp.path}/test_typography.epub');
      file.writeAsBytesSync(Uint8List.fromList(bytes));
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      final typography = await parser.getReaderTypography(file.path);

      expect(typography, isNotNull);
      // 相对字号 1em 以应用默认 21px 为基准
      expect(typography!.fontSize, closeTo(21.0, 0.01));
      expect(typography.lineHeight, closeTo(1.5, 0.01));
      // margin-bottom: 1em → 段距系数 1.0
      expect(typography.paragraphSpacing, closeTo(1.0, 0.01));
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

    group('getChapterContentMerged', () {
      test('按锚点提取时保留完整起始标签（不把 <a> 渲染成源码文本）', () async {
        final path = _buildAnchoredTocEpub();
        addTearDown(() {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        });

        final chapters = await parser.getChapters(path);
        expect(chapters, isNotEmpty);
        // 目录里的图片链接（封面）被注入为独立章节，因此目录章节不再固定为首项
        final tocChapter = chapters.firstWhere(
            (c) => (c.location.href ?? '').contains('#toc1'));
        expect(tocChapter.title, '目录');

        final content = await parser.getChapterContentMerged(
            path, tocChapter, chapters);

        expect(content, isNotNull);
        // 锚点元素是 <a id="toc1">，片段必须从 '<' 开始，保留完整标签
        expect(content!.html, contains('<a href="Image00000.jpg"'));
        expect(content.html, contains('封面'));
        // 不能出现被吞掉 '<' 的源码文本（如 `a href=...&gt;封面`）
        expect(content.html, isNot(contains('&gt;封面')));
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

      test('无真正前置页时返回 null（避免与第一章重复）', () async {
        // 该 EPUB 的第一个内容文档即第一个章节，若仍作为开头页返回，
        // 阅读时「开头页末页」与「第一章首页」会是同一份内容的重复。
        final content = await parser.getOpeningContent(testFilePath);

        expect(content, isNull);
      });

      test('目录首项为图片（封面被注入为首章节）时仍返回 null', () async {
        // 回归：图片章节 href 为图片文件而非 spine 文档，若把它当作「首章节」
        // 界定前置页，会导致所有 spine 文档都被当成开头页（整本书重复一遍）。
        final path = _buildAnchoredTocEpub();
        addTearDown(() {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        });

        final chapters = await parser.getChapters(path);
        expect(chapters.first.title, '封面');
        expect(chapters.where((c) => c.title == '封面').length, 1,
            reason: '封面只应作为独立章节出现一次');

        expect(await parser.getOpeningContent(path), isNull,
            reason: '封面是首章节时不应再把整本书当作前置页');
      });
    });

  });
}

/// 构造一个「章节指向目录文件内锚点、锚点位于 <a> 上」的临时 EPUB。
///
/// 用于验证 [EpubParser.getChapterContentMerged] 按锚点提取时不会丢掉起始标签的
/// `<`（否则 `<a ...>封面</a>` 会被当作纯文本渲染出源码）。
String _buildAnchoredTocEpub() {
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
    <dc:identifier id="uid">test-anchored-id</dc:identifier>
  </metadata>
  <manifest>
    <item href="text00000.html" id="toc" media-type="application/xhtml+xml"/>
    <item href="toc.ncx" id="ncx" media-type="application/x-dtbncx+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="toc"/>
  </spine>
</package>''',
    ))
    ..addFile(ArchiveFile.string(
      'OEBPS/toc.ncx',
      '''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="test-anchored-id"/></head>
  <docTitle><text>Test</text></docTitle>
  <navMap>
    <navPoint id="n1" playOrder="1">
      <navLabel><text>目录</text></navLabel>
      <content src="text00000.html#toc1"/>
    </navPoint>
  </navMap>
</ncx>''',
    ))
    ..addFile(ArchiveFile.string(
      'OEBPS/text00000.html',
      '<html><body><div class="contents1">'
          '<a href="Image00000.jpg" id="toc1">封面</a></div></body></html>',
    ));

  final bytes = ZipEncoder().encode(archive);
  final file = File('${Directory.systemTemp.path}/test_anchored_toc.epub');
  file.writeAsBytesSync(Uint8List.fromList(bytes));
  return file.path;
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
