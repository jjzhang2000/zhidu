import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/pdf_service.dart';

class PdfReaderScreen extends StatefulWidget {
  final Book book;
  final int chapterIndex;
  final int currentPage;

  const PdfReaderScreen({
    Key? key,
    required this.book,
    required this.chapterIndex,
    required this.currentPage,
  }) : super(key: key);

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late Book _book;
  late int _chapterIndex;
  late int _currentPage;
  late PageController _pageController;
  List<String> _pageContents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _chapterIndex = widget.chapterIndex;
    _currentPage = widget.currentPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadChapterPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadChapterPages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取当前章节的所有页面
      final pageRange =
          await PdfService().getChapterPageRange(_book.filePath, _chapterIndex);

      final contents = <String>[];
      for (final pageNumber in pageRange) {
        final pageContent =
            await PdfService().getPageContent(_book.filePath, pageNumber);
        contents.add(pageContent.content);
      }

      setState(() {
        _pageContents = contents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _pageContents = ['加载章节失败: $e'];
        _isLoading = false;
      });
    }
  }

  void _onPageChanged(int pageIndex) {
    setState(() {
      _currentPage = pageIndex + 1;
    });
  }

  Future<void> _navigateToChapter(int chapterIndex) async {
    // TODO: 实现章节导航逻辑
    setState(() {
      _chapterIndex = chapterIndex;
      _currentPage = 1; // 章节的第一页
    });
    await _loadChapterPages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_book.title} - 第$_chapterIndex章'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _pageContents.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Text(
                      _pageContents[index],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () => _navigateToChapter(_chapterIndex - 1),
              tooltip: '前一章',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (_currentPage > 1) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              tooltip: '前一页',
            ),
            Text('第$_currentPage页 / ${_pageContents.length}'),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                if (_currentPage < _pageContents.length) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              tooltip: '后一页',
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () => _navigateToChapter(_chapterIndex + 1),
              tooltip: '后一章',
            ),
          ],
        ),
      ),
    );
  }
}
