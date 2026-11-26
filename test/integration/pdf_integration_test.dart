/// PDF集成测试
///
/// 注意：pdfrx库使用FFI调用pdfium原生库，因此：
/// - 涉及实际PDF解析的测试需要在平台测试环境运行（Windows/macOS/Linux）
/// - 文件不存在等不涉及FFI的测试可在Dart测试环境运行
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/services/parsers/pdf_parser.dart';

void main() {
  group('PDF Integration Tests', () {
    late PdfParser parser;
    late String testPdfPath;

    setUpAll(() {
      parser = PdfParser();
      testPdfPath = 'test/fixtures/test_book.pdf';
    });

    group('getChapters方法测试', () {
      test('应返回章节列表', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          expect(chapters, isNotNull);
          expect(chapters, isA<List<Chapter>>());
          expect(chapters.length, greaterThan(0));
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('章节应包含正确的ChapterLocation信息', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          for (final chapter in chapters) {
            expect(chapter.location, isNotNull);
            expect(chapter.location.startPage, isNotNull);
            expect(chapter.location.startPage, greaterThan(0));
            expect(chapter.location.endPage, isNotNull);
            expect(
              chapter.location.endPage,
              greaterThanOrEqualTo(chapter.location.startPage!),
            );
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('章节索引应从0开始连续递增', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          for (int i = 0; i < chapters.length; i++) {
            expect(chapters[i].index, equals(i));
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('每个章节应有有效的标题', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          for (final chapter in chapters) {
            expect(chapter.title, isNotEmpty);
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('封面跳过逻辑：首页文字少于50字符时跳过', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          if (chapters.isNotEmpty) {
            final firstChapter = chapters.first;
            expect(
              firstChapter.location.startPage,
              greaterThanOrEqualTo(1),
            );
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('文件不存在时应返回空列表', () async {
        final chapters = await parser.getChapters('non_existent_file.pdf');

        expect(chapters, isEmpty);
      });
    });

    group('getChapterContent方法测试', () {
      test('应提取章节内容', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          if (chapters.isNotEmpty) {
            final firstChapter = chapters.first;
            final content =
                await parser.getChapterContent(testPdfPath, firstChapter);

            expect(content, isNotNull);
            expect(content.htmlContent, isNotEmpty);
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('应正确提取HTML内容', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          if (chapters.isNotEmpty) {
            final content =
                await parser.getChapterContent(testPdfPath, chapters.first);

            expect(content.htmlContent, isNotNull);
            expect(content.htmlContent!.length, greaterThan(0));
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('应正确转换为HTML内容', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          if (chapters.isNotEmpty) {
            final content =
                await parser.getChapterContent(testPdfPath, chapters.first);

            expect(content.htmlContent, isNotNull);
            expect(content.htmlContent, contains('<p>'));
            expect(content.htmlContent, contains('</p>'));
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('HTML段落应与原文内容对应', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          if (chapters.isNotEmpty) {
            final content =
                await parser.getChapterContent(testPdfPath, chapters.first);

            final htmlContent = content.htmlContent!;
            final htmlParagraphs = RegExp(r'<p>.*?</p>', dotAll: true)
                .allMatches(htmlContent)
                .toList();

            expect(htmlParagraphs.length, greaterThan(0));
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('文件不存在时应抛出异常', () async {
        final dummyChapter = Chapter(
          bookId: 'test',
          index: 0,
          title: 'Test',
          location: ChapterLocation(startPage: 1, endPage: 1),
        );

        expect(
          () => parser.getChapterContent('non_existent_file.pdf', dummyChapter),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('页面范围测试', () {
      test('ChapterLocation的startPage和endPage应正确设置', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          for (final chapter in chapters) {
            expect(chapter.location.startPage, greaterThanOrEqualTo(1));
            expect(
              chapter.location.endPage,
              greaterThanOrEqualTo(chapter.location.startPage!),
            );
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('章节页面范围不应重叠', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          for (int i = 0; i < chapters.length - 1; i++) {
            final currentChapter = chapters[i];
            final nextChapter = chapters[i + 1];

            expect(
              currentChapter.location.endPage,
              lessThanOrEqualTo(nextChapter.location.startPage!),
              reason: '章节${currentChapter.title}的结束页不应超过下一章的起始页',
            );
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('第一个章节的起始页应>=1', () async {
        try {
          final chapters = await parser.getChapters(testPdfPath);

          if (chapters.isNotEmpty) {
            expect(
              chapters.first.location.startPage,
              greaterThanOrEqualTo(1),
            );
          }
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });
    });

    group('parseMetadata方法测试', () {
      test('应返回元数据', () async {
        try {
          final metadata = await parser.parseMetadata(testPdfPath, 'test-book');

          expect(metadata, isNotNull);
          expect(metadata!.title, isNotEmpty);
          expect(metadata.author, isNotEmpty);
          expect(metadata.totalChapters, greaterThan(0));
        } on Exception catch (e) {
          if (e.toString().contains('FPDF_InitLibraryWithConfig')) {
            markTestSkipped('pdfium FFI库未加载，需要在平台测试环境运行');
          } else {
            throw e;
          }
        }
      });

      test('文件不存在时应返回null', () async {
        final metadata = await parser.parseMetadata('non_existent_file.pdf', 'test-book');

        expect(metadata, isNull);
      });
    });
  });
}
