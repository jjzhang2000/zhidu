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
      final chapters = _detectChapters(document);

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
  List<PdfChapter> _detectChapters(PdfDocument document) {
    final chapters = <PdfChapter>[];
    final totalPages = document.pages.length;

    // 简单的章节检测：假设每10页为一个章节（后续可改进）
    const pagesPerChapter = 10;
    final totalChapters = (totalPages / pagesPerChapter).ceil();

    for (int i = 0; i < totalChapters; i++) {
      final startPage = i * pagesPerChapter + 1;
      final endPage = (i + 1) * pagesPerChapter < totalPages
          ? (i + 1) * pagesPerChapter
          : totalPages;

      chapters.add(PdfChapter(
        index: i,
        title: '第${i + 1}章',
        startPage: startPage,
        endPage: endPage,
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
