import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeContent().then((_) {
      // 内容加载完成后再加载摘要，这样可以正确判断是否需要自动生成
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
        chapters =
            await _epubService.getHierarchicalChapterList(widget.filePath!);
      }

      // 将层级章节展平
      final flatChapters = <ChapterInfo>[];
      void flatten(List<ChapterInfo> list) {
        for (final c in list) {
          flatChapters.add(c);
          if (c.children.isNotEmpty) {
            flatten(c.children);
          }
        }
      }

      flatten(chapters);

      _log.d('SummaryScreen',
          '章节总数: ${flatChapters.length}, 请求索引: ${widget.chapterIndex}');

      if (widget.chapterIndex < 0 ||
          widget.chapterIndex >= flatChapters.length) {
        if (!mounted) return;
        setState(() {
          _error =
              '章节索引超出范围: ${widget.chapterIndex}, 总章节数: ${flatChapters.length}';
          _isLoadingContent = false;
        });
        return;
      }

      final chapter = chapters[widget.chapterIndex];
      _title = chapter.title;

      final html = await _epubService.getChapterHtml(
        widget.filePath!,
        widget.chapterIndex,
      );

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
        _content = html;
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
    final summary =
        await _summaryService.getSummary(widget.bookId, widget.chapterIndex);
    if (!mounted) return;
    setState(() {
      _summary = summary;
    });

    // 如果没有摘要
    if (summary == null) {
      // AI服务未配置：显示原文，禁用AI按钮
      if (!_aiService.isConfigured) {
        setState(() {
          _showOriginalText = true;
        });
        return;
      }

      // 内容足够长：自动生成摘要
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

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      if (_content.isEmpty || _contentTooShort) {
        return;
      }

      final content = _extractTextContent(_content);

      final objectiveSummary = await _aiService.generateObjectiveSummary(
        content,
        chapterTitle: widget.chapterTitle,
      );

      final aiInsight = await _aiService.generateAIInsight(
        content,
        chapterTitle: widget.chapterTitle,
      );

      // 检查AI返回的内容是否为空或只有空白
      final effectiveObjective =
          (objectiveSummary?.trim().isEmpty ?? true) ? null : objectiveSummary;
      final effectiveInsight =
          (aiInsight?.trim().isEmpty ?? true) ? null : aiInsight;

      if (effectiveObjective != null || effectiveInsight != null) {
        final summary = ChapterSummary(
          bookId: widget.bookId,
          chapterIndex: widget.chapterIndex,
          chapterTitle: widget.chapterTitle,
          objectiveSummary: effectiveObjective ?? '生成失败',
          aiInsight: effectiveInsight ?? '生成失败',
          keyPoints: _extractKeyPoints(effectiveObjective),
          createdAt: DateTime.now(),
        );

        await _summaryService.saveSummary(summary);

        if (!mounted) return;
        setState(() {
          _summary = summary;
          _isGenerating = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error =
              '生成摘要失败，AI返回内容为空\n\n可能原因：\n1. AI服务暂时不可用\n2. 内容过长或过短\n3. API配额已用完';
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

  List<String> _extractKeyPoints(String? summary) {
    if (summary == null) return [];

    final points = <String>[];
    final lines = summary.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('•') ||
          trimmed.startsWith('-') ||
          trimmed.startsWith('*') ||
          RegExp(r'^\d+\.').hasMatch(trimmed)) {
        points.add(trimmed);
      }
    }

    return points.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title.isNotEmpty ? _title : widget.chapterTitle),
        centerTitle: true,
      ),
      body: _buildBody(),
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
    // 判断AI按钮是否应该禁用
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '本章摘要',
            icon: Icons.auto_awesome,
            color: Colors.blue,
            content: _summary!.objectiveSummary,
          ),
          if (_summary!.keyPoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildKeyPointsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildOriginalTextView() {
    return SingleChildScrollView(
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
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyPointsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  '关键要点',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...(_summary!.keyPoints.map((point) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ))),
          ],
        ),
      ),
    );
  }
}
