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
  String _pageContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _chapterIndex = widget.chapterIndex;
    _currentPage = widget.currentPage;
    _loadPageContent();
  }

  Future<void> _loadPageContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pageContent =
          await PdfService().getPageContent(_book.filePath, _currentPage);
      setState(() {
        _pageContent = pageContent.content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _pageContent = '加载页面失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToPage(int pageNumber) async {
    if (pageNumber < 1 || pageNumber > 1000) return; // TODO: 获取实际总页数

    setState(() {
      _currentPage = pageNumber;
    });
    await _loadPageContent();
  }

  Future<void> _navigateToChapter(int chapterIndex) async {
    // TODO: 实现章节导航逻辑
    setState(() {
      _chapterIndex = chapterIndex;
      _currentPage = 1; // 章节的第一页
    });
    await _loadPageContent();
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
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _pageContent,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
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
              onPressed: () => _navigateToPage(_currentPage - 1),
              tooltip: '前一页',
            ),
            Text('第$_currentPage页'),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _navigateToPage(_currentPage + 1),
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
