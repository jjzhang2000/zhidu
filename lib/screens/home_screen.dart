// ============================================================================
// 文件名：home_screen.dart
// 功能：应用首页界面，包含书架展示、书籍导入、搜索等功能
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zhidu/l10n/app_localizations.dart';
import '../services/book_service.dart';
import '../services/library_import_service.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';
import '../models/book.dart';
import 'book_screen.dart';
import 'settings_screen.dart';

/// 应用首页：书架展示、搜索、排序与书籍导入入口
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _bookService = BookService();
  final _libraryImportService = LibraryImportService();

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _shelfFocusNode = FocusNode();

  String _searchQuery = '';
  BookSortType _sortType = SettingsService().bookshelfSortType.value;

  @override
  void initState() {
    super.initState();
    _libraryImportService.refreshSignal.addListener(_onLibraryRefresh);
  }

  @override
  void dispose() {
    _libraryImportService.refreshSignal.removeListener(_onLibraryRefresh);
    _searchController.dispose();
    _scrollController.dispose();
    _shelfFocusNode.dispose();
    super.dispose();
  }

  /// 书库后台导入刷新信号回调（每实际新增 50 本或导入完成时触发）
  void _onLibraryRefresh() {
    if (mounted) setState(() {});
  }

  /// 按当前排序方式排列书架书籍
  List<Book> _sortedBooks() {
    final books = List<Book>.from(_bookService.books);
    books.sort((a, b) {
      switch (_sortType) {
        case BookSortType.lastRead:
          final ta = a.lastReadAt;
          final tb = b.lastReadAt;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        case BookSortType.addedAsc:
          return a.addedAt.compareTo(b.addedAt);
        case BookSortType.addedDesc:
          return b.addedAt.compareTo(a.addedAt);
        case BookSortType.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case BookSortType.titleDesc:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        case BookSortType.authorAsc:
          return a.author.toLowerCase().compareTo(b.author.toLowerCase());
        case BookSortType.authorDesc:
          return b.author.toLowerCase().compareTo(a.author.toLowerCase());
      }
    });
    return books;
  }

  /// 排序方式的显示名称
  String _sortLabel(BuildContext context, BookSortType type) {
    final loc = AppLocalizations.of(context);
    switch (type) {
      case BookSortType.lastRead:
        return loc?.sortLastRead ?? '最近阅读时间';
      case BookSortType.addedAsc:
        return loc?.sortAddedAsc ?? '加入时间-递增';
      case BookSortType.addedDesc:
        return loc?.sortAddedDesc ?? '加入时间-递减';
      case BookSortType.titleAsc:
        return loc?.sortTitleAsc ?? '书名-递增';
      case BookSortType.titleDesc:
        return loc?.sortTitleDesc ?? '书名-递减';
      case BookSortType.authorAsc:
        return loc?.sortAuthorAsc ?? '作者-递增';
      case BookSortType.authorDesc:
        return loc?.sortAuthorDesc ?? '作者-递减';
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = _searchQuery.isEmpty
        ? _sortedBooks()
        : _bookService.searchBooks(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)?.appTitle ?? '智读'),
            const SizedBox(width: 6),
            Text(
              _searchQuery.isEmpty
                  ? '(${_bookService.books.length})'
                  : '(${books.length}/${_bookService.books.length})',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            width: 160,
            height: 32,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
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
          PopupMenuButton<BookSortType>(
            icon: const Icon(Icons.swap_vert),
            tooltip: AppLocalizations.of(context)?.sortBy ?? '排序',
            onSelected: (type) {
              setState(() {
                _sortType = type;
              });
              SettingsService().setBookshelfSortType(type);
            },
            itemBuilder: (context) => BookSortType.values.map((type) {
              return CheckedPopupMenuItem(
                value: type,
                checked: type == _sortType,
                child: Text(_sortLabel(context, type)),
              );
            }).toList(),
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
    return Focus(
      focusNode: _shelfFocusNode,
      autofocus: true,
      onKeyEvent: _handleShelfKey,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 3 / 4.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return BookCard(
            book: book,
            onDeleted: () => setState(() {}),
            onOpened: () {
              if (_sortType == BookSortType.lastRead) {
                setState(() {});
              }
            },
          );
        },
      ),
    );
  }

  /// 处理书架键盘滚动（PgUp/PgDn/上下箭头）
  KeyEventResult _handleShelfKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_scrollController.hasClients) return KeyEventResult.ignored;

    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    double delta = 0;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      delta = -viewport * 0.2;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      delta = viewport * 0.2;
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      delta = -viewport * 0.9;
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      delta = viewport * 0.9;
    } else {
      return KeyEventResult.ignored;
    }

    final target =
        (position.pixels + delta).clamp(0.0, position.maxScrollExtent).toDouble();
    _scrollController.jumpTo(target);
    return KeyEventResult.handled;
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

/// 书籍卡片：封面、书名、作者与阅读进度，悬停显示删除按钮
class BookCard extends StatefulWidget {
  final Book book;

  final VoidCallback? onDeleted;

  /// 打开书籍详情返回后的回调（用于刷新书架排序）
  final VoidCallback? onOpened;

  const BookCard({
    super.key,
    required this.book,
    this.onDeleted,
    this.onOpened,
  });

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  bool _isHovered = false;

  final _bookService = BookService();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _openBook(),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.4),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCover(),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.book.format == BookFormat.pdf ? 'PDF' : 'EPUB',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.75),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const titleStyle = TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        height: 1.2,
                      );
                      final titlePainter = TextPainter(
                        text: TextSpan(
                          text: widget.book.title,
                          style: titleStyle,
                        ),
                        maxLines: 2,
                        textDirection: Directionality.of(context),
                      )..layout(maxWidth: constraints.maxWidth);
                      final titleOverflow = titlePainter.didExceedMaxLines;

                      final titleText = Text(
                        widget.book.title,
                        style: titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (titleOverflow)
                            Tooltip(
                              message: widget.book.title,
                              child: titleText,
                            )
                          else
                            titleText,
                          const SizedBox(height: 2),
                          Text(
                            widget.book.author,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.book.readingProgress > 0) ...[
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: widget.book.readingProgress,
                              backgroundColor: Colors.grey[200],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (_isHovered)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Material(
                    color: Colors.red.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _showDeleteConfirmDialog,
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
      ),
    );
  }

  Widget _buildCover() {
    if (widget.book.coverPath != null &&
        File(widget.book.coverPath!).existsSync()) {
      return Image.file(
        File(widget.book.coverPath!),
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
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

  /// 打开书籍详情页（阅读入口在详情页的「阅读」按钮）
  void _openBook() async {
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
    widget.onOpened?.call();
  }

  Future<void> _showDeleteConfirmDialog() async {
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
          SnackBar(content: Text(loc.failed)),
        );
      }
    }
  }
}
