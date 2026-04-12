import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/chapter_summary.dart';
import '../services/ai_service.dart';
import '../services/summary_service.dart';
import '../services/epub_service.dart';
import '../services/log_service.dart';

class SummaryScreen extends StatefulWidget {
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String? chapterContent;
  final String? filePath;
  final List<ChapterInfo>? chapters;

  const SummaryScreen({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.chapterContent,
    this.filePath,
    this.chapters,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _aiService = AIService();
  final _log = LogService();
  final _summaryService = SummaryService();
  final _epubService = EpubService();

  ChapterSummary? _summary;
  bool _isGenerating = false;
  String? _error;

  bool _isLoadingContent = false;
  String _content = '';
  String _title = '';
  bool _showOriginalText = false;
  bool _contentTooShort = false; // 切换摘要/原文视图
  List<ChapterInfo> _chapters = [];

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
      List<ChapterInfo> chapters = widget.chapters ?? [];
      if (chapters.isEmpty && widget.filePath != null) {
        final allChapters =
            await _epubService.getHierarchicalChapterList(widget.filePath!);
        // 只取第一级章节
        chapters = allChapters.where((c) => c.level == 0).toList();
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

      // 直接从archive获取章节内容
      String? html;
      try {
        if (chapter.href != null) {
          html = await _epubService.getChapterContentFromHref(
              widget.filePath!, chapter.href!);
        }
      } catch (e) {
        _log.e('SummaryScreen', '获取章节内容失败', e);
      }

      if (html == null || html.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = '章节内容为空';
          _isLoadingContent = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _content = html ?? '';
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

    if (summary == null) {
      if (!_aiService.isConfigured) {
        setState(() {
          _showOriginalText = true;
        });
        return;
      }

      if (!_contentTooShort && _content.isNotEmpty) {
        _generateSummary();
      }
    }
  }

  Future<void> _generateSummary() async {
    if (!_aiService.isConfigured) {
      setState(() {
        _error = 'AI服务未配置，请在 ai_config.json 中设置 API Key';
      });
      return;
    }

    if (_content.isEmpty || _contentTooShort) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final content = _extractTextContent(_content);
      final success = await _summaryService.generateSingleSummary(
        widget.bookId,
        widget.chapterIndex,
        widget.chapterTitle,
        content,
      );

      if (!mounted) return;

      if (success) {
        final summary = await _summaryService.getSummary(
            widget.bookId, widget.chapterIndex);
        setState(() {
          _summary = summary;
          _isGenerating = false;
        });
      } else {
        setState(() {
          _error = '生成摘要失败';
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '生成摘要时出错: $e';
        _isGenerating = false;
      });
    }
  }

  String _extractTextContent(String htmlContent) {
    final text = htmlContent
        .replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<audio[^>]*>[\s\S]*?</audio>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<video[^>]*>[\s\S]*?</video>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<iframe[^>]*>[\s\S]*?</iframe>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<object[^>]*>[\s\S]*?</object>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<embed[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.length > 4000) {
      return text.substring(0, 4000);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title.isNotEmpty ? _title : widget.chapterTitle),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_chapters.isNotEmpty) _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingContent) {
      return _buildContentLoadingView();
    }

    if (_isGenerating) {
      return _buildGeneratingView();
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_summary == null) {
      if (_contentTooShort) {
        return _buildSummaryView();
      }
      return _buildEmptyView();
    }

    return _buildSummaryView();
  }

  Widget _buildContentLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '正在加载章节内容...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.summarize_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无摘要',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮生成 AI 摘要',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generateSummary,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('生成摘要'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          if (!_aiService.isConfigured) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '提示：请先在 ai_config.json 中配置 API Key',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
            child: _showOriginalText
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
                        Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
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
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
    final isFirst = widget.chapterIndex <= 0;
    final isLast = widget.chapterIndex >= _chapters.length - 1;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
                Icons.chevron_left,
                color: isFirst ? Colors.grey.shade600 : Colors.white,
                size: 28,
              ),
            ),
          ),
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
                Icons.chevron_right,
                color: isLast ? Colors.grey.shade600 : Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
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
        ),
      ),
    );
  }
}
