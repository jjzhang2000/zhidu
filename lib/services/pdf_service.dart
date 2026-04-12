import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import '../models/book.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  /// 解析PDF文件并创建Book对象
  Future<Book?> parsePdfFile(String filePath) async {
    try {
      final document = await PdfDocument.openFile(filePath);

      final totalPages = document.pages.length;

      // 提取标题（使用文件名作为默认标题）
      final fileName = filePath.split('/').last.split('\\').last;
      final title = fileName.substring(0, fileName.lastIndexOf('.'));

      // 检测章节结构
      final chapters = await _detectChapters(document);

      await document.dispose();

      return Book(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        author: 'Unknown',
        filePath: filePath,
        format: BookFormat.pdf,
        totalChapters: chapters.length,
        currentChapter: 0,
        readingProgress: 0.0,
        addedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error parsing PDF: $e');
      return null;
    }
  }

  /// 检测PDF中的章节结构
  Future<List<PdfChapter>> _detectChapters(PdfDocument document) async {
    final chapters = <PdfChapter>[];
    final totalPages = document.pages.length;

    // 收集所有页面的文本内容
    final pageContents = <String>[];
    for (int i = 0; i < totalPages; i++) {
      final page = document.pages[i];
      final pageText = await page.loadText();
      pageContents.add(pageText.fullText);
    }

    // 章节标题正则表达式模式
    final patterns = [
      r'第[一二三四五六七八九十百]+章',
      r'第\d+章',
      r'Chapter\s+\d+',
      r'CHAPTER\s+\d+',
      r'^\d+\.\s+[A-Za-z]',
      r'^[A-Z][a-z]+\s+\d+',
    ];

    final chapterBoundaries = <int>[0]; // 章节起始页面索引

    // 检测章节边界
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

    // 添加最后一页作为边界
    if (chapterBoundaries.last != totalPages - 1) {
      chapterBoundaries.add(totalPages - 1);
    }

    // 创建章节对象
    for (int i = 0; i < chapterBoundaries.length - 1; i++) {
      final startIndex = chapterBoundaries[i];
      final endIndex = chapterBoundaries[i + 1];

      // 尝试从页面内容中提取章节标题
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

      chapters.add(PdfChapter(
        index: i,
        title: chapterTitle,
        startPage: startIndex + 1,
        endPage: endIndex + 1,
      ));
    }

    return chapters;
  }

  /// 获取指定章节的页面内容
  Future<List<PdfPageContent>> getChapterPages(
      String filePath, int chapterIndex) async {
    final document = await PdfDocument.openFile(filePath);

    // 这里需要根据实际的章节检测逻辑获取页面范围
    // 暂时返回所有页面（后续完善）
    final pages = <PdfPageContent>[];
    for (int i = 0; i < document.pages.length; i++) {
      final page = document.pages[i];
      final pageText = await page.loadText();
      pages.add(PdfPageContent(
        pageNumber: i + 1,
        content: pageText.fullText,
      ));
    }

    await document.dispose();
    return pages;
  }

  /// 获取指定章节的页面范围
  Future<List<int>> getChapterPageRange(
      String filePath, int chapterIndex) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = await PdfDocument.openData(bytes);

    final chapters = await _detectChapters(document);
    await document.dispose();

    if (chapterIndex < chapters.length) {
      final chapter = chapters[chapterIndex];
      return List.generate(
        chapter.endPage - chapter.startPage + 1,
        (index) => chapter.startPage + index,
      );
    }

    return [1]; // 默认返回第一页
  }

  /// 获取指定页面的内容
  Future<PdfPageContent> getPageContent(String filePath, int pageNumber) async {
    final document = await PdfDocument.openFile(filePath);

    final page = document.pages[pageNumber - 1];
    final pageText = await page.loadText();

    await document.dispose();

    return PdfPageContent(
      pageNumber: pageNumber,
      content: pageText.fullText,
    );
  }
}

class PdfChapter {
  final int index;
  final String title;
  final int startPage;
  final int endPage;

  PdfChapter({
    required this.index,
    required this.title,
    required this.startPage,
    required this.endPage,
  });
}

class PdfPageContent {
  final int pageNumber;
  final String content;

  PdfPageContent({
    required this.pageNumber,
    required this.content,
  });
}
