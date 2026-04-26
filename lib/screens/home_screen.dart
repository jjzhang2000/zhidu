/// ============================================================================
/// 文件名：home_screen.dart
/// 功能：应用首页界面，包含书架展示、书籍导入、搜索等功能
/// 主要组件：
///   - HomeScreen: 首页入口组件，管理底部导航和书籍导入
///   - BookshelfScreen: 书架界面，展示书籍列表和搜索功能
///   - BookCard: 书籍卡片组件，显示封面、标题、作者等信息
/// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zhidu/l10n/app_localizations.dart';
import '../services/book_service.dart';
import '../services/summary_service.dart';
import '../services/log_service.dart';
import '../models/book.dart';
import 'book_detail_screen.dart';
import 'settings_screen.dart';

/// ============================================================================
/// 类名：HomeScreen
/// 功能：应用首页入口组件
/// 父类：StatefulWidget
/// 说明：
///   - 作为应用的主界面容器
///   - 包含书架界面（BookshelfScreen）
///   - 提供悬浮按钮触发书籍导入
///   - 使用GlobalKey管理子组件状态，支持导入后刷新书架
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
  /// 书籍服务实例，用于导入书籍
  final _bookService = BookService();

  /// 日志服务实例，用于调试日志输出
  final _log = LogService();

  /// 书架组件的GlobalKey，用于在导入书籍后刷新书架列表
  /// 通过currentState?.refresh()调用子组件方法
  final GlobalKey<_BookshelfScreenState> _bookshelfKey = GlobalKey();

  /// 方法名：initState
  /// 功能：组件初始化生命周期方法
  /// 说明：记录初始化日志，调用父类初始化
  @override
  void initState() {
    _log.v('HomeScreen', '_HomeScreenState initState 开始执行');
    super.initState();
  }

  /// 方法名：build
  /// 功能：构建首页UI
  /// 返回值：Widget - 首页Scaffold组件
  /// 说明：
  ///   - body: 书架界面（BookshelfScreen）
  ///   - floatingActionButton: 悬浮按钮，点击触发书籍导入
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

  /// 方法名：_importBook
  /// 功能：导入书籍的异步方法
  /// 流程：
  ///   1. 调用BookService.importBook()打开文件选择器
  ///   2. 用户选择EPUB/PDF文件后进行解析
  ///   3. 导入成功后刷新书架列表
  ///   4. 显示成功提示SnackBar
  /// 说明：
  ///   - book为null表示用户取消选择或导入失败
  ///   - 使用mounted检查确保组件仍然存在于树中
  ///   - 通过_bookshelfKey.currentState?.refresh()刷新书架
  Future<void> _importBook() async {
    _log.v('HomeScreen', '_importBook 开始执行');
    final book = await _bookService.importBook();
    if (book != null && mounted) {
      _log.v('HomeScreen', '_importBook 书籍导入成功: ${book.title}');
      _bookshelfKey.currentState?.refresh();
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.addedSuccessfully(book.title)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _log.v('HomeScreen', '_importBook 书籍导入被取消或失败');
    }
  }
}

/// ============================================================================
/// 类名：BookshelfScreen
/// 功能：书架界面组件
/// 父类：StatefulWidget
/// 说明：
///   - 展示书籍网格列表
///   - 提供搜索功能过滤书籍
///   - 包含顶部AppBar和设置按钮
///   - 支持空状态和搜索无结果状态显示
/// ============================================================================
class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

/// ============================================================================
/// 类名：_BookshelfScreenState
/// 功能：BookshelfScreen的状态管理类
/// 父类：State<BookshelfScreen>
/// ============================================================================
class _BookshelfScreenState extends State<BookshelfScreen> {
  /// 书籍服务实例，用于获取书籍列表和搜索
  final _bookService = BookService();

  /// 日志服务实例，用于调试日志输出
  final _log = LogService();

  /// 搜索框控制器，用于获取和清空搜索文本
  final _searchController = TextEditingController();

  /// 当前搜索关键词，用于过滤书籍列表
  String _searchQuery = '';

  /// 方法名：refresh
  /// 功能：刷新书架界面
  /// 调用方：HomeScreen._importBook()（导入书籍后调用）
  /// 说明：通过setState触发重建，重新从BookService获取书籍列表
  void refresh() {
    _log.v('BookshelfScreen', 'refresh 开始执行');
    setState(() {
      _log.v('BookshelfScreen', 'setState called in refresh');
    });
  }

  /// 方法名：dispose
  /// 功能：组件销毁生命周期方法
  /// 说明：释放_searchController资源，避免内存泄漏
  @override
  void dispose() {
    _log.v('BookshelfScreen', 'dispose 开始执行');
    _searchController.dispose();
    super.dispose();
    _log.v('BookshelfScreen', 'dispose 执行完成');
  }

  /// 方法名：build
  /// 功能：构建书架界面UI
  /// 返回值：Widget - 书架Scaffold组件
  /// 说明：
  ///   - AppBar包含标题、搜索框、设置按钮
  ///   - 根据搜索关键词过滤书籍列表
  ///   - 空状态显示提示信息
  ///   - 非空状态显示书籍网格
  @override
  Widget build(BuildContext context) {
    _log.v('BookshelfScreen', 'build 开始执行, searchQuery: $_searchQuery');

    /// 根据搜索关键词决定获取全部书籍还是过滤书籍
    /// 空关键词：返回全部书籍
    /// 非空关键词：返回匹配的书籍
    final books = _searchQuery.isEmpty
        ? _bookService.books
        : _bookService.searchBooks(_searchQuery);
    _log.v('BookshelfScreen', 'build 找到书籍数量: ${books.length}');

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.appTitle ?? '智读'),
        centerTitle: true,
        actions: [
          /// 搜索框容器
          /// 宽度160，高度32，圆角16
          /// 使用半透明白色背景
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
                    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
              style: const TextStyle(color: Colors.white, fontSize: 13),

              /// 输入变化时更新搜索关键词，触发重建过滤书籍
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          /// 设置按钮，点击跳转到设置页面
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

      /// 根据书籍列表是否为空显示不同内容
      /// 空列表：显示空状态提示
      /// 非空列表：显示书籍网格
      body: books.isEmpty
          ? _buildEmptyState(isSearching: _searchQuery.isNotEmpty)
          : _buildBookGrid(books),
    );
  }

  /// 方法名：_buildEmptyState
  /// 功能：构建空状态UI
  /// 参数：isSearching - 是否正在搜索（区分空书架和搜索无结果）
  /// 返回值：Widget - 空状态居中组件
  /// 说明：
  ///   - 空书架：显示书籍图标和"书架空空如也"提示
  ///   - 搜索无结果：显示搜索图标和"未找到相关书籍"提示
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
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching 
              ? (AppLocalizations.of(context)?.tryOtherKeywords ?? '请尝试其他关键词') 
              : (AppLocalizations.of(context)?.clickToAddBooks ?? '点击右下角按钮添加书籍'),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// 方法名：_buildBookGrid
  /// 功能：构建书籍网格列表
  /// 参数：books - 要显示的书籍列表
  /// 返回值：Widget - GridView组件
  /// 说明：
  ///   - 每行4列（crossAxisCount: 4）
  ///   - 宽高比0.7（竖向卡片）
  ///   - 卡片间距12
  ///   - 每个书籍用BookCard组件展示
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
  /// 书籍数据模型
  final Book book;

  /// 删除回调函数，删除后刷新父组件
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
  /// 鼠标是否悬停在卡片上，用于控制删除按钮显示
  bool _isHovered = false;

  /// 书籍服务实例，用于获取最新书籍信息和删除书籍
  final _bookService = BookService();

  /// 摘要服务实例，用于删除书籍时同时删除相关摘要
  final _summaryService = SummaryService();

  /// 方法名：build
  /// 功能：构建书籍卡片UI
  /// 返回值：Widget - 卡片组件
  /// 说明：
  ///   - MouseRegion监听鼠标进入/离开，控制删除按钮显示
  ///   - GestureDetector处理点击，进入书籍详情
  ///   - 封面占卡片高度的4/5（Expanded flex: 4）
  ///   - 信息区占卡片高度的1/5（Expanded flex: 1）
  ///   - 阅读进度大于0时显示进度条
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      /// 鼠标进入时显示删除按钮
      onEnter: (_) => setState(() => _isHovered = true),

      /// 鼠标离开时隐藏删除按钮
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        /// 点击卡片打开书籍详情
        onTap: () => _openBook(context),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// 封面区域，占卡片高度的4/5
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    /// 封面图片或默认封面
                    _buildCover(),

                    /// 悬停时显示删除按钮（右下角红色圆形按钮）
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

              /// 信息区域，占卡片高度的1/5
              /// 包含标题、作者、阅读进度条
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 书籍标题，单行显示，超出省略
                      Flexible(  // 添加Flexible以确保在空间不足时可以收缩
                        child: Text(
                          widget.book.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
 
                      /// 作者名称，单行显示，超出省略
                      Flexible(  // 添加Flexible以允许收缩
                        child: Text(
                          widget.book.author,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
 
                      /// 阅读进度条，仅当有进度时显示
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

  /// 方法名：_buildCover
  /// 功能：构建书籍封面
  /// 返回值：Widget - 封面组件
  /// 说明：
  ///   - 优先显示本地封面图片（book.coverPath）
  ///   - 封面文件不存在或加载失败时显示默认封面
  Widget _buildCover() {
    if (widget.book.coverPath != null &&
        File(widget.book.coverPath!).existsSync()) {
      return Image.file(
        File(widget.book.coverPath!),
        fit: BoxFit.cover,

        /// 图片加载失败时显示默认封面
        errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
      );
    }
    return _buildDefaultCover();
  }

  /// 方法名：_buildDefaultCover
  /// 功能：构建默认封面（无封面图片时显示）
  /// 返回值：Widget - 默认封面组件
  /// 说明：灰色背景 + 书籍图标
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

  /// 方法名：_openBook
  /// 功能：打开书籍详情页
  /// 参数：context - BuildContext
  /// 流程：
  ///   1. 从BookService获取最新书籍信息（确保数据同步）
  ///   2. 跳转到BookDetailScreen
  ///   3. 返回后刷新卡片状态（更新阅读进度等）
  /// 说明：使用mounted检查确保组件仍存在
  void _openBook(BuildContext context) async {
    /// 获取最新书籍信息，避免使用过时数据
    final latestBook = _bookService.getBookById(widget.book.id) ?? widget.book;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookDetailScreen(book: latestBook),
      ),
    );

    /// 返回后刷新卡片，更新阅读进度显示
    if (mounted) {
      setState(() {});
    }
  }

  /// 方法名：_showDeleteConfirmDialog
  /// 功能：显示删除确认对话框
  /// 参数：context - BuildContext
  /// 流程：
  ///   1. 显示确认对话框
  ///   2. 用户确认后调用BookService删除书籍
  ///   3. 调用SummaryService删除相关摘要
  ///   4. 调用onDeleted回调刷新书架列表
  ///   5. 显示删除成功提示
  /// 说明：
  ///   - confirmed为true表示用户确认删除
  ///   - 删除书籍同时删除关联的章节摘要
  ///   - 使用mounted检查确保组件仍存在
  Future<void> _showDeleteConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.confirmRemoval ?? '确认移除'),
        content: Text(AppLocalizations.of(context)?.removeConfirmation(widget.book.title) ?? '确定要从书架移除《${widget.book.title}》吗？'),
        actions: [
          /// 取消按钮
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? '取消'),
          ),

          /// 移除按钮（红色警告样式）
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)?.remove ?? '移除'),
          ),
        ],
      ),
    );

    /// 用户确认删除后执行删除操作
    if (confirmed == true && mounted) {
      /// 删除书籍记录
      await _bookService.deleteBook(widget.book.id);

      /// 删除该书籍的所有摘要数据
      await _summaryService.deleteAllSummariesForBook(widget.book.id);

      /// 通知父组件刷新列表
      widget.onDeleted?.call();

      /// 显示删除成功提示
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.removedSuccessfully(widget.book.title))),
        );
      }
    }
  }
}
