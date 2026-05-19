/// ============================================================================
/// 文件名：home_screen.dart
/// 功能：应用首页界面，包含书架展示、书籍导入、搜索等功能
/// 主要组件：
///   - HomeScreen: 首页入口组件，管理AppBar/FAB/书架展示
///   - BookCard: 书籍卡片组件，显示封面、标题、作者等信息
/// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zhidu/l10n/app_localizations.dart';
import '../services/book_service.dart';
import '../models/book.dart';
import 'book_screen.dart';
import 'settings_screen.dart';

/// ============================================================================
/// 类名：HomeScreen
/// 功能：应用首页入口组件
/// 父类：StatefulWidget
/// 说明：
///   - 作为应用的主界面容器
///   - 包含书架展示、搜索、书籍导入功能
///   - AppBar含搜索框和设置按钮
///   - FAB触发书籍导入
///   - 支持空状态和搜索无结果状态显示
/// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// ============================================================================
/// 类名：_HomeScreenState
/// 功能：HomeScreen的状态管理类
/// 父类：State<HomeScreen>
/// ============================================================================
class _HomeScreenState extends State<HomeScreen> {
  final _bookService = BookService();

  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final books = _searchQuery.isEmpty
        ? _bookService.books
        : _bookService.searchBooks(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.appTitle ?? '智读'),
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
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)?.search ?? '搜索',
                hintStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                border: InputBorder.none,
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white70, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _importBook(),
        child: const Icon(Icons.add),
      ),
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
            isSearching
                ? (AppLocalizations.of(context)?.noRelatedBooks ?? '未找到相关书籍')
                : (AppLocalizations.of(context)?.bookshelfEmpty ?? '书架空空如也'),
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? (AppLocalizations.of(context)?.tryOtherKeywords ?? '请尝试其他关键词')
                : (AppLocalizations.of(context)?.clickToAddBooks ??
                    '点击右下角按钮添加书籍'),
            style: const TextStyle(fontSize: 14, color: Colors.grey),
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
        childAspectRatio: 0.6,
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

  Future<void> _importBook() async {
    final book = await _bookService.importBook();
    if (book != null && mounted) {
      setState(() {});
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.addedSuccessfully(book.title)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// ============================================================================
/// 类名：BookCard
/// 功能：书籍卡片组件
/// 父类：StatefulWidget
/// 说明：
///   - 显示书籍封面、标题、作者
///   - 显示阅读进度条
///   - 鼠标悬停时显示删除按钮
///   - 点击卡片进入书籍详情页
/// ============================================================================
class BookCard extends StatefulWidget {
  final Book book;

  final VoidCallback? onDeleted;

  const BookCard({super.key, required this.book, this.onDeleted});

  @override
  State<BookCard> createState() => _BookCardState();
}

/// ============================================================================
/// 类名：_BookCardState
/// 功能：BookCard的状态管理类
/// 父类：State<BookCard>
/// ============================================================================
class _BookCardState extends State<BookCard> {
  bool _isHovered = false;

  final _bookService = BookService();

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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const neededHeight = 16.0 + 2.0 + 14.0;
                    const progressHeight = 4.0;
                    final hasProgress = widget.book.readingProgress > 0;
                    final totalNeeded =
                        neededHeight + (hasProgress ? progressHeight : 0) + 8.0;

                    double scaleFactor = 1.0;
                    if (constraints.maxHeight < totalNeeded) {
                      scaleFactor = constraints.maxHeight / totalNeeded;
                    }

                    final fontSize = 12.0 * scaleFactor;
                    final authorFontSize = 10.0 * scaleFactor;
                    final gap = 2.0 * scaleFactor;
                    final vPadding = 4.0 * scaleFactor;
                    final hPadding = 8.0 * scaleFactor;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPadding,
                        vertical: vPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.book.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: gap),
                          Text(
                            widget.book.author,
                            style: TextStyle(
                              fontSize: authorFontSize,
                              color: Colors.grey[600],
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.book.readingProgress > 0) ...[
                            const Spacer(),
                            LinearProgressIndicator(
                              value: widget.book.readingProgress,
                              backgroundColor: Colors.grey[200],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
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
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1.0,
          child: Image.file(
            File(widget.book.coverPath!),
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
          ),
        ),
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
        builder: (context) => BookScreen(book: latestBook),
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
        title: Text(AppLocalizations.of(context)?.confirmRemoval ?? '确认移除'),
        content: Text(AppLocalizations.of(context)
                ?.removeConfirmation(widget.book.title) ??
            '确定要从书架移除《${widget.book.title}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? '取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)?.remove ?? '移除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final deleted = await _bookService.deleteBook(widget.book.id);
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      if (deleted) {
        widget.onDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.removedSuccessfully(widget.book.title))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请稍后重试')),
        );
      }
    }
  }
}
