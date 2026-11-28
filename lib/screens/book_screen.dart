// 书籍详情页面
//
// 展示书籍信息（封面/书名/作者/出版信息）与全层级章节列表；
// 点击章节进入阅读，「阅读」按钮续读上次位置。

import 'dart:async';

import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/parsers/book_format_parser.dart';
import '../services/parsers/rendered_content.dart';
import '../models/chapter.dart';
import '../models/reader_typography.dart';
import '../services/log_service.dart';
import '../utils/app_theme.dart';
import '../widgets/chapter_directory.dart';
import 'chapter_screen.dart';

/// 书籍详情页：展示书籍信息与章节列表
class BookScreen extends StatefulWidget {
  final Book book;

  const BookScreen({super.key, required this.book});

  /// 已解析章节列表的内存缓存（`bookId|filePath` → 章节）
  ///
  /// 每次从书架进入详情页都重新解压解析会让转场停顿（大书可达数百毫秒），
  /// 命中缓存后直接显示章节列表。
  static final Map<String, List<Chapter>> _chapterCache = {};

  /// 测试用：清空章节缓存
  @visibleForTesting
  static void clearChapterCacheForTest() => _chapterCache.clear();

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  /// 书籍管理服务（单例）
  final _bookService = BookService();

  /// 日志服务
  final _log = LogService();

  /// 当前书籍（可能被刷新更新）
  late Book _book;

  /// 扁平化的章节列表（含子章节，level 表示目录层级）
  List<Chapter> _flatChapters = [];

  /// 是否正在加载章节列表
  bool _isLoadingChapters = false;

  /// 书籍自身排版（字号/行距/段距），用于阅读页起步值与「重置」目标
  ReaderTypography? _bookTypography;

  @override
  void initState() {
    super.initState();

    // 获取最新的书籍数据（可能已在其他地方更新）
    _book = _bookService.getBookById(widget.book.id) ?? widget.book;

    // 更新最后阅读时间并持久化
    _updateLastReadAt();

    // 加载章节列表
    _loadChapters();
  }

  /// 更新书籍的最后阅读时间并持久化
  ///
  /// 进入书籍详情页即视为一次阅读，记录当前时间，
  /// 供首页书架按「最近阅读」排序使用。
  void _updateLastReadAt() {
    _book = _book.copyWith(lastReadAt: DateTime.now());
    _bookService.updateBook(_book);
  }

  /// 当前书籍的章节缓存键
  String get _chapterCacheKey => '${_book.id}|${_book.filePath}';

  /// 加载书籍章节列表
  ///
  /// 使用格式注册表获取对应的解析器（EPUB/PDF），
  /// 解析书籍结构并获取扁平化的章节列表。
  Future<void> _loadChapters() async {
    // 命中缓存：直接显示，避免重复解析造成的进入停顿
    final cached = BookScreen._chapterCache[_chapterCacheKey];
    if (cached != null && cached.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _flatChapters = cached;
        _isLoadingChapters = false;
      });
      // 章节已缓存时排版信息在后台补充（用于阅读页起步值与重置）
      _loadTypographyInBackground();
      return;
    }

    setState(() => _isLoadingChapters = true);

    try {
      // 首次打开时确保书籍文件在本地（非本地则复制到应用目录）
      _book = await _bookService.ensureBookFileLocal(_book);

      // 根据书籍格式获取对应的解析器
      final parser = FormatRegistry.getParser('.${_book.format.name}');
      if (parser == null) {
        _log.e('BookScreen', '不支持的格式: ${_book.format}');
        setState(() => _isLoadingChapters = false);
        return;
      }

      // 先解析章节结构并显示（EPUB 解析已在后台 isolate 完成，不阻塞转场动画）
      // 原始排版与章节并行解析，避免串行等待
      final typographyFuture = parser.getReaderTypography(_book.filePath);
      final chapters = await parser.getChapters(_book.filePath);
      final typography = await typographyFuture;
      if (!mounted) return;

      if (chapters.isNotEmpty) {
        BookScreen._chapterCache[_chapterCacheKey] = chapters;
      }
      setState(() {
        _flatChapters = chapters;
        _bookTypography = typography;
        _isLoadingChapters = false;
      });

      _log.d('BookScreen', '章节加载完成: ${chapters.length} 个章节');

      // 首次成功获取章节数后持久化保存，后续打开优先使用缓存值避免重复解析
      if (chapters.isNotEmpty && chapters.length != _book.totalChapters) {
        _book = _book.copyWith(totalChapters: chapters.length);
        await _bookService.updateBook(_book);
      }

      // 出版信息缺失时再解析补充：放在章节显示之后，避免拖慢首屏
      unawaited(_fillPublishInfoIfMissing(parser));
    } catch (e, stackTrace) {
      _log.e('BookScreen', '加载章节列表失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
        });
      }
    }
  }

  /// 后台补充书籍原始排版（章节命中缓存时使用，不阻塞界面）
  Future<void> _loadTypographyInBackground() async {
    try {
      final parser = FormatRegistry.getParser('.${_book.format.name}');
      if (parser == null) return;
      final typography = await parser.getReaderTypography(_book.filePath);
      if (!mounted || typography == null) return;
      setState(() => _bookTypography = typography);
    } catch (e) {
      _log.w('BookScreen', '补充书籍原始排版失败: $e');
    }
  }

  /// 补充出版信息（第二优先级来源）
  ///
  /// 出版方/出版时间的第一优先级来源是 Calibre 导入时的 OPF 元数据；
  /// 若为空，则进入详情页时解析书籍文件内部元数据（EPUB 内部 OPF）补充并持久化。
  /// PDF 无 OPF，无法提供出版信息，直接跳过。
  Future<void> _fillPublishInfoIfMissing(BookFormatParser parser) async {
    if (_book.format != BookFormat.epub) return;

    final hasPublisher = _book.publisher?.isNotEmpty ?? false;
    final hasPublishDate = _book.publishDate?.isNotEmpty ?? false;
    if (hasPublisher && hasPublishDate) return;

    try {
      final metadata = await parser.parseMetadata(_book.filePath, _book.id);
      if (metadata == null) return;

      final publisher = hasPublisher ? _book.publisher : metadata.publisher;
      final publishDate = hasPublishDate ? _book.publishDate : metadata.publishDate;

      if ((publisher == null || publisher.isEmpty) &&
          (publishDate == null || publishDate.isEmpty)) {
        return;
      }

      _book = _book.copyWith(publisher: publisher, publishDate: publishDate);
      await _bookService.updateBook(_book);
      // 后台补充完成后刷新头部信息（章节列表已先显示，不阻塞首屏）
      if (mounted) setState(() {});
    } catch (e) {
      _log.w('BookScreen', '解析书籍文件补充出版信息失败: $e');
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
          // 顶部书籍信息区域：封面、标题、作者、出版信息
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildBookHeader(),
          ),
          const Divider(height: 1),
          // 底部章节目录
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildChapterStructureContent(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建书籍头部信息（封面、书名、作者、出版方/时间）
  Widget _buildBookHeader() {
    final theme = Theme.of(context);
    final metaBase = theme.textTheme.bodyMedium;
    final metaFontSize = metaBase?.fontSize ?? 14;
    // 出版时间/出版方
    final metaStyle = metaBase?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: metaFontSize + 4,
    );
    // 作者（比出版信息再大2号）
    final authorStyle = metaBase?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: metaFontSize + 6,
    );
    final titleBase = theme.textTheme.titleLarge;
    final titleFontSize = titleBase?.fontSize ?? 22;
    final titleStyle = titleBase?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: titleFontSize + 8,
    );

    final publishDate = _formatPublishDate(_book.publishDate);
    final publisher =
        (_book.publisher?.isNotEmpty ?? false) ? _book.publisher : null;

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCover(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 书名（最多2行）
                  Text(
                    _book.title,
                    style: titleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // 作者
                  Text(_book.author, style: authorStyle),
                  // 出版信息（有值才显示，缺失时不显示，仅显示值）
                  if (publishDate != null || publisher != null) ...[
                    // 作者与出版时间之间空 2 行
                    const SizedBox(height: 40),
                    if (publishDate != null) Text(publishDate, style: metaStyle),
                    if (publishDate != null && publisher != null)
                      const SizedBox(height: 4),
                    if (publisher != null) Text(publisher, style: metaStyle),
                  ],
                ],
              ),
            ),
          ],
        ),
        // 封面所在整行的右下角「阅读」按钮（开卷图标）
        Positioned(
          right: 0,
          bottom: 0,
          child: IconButton(
            onPressed: _startReading,
            icon: const Icon(Icons.auto_stories, size: 36, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  /// 将出版时间格式化为「年月」（YYYY-MM），缺失或无法识别时返回 null
  String? _formatPublishDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(r'^(\d{4})(?:-(\d{1,2}))?').firstMatch(raw.trim());
    if (match == null) return null;
    final year = match.group(1)!;
    final month = match.group(2);
    if (month == null) return year;
    return '$year-${month.padLeft(2, '0')}';
  }

  /// 开始阅读：续读上次位置，或从书籍开头页开始
  ///
  /// `lastChapterIndex` 语义：-1 = 开头页（目录/版权等未列入章节的前置页），
  /// 0 起 = 顶层章节索引。
  Future<void> _startReading() async {
    if (_flatChapters.isEmpty) return;

    // 读取最新的书籍记录：本页缓存的 _book 可能还是上次进入阅读前的快照，
    // 若不刷新会读不到刚保存的阅读进度
    _book = BookService().getBookById(_book.id) ?? _book;

    final resumeIndex = _book.lastChapterIndex;
    final resumePage = _book.lastPageIndex ?? 0;

    // PDF：无前置页，从第 1 页开始（有进度则回到上次页）
    if (_book.format == BookFormat.pdf) {
      if (resumeIndex != null && resumeIndex > 0) {
        _resumeReading(resumeIndex);
        return;
      }
      _openChapter(_flatChapters.first,
          initialPage: resumeIndex != null ? resumePage + 1 : 1);
      return;
    }

    // 有进度且不在首章：直接续读该章
    if (resumeIndex != null && resumeIndex > 0) {
      _resumeReading(resumeIndex);
      return;
    }

    // 停留在开头页：恢复开头页的页码
    if (resumeIndex == -1) {
      final opening = await _loadOpeningContent();
      if (!mounted) return;
      if (opening != null) {
        _openOpening(opening, initialPagedPage: resumePage);
      } else {
        _openChapter(_flatChapters.first);
      }
      return;
    }

    // 首次阅读：从开头的全部前置页开始，无独立开头页则回退到第一章
    if (resumeIndex == null) {
      final opening = await _loadOpeningContent();
      if (!mounted) return;
      if (opening != null) {
        _openOpening(opening);
      } else {
        _openChapter(_flatChapters.first);
      }
      return;
    }

    // 停留在第一章：恢复其页码
    _openChapter(_flatChapters.first, initialPagedPage: resumePage);
  }

  /// 读取书籍开头内容（EPUB 前置页），无前置页时返回 null
  Future<RenderedContent?> _loadOpeningContent() async {
    final dot = _book.filePath.lastIndexOf('.');
    final ext = dot == -1 ? '' : _book.filePath.substring(dot).toLowerCase();
    final parser = FormatRegistry.getParser(ext);
    if (parser == null) return null;
    final opening = await parser.getOpeningContent(_book.filePath);
    if (opening == null || opening.html.isEmpty) return null;
    return opening;
  }

  /// 续读：打开上次阅读的章节与页码（EPUB 恢复分页页码，PDF 恢复页）
  void _resumeReading(int chapterIndex) {
    final chapter = _flatChapters.firstWhere(
      (c) => c.level == 0 && c.index == chapterIndex,
      orElse: () => _flatChapters.first,
    );
    final isPdf = _book.format == BookFormat.pdf;
    final lastPage = _book.lastPageIndex ?? 0;
    _openChapter(
      chapter,
      initialPage: isPdf ? lastPage + 1 : null,
      initialPagedPage: isPdf ? null : lastPage,
    );
  }

  /// 打开书籍第一页（开头内容，如 EPUB 标题页）
  ///
  /// [initialPagedPage] 用于续读时恢复分页页码。
  void _openOpening(RenderedContent opening, {int? initialPagedPage}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterScreen(
          bookId: _book.id,
          chapterIndex: 0,
          chapterTitle: _book.title,
          filePath: _book.filePath,
          chapters: _flatChapters,
          book: _book,
          bookTypography: _bookTypography,
          openingContent: opening.html,
          openingFonts: opening.fonts,
          openingIsVertical: opening.isVertical,
          openingPlainText: opening.plainText,
          initialPagedPage: initialPagedPage,
        ),
      ),
    );
  }

  /// 跳转到指定章节的阅读页面
  ///
  /// 子章节（level>0）没有独立索引，需先定位其所属的顶层章节，
  /// 再以该顶层章节为阅读单位，并把子章节标题作为初始定位锚点。
  void _openChapter(Chapter chapter,
      {int? initialPage, int? initialPagedPage}) {
    final topChapter = _topLevelChapterOf(chapter);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterScreen(
          bookId: _book.id,
          chapterIndex: topChapter.index,
          chapterTitle: topChapter.title,
          filePath: _book.filePath,
          chapters: _flatChapters,
          book: _book,
          bookTypography: _bookTypography,
          initialPage: initialPage,
          initialPagedPage: initialPagedPage,
          initialAnchor: chapter.level > 0 ? chapter.title : null,
        ),
      ),
    );
  }

  /// 找到章节所属的顶层章节（level==0）：自身即顶层时直接返回，
  /// 否则向上找到最近的一个顶层章节
  Chapter _topLevelChapterOf(Chapter chapter) {
    if (chapter.level == 0) return chapter;

    var index = _flatChapters.indexWhere((c) => identical(c, chapter));
    if (index < 0) {
      index = _flatChapters.indexWhere(
        (c) => c.level == chapter.level && c.title == chapter.title,
      );
    }
    for (var i = index; i >= 0; i--) {
      if (_flatChapters[i].level == 0) return _flatChapters[i];
    }
    return _flatChapters.isNotEmpty ? _flatChapters.first : chapter;
  }

  /// 构建封面（实际封面缺失时回退默认图标，逻辑见 [BookCover]）
  Widget _buildCover() {
    return BookCover(book: _book);
  }

  /// 构建章节目录内容（加载中 → 进度指示；空 → 提示；否则章节列表）
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

  /// 构建章节列表项（缩进/字号/配色见 [buildChapterTiles]）
  List<Widget> _buildChapterList() {
    return buildChapterTiles(
      context,
      chapters: _flatChapters,
      onChapterTap: _openChapter,
    );
  }
}
