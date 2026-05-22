import 'dart:io';
import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';
import 'package:image/image.dart' as img;

import '../../models/chapter.dart';
import 'book_format_parser.dart';
import '../storage_config.dart';
import 'package:logger/logger.dart';
import '../log_helper.dart';

/// PDF 格式解析器
///
/// 章节检测：逐页匹配中英文章节标题正则，自动跳过封面页（首页文字 < 50 字符）。
/// 封面提取：渲染第一页为 600px 宽 PNG 图片。
class PdfParser implements BookFormatParser {
  final _log = Logger(output: LogHelper.output);

  @override
  Future<BookMetadata?> parseMetadata(String filePath, String bookId) async {
    try {
      final document = await PdfDocument.openFile(filePath);

      final fileName = filePath.split('/').last.split('\\').last;
      var title = fileName.substring(0, fileName.lastIndexOf('.'));

      final chapters = await _detectChapters(document);
      _log.i('检测到 ${chapters.length} 个章节');

      final String? coverPath = await _extractCover(document, bookId);

      await document.dispose();

      const author = '未知作者';

      return BookMetadata(
        title: title,
        author: author,
        totalChapters: chapters.length,
        coverPath: coverPath,
      );
    } catch (e, stackTrace) {
      _log.e('解析 PDF 元数据失败', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 检测 PDF 章节结构：封面检测 → 逐页正则匹配章节标题 → 边界转 Chapter 列表
  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('文件不存在: $filePath');
      return [];
    }

    try {
      final document = await PdfDocument.openFile(filePath);
      final totalPages = document.pages.length;

      if (totalPages == 0) {
        await document.dispose();
        return [];
      }

      final pageContents = <String>[];
      for (int i = 0; i < totalPages; i++) {
        final page = document.pages[i];
        final pageText = await page.loadText();
        pageContents.add(pageText?.fullText ?? '');
      }

      await document.dispose();

      int startOffset = 0;
      final coverThreshold = 50;

      if (pageContents.isNotEmpty &&
          pageContents[0].trim().length < coverThreshold) {
        startOffset = 1;
      }

      final effectivePages = totalPages - startOffset;
      if (effectivePages <= 0) {
        _log.i('跳过封面后无有效页面');
        return [];
      }

      final patterns = [
        r'^第[一二三四五六七八九十百零]+章[：:\s]',
        r'^第\d+章[：:\s]',
        r'^Chapter\s+\d+[：:\s]',
        r'^CHAPTER\s+\d+[：:\s]',
      ];

      final chapterBoundaries = <int>[startOffset];
      final chapterTitles = <String>['全文'];
      int lastChapterNum = -1;

      for (int i = startOffset; i < pageContents.length; i++) {
        final content = pageContents[i];
        final firstLines = content.split('\n').take(5);

        for (final line in firstLines) {
          for (final pattern in patterns) {
            final regex =
                RegExp(pattern, multiLine: true, caseSensitive: false);
            final match = regex.firstMatch(line);

            if (match != null) {
              final title = match.group(0)?.trim() ?? '';
              final numMatch = RegExp(r'\d+|[一二三四五六七八九十百零]+').firstMatch(title);
              if (numMatch != null) {
                final chapterNum = numMatch.group(0);

                if (i != startOffset &&
                    chapterNum != null &&
                    !chapterBoundaries.contains(i) &&
                    lastChapterNum != int.tryParse(chapterNum)) {
                  chapterBoundaries.add(i);
                  chapterTitles.add(title);
                  lastChapterNum = int.tryParse(chapterNum) ?? -1;
                }
              }
              break;
            }
          }
        }
      }

      if (chapterBoundaries.length == 1) {
        _log.i('未检测到章节结构，将有效文档视为一个章节');
        return [
          Chapter(
            index: 0,
            title: '全文',
            location: ChapterLocation(
              startPage: startOffset + 1,
              endPage: totalPages,
            ),
            level: 0,
          ),
        ];
      }

      if (chapterBoundaries.last != totalPages - 1) {
        chapterBoundaries.add(totalPages - 1);
        chapterTitles.add('结束');
      }

      final chapters = <Chapter>[];
      for (int i = 0; i < chapterBoundaries.length - 1; i++) {
        final startIndex = chapterBoundaries[i];
        final endIndex = chapterBoundaries[i + 1];
        final title =
            i < chapterTitles.length ? chapterTitles[i] : '第${i + 1}章';

        chapters.add(Chapter(
          index: i,
          title: title,
          location: ChapterLocation(
            startPage: startIndex + 1,
            endPage: endIndex + 1,
          ),
          level: 0,
        ));
      }

      _log.i('检测到 ${chapters.length} 个章节');
      return chapters;
    } catch (e, stackTrace) {
      _log.e('获取章节列表失败', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// 提取章节内容：按 startPage-endPage 范围提取页面文本，转换为 <p> 包裹的 HTML
  @override
  Future<Chapter> getChapterContent(
      String filePath, Chapter chapter) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('文件不存在: $filePath');
      throw Exception('PDF file not found: $filePath');
    }

    try {
      final document = await PdfDocument.openFile(filePath);

      final startPage = chapter.location.startPage;
      final endPage = chapter.location.endPage;

      if (startPage == null || endPage == null) {
        await document.dispose();
        _log.w('章节缺少页面范围信息: ${chapter.title}');
        return chapter;
      }

      final buffer = StringBuffer();
      for (int pageNum = startPage;
          pageNum <= endPage && pageNum <= document.pages.length;
          pageNum++) {
        final page = document.pages[pageNum - 1];
        final pageText = await page.loadText();

        if (buffer.isNotEmpty) {
          buffer.write('\n\n');
        }
        buffer.write(pageText?.fullText ?? '');
      }

      await document.dispose();

      final plainText = buffer.toString().trim();

      if (plainText.isEmpty) {
        _log.w('章节内容为空: ${chapter.title}');
        return chapter;
      }

      final paragraphs =
          plainText.split('\n').where((p) => p.trim().isNotEmpty);
      final htmlContent =
          paragraphs.map((p) => '<p>${p.trim()}</p>').join('\n');

      return Chapter(
        bookId: chapter.bookId,
        index: chapter.index,
        title: chapter.title,
        location: chapter.location,
        level: chapter.level,
        htmlContent: htmlContent,
      );
    } catch (e, stackTrace) {
      _log.e('获取章节内容失败', error: e, stackTrace: stackTrace);
      return chapter;
    }
  }

  /// 检测 PDF 章节结构，返回章节信息列表（供 parseMetadata 调用）
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

  /// 提取 PDF 封面（渲染第一页为图片）
  Future<String?> _extractCover(PdfDocument document, String bookId) async {
    try {
      if (document.pages.isEmpty) {
        _log.w('PDF没有页面');
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
        _log.w('渲染返回空图片');
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

      final coverPath = await StorageConfig.getCoverSavePath(bookId, 'png');
      final coverFile = File(coverPath);

      await coverFile.writeAsBytes(pngBytes);

      pdfImage.dispose();

      return coverPath;
    } catch (e, stackTrace) {
      _log.e('提取封面渲染失败', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}

/// 内部章节信息（PDF 解析过程中的临时结构）
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
