import 'dart:async';

import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/chapter_summary.dart';
import '../models/section_summary.dart';
import '../services/summary_service.dart';
import '../services/epub_service.dart';
import '../services/log_service.dart';
import 'section_reader_screen.dart';

class ChapterListScreen extends StatefulWidget {
  final Book book;

  const ChapterListScreen({super.key, required this.book});

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {
  final _summaryService = SummaryService();
  final _epubService = EpubService();
  final _log = LogService();

  List<ChapterSummary> _chapterSummaries = [];
  final Map<int, List<SectionSummary>> _sectionSummaries = {};
  final Map<int, bool> _expandedChapters = {};
  Map<int, int> _chapterSectionCounts = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  List<ChapterInfo> _epubChapters = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    // 每2秒检查一次是否有新的摘要生成
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkForNewSummaries();
    });
  }

  Future<void> _checkForNewSummaries() async {
    if (!mounted) return;

    // 检查章节摘要
    final summaries = await _summaryService.getSummariesForBook(widget.book.id);
    if (summaries.length != _chapterSummaries.length) {
      setState(() {
        _chapterSummaries = summaries;
      });
    }

    // 检查小节摘要
    for (int i = 0; i < summaries.length; i++) {
      final sections = await _summaryService.getSectionSummariesForChapter(
          widget.book.id, i);
      final existingSections = _sectionSummaries[i] ?? [];
      if (sections.length != existingSections.length) {
        setState(() {
          if (sections.isNotEmpty) {
            _sectionSummaries[i] = sections;
          }
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _log.d('ChapterListScreen', '开始加载数据, bookId: ${widget.book.id}');

    // 获取EPUB章节列表（扁平化）
    _epubChapters = await _epubService.getChapterList(widget.book.filePath);
    _log.d('ChapterListScreen', '获取到EPUB章节数量: ${_epubChapters.length}');

    final summaries = await _summaryService.getSummariesForBook(widget.book.id);
    _log.d('ChapterListScreen', '获取到摘要数量: ${summaries.length}');

    // 建立摘要索引到EPUB章节索引的映射
    final sectionCounts = <int, int>{};
    for (int i = 0; i < summaries.length; i++) {
      final summary = summaries[i];
      _log.v('ChapterListScreen', '处理摘要: ${summary.chapterTitle}');
      // 根据章节标题找到对应的EPUB章节索引
      final epubIndex = _findEpubChapterIndex(summary.chapterTitle);
      if (epubIndex >= 0) {
        _log.v('ChapterListScreen', '找到匹配的EPUB章节索引: $epubIndex');
        final sections = await _epubService.getSectionsInChapter(
            widget.book.filePath, epubIndex);
        sectionCounts[i] = sections.length;
      } else {
        _log.v('ChapterListScreen', '未找到匹配的EPUB章节: ${summary.chapterTitle}');
      }
    }

    if (mounted) {
      setState(() {
        _chapterSummaries = summaries;
        _chapterSectionCounts = sectionCounts;
        _log.d('ChapterListScreen', '设置界面状态, 章节数量: ${summaries.length}');
        _isLoading = false;
      });
    }

    // 从 SummaryService 加载小节摘要
    for (int i = 0; i < summaries.length; i++) {
      final sections = await _summaryService.getSectionSummariesForChapter(
          widget.book.id, i);
      if (sections.isNotEmpty && mounted) {
        setState(() {
          _sectionSummaries[i] = sections;
        });
      }
    }
  }

  // 根据章节标题找到对应的EPUB章节索引（更灵活的匹配）
  int _findEpubChapterIndex(String chapterTitle) {
    // 首先尝试精确匹配
    for (int i = 0; i < _epubChapters.length; i++) {
      if (_epubChapters[i].title == chapterTitle) {
        return i;
      }
    }

    // 然后尝试模糊匹配（忽略大小写和多余空格）
    final normalizedTitle = chapterTitle.trim().toLowerCase();
    for (int i = 0; i < _epubChapters.length; i++) {
      final epubTitle = _epubChapters[i].title.trim().toLowerCase();
      if (epubTitle == normalizedTitle) {
        return i;
      }
      // 尝试EPUB标题是否包含章节标题或反之
      if (epubTitle.contains(normalizedTitle) ||
          normalizedTitle.contains(epubTitle)) {
        return i;
      }
    }

    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _epubChapters.isEmpty
              ? const Center(child: Text('无法加载章节'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _epubChapters.length,
                  itemBuilder: (context, index) {
                    return _buildChapterItem(index);
                  },
                ),
    );
  }

  Widget _buildChapterItem(int index) {
    final chapter = _epubChapters[index];
    final hasSummary = _chapterSummaries
        .any((s) => _findEpubChapterIndex(s.chapterTitle) == index);

    return Card(
      child: ListTile(
        title: Text(
          chapter.title,
          style: TextStyle(
            fontWeight: hasSummary ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: hasSummary
            ? const Icon(Icons.summarize, color: Colors.green)
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openChapter(index),
      ),
    );
  }

  void _openChapter(int chapterIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SectionReaderScreen(
          book: widget.book,
          chapterIndex: chapterIndex,
        ),
      ),
    );
  }

  Widget _buildChapterCard(int index) {
    final summary = _chapterSummaries[index];
    final hasSections = _sectionSummaries.containsKey(index) &&
        _sectionSummaries[index]!.isNotEmpty;
    final isExpanded = _expandedChapters[index] ?? false;
    final sectionCount = _chapterSectionCounts[index] ?? 0;
    final shouldShowSections = hasSections && isExpanded;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          if (hasSections) {
            setState(() {
              _expandedChapters[index] = !isExpanded;
            });
          } else {
            _openChapterContent(index);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.chapterTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (sectionCount > 0)
                    Text(
                      '$sectionCount 节',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  if (hasSections)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[600],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary.objectiveSummary,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              if (shouldShowSections) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ..._sectionSummaries[index]!.asMap().entries.map((entry) {
                  return _buildSectionCard(index, entry.key, entry.value);
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      int chapterIndex, int sectionIndex, SectionSummary summary) {
    return Card(
      margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: InkWell(
        onTap: () => _openSectionContent(chapterIndex, sectionIndex),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.sectionTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                summary.objectiveSummary,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChapterContent(int summaryIndex) {
    // 根据摘要索引找到对应的EPUB章节索引
    final summary = _chapterSummaries[summaryIndex];
    final epubIndex = _findEpubChapterIndex(summary.chapterTitle);
    if (epubIndex < 0) {
      _log.w('ChapterListScreen', '未找到对应的EPUB章节: ${summary.chapterTitle}');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SectionReaderScreen(
          book: widget.book,
          chapterIndex: epubIndex,
        ),
      ),
    );
  }

  void _openSectionContent(int summaryIndex, int sectionIndex) {
    // 根据摘要索引找到对应的EPUB章节索引
    final summary = _chapterSummaries[summaryIndex];
    final epubIndex = _findEpubChapterIndex(summary.chapterTitle);
    if (epubIndex < 0) {
      _log.w('ChapterListScreen', '未找到对应的EPUB章节: ${summary.chapterTitle}');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SectionReaderScreen(
          book: widget.book,
          chapterIndex: epubIndex,
          sectionIndex: sectionIndex,
        ),
      ),
    );
  }
}
