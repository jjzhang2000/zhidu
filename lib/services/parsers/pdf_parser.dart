import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as p;

import '../../models/book.dart';
import '../../models/book_metadata.dart';
import '../../models/chapter.dart';
import '../../models/chapter_content.dart';
import '../../models/chapter_location.dart';
import 'book_format_parser.dart';
import '../log_service.dart';

/// PDF格式解析器实现
/// 用于解析PDF文件并提取元数据、章节列表和内容
class PdfParser implements BookFormatParser {
  final LogService _log = LogService();

  @override
  Future<BookMetadata> parse(String filePath) async {
    _log.v('PdfParser', 'parse 开始执行, filePath: $filePath');

    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('PdfParser', '文件不存在: $filePath');
      throw Exception('PDF file not found: $filePath');
    }

    try {
      final document = await PdfDocument.openFile(filePath);
      final totalPages = document.pages.length;
      await document.dispose();

      // 提取标题（使用文件名作为默认标题）
      final fileName = p.basenameWithoutExtension(filePath);
      final title = fileName.replaceAll('_', ' ').replaceAll('-', ' ');

      _log.d('PdfParser', '书名: $title');
      _log.d('PdfParser', '总页数: $totalPages');

      return BookMetadata(
        title: title,
        author: 'Unknown',
        coverPath: null,
        totalChapters: totalPages > 0 ? 1 : 0,
        format: BookFormat.pdf,
      );
    } catch (e, stackTrace) {
      _log.e('PdfParser', '解析PDF失败', e, stackTrace);
      throw Exception('Failed to parse PDF: $e');
    }
  }

  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    _log.v('PdfParser', 'getChapters 开始执行, filePath: $filePath');

    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('PdfParser', '文件不存在: $filePath');
      return [];
    }

    try {
      final document = await PdfDocument.openFile(filePath);
      final totalPages = document.pages.length;

      if (totalPages == 0) {
        await document.dispose();
        return [];
      }

      // 收集所有页面的文本内容
      final pageContents = <String>[];
      for (int i = 0; i < totalPages; i++) {
        final page = document.pages[i];
        final pageText = await page.loadText();
        pageContents.add(pageText.fullText);
      }

      await document.dispose();

      // 章节标题正则表达式模式
      final patterns = [
        r'第[一二三四五六七八九十百]+章[^\n]*',
        r'第\d+章[^\n]*',
        r'Chapter\s+\d+[^\n]*',
        r'CHAPTER\s+\d+[^\n]*',
      ];

      final chapterBoundaries = <int>[0]; // 章节起始页面索引（0-based）

      // 检测章节边界
      for (int i = 0; i < pageContents.length; i++) {
        final content = pageContents[i];
        for (final pattern in patterns) {
          final regex = RegExp(pattern, multiLine: true, caseSensitive: false);
          if (regex.hasMatch(content)) {
            if (i != 0 && i != chapterBoundaries.last) {
              chapterBoundaries.add(i);
            }
            break;
          }
        }
      }

      // 如果没有检测到多个章节，将整个文档视为一个章节
      if (chapterBoundaries.length == 1) {
        _log.d('PdfParser', '未检测到多个章节，将整个文档视为一个章节');
        return [
          Chapter(
            id: 'pdf_chapter_0',
            index: 0,
            title: '第1章',
            location: ChapterLocation(
              startPage: 1,
              endPage: totalPages,
            ),
          ),
        ];
      }

      // 添加最后一页作为边界
      if (chapterBoundaries.last != totalPages - 1) {
        chapterBoundaries.add(totalPages - 1);
      }

      // 创建章节对象
      final chapters = <Chapter>[];
      for (int i = 0; i < chapterBoundaries.length - 1; i++) {
        final startIndex = chapterBoundaries[i];
        final endIndex = chapterBoundaries[i + 1];

        // 尝试从页面内容中提取章节标题
        String chapterTitle = '第${i + 1}章';
        if (startIndex < pageContents.length) {
          final firstPageContent = pageContents[startIndex];
          for (final pattern in patterns) {
            final regex =
                RegExp(pattern, multiLine: true, caseSensitive: false);
            final match = regex.firstMatch(firstPageContent);
            if (match != null) {
              chapterTitle = match.group(0)?.trim() ?? chapterTitle;
              break;
            }
          }
        }

        chapters.add(Chapter(
          id: 'pdf_chapter_$i',
          index: i,
          title: chapterTitle,
          location: ChapterLocation(
            startPage: startIndex + 1, // 1-based page numbers
            endPage: endIndex + 1,
          ),
        ));
      }

      _log.d('PdfParser', '检测到 ${chapters.length} 个章节');
      return chapters;
    } catch (e, stackTrace) {
      _log.e('PdfParser', '获取章节列表失败', e, stackTrace);
      return [];
    }
  }

  @override
  Future<ChapterContent> getChapterContent(
      String filePath, Chapter chapter) async {
    _log.v('PdfParser',
        'getChapterContent 开始执行, filePath: $filePath, chapter: ${chapter.title}');

    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('PdfParser', '文件不存在: $filePath');
      throw Exception('PDF file not found: $filePath');
    }

    try {
      final document = await PdfDocument.openFile(filePath);

      final startPage = chapter.location.startPage;
      final endPage = chapter.location.endPage;

      if (startPage == null || endPage == null) {
        await document.dispose();
        _log.w('PdfParser', '章节缺少页面范围信息: ${chapter.title}');
        return ChapterContent(plainText: '');
      }

      // 提取页面范围内的所有文本
      final buffer = StringBuffer();
      for (int pageNum = startPage;
          pageNum <= endPage && pageNum <= document.pages.length;
          pageNum++) {
        final page = document.pages[pageNum - 1]; // pages是0-based
        final pageText = await page.loadText();
        if (buffer.isNotEmpty) {
          buffer.write('\n\n');
        }
        buffer.write(pageText.fullText);
      }

      await document.dispose();

      final plainText = buffer.toString().trim();
      _log.d('PdfParser', '章节内容提取成功，长度: ${plainText.length}');

      // PDF没有HTML内容，所以htmlContent为null
      return ChapterContent(
        plainText: plainText,
        htmlContent: null,
      );
    } catch (e, stackTrace) {
      _log.e('PdfParser', '获取章节内容失败', e, stackTrace);
      return ChapterContent(plainText: '');
    }
  }

  @override
  Future<String?> extractCover(String filePath) async {
    _log.v('PdfParser', 'extractCover 开始执行, filePath: $filePath');

    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('PdfParser', '文件不存在: $filePath');
      return null;
    }

    // PDF文件通常没有像EPUB那样的独立封面图片
    // 第一页通常包含内容而非专门的封面设计
    // 因此返回null，让UI层使用默认封面占位图
    _log.d('PdfParser', 'PDF不支持封面提取，返回null');
    return null;
  }
}
