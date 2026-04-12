import 'dart:io';

import 'package:flutter/material.dart';
import '../services/book_service.dart';
import '../services/summary_service.dart';
import '../services/log_service.dart';
import '../models/book.dart';
import 'book_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _bookService = BookService();
  final _log = LogService();
  final GlobalKey<_BookshelfScreenState> _bookshelfKey = GlobalKey();

  @override
  void initState() {
    _log.v('HomeScreen', '_HomeScreenState initState 开始执行');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _log.v('HomeScreen', 'build 开始执行');
    return Scaffold(
      body: BookshelfScreen(key: _bookshelfKey),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _importBook(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _importBook() async {
    _log.v('HomeScreen', '_importBook 开始执行');
    final book = await _bookService.importBook();
    if (book != null && mounted) {
      _log.v('HomeScreen', '_importBook 书籍导入成功: ${book.title}');
      _bookshelfKey.currentState?.refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加: ${book.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _log.v('HomeScreen', '_importBook 书籍导入被取消或失败');
    }
  }
}

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  final _bookService = BookService();
  final _log = LogService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  void refresh() {
    _log.v('BookshelfScreen', 'refresh 开始执行');
    setState(() {
      _log.v('BookshelfScreen', 'setState called in refresh');
    });
  }

  @override
  void dispose() {
    _log.v('BookshelfScreen', 'dispose 开始执行');
    _searchController.dispose();
    super.dispose();
    _log.v('BookshelfScreen', 'dispose 执行完成');
  }

  @override
  Widget build(BuildContext context) {
    _log.v('BookshelfScreen', 'build 开始执行, searchQuery: $_searchQuery');
    final books = _searchQuery.isEmpty
        ? _bookService.books
        : _bookService.searchBooks(_searchQuery);
    _log.v('BookshelfScreen', 'build 找到书籍数量: ${books.length}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('智读'),
        centerTitle: true,
        actions: [
          Container(
            width: 160,
            height: 32,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜索',
                hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.white70, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: books.isEmpty
          ? _buildEmptyState(isSearching: _searchQuery.isNotEmpty)
          : _buildBookGrid(books),
    );
  }

  Widget _buildEmptyState({bool isSearching = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.library_books,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? '未找到相关书籍' : '书架空空如也',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching ? '请尝试其他关键词' : '点击右下角按钮添加书籍',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookGrid(List<Book> books) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(
          book: book,
          onDeleted: () => setState(() {}),
        );
      },
    );
  }
}

class BookCard extends StatefulWidget {
  final Book book;
  final VoidCallback? onDeleted;

  const BookCard({super.key, required this.book, this.onDeleted});

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  bool _isHovered = false;
  final _bookService = BookService();
  final _summaryService = SummaryService();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _openBook(context),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCover(),
                    if (_isHovered)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Material(
                          color: Colors.red.withOpacity(0.9),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _showDeleteConfirmDialog(context),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.remove,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.book.author,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (widget.book.readingProgress > 0)
                        LinearProgressIndicator(
                          value: widget.book.readingProgress,
                          backgroundColor: Colors.grey[200],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (widget.book.coverPath != null &&
        File(widget.book.coverPath!).existsSync()) {
      return Image.file(
        File(widget.book.coverPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
      );
    }
    return _buildDefaultCover();
  }

  Widget _buildDefaultCover() {
    return Container(
      color: Colors.blueGrey[100],
      child: Center(
        child: Icon(
          Icons.book,
          size: 48,
          color: Colors.blueGrey[300],
        ),
      ),
    );
  }

  void _openBook(BuildContext context) async {
    final latestBook = _bookService.getBookById(widget.book.id) ?? widget.book;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookDetailScreen(book: latestBook),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showDeleteConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认移除'),
        content: Text('确定要从书架移除《${widget.book.title}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _bookService.deleteBook(widget.book.id);
      await _summaryService.deleteAllSummariesForBook(widget.book.id);
      widget.onDeleted?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已移除《${widget.book.title}》')),
        );
      }
    }
  }
}
