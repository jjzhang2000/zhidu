import 'dart:io';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/screens/chapter_screen.dart';
import 'package:zhidu/services/parsers/book_format_parser.dart';
import 'package:zhidu/services/parsers/epub_parser.dart';

/// 1x1 透明 PNG，用于图片链接用例
final Uint8List _pngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

/// 点击正文（目录章节）里的链接应跳到对应章节。
void main() {
  testWidgets('点击目录中的链接跳转到对应章节', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    FormatRegistry.clear();
    FormatRegistry.register('.epub', EpubParser());

    final path = _buildTocEpub();
    addTearDown(() {
      // Windows 上解析器可能仍持有文件句柄，删除失败不影响测试结果
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    });

    final List<Chapter> chapters =
        await tester.runAsync(() => EpubParser().getChapters(path)) ??
            const <Chapter>[];
    // 图片目录项被注入为独立章节：首项「封面」在最前，中间图片插入到
    // 「目录条目一」与「目录条目二」之间
    expect(chapters.where((c) => c.level == 0).length, 5);
    expect(chapters.map((c) => c.title).toList(),
        ['封面', '目录', '第一章', '中间图片', '第二章']);
    final tocIndex = chapters.indexWhere((c) => c.title == '目录');

    await tester.pumpWidget(
      MaterialApp(
        home: ChapterScreen(
          bookId: 'link_nav_test',
          chapterIndex: tocIndex,
          chapterTitle: '目录',
          filePath: path,
          chapters: chapters,
        ),
      ),
    );

    // 等目录章节内容解析 + 分页稳定
    expect(await _waitForText(tester, '目录条目一'), isTrue);

    // 找到屏幕内可见的链接文字并点击其左端文字（左对齐）
    final point = _visibleTextPoint(tester, '目录条目一');
    expect(point, isNotNull, reason: '未找到目录链接文字');
    await tester.tapAt(point!);
    await tester.pump();

    // 应加载目标章节正文
    expect(await _waitForText(tester, '第一章正文内容'), isTrue,
        reason: '点击目录链接后应跳转到第一章');

    expect(tester.takeException(), isNull);
  });

  testWidgets('点击图片链接（封面）打开图片页', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    FormatRegistry.clear();
    FormatRegistry.register('.epub', EpubParser());

    final path = _buildTocEpub();
    addTearDown(() {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    });

    final List<Chapter> chapters =
        await tester.runAsync(() => EpubParser().getChapters(path)) ??
            const <Chapter>[];
    final tocIndex = chapters.indexWhere((c) => c.title == '目录');

    await tester.pumpWidget(
      MaterialApp(
        home: ChapterScreen(
          bookId: 'img_link_test',
          chapterIndex: tocIndex,
          chapterTitle: '目录',
          filePath: path,
          chapters: chapters,
        ),
      ),
    );

    expect(await _waitForText(tester, '封面'), isTrue);

    final point = _visibleTextPoint(tester, '封面');
    expect(point, isNotNull, reason: '未找到封面链接文字');
    await tester.tapAt(point!);
    await tester.pump();

    // 跳转到「封面」图片页：目录正文离开屏幕，出现封面图片
    expect(
      await _waitUntil(
          tester, () => !_isTextOnScreen(tester, '目录条目一')),
      isTrue,
      reason: '点击封面图片链接应离开目录、跳到封面页',
    );
    expect(find.byType(Image), findsWidgets, reason: '封面页应渲染图片');
    expect(tester.takeException(), isNull);
  });
}

/// 轮询等待条件成立
Future<bool> _waitUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return true;
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  return condition();
}

/// 找到文字在屏幕内可见的位置（取其左侧文字区域）
Offset? _visibleTextPoint(WidgetTester tester, String text) {
  for (final element in find.textContaining(text, findRichText: true).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final origin = box.localToGlobal(Offset.zero);
    if (origin.dx > -1 && origin.dx < 1280) {
      return origin + Offset(8, box.size.height / 2);
    }
  }
  return null;
}

/// 轮询等待某段文字出现在屏幕内（真实 IO 与分页测量需让出真实事件循环）
Future<bool> _waitForText(WidgetTester tester, String text) async {
  for (var i = 0; i < 400; i++) {
    if (_isTextOnScreen(tester, text)) return true;
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  return _isTextOnScreen(tester, text);
}

bool _isTextOnScreen(WidgetTester tester, String text) {
  for (final element in find.textContaining(text, findRichText: true).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final origin = box.localToGlobal(Offset.zero);
    if (origin.dx > -1 && origin.dx < 1280 && origin.dy > -1 && origin.dy < 800) {
      return true;
    }
  }
  return false;
}

/// 构造一个含「目录章节 + 两个正文章节」的临时 EPUB，返回其文件路径。
String _buildTocEpub() {
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
    <dc:title>Link Nav Test</dc:title>
    <dc:identifier id="uid">link-nav-test-id</dc:identifier>
  </metadata>
  <manifest>
    <item href="toc.xhtml" id="toc" media-type="application/xhtml+xml"/>
    <item href="c1.xhtml" id="c1" media-type="application/xhtml+xml"/>
    <item href="c2.xhtml" id="c2" media-type="application/xhtml+xml"/>
    <item href="toc.ncx" id="ncx" media-type="application/x-dtbncx+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="toc"/>
    <itemref idref="c1"/>
    <itemref idref="c2"/>
  </spine>
</package>''',
    ))
    ..addFile(ArchiveFile.string(
      'OEBPS/toc.ncx',
      '''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="link-nav-test-id"/></head>
  <docTitle><text>Link Nav Test</text></docTitle>
  <navMap>
    <navPoint id="n0" playOrder="1">
      <navLabel><text>目录</text></navLabel>
      <content src="toc.xhtml"/>
    </navPoint>
    <navPoint id="n1" playOrder="2">
      <navLabel><text>第一章</text></navLabel>
      <content src="c1.xhtml"/>
    </navPoint>
    <navPoint id="n2" playOrder="3">
      <navLabel><text>第二章</text></navLabel>
      <content src="c2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''',
    ))
    ..addFile(ArchiveFile.string(
      'OEBPS/toc.xhtml',
      '<html><body>'
          '<p>目录</p>'
          '<p><a href="cover.png">封面</a></p>'
          '<p><a href="c1.xhtml">目录条目一</a></p>'
          '<p><a href="mid.png">中间图片</a></p>'
          '<p><a href="c2.xhtml">目录条目二</a></p>'
          '</body></html>',
    ))
    ..addFile(ArchiveFile.bytes('OEBPS/cover.png', _pngBytes))
    ..addFile(ArchiveFile.bytes('OEBPS/mid.png', _pngBytes))
    ..addFile(ArchiveFile.string(
      'OEBPS/c1.xhtml',
      '<html><body><p>第一章正文内容</p></body></html>',
    ))
    ..addFile(ArchiveFile.string(
      'OEBPS/c2.xhtml',
      '<html><body><p>第二章正文内容</p></body></html>',
    ));

  final bytes = ZipEncoder().encode(archive);
  final file = File('${Directory.systemTemp.path}/test_link_nav.epub');
  file.writeAsBytesSync(Uint8List.fromList(bytes));
  return file.path;
}
