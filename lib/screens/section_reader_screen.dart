import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../models/book.dart';
import '../models/chapter_summary.dart';
import '../services/epub_service.dart';
import '../services/summary_service.dart';
import '../services/log_service.dart';
import 'summary_screen.dart';

class SectionReaderScreen extends StatefulWidget {
  final Book book;
  final int chapterIndex;
  final int? sectionIndex;

  const SectionReaderScreen({
    super.key,
    required this.book,
    required this.chapterIndex,
    this.sectionIndex,
  });

  @override
  State<SectionReaderScreen> createState() => _SectionReaderScreenState();
}

class _SectionReaderScreenState extends State<SectionReaderScreen> {
  final _epubService = EpubService();
  final _summaryService = SummaryService();
  final _log = LogService();
  bool _isLoading = true;
  String _title = '';
  String _content = '';
  double _fontSize = 16.0;
  bool _hasSummary = false;

  // 分页相关
  int _currentPage = 0;
  List<String> _pages = [];
  late PageController _pageController;

  // 页面尺寸 (适配屏幕)
  final double _pagePadding = 24;

  // 用于记录阅读位置（字符偏移量）
  int _currentCharOffset = 0;
  Size? _lastScreenSize;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant SectionReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 初始化时记录屏幕尺寸
    if (_lastScreenSize == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _lastScreenSize = MediaQuery.of(context).size;
          });
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 检测窗口大小变化
    final currentSize = MediaQuery.of(context).size;
    if (_lastScreenSize != null &&
        (_lastScreenSize!.width != currentSize.width ||
            _lastScreenSize!.height != currentSize.height)) {
      // 窗口大小发生变化，需要重新分页并恢复位置
      if (_content.isNotEmpty && _pages.isNotEmpty) {
        // 先计算当前字符偏移量
        _currentCharOffset = _calculateCharOffset(_currentPage);

        // 重新分页
        _splitContentIntoPages();

        // 根据字符偏移量找到新页面
        final newPage = _findPageByCharOffset(_currentCharOffset);

        if (mounted) {
          setState(() {
            _currentPage = newPage;
          });
          // 使用微任务确保在下一帧跳转到正确页面
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(newPage);
            }
          });
        }
      }
    }
    _lastScreenSize = currentSize;
  }

  // 计算到指定页面的累计字符偏移量
  int _calculateCharOffset(int pageIndex) {
    int offset = 0;
    for (int i = 0; i < pageIndex && i < _pages.length; i++) {
      offset += _pages[i].replaceAll(RegExp(r'<[^>]+>'), '').length;
    }
    return offset;
  }

  // 根据字符偏移量找到对应的页面
  int _findPageByCharOffset(int targetOffset) {
    if (_pages.isEmpty) return 0;

    int currentOffset = 0;
    for (int i = 0; i < _pages.length; i++) {
      final pageTextLength =
          _pages[i].replaceAll(RegExp(r'<[^>]+>'), '').length;
      // 如果目标偏移量在当前页面范围内，返回该页面
      if (currentOffset <= targetOffset &&
          targetOffset < currentOffset + pageTextLength) {
        return i;
      }
      currentOffset += pageTextLength;
    }
    // 如果超出范围，返回最后一页
    return _pages.length - 1;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SummaryScreen(
          bookId: widget.book.id,
          chapterIndex: widget.chapterIndex,
          chapterTitle: _title,
          chapterContent: _content,
        ),
      ),
    ).then((_) async {
      final summary =
          await _summaryService.getSummary(widget.book.id, widget.chapterIndex);
      if (summary != null && mounted) {
        setState(() {
          _hasSummary = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('摘要生成成功')),
        );
      }
    });
  }

  Future<void> _loadContent() async {
    _log.info('SectionReaderScreen', '===== _loadContent 开始执行 =====');
    setState(() => _isLoading = true);

    try {
      final chapters = await _epubService.getChapterList(widget.book.filePath);
      _log.info('SectionReaderScreen',
          '获取到章节数量: ${chapters.length}, 当前索引: ${widget.chapterIndex}');
      if (widget.chapterIndex < 0 || widget.chapterIndex >= chapters.length) {
        _log.w('SectionReaderScreen', '章节索引超出范围！');
        setState(() => _isLoading = false);
        return;
      }

      final chapter = chapters[widget.chapterIndex];
      _title = chapter.title;
      _log.info('SectionReaderScreen', '章节标题: $_title');

      if (widget.sectionIndex != null) {
        final sections = await _epubService.getSectionsInChapter(
          widget.book.filePath,
          widget.chapterIndex,
        );
        if (widget.sectionIndex! >= 0 &&
            widget.sectionIndex! < sections.length) {
          _title = sections[widget.sectionIndex!].title;
        }
        _content = await _epubService.getSectionHtml(
              widget.book.filePath,
              widget.chapterIndex,
              widget.sectionIndex!,
            ) ??
            '';
      } else {
        _content = await _epubService.getChapterHtml(
              widget.book.filePath,
              widget.chapterIndex,
            ) ??
            '';
      }
      _log.info('SectionReaderScreen', '内容长度: ${_content.length}');
    } catch (e, stackTrace) {
      _log.e('SectionReaderScreen', '加载内容失败', e, stackTrace);
    }

    // 检查是否已有摘要
    _log.info('SectionReaderScreen',
        '开始检查摘要, bookId: ${widget.book.id}, chapterIndex: ${widget.chapterIndex}, title: $_title');
    ChapterSummary? summary =
        await _summaryService.getSummary(widget.book.id, widget.chapterIndex);
    _log.info('SectionReaderScreen',
        '按索引查找结果: ${summary != null ? "找到摘要" : "未找到摘要"}');

    // 如果按索引未找到摘要，尝试按标题查找
    if (summary == null && _title.isNotEmpty) {
      _log.info('SectionReaderScreen', '按索引未找到摘要，尝试按标题查找: $_title');
      summary = await _summaryService.getSummaryByTitle(widget.book.id, _title);
      _log.info('SectionReaderScreen',
          '按标题查找结果: ${summary != null ? "找到摘要" : "未找到摘要"}');
    } else if (summary == null) {
      _log.w('SectionReaderScreen',
          '无法按标题查找，因为_title为空: "${_title}" 或长度: ${_title.length}');
    }

    _log.info('SectionReaderScreen', '最终设置 _hasSummary = ${summary != null}');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasSummary = summary != null;
      });
      _log.info(
          'SectionReaderScreen', 'setState 完成, _hasSummary = $_hasSummary');
    }

    // 延迟到下一帧进行分页，确保 MediaQuery 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _content.isNotEmpty) {
        setState(() {
          _splitContentIntoPages();
        });
      }
    });
  }

  void _splitContentIntoPages() {
    _pages = [];
    if (_content.isEmpty) {
      _pages.add('<p>暂无内容</p>');
      return;
    }

    // 获取屏幕可用高度，计算每页可容纳的字符数
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 减去AppBar(56)和底部翻页按钮区域(60)和内边距(32*2=64)
    final availableHeight = screenHeight - 56 - 60 - 64;

    // 行高是字体大小的1.8倍
    final lineHeight = _fontSize * 1.8;
    final linesPerPage = (availableHeight / lineHeight).floor();

    // 根据屏幕宽度和字体大小估算每行字符数
    // 中文字符宽度约等于字体大小，英文约为一半
    // 假设平均字符宽度为字体大小的0.6倍
    final avgCharWidth = _fontSize * 0.6;
    final charsPerLine = (screenWidth / avgCharWidth).floor();

    // 每页字符数，增加20%的缓冲
    final charsPerPage = (linesPerPage * charsPerLine * 1.2).floor();

    _log.d('SectionReaderScreen',
        '分页参数: 屏幕高度=$screenHeight, 可用高度=$availableHeight, 每页行数=$linesPerPage, 每行字符=$charsPerLine, 每页字符=$charsPerPage');

    // 移除 HTML 标签计算纯文本长度
    final plainText = _content.replaceAll(RegExp(r'<[^>]+>'), '');

    if (plainText.length <= charsPerPage) {
      _pages.add(_content);
    } else {
      // 按段落分割，保留标题标签的完整性
      final paragraphs =
          _content.split(RegExp(r'(?=</p>|</div>|</h[1-6]>|</li>)'));
      var currentPage = '';
      var currentCharCount = 0;

      for (var para in paragraphs) {
        if (para.trim().isEmpty) continue;

        final paraText = para.replaceAll(RegExp(r'<[^>]+>'), '');
        final paraLength = paraText.length;

        if (currentCharCount + paraLength > charsPerPage &&
            currentPage.isNotEmpty) {
          // 确保当前页有正确的HTML结构
          _pages.add(_wrapWithBody(currentPage));
          currentPage = para;
          currentCharCount = paraLength;
        } else {
          currentPage += para;
          currentCharCount += paraLength;
        }
      }

      if (currentPage.isNotEmpty) {
        _pages.add(_wrapWithBody(currentPage));
      }
    }

    if (_pages.isEmpty) {
      _pages.add(_content);
    }

    _log.d('SectionReaderScreen', '分页完成: 共 ${_pages.length} 页');

    // 重置到第一页
    _currentPage = 0;
  }

  // 将内容包装在body标签中，确保样式正确应用
  String _wrapWithBody(String content) {
    // 如果内容已经有body标签，直接返回
    if (content.trim().startsWith('<body')) {
      return content;
    }
    return '<body>$content</body>';
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          if (_pages.length > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentPage + 1} / ${_pages.length}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          // 生成摘要按钮
          if (!_hasSummary)
            IconButton(
              icon: const Icon(Icons.summarize),
              onPressed: _openSummary,
              tooltip: '生成摘要',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'increase') {
                setState(() {
                  _fontSize = (_fontSize + 2).clamp(12.0, 28.0);
                  _splitContentIntoPages();
                });
              } else if (value == 'decrease') {
                setState(() {
                  _fontSize = (_fontSize - 2).clamp(12.0, 28.0);
                  _splitContentIntoPages();
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'increase',
                child: ListTile(
                  leading: Icon(Icons.text_increase),
                  title: Text('增大字体'),
                ),
              ),
              const PopupMenuItem(
                value: 'decrease',
                child: ListTile(
                  leading: Icon(Icons.text_decrease),
                  title: Text('减小字体'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(_pagePadding),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                          // 更新字符偏移量
                          _currentCharOffset = _calculateCharOffset(index);
                        });
                      },
                      itemBuilder: (context, index) {
                        return Html(
                          data: _pages[index],
                          style: {
                            'body': Style(
                              fontSize: FontSize(_fontSize),
                              lineHeight: const LineHeight(1.8),
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                            ),
                            'p': Style(
                              margin: Margins.only(bottom: 16),
                              lineHeight: const LineHeight(1.8),
                            ),
                            'h1': Style(
                              fontSize: FontSize(_fontSize + 4),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(bottom: 16, top: 24),
                            ),
                            'h2': Style(
                              fontSize: FontSize(_fontSize + 3),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(bottom: 14, top: 20),
                            ),
                            'h3': Style(
                              fontSize: FontSize(_fontSize + 2),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(bottom: 12, top: 16),
                            ),
                            'h4': Style(
                              fontSize: FontSize(_fontSize + 1),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(bottom: 10, top: 14),
                            ),
                            'h5': Style(
                              fontSize: FontSize(_fontSize),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(bottom: 8, top: 12),
                            ),
                            'h6': Style(
                              fontSize: FontSize(_fontSize),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(bottom: 8, top: 12),
                            ),
                            'div': Style(
                              margin: Margins.only(bottom: 12),
                            ),
                            'br': Style(
                              height: Height(12),
                            ),
                            'hr': Style(
                              display: Display.none,
                            ),
                          },
                        );
                      },
                    ),
                  ),
                ),
                // 底部翻页按钮
                if (_pages.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 左箭头
                        if (_currentPage > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _previousPage,
                            tooltip: '上一页',
                          )
                        else
                          const SizedBox(width: 48),

                        // 页码
                        Text(
                          '${_currentPage + 1} / ${_pages.length}',
                          style: const TextStyle(fontSize: 14),
                        ),

                        // 右箭头
                        if (_currentPage < _pages.length - 1)
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _nextPage,
                            tooltip: '下一页',
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
