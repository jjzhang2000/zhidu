import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdfrx/pdfrx.dart';
import '../models/chapter_summary.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/ai_service.dart';
import '../services/summary_service.dart';
import '../services/book_service.dart';
import '../services/parsers/format_registry.dart';
import '../services/log_service.dart';

class SummaryScreen extends StatefulWidget {
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String? chapterContent;
  final String? filePath;
  final List<Chapter>? chapters;
  final Book? book;

  const SummaryScreen({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.chapterContent,
    this.filePath,
    this.chapters,
    this.book,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _aiService = AIService();
  final _log = LogService();
  final _summaryService = SummaryService();
  final _bookService = BookService();

  ChapterSummary? _summary;
  bool _isGenerating = false;
  String? _error;

  bool _isLoadingContent = false;
  String _content = '';
  String _title = '';
  bool _showOriginalText = false;
  bool _contentTooShort = false;
  List<Chapter> _chapters = [];

  // PDF相关状态
  int _pdfCurrentPage = 1;
  int _pdfTotalPages = 0;

  @override
  void initState() {
    super.initState();
    // 只保留第一级章节
    if (widget.chapters != null) {
      _chapters = widget.chapters!.where((c) => c.level == 0).toList();
    }
    _initializeContent().then((_) {
      _loadSummary();
    });
  }

  Future<void> _initializeContent() async {
    if (widget.chapterContent != null && widget.chapterContent!.isNotEmpty) {
      _content = widget.chapterContent!;
      _title = widget.chapterTitle;
      _checkContentLength();
      if (!mounted) return;
      setState(() => _isLoadingContent = false);
      return;
    }

    if (widget.filePath != null) {
      if (!mounted) return;
      setState(() => _isLoadingContent = true);
      await _loadChapterContent();
      return;
    }

    if (!mounted) return;
    setState(() {
      _error = '未提供章节内容或文件路径';
      _isLoadingContent = false;
    });
  }

  void _checkContentLength() {
    final textContent = _extractTextContent(_content);
    final byteLength = utf8.encode(textContent).length;
    _contentTooShort = byteLength < 2000;
    if (_contentTooShort && _summary == null) {
      _showOriginalText = true;
    }
  }

  Future<void> _loadChapterContent() async {
    try {
      List<Chapter> chapters = widget.chapters ?? [];

      if (chapters.isEmpty && widget.filePath != null) {
        _log.d('SummaryScreen', '使用FormatRegistry加载章节列表');
        // 获取格式类型并加载章节
        final extension = _getFileExtension(widget.filePath!);
        final parser = FormatRegistry.getParser(extension);

        if (parser != null) {
          chapters = await parser.getChapters(widget.filePath!);
        } else {
          _log.e('SummaryScreen', '不支持的格式: $extension');
        }
      }

      // 只取第一级章节
      final topLevelChapters = chapters.where((c) => c.level == 0).toList();
      _chapters = topLevelChapters;

      _log.d('SummaryScreen',
          '第一级章节总数: ${topLevelChapters.length}, 请求索引: ${widget.chapterIndex}');

      if (widget.chapterIndex < 0 ||
          widget.chapterIndex >= topLevelChapters.length) {
        if (!mounted) return;
        setState(() {
          _error =
              '章节索引超出范围: ${widget.chapterIndex}, 总章节数: ${topLevelChapters.length}';
          _isLoadingContent = false;
        });
        return;
      }

      final chapter = topLevelChapters[widget.chapterIndex];
      _title = chapter.title;

      // 使用FormatRegistry获取章节内容
      String? content;
      try {
        if (widget.filePath != null) {
          final extension = _getFileExtension(widget.filePath!);
          final parser = FormatRegistry.getParser(extension);

          if (parser != null) {
            final chapterContent = await parser.getChapterContent(
              widget.filePath!,
              chapter,
            );
            content = chapterContent.htmlContent;
          }
        }
      } catch (e) {
        _log.e('SummaryScreen', '获取章节内容失败', e);
      }

      if (content == null || content.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = '章节内容为空';
          _isLoadingContent = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _content = content ?? '';
        _isLoadingContent = false;
      });
      _checkContentLength();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载章节内容失败: $e';
        _isLoadingContent = false;
      });
    }
  }

  Future<void> _loadSummary() async {
    final generatingFuture =
        _summaryService.getGeneratingFuture(widget.bookId, widget.chapterIndex);

    if (generatingFuture != null) {
      _log.d('SummaryScreen', '章节摘要正在后台生成中，等待完成');
      setState(() {
        _isGenerating = true;
      });
      try {
        await generatingFuture;
        if (!mounted) return;
        final summary = await _summaryService.getSummary(
            widget.bookId, widget.chapterIndex);
        setState(() {
          _summary = summary;
          _isGenerating = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = '生成摘要失败: $e';
          _isGenerating = false;
        });
      }
      return;
    }

    final summary =
        await _summaryService.getSummary(widget.bookId, widget.chapterIndex);
    if (!mounted) return;
    setState(() {
      _summary = summary;
    });
  }

  Future<void> _generateSummary() async {
    if (_content.isEmpty) {
      setState(() {
        _error = '无法生成摘要：章节内容为空';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final plainText = _extractTextContent(_content);

      final success = await _summaryService.generateSingleSummary(
        widget.bookId,
        widget.chapterIndex,
        _title,
        plainText,
      );

      if (!mounted) return;

      if (success) {
        final summary = await _summaryService.getSummary(
          widget.bookId,
          widget.chapterIndex,
        );

        final updatedBook = _bookService.getBookById(widget.bookId);
        if (updatedBook != null) {
          final newTitle = updatedBook.chapterTitles?[widget.chapterIndex];
          setState(() {
            _summary = summary;
            _title = newTitle ?? _title;
            _isGenerating = false;
          });
        } else {
          setState(() {
            _summary = summary;
            _isGenerating = false;
          });
        }
      } else {
        setState(() {
          _error = '生成摘要失败';
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '生成摘要失败: $e';
        _isGenerating = false;
      });
    }
  }

  String _extractTextContent(String html) {
    // 使用正则表达式移除HTML标签
    final text = html.replaceAll(RegExp(r'<[^>]+>'), '');
    // 解码HTML实体
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
  }

  /// 获取文件扩展名（包含点，如 .epub）
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filePath.substring(lastDot).toLowerCase();
  }

  String _getChapterTitle(int index, String defaultTitle) {
    if (widget.book != null) {
      final titles = widget.book!.chapterTitles;
      if (titles != null && titles.containsKey(index)) {
        return titles[index]!;
      }
    }
    return defaultTitle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getChapterTitle(widget.chapterIndex, widget.chapterTitle),
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_summary == null && !_isGenerating && _content.isNotEmpty)
            TextButton.icon(
              onPressed: _generateSummary,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text('生成摘要'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_chapters.length > 1) _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingContent) {
      return _buildLoadingView();
    }

    if (_error != null && _content.isEmpty) {
      return _buildErrorView();
    }

    if (_isGenerating) {
      return _buildGeneratingView();
    }

    return _buildSummaryView();
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '正在加载章节内容...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'AI 正在生成摘要...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '这可能需要几秒钟',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              '出错了',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateSummary,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    // 对于PDF，原文阅读按钮跳转到PDF阅读界面
    final bool isPdf =
        widget.book != null && widget.book!.format == BookFormat.pdf;
    final bool aiButtonDisabled = (_contentTooShort && _showOriginalText) ||
        (!_aiService.isConfigured && _showOriginalText && _summary == null);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 14),
            child: InkWell(
              onTap: aiButtonDisabled
                  ? null
                  : () {
                      setState(() {
                        _showOriginalText = !_showOriginalText;
                      });
                    },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: aiButtonDisabled
                      ? Colors.grey.withAlpha(30)
                      : Theme.of(context).colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _showOriginalText ? Icons.auto_awesome : Icons.menu_book,
                  size: 20,
                  color: aiButtonDisabled
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _showOriginalText || _summary == null
                ? _buildOriginalTextView()
                : _buildSummaryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryContent() {
    final htmlContent = md.markdownToHtml(_summary!.objectiveSummary);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '本章摘要',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Html(
                      data: htmlContent,
                      style: {
                        'body': Style(
                          fontSize: FontSize(14),
                          lineHeight: const LineHeight(1.6),
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                        'h2': Style(
                          fontSize: FontSize(15),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(bottom: 8, top: 16),
                        ),
                        'h3': Style(
                          fontSize: FontSize(14),
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOriginalTextView() {
    final isPdf = widget.book != null && widget.book!.format == BookFormat.pdf;

    if (isPdf && widget.filePath != null) {
      // PDF格式：显示单页PDF查看器
      final currentChapter =
          _chapters.isNotEmpty ? _chapters[widget.chapterIndex] : null;
      final startPage = currentChapter?.location.startPage ?? 1;

      // 初始化当前页码
      if (_pdfCurrentPage < startPage) {
        _pdfCurrentPage = startPage;
      }

      return PdfDocumentViewBuilder.file(
        widget.filePath!,
        builder: (context, document) {
          if (document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _pdfTotalPages = document.pages.length;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Colors.grey.withAlpha(30),
              child: PdfPageView(
                document: document,
                pageNumber: _pdfCurrentPage.clamp(1, _pdfTotalPages),
              ),
            ),
          );
        },
      );
    }

    // EPUB/其他格式：显示HTML内容
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Html(
                data: _content,
                style: {
                  'body': Style(
                    fontSize: FontSize(16),
                    lineHeight: const LineHeight(1.8),
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  'p': Style(
                    margin: Margins.only(bottom: 16),
                    lineHeight: const LineHeight(1.8),
                  ),
                  'h1': Style(
                    fontSize: FontSize(20),
                    fontWeight: FontWeight.bold,
                    margin: Margins.only(bottom: 16, top: 24),
                  ),
                  'h2': Style(
                    fontSize: FontSize(18),
                    fontWeight: FontWeight.bold,
                    margin: Margins.only(bottom: 14, top: 20),
                  ),
                  'h3': Style(
                    fontSize: FontSize(17),
                    fontWeight: FontWeight.bold,
                    margin: Margins.only(bottom: 12, top: 16),
                  ),
                  'code': Style(
                    fontFamily: 'monospace',
                    fontSize: FontSize(14),
                  ),
                  'pre': Style(
                    fontFamily: 'monospace',
                    fontSize: FontSize(14),
                    padding: HtmlPaddings.all(8),
                    margin: Margins.only(bottom: 16),
                  ),
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;

    final chapter = _chapters[index];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SummaryScreen(
          bookId: widget.bookId,
          chapterIndex: index,
          chapterTitle: chapter.title,
          filePath: widget.filePath,
          chapters: _chapters,
          book: widget.book,
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isFirst = widget.chapterIndex <= 0;
    final isLast = widget.chapterIndex >= _chapters.length - 1;
    final isPdf = widget.book != null && widget.book!.format == BookFormat.pdf;
    final isPdfOriginalView = isPdf && _showOriginalText;

    // 判断是否可以翻页（仅PDF原文阅读时）
    final currentChapter =
        _chapters.isNotEmpty ? _chapters[widget.chapterIndex] : null;
    final startPage = currentChapter?.location.startPage ?? 1;
    final endPage = currentChapter?.location.endPage ?? startPage;
    final canPrevPage = isPdfOriginalView && _pdfCurrentPage > startPage;
    final canNextPage = isPdfOriginalView && _pdfCurrentPage < endPage;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // << 上一章按钮
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(76),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: isFirst
                  ? null
                  : () => _navigateToChapter(widget.chapterIndex - 1),
              icon: Icon(
                Icons.keyboard_double_arrow_left,
                color: isFirst ? Colors.grey.shade600 : Colors.white,
                size: 28,
              ),
            ),
          ),
          // < 上一页按钮（仅PDF原文阅读时显示）
          if (isPdfOriginalView)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(76),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: canPrevPage
                    ? () {
                        setState(() {
                          _pdfCurrentPage--;
                        });
                      }
                    : null,
                icon: Icon(
                  Icons.chevron_left,
                  color: canPrevPage ? Colors.white : Colors.grey.shade600,
                  size: 28,
                ),
              ),
            ),
          // 空位填充（当不显示翻页按钮时）
          if (!isPdfOriginalView) const SizedBox(width: 48),
          // > 下一页按钮（仅PDF原文阅读时显示）
          if (isPdfOriginalView)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(76),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: canNextPage
                    ? () {
                        setState(() {
                          _pdfCurrentPage++;
                        });
                      }
                    : null,
                icon: Icon(
                  Icons.chevron_right,
                  color: canNextPage ? Colors.white : Colors.grey.shade600,
                  size: 28,
                ),
              ),
            ),
          // 空位填充（当不显示翻页按钮时）
          if (!isPdfOriginalView) const SizedBox(width: 48),
          // >> 下一章按钮
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(76),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: isLast
                  ? null
                  : () => _navigateToChapter(widget.chapterIndex + 1),
              icon: Icon(
                Icons.keyboard_double_arrow_right,
                color: isLast ? Colors.grey.shade600 : Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
