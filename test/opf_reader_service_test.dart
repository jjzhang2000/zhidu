import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhidu/services/opf_reader_service.dart';

void main() {
  group('OpfReaderService', () {
    late String testTempDir;

    setUp(() {
      testTempDir = p.join(Directory.current.path, '.test_temp');
      if (!Directory(testTempDir).existsSync()) {
        Directory(testTempDir).createSync(recursive: true);
      }
    });

    tearDown(() {
      if (Directory(testTempDir).existsSync()) {
        Directory(testTempDir).deleteSync(recursive: true);
      }
    });

    test('readFromOpfFile should parse valid OPF file correctly', () async {
      final opfContent = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="uuid_id" opf:scheme="uuid">12345678-1234-1234-1234-123456789012</dc:identifier>
    <dc:title>测试书籍标题</dc:title>
    <dc:creator opf:role="aut">测试作者</dc:creator>
    <dc:language>zh-CN</dc:language>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover-image" href="cover.jpg" media-type="image/jpeg"/>
    <item id="titlepage" href="titlepage.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="titlepage"/>
  </spine>
  <guide>
    <reference type="cover" href="cover.jpg"/>
  </guide>
</package>''';

      final opfPath = p.join(testTempDir, 'metadata.opf');
      await File(opfPath).writeAsString(opfContent);

      final result = await OpfReaderService.readFromOpfFile(opfPath);

      expect(result, isNotNull);
      expect(result!.title, '测试书籍标题');
      expect(result.author, '测试作者');
      expect(result.language, 'zh-CN');
      expect(result.coverPath, 'cover.jpg');
    });

    test('readFromOpfFile should return null for invalid OPF file', () async {
      final invalidOpfContent = '<invalid xml>';
      final opfPath = p.join(testTempDir, 'invalid.opf');
      await File(opfPath).writeAsString(invalidOpfContent);

      final result = await OpfReaderService.readFromOpfFile(opfPath);

      expect(result, isNull);
    });

    test('readFromOpfFile should return null for non-existent file', () async {
      final result = await OpfReaderService.readFromOpfFile('non_existent.opf');

      expect(result, isNull);
    });

    test('readFromSameDirectory should find and parse OPF in same directory', () async {
      final opfContent = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="uuid_id" opf:scheme="uuid">12345678-1234-1234-1234-123456789012</dc:identifier>
    <dc:title>目录测试标题</dc:title>
    <dc:creator opf:role="aut">目录测试作者</dc:creator>
    <dc:language>en</dc:language>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover-image" href="cover.png" media-type="image/png"/>
  </manifest>
  <spine>
    <itemref idref="cover-image"/>
  </spine>
  <guide>
    <reference type="cover" href="cover.png"/>
  </guide>
</package>''';

      final bookPath = p.join(testTempDir, 'test_book.epub');
      final opfPath = p.join(testTempDir, 'metadata.opf');
      
      await File(bookPath).writeAsString('dummy epub content');
      await File(opfPath).writeAsString(opfContent);

      final result = await OpfReaderService.readFromSameDirectory(bookPath);

      expect(result, isNotNull);
      expect(result!.title, '目录测试标题');
      expect(result.author, '目录测试作者');
      expect(result.language, 'en');
      expect(result.coverPath, 'cover.png');
    });

    test('readFromSameDirectory should return null if no OPF in directory', () async {
      final bookPath = p.join(testTempDir, 'test_book.epub');
      
      await File(bookPath).writeAsString('dummy epub content');

      final result = await OpfReaderService.readFromSameDirectory(bookPath);

      expect(result, isNull);
    });
  });
}
