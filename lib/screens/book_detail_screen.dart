import 'dart:io';

import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/summary_service.dart';
import '../services/epub_service.dart' show EpubService, ChapterInfo;
import '../services/ai_service.dart';
import '../services/log_service.dart';
import 'chapter_list_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _bookService = BookService();
  final _epubService = EpubService();
  final _aiService = AIService();
  final _log = LogService();
  late Book _book;
  List<ChapterInfo> _chapters = [];
  List<ChapterInfo> _flatChapters = []; // NEW: flat list for index lookup
  bool _isLoadingChapters = false;
  bool _showChapterStructure = false;
  bool _isGeneratingIntroduction = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _loadChapters();
    _loadOrGenerateIntroduction();
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoadingChapters = true);
    try {
      final chapters =
          await _epubService.getHierarchicalChapterList(_book.filePath);

      final flatChapters = await _epubService.getChapterList(_book.filePath);

      if (mounted) {
        setState(() {
          _chapters = chapters;
          _flatChapters = flatChapters;
          _isLoadingChapters = false;
        });
      }
    } catch (e, stackTrace) {
      _log.e('BookDetailScreen', '加载章节列表失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
        });
      }
    }
  }

  void _toggleView() {
    setState(() {
      _showChapterStructure = !_showChapterStructure;
    });
  }

  /// 加载或生成书籍介绍
  Future<void> _loadOrGenerateIntroduction() async {
    // 如果已有介绍，直接显示
    if (_book.aiIntroduction != null && _book.aiIntroduction!.isNotEmpty) {
      return;
    }

    // 检查AI服务是否配置
    if (!_aiService.isConfigured) {
      return;
    }

    setState(() {
      _isGeneratingIntroduction = true;
    });

    try {
      // 提取前言内容
      final prefaceContent =
          await _epubService.extractPrefaceContent(_book.filePath);

      // 生成书籍介绍
      final introduction = await _aiService.generateBookIntroduction(
        title: _book.title,
        author: _book.author,
        prefaceContent: prefaceContent,
        totalChapters: _book.totalChapters,
      );

      if (introduction != null && introduction.isNotEmpty) {
        // 更新书籍对象
        final updatedBook = _book.copyWith(aiIntroduction: introduction);
        await _bookService.updateBook(updatedBook);

        if (mounted) {
          setState(() {
            _book = updatedBook;
            _isGeneratingIntroduction = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isGeneratingIntroduction = false;
        });
      }
    } catch (e, stackTrace) {
      _log.e('BookDetailScreen', '生成书籍介绍失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isGeneratingIntroduction = false;
        });
      }
    }
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
                  _buildInfoChip(Icons.menu_book, '${_book.totalChapters} 章'),
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
          padding: const EdgeInsets.only(top: 16, right: 8),
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
    // 正在生成中
    if (_isGeneratingIntroduction) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '正在生成内容介绍...',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // 没有介绍且AI未配置
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
              _aiService.isConfigured ? '暂无内容介绍' : 'AI服务未配置，无法生成介绍',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (_aiService.isConfigured) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadOrGenerateIntroduction,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('生成介绍'),
              ),
            ],
          ],
        ),
      );
    }

    // 显示介绍内容
    return SingleChildScrollView(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChapterListScreen(book: _book),
            ),
          );
        },
        child: Text(
          _book.aiIntroduction!,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
          ),
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
    if (_chapters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('暂无章节信息'),
        ),
      );
    }
    return ListView(
      children: _buildChapterTree(_chapters, 0),
    );
  }

  List<Widget> _buildChapterTree(List<ChapterInfo> chapters, int depth) {
    final widgets = <Widget>[];
    for (final chapter in chapters) {
      widgets.add(
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.only(left: depth * 16.0),
          title: Text(
            chapter.title,
            style: const TextStyle(
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChapterListScreen(book: _book),
              ),
            );
          },
        ),
      );
      // 递归添加子章节
      if (chapter.children.isNotEmpty) {
        widgets.addAll(_buildChapterTree(chapter.children, depth + 1));
      }
    }
    return widgets;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
