import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhidu/services/opf_reader_service.dart';

void main() {
  group('OPF Integration Test', () {
    late String testTempDir;

    setUp(() {
      testTempDir = p.join(Directory.current.path, '.opf_integration_test');
      if (!Directory(testTempDir).existsSync()) {
        Directory(testTempDir).createSync(recursive: true);
      }
    });

    tearDown(() {
      if (Directory(testTempDir).existsSync()) {
        Directory(testTempDir).deleteSync(recursive: true);
      }
    });

    test('Complete OPF workflow - Calibre style metadata.opf', () async {
      final bookFilePath = p.join(testTempDir, 'my_book.epub');
      final opfFilePath = p.join(testTempDir, 'metadata.opf');
      
      await File(bookFilePath).writeAsString('dummy epub content');
      
      final calibreStyleOpfContent = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="uuid_id" opf:scheme="calibre">12345678-1234-5678-9012-123456789012</dc:identifier>
    <dc:title>三体</dc:title>
    <dc:creator opf:role="aut" opf:file-as="Liu, Cixin">刘慈欣</dc:creator>
    <dc:language>zh-CN</dc:language>
    <dc:publisher>重庆出版社</dc:publisher>
    <dc:description>《三体》是中国科幻作家刘慈欣创作的长篇科幻小说...</dc:description>
    <dc:subject>科幻小说</dc:subject>
    <dc:subject>中国文学</dc:subject>
    <dc:date opf:event="publication">2006-05-01</dc:date>
    <meta name="calibre:series" content="地球往事三部曲"/>
    <meta name="calibre:series_index" content="1.0"/>
    <meta name="cover" content="cover_image"/>
  </metadata>
  <manifest>
    <item id="cover_image" href="cover.jpg" media-type="image/jpeg"/>
    <item id="titlepage" href="titlepage.xhtml" media-type="application/xhtml+xml"/>
    <item id="stylesheet" href="stylesheet.css" media-type="text/css"/>
  </manifest>
  <spine>
    <itemref idref="titlepage"/>
  </spine>
  <guide>
    <reference type="cover" href="cover.jpg"/>
  </guide>
</package>''';
      
      await File(opfFilePath).writeAsString(calibreStyleOpfContent);

      final opfMetadata = await OpfReaderService.readFromSameDirectory(bookFilePath);

      expect(opfMetadata, isNotNull);
      expect(opfMetadata!.title, '三体');
      expect(opfMetadata.author, '刘慈欣');
      expect(opfMetadata.language, 'zh-CN');
      expect(opfMetadata.coverPath, 'cover.jpg');
    });

    test('OPF with minimal metadata still works', () async {
      final bookFilePath = p.join(testTempDir, 'minimal_book.epub');
      final opfFilePath = p.join(testTempDir, 'metadata.opf');
      
      await File(bookFilePath).writeAsString('dummy epub content');
      
      final minimalOpfContent = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="uuid_id" opf:scheme="uuid">abcd-efgh-ijkl-mnop</dc:identifier>
    <dc:title>Minimal Book</dc:title>
    <dc:creator>Minimal Author</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="titlepage" href="titlepage.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="titlepage"/>
  </spine>
</package>''';
      
      await File(opfFilePath).writeAsString(minimalOpfContent);

      final opfMetadata = await OpfReaderService.readFromSameDirectory(bookFilePath);

      expect(opfMetadata, isNotNull);
      expect(opfMetadata!.title, 'Minimal Book');
      expect(opfMetadata.author, 'Minimal Author');
      expect(opfMetadata.language, 'en');
      expect(opfMetadata.coverPath, isNull);
    });

    test('No OPF file returns null gracefully', () async {
      final bookFilePath = p.join(testTempDir, 'book_without_opf.epub');
      await File(bookFilePath).writeAsString('dummy epub content');

      final opfMetadata = await OpfReaderService.readFromSameDirectory(bookFilePath);

      expect(opfMetadata, isNull);
    });

    test('Invalid OPF file returns null gracefully', () async {
      final bookFilePath = p.join(testTempDir, 'book_with_invalid_opf.epub');
      final opfFilePath = p.join(testTempDir, 'metadata.opf');
      
      await File(bookFilePath).writeAsString('dummy epub content');
      await File(opfFilePath).writeAsString('<invalid xml content');

      final opfMetadata = await OpfReaderService.readFromSameDirectory(bookFilePath);

      expect(opfMetadata, isNull);
    });
  });
}
