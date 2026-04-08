import 'package:flutter/material.dart';
import '../models/chapter_summary.dart';
import '../services/ai_service.dart';
import '../services/summary_service.dart';

class SummaryScreen extends StatefulWidget {
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String chapterContent;

  const SummaryScreen({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.chapterContent,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _aiService = AIService();
  final _summaryService = SummaryService();

  ChapterSummary? _summary;
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary =
        await _summaryService.getSummary(widget.bookId, widget.chapterIndex);
    setState(() {
      _summary = summary;
    });
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
      // 检查原始内容是否为空
      if (widget.chapterContent.isEmpty) {
        setState(() {
          _error = '章节内容为空，无法生成摘要\n\n可能原因：\n1. 章节文件读取失败\n2. EPUB文件格式问题';
          _isGenerating = false;
        });
        return;
      }

      final content = _extractTextContent(widget.chapterContent);

      if (content.length < 100) {
        setState(() {
          _error =
              '章节内容太短（仅 ${content.length} 个字符），无法生成摘要\n\n原始内容长度：${widget.chapterContent.length}';
          _isGenerating = false;
        });
        return;
      }

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

        setState(() {
          _summary = summary;
          _isGenerating = false;
        });
      } else {
        setState(() {
          _error =
              '生成摘要失败，AI返回内容为空\n\n可能原因：\n1. AI服务暂时不可用\n2. 内容过长或过短\n3. API配额已用完';
          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '生成摘要时出错: $e';
        _isGenerating = false;
      });
    }
  }

  String _extractTextContent(String htmlContent) {
    final text = htmlContent
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
        title: Text(_summary?.chapterTitle ?? widget.chapterTitle),
        centerTitle: true,
        actions: [
          if (_summary != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isGenerating ? null : _generateSummary,
              tooltip: '重新生成',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isGenerating) {
      return _buildGeneratingView();
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_summary == null) {
      return _buildEmptyView();
    }

    return _buildSummaryView();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '客观摘要',
            icon: Icons.article_outlined,
            color: Colors.blue,
            content: _summary!.objectiveSummary,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'AI 见解',
            icon: Icons.lightbulb_outline,
            color: Colors.orange,
            content: _summary!.aiInsight,
          ),
          if (_summary!.keyPoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildKeyPointsCard(),
          ],
          const SizedBox(height: 16),
          _buildMetaInfo(),
        ],
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

  Widget _buildMetaInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            '生成于 ${_formatDateTime(_summary!.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
