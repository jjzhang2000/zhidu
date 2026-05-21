import 'dart:io';
import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';
import 'package:image/image.dart' as img;
import '../models/book.dart';
import 'storage_config.dart';
import 'log_service.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  final _log = LogService();

  Future<Book?> parsePdfFile(String filePath, String bookId) async {
    try {
      final document = await PdfDocument.openFile(filePath);

      final fileName = filePath.split('/').last.split('\\').last;
      var title = fileName.substring(0, fileName.lastIndexOf('.'));

      final chapters = await _detectChapters(document);
      _log.d('PdfService', '检测到 ${chapters.length} 个章节');

      final String? coverPath = await _extractCover(document, bookId);

      await document.dispose();

      const author = 'Unknown';

      return Book(
        id: bookId,
        title: title,
        author: author,
        filePath: filePath,
        coverPath: coverPath,
        format: BookFormat.pdf,
        totalChapters: chapters.length,
        addedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      _log.e('PdfService', '解析PDF失败', e, stackTrace);
      return null;
    }
  }

  Future<String?> _extractCover(PdfDocument document, String bookId) async {
    try {
      if (document.pages.isEmpty) {
        _log.w('PdfService', 'PDF没有页面');
        return null;
      }

      final firstPage = document.pages[0];

      final pageWidth = firstPage.width;
      final pageHeight = firstPage.height;
      final targetWidth = 600;
      final targetHeight = (pageHeight * targetWidth / pageWidth).round();

      final pdfImage = await firstPage.render(
        width: targetWidth,
        height: targetHeight,
        backgroundColor: 0xFFFFFFFF,
      );

      if (pdfImage == null) {
        _log.w('PdfService', '渲染返回空图片');
        return null;
      }

      final image = img.Image(width: targetWidth, height: targetHeight);

      final pixels = pdfImage.pixels;

      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          final offset = (y * pdfImage.width + x) * 4;
          if (offset + 3 < pixels.length) {
            final r = pixels[offset];
            final g = pixels[offset + 1];
            final b = pixels[offset + 2];
            final a = pixels[offset + 3];
            image.setPixelRgba(x, y, r, g, b, a);
          }
        }
      }

      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final coverPath =
          await StorageConfig.getCoverSavePath(bookId, 'png');
      final coverFile = File(coverPath);

      await coverFile.writeAsBytes(pngBytes);

      pdfImage.dispose();

      _log.info('PdfService', '封面已保存: $coverPath');
      return coverPath;
    } catch (e, stackTrace) {
      _log.e('PdfService', '提取封面渲染失败', e, stackTrace);
      return null;
    }
  }

  Future<List<_PdfChapter>> _detectChapters(PdfDocument document) async {
    final chapters = <_PdfChapter>[];
    final totalPages = document.pages.length;

    final pageContents = <String>[];
    for (int i = 0; i < totalPages; i++) {
      final page = document.pages[i];
      final pageText = await page.loadText();
      pageContents.add(pageText?.fullText ?? '');
    }

    final patterns = [
      r'第[一二三四五六七八九十百]+章',
      r'第\d+章',
      r'Chapter\s+\d+',
      r'CHAPTER\s+\d+',
      r'^\d+\.\s+[A-Za-z]',
      r'^[A-Z][a-z]+\s+\d+',
    ];

    final chapterBoundaries = <int>[0];

    for (int i = 0; i < pageContents.length; i++) {
      final content = pageContents[i];
      for (final pattern in patterns) {
        final regex = RegExp(pattern, multiLine: true);
        if (regex.hasMatch(content)) {
          chapterBoundaries.add(i);
          break;
        }
      }
    }

    if (chapterBoundaries.last != totalPages - 1) {
      chapterBoundaries.add(totalPages - 1);
    }

    for (int i = 0; i < chapterBoundaries.length - 1; i++) {
      final startIndex = chapterBoundaries[i];
      final endIndex = chapterBoundaries[i + 1];

      String chapterTitle = '第${i + 1}章';
      if (startIndex < pageContents.length) {
        final firstPageContent = pageContents[startIndex];
        for (final pattern in patterns) {
          final regex = RegExp(pattern, multiLine: true);
          final match = regex.firstMatch(firstPageContent);
          if (match != null) {
            chapterTitle = match.group(0) ?? chapterTitle;
            break;
          }
        }
      }

      chapters.add(_PdfChapter(
        index: i,
        title: chapterTitle,
        startPage: startIndex + 1,
        endPage: endIndex + 1,
      ));
    }

    return chapters;
  }
}

class _PdfChapter {
  final int index;
  final String title;
  final int startPage;
  final int endPage;

  _PdfChapter({
    required this.index,
    required this.title,
    required this.startPage,
    required this.endPage,
  });
}
