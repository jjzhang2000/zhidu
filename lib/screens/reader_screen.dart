import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:archive/archive.dart';
import 'package:epub_plus/epub_plus.dart';
import '../models/book.dart';
import '../models/chapter_summary.dart';
import '../services/book_service.dart';
import '../services/summary_service.dart';
import '../services/log_service.dart';
import 'summary_screen.dart';

class ChapterInfo {
  final String title;
  final String? href;
  ChapterInfo({required this.title, this.href});
}

class ReaderScreen extends StatefulWidget {
  final Book book;
  final bool showToc;
  final int initialChapter;

  const ReaderScreen({
    super.key,
    required this.book,
    this.showToc = false,
    this.initialChapter = 0,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _bookService = BookService();
  final _summaryService = SummaryService();
  final _log = LogService();

  Archive? _archive;
  List<ChapterInfo> _chapters = [];
  Map<String, String> _htmlContent = {};
  int _currentChapterIndex = 0;
  String _chapterContent = '';
  bool _isLoading = true;
  bool _showToc = false;
  bool _hasSummary = false;
  ChapterSummary? _currentSummary;
  bool _showSummary = false;

  double _fontSize = 16.0;
  final double _minFontSize = 12.0;
  final double _maxFontSize = 28.0;

  @override
  void initState() {
    super.initState();
    _showToc = widget.showToc;
    _loadBook();
  }

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final file = File(widget.book.filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('书籍文件不存在')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final bytes = await file.readAsBytes();
      _log.d('ReaderScreen', '读取文件成功，大小: ${bytes.length} bytes');

      _archive = ZipDecoder().decodeBytes(bytes);

      await _loadHtmlContent();

      try {
        final epubBook = await EpubReader.readBook(bytes);
        _log.d('ReaderScreen', 'EPUB打开成功');
        _extractChaptersFromEpub(epubBook);
      } catch (e, stackTrace) {
        _log.e('ReaderScreen', '打开EPUB失败', e, stackTrace);
        _extractChaptersFromArchive();
      }

      _log.d('ReaderScreen', '提取章节数: ${_chapters.length}');

      if (_chapters.isEmpty) {
        _extractChaptersFromArchive();
        _log.d('ReaderScreen', '从归档提取章节数: ${_chapters.length}');
      }

      if (_chapters.isNotEmpty) {
        _currentChapterIndex =
            widget.initialChapter.clamp(0, _chapters.length - 1);
        _log.d('ReaderScreen', '当前章节索引: $_currentChapterIndex');
        await _loadChapter(_currentChapterIndex);
      } else {
        _log.w('ReaderScreen', '警告: 章节列表为空！');
      }
    } catch (e, stackTrace) {
      _log.e('ReaderScreen', '加载书籍失败', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载书籍失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHtmlContent() async {
    if (_archive == null) return;

    for (final file in _archive!.files) {
      final name = file.name.toLowerCase();
      if (name.endsWith('.html') || name.endsWith('.xhtml')) {
        try {
          final content = utf8.decode(file.content as List<int>);
          _htmlContent[file.name] = content;
          _htmlContent[name] = content;
        } catch (e) {
          try {
            final content = String.fromCharCodes(file.content as List<int>);
            _htmlContent[file.name] = content;
            _htmlContent[name] = content;
          } catch (e2, stackTrace) {
            _log.e('ReaderScreen', '加载HTML文件失败: ${file.name}', e2, stackTrace);
          }
        }
      }
    }
    _log.d('ReaderScreen', '加载了 ${_htmlContent.length} 个HTML文件');
  }

  void _extractChaptersFromEpub(EpubBook epubBook) {
    _chapters.clear();

    void traverseChapters(List<EpubChapter> chapters) {
      for (final chapter in chapters) {
        final title = chapter.title ?? '未知章节';
        final href = chapter.contentFileName;
        _chapters.add(ChapterInfo(title: title, href: href));
        // 递归处理子章节
        if (chapter.subChapters?.isNotEmpty == true) {
          traverseChapters(chapter.subChapters!);
        }
      }
    }

    if (epubBook.chapters?.isNotEmpty == true) {
      traverseChapters(epubBook.chapters!);
    }
  }

  void _extractChaptersFromArchive() {
    if (_archive == null) return;

    final htmlFiles = <String>[];
    for (final file in _archive!.files) {
      final name = file.name.toLowerCase();
      if ((name.endsWith('.html') || name.endsWith('.xhtml')) &&
          !name.contains('nav') &&
          !name.contains('toc')) {
        htmlFiles.add(file.name);
      }
    }

    htmlFiles.sort();

    for (int i = 0; i < htmlFiles.length; i++) {
      final fileName = htmlFiles[i];
      final title = '第 ${i + 1} 章';
      _chapters.add(ChapterInfo(title: title, href: fileName));
    }
  }

  Future<void> _loadChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;

    final chapter = _chapters[index];
    String content = '';

    final href = chapter.href;
    _log.d('ReaderScreen', '尝试加载章节: ${chapter.title}, href: $href');

    if (href != null) {
      for (final key in _htmlContent.keys) {
        if (key.endsWith(href) || key == href || key.endsWith('/$href')) {
          content = _htmlContent[key] ?? '';
          _log.d('ReaderScreen', '找到章节内容，长度: ${content.length}');
          break;
        }
      }

      if (content.isEmpty) {
        final hrefLower = href.toLowerCase();
        for (final key in _htmlContent.keys) {
          if (key.toLowerCase().endsWith(hrefLower) ||
              key.toLowerCase() == hrefLower ||
              key.toLowerCase().endsWith('/$hrefLower')) {
            content = _htmlContent[key] ?? '';
            _log.d('ReaderScreen', '通过小写匹配找到内容，长度: ${content.length}');
            break;
          }
        }
      }

      // 如果还是找不到，尝试从archive直接读取
      if (content.isEmpty && _archive != null) {
        _log.d('ReaderScreen', '从缓存查找失败，尝试从archive直接读取...');
        content = await _getChapterContentFromArchive(href);
        if (content.isNotEmpty) {
          _log.d('ReaderScreen', '从archive读取成功，长度: ${content.length}');
        }
      }
    }

    if (content.isEmpty) {
      _log.w('ReaderScreen', '警告: 无法加载章节内容: ${chapter.title}');
    }

    final summary = await _summaryService.getSummary(widget.book.id, index);
    final hasSummary = summary != null;

    setState(() {
      _currentChapterIndex = index;
      _chapterContent = content;
      _hasSummary = hasSummary;
      _currentSummary = summary;
      _showSummary = hasSummary;
    });

    await _saveProgress();
  }

  /// 从archive直接读取章节内容（回退方案）
  Future<String> _getChapterContentFromArchive(String href) async {
    if (_archive == null) return '';

    // 尝试直接匹配href
    for (final file in _archive!.files) {
      if (file.name == href ||
          file.name.endsWith('/$href') ||
          file.name.endsWith(href)) {
        try {
          return utf8.decode(file.content as List<int>);
        } catch (e) {
          try {
            return String.fromCharCodes(file.content as List<int>);
          } catch (e2) {
            return '';
          }
        }
      }
    }

    // 尝试小写匹配
    final hrefLower = href.toLowerCase();
    for (final file in _archive!.files) {
      final fileNameLower = file.name.toLowerCase();
      if (fileNameLower == hrefLower ||
          fileNameLower.endsWith('/$hrefLower') ||
          fileNameLower.endsWith(hrefLower)) {
        try {
          return utf8.decode(file.content as List<int>);
        } catch (e) {
          try {
            return String.fromCharCodes(file.content as List<int>);
          } catch (e2) {
            return '';
          }
        }
      }
    }

    return '';
  }

  Future<void> _saveProgress() async {
    final progress =
        _chapters.isEmpty ? 0.0 : (_currentChapterIndex + 1) / _chapters.length;

    await _bookService.updateReadingProgress(
      widget.book.id,
      _currentChapterIndex,
      progress,
    );
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      _loadChapter(_currentChapterIndex - 1);
    }
  }

  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      _loadChapter(_currentChapterIndex + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showToc
              ? _buildTocView()
              : _buildReaderView(),
      bottomNavigationBar: _isLoading || _showToc ? null : _buildBottomBar(),
      floatingActionButton: _isLoading || _showToc || _hasSummary
          ? null
          : FloatingActionButton.extended(
              onPressed: _openSummary,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('生成摘要'),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _showToc ? '目录' : widget.book.title,
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: true,
      actions: [
        if (!_showToc && _hasSummary)
          IconButton(
            icon: Icon(_showSummary ? Icons.menu_book : Icons.summarize),
            onPressed: () {
              setState(() {
                _showSummary = !_showSummary;
              });
            },
            tooltip: _showSummary ? '阅读原文' : 'AI摘要',
          ),
        if (!_showToc && !_hasSummary)
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: _openSummary,
            tooltip: '生成摘要',
          ),
        IconButton(
          icon: const Icon(Icons.list),
          onPressed: () {
            setState(() {
              _showToc = !_showToc;
            });
          },
          tooltip: _showToc ? '返回阅读' : '目录',
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'font_increase',
              child: ListTile(
                leading: Icon(Icons.text_increase),
                title: Text('增大字体'),
              ),
            ),
            const PopupMenuItem(
              value: 'font_decrease',
              child: ListTile(
                leading: Icon(Icons.text_decrease),
                title: Text('减小字体'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SummaryScreen(
          bookId: widget.book.id,
          chapterIndex: _currentChapterIndex,
          chapterTitle: _chapters[_currentChapterIndex].title,
          chapterContent: _chapterContent,
        ),
      ),
    ).then((_) async {
      final summary = await _summaryService.getSummary(
          widget.book.id, _currentChapterIndex);
      setState(() {
        _hasSummary = summary != null;
        _currentSummary = summary;
        if (summary != null) {
          _showSummary = true;
        }
      });
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'font_increase':
        if (_fontSize < _maxFontSize) {
          setState(() {
            _fontSize += 2;
          });
        }
        break;
      case 'font_decrease':
        if (_fontSize > _minFontSize) {
          setState(() {
            _fontSize -= 2;
          });
        }
        break;
    }
  }

  Widget _buildReaderView() {
    if (_chapters.isEmpty) {
      return const Center(
        child: Text('无法读取章节内容'),
      );
    }

    if (_showSummary && _currentSummary != null) {
      return _buildSummaryView();
    }

    return GestureDetector(
      onHorizontalDragEnd: _handleSwipe,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chapters[_currentChapterIndex].title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 32),
            Html(
              data: _chapterContent,
              style: {
                'body': Style(
                  fontSize: FontSize(_fontSize),
                  lineHeight: const LineHeight(1.8),
                ),
                'p': Style(
                  margin: Margins.only(bottom: 12),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    return GestureDetector(
      onHorizontalDragEnd: _handleSwipe,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chapters[_currentChapterIndex].title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 32),
            if (_currentSummary!.objectiveSummary != null) ...[
              Text(
                _currentSummary!.objectiveSummary!,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: 1.8,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('展开详细内容'),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentSummary!.aiInsight.isNotEmpty) ...[
                        Text(
                          'AI 洞察',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentSummary!.aiInsight,
                          style: TextStyle(
                            fontSize: _fontSize,
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_currentSummary!.keyPoints.isNotEmpty) ...[
                        Text(
                          '关键要点',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        ..._currentSummary!.keyPoints
                            .asMap()
                            .entries
                            .map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key + 1}. ',
                                  style: TextStyle(
                                    fontSize: _fontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: _fontSize,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (_currentSummary!.aiInsight.isEmpty &&
                          _currentSummary!.keyPoints.isEmpty)
                        const Text('暂无详细内容'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showSummary = false;
                  });
                },
                icon: const Icon(Icons.menu_book),
                label: const Text('阅读原文'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    if (details.primaryVelocity! > 300) {
      _previousChapter();
    } else if (details.primaryVelocity! < -300) {
      _nextChapter();
    }
  }

  Widget _buildTocView() {
    return ListView.builder(
      itemCount: _chapters.length,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        final isCurrentChapter = index == _currentChapterIndex;

        return ListTile(
          leading: isCurrentChapter
              ? Icon(Icons.play_arrow,
                  color: Theme.of(context).colorScheme.primary)
              : null,
          title: Text(
            chapter.title,
            style: TextStyle(
              fontWeight:
                  isCurrentChapter ? FontWeight.bold : FontWeight.normal,
              color: isCurrentChapter
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          onTap: () {
            _loadChapter(index);
            setState(() {
              _showToc = false;
            });
          },
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentChapterIndex > 0 ? _previousChapter : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '第 ${_currentChapterIndex + 1} / ${_chapters.length} 章',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _chapters.isEmpty
                      ? 0
                      : (_currentChapterIndex + 1) / _chapters.length,
                  minHeight: 4,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentChapterIndex < _chapters.length - 1
                ? _nextChapter
                : null,
          ),
        ],
      ),
    );
  }
}
