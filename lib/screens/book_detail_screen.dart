import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/parsers/format_registry.dart';
import '../models/chapter.dart';
import '../services/ai_service.dart';
import '../services/summary_service.dart';
import '../services/log_service.dart';
import 'summary_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _bookService = BookService();

  final _aiService = AIService();
  final _summaryService = SummaryService();
  final _log = LogService();
  late Book _book;
  List<Chapter> _flatChapters = [];
  bool _isLoadingChapters = false;
  bool _showChapterStructure = false;
  bool _isPreGenerating = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _book = _bookService.getBookById(widget.book.id) ?? widget.book;
    _loadChapters();
    _startPreGeneration();
    // 定时刷新书籍信息，检测全书摘要是否生成完成
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshBookIfNeeded();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    _log.v('BookDetailScreen', '_loadChapters 开始执行');
    setState(() => _isLoadingChapters = true);
    try {
      final parser = FormatRegistry.getParser(_book.format.name);
      if (parser == null) {
        _log.e('BookDetailScreen', '不支持的格式: ${_book.format}');
        setState(() => _isLoadingChapters = false);
        return;
      }

      final chapters = await parser.getChapters(_book.filePath);

      setState(() {
        _flatChapters = chapters;
        _isLoadingChapters = false;
      });

      _log.d('BookDetailScreen', '章节加载完成: ${chapters.length} 个章节');
    } catch (e, stackTrace) {
      _log.e('BookDetailScreen', '加载章节列表失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
        });
      }
    }
  }

  /// 后台静默预生成章节摘要
  void _startPreGeneration() {
    if (!_aiService.isConfigured) {
      _log.d('BookDetailScreen', 'AI服务未配置，跳过预生成');
      return;
    }

    if (_isPreGenerating) {
      _log.d('BookDetailScreen', '已在预生成中，跳过');
      return;
    }

    _isPreGenerating = true;

    // 异步执行，不阻塞UI
    Future(() async {
      try {
        _log.d('BookDetailScreen', '开始后台预生成章节摘要');

        // 先刷新一次，因为 generateSummariesForBook 可能在前台已完成前言摘要
        _refreshBookIfNeeded();

        await _summaryService.generateSummariesForBook(_book);
        _log.d('BookDetailScreen', '后台预生成章节摘要完成');

        _refreshBookIfNeeded();
      } catch (e, stackTrace) {
        _log.e('BookDetailScreen', '后台预生成章节摘要失败', e, stackTrace);
      } finally {
        _isPreGenerating = false;
      }
    });
  }

  void _refreshBookIfNeeded() {
    final refreshedBook = _bookService.getBookById(_book.id);
    if (refreshedBook != null && mounted) {
      if (refreshedBook.aiIntroduction != _book.aiIntroduction) {
        setState(() {
          _book = refreshedBook;
        });
      } else {
        _book = refreshedBook;
      }
    }
  }

  void _toggleView() {
    setState(() {
      _showChapterStructure = !_showChapterStructure;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书籍详情'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 顶部书籍信息区域
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildBookHeader(),
          ),
          const Divider(height: 1),
          // 底部内容区域（可滚动，延伸到窗口底部）
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildAIIntroduction(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCover(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _book.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _book.author,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                      Icons.menu_book,
                      _isLoadingChapters
                          ? '加载中...'
                          : '${_flatChapters.length} 章'),
                  _buildInfoChip(
                      Icons.calendar_today, _formatDate(_book.addedAt)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCover() {
    final coverSize = 120.0;

    if (_book.coverPath != null && File(_book.coverPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_book.coverPath!),
          width: coverSize * 0.7,
          height: coverSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildDefaultCover(coverSize),
        ),
      );
    }
    return _buildDefaultCover(coverSize);
  }

  Widget _buildDefaultCover(double size) {
    return Container(
      width: size * 0.7,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blueGrey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.book,
          size: 40,
          color: Colors.blueGrey[300],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIIntroduction() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧切换按钮（在卡片外部）
        Padding(
          padding: const EdgeInsets.only(top: 14, right: 8),
          child: InkWell(
            onTap: _toggleView,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _showChapterStructure
                    ? Icons.auto_awesome
                    : Icons.format_list_numbered,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        // 主内容卡片
        Expanded(
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _showChapterStructure
                            ? Icons.format_list_numbered
                            : Icons.auto_awesome,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _showChapterStructure ? '目录' : '内容介绍',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // 内容区域（可滚动）
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _showChapterStructure
                        ? _buildChapterStructureContent()
                        : _buildAIIntroductionContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIIntroductionContent() {
    // 没有全书摘要
    if (_book.aiIntroduction == null || _book.aiIntroduction!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              _aiService.isConfigured ? '全书摘要生成中，请稍候...' : 'AI服务未配置，无法生成全书摘要',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 显示全书摘要（Markdown渲染）
    final htmlContent = md.markdownToHtml(_book.aiIntroduction!);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Html(
          data: htmlContent,
          style: {
            'body': Style(
              fontSize: FontSize(14),
              lineHeight: const LineHeight(1.6),
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            'h2': Style(
              fontSize: FontSize(16),
              fontWeight: FontWeight.bold,
              margin: Margins.only(bottom: 8, top: 16),
            ),
            'h3': Style(
              fontSize: FontSize(15),
              fontWeight: FontWeight.bold,
              margin: Margins.only(bottom: 6, top: 12),
            ),
            'p': Style(
              fontSize: FontSize(14),
              lineHeight: const LineHeight(1.6),
              margin: Margins.only(bottom: 8),
            ),
            'ul': Style(
              margin: Margins.only(bottom: 8),
            ),
            'li': Style(
              fontSize: FontSize(14),
              lineHeight: const LineHeight(1.5),
            ),
            'strong': Style(
              fontWeight: FontWeight.bold,
            ),
          },
        ),
      ),
    );
  }

  Widget _buildChapterStructureContent() {
    if (_isLoadingChapters) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_flatChapters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('暂无章节信息'),
        ),
      );
    }
    return ListView(
      children: _buildChapterList(),
    );
  }

  List<Widget> _buildChapterList() {
    final widgets = <Widget>[];
    for (final chapter in _flatChapters) {
      widgets.add(
        ListTile(
          dense: true,
          title: Text(
            chapter.title,
            style: const TextStyle(
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            _log.d('BookDetailScreen', '点击章节: ${chapter.title}');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SummaryScreen(
                  bookId: _book.id,
                  chapterIndex: chapter.index,
                  chapterTitle: chapter.title,
                  filePath: _book.filePath,
                  chapters: _flatChapters,
                  book: _book,
                ),
              ),
            );
          },
        ),
      );
    }
    return widgets;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
