// 书籍详情页面
//
// 显示书籍的基本信息（封面、书名、作者、出版信息）和章节目录。
//
// 核心功能：
// 1. **书籍信息展示**：封面、书名、作者、出版时间、出版方
// 2. **章节目录展示**：层级缩进的章节列表
//
// 用户交互：
// - 点击顶层章节 → 进入该章节阅读

import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/parsers/book_format_parser.dart';
import '../services/parsers/rendered_content.dart';
import '../models/chapter.dart';
import '../services/log_service.dart';
import 'chapter_screen.dart';

/// 书籍详情页面的StatefulWidget
///
/// 接收一个[Book]对象，显示该书籍的详细信息。
class BookScreen extends StatefulWidget {
  final Book book;

  const BookScreen({super.key, required this.book});

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

  /// 扁平化的章节列表（从EPUB/PDF解析）
  ///
  /// 存储所有章节的线性列表，每个章节包含：
  /// - [Chapter.index] 章节索引
  /// - [Chapter.title] 章节标题
  /// - [Chapter.level] 层级深度（0=顶层，1=子章节...）
  List<Chapter> _flatChapters = [];

  /// 是否正在加载章节列表
  bool _isLoadingChapters = false;

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

  /// 加载书籍章节列表
  ///
  /// 使用格式注册表获取对应的解析器（EPUB/PDF），
  /// 解析书籍结构并获取扁平化的章节列表。
  Future<void> _loadChapters() async {
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

      // 第二优先级：出版信息缺失时解析书籍文件内部元数据补充
      await _fillPublishInfoIfMissing(parser);

      // 解析章节结构
      final chapters = await parser.getChapters(_book.filePath);

      setState(() {
        _flatChapters = chapters;
        _isLoadingChapters = false;
      });

      _log.d('BookScreen', '章节加载完成: ${chapters.length} 个章节');

      // 首次成功获取章节数后持久化保存，后续打开优先使用缓存值避免重复解析
      if (chapters.isNotEmpty && chapters.length != _book.totalChapters) {
        _book = _book.copyWith(totalChapters: chapters.length);
        await _bookService.updateBook(_book);
      }
    } catch (e, stackTrace) {
      _log.e('BookScreen', '加载章节列表失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
        });
      }
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

  /// 构建书籍头部信息
  ///
  /// 包含：封面图片、书名、作者、出版时间、出版方
  Widget _buildBookHeader() {
    final theme = Theme.of(context);
    final metaBase = theme.textTheme.bodyMedium;
    final metaFontSize = metaBase?.fontSize ?? 14;
    // 出版时间/出版方
    final metaStyle = metaBase?.copyWith(
      color: Colors.grey[600],
      fontSize: metaFontSize + 4,
    );
    // 作者（比出版信息再大2号）
    final authorStyle = metaBase?.copyWith(
      color: Colors.grey[600],
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
              backgroundColor: Colors.deepOrange,
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

  /// 开始阅读：从书籍开头开始（EPUB：前置页合并内容；PDF：第 1 页）
  Future<void> _startReading() async {
    if (_flatChapters.isEmpty) return;

    // PDF：从第 1 页开始阅读
    if (_book.format == BookFormat.pdf) {
      _openChapter(_flatChapters.first, initialPage: 1);
      return;
    }

    // EPUB：从开头的全部前置页开始，无独立开头页则回退到第一章
    final dot = _book.filePath.lastIndexOf('.');
    final ext = dot == -1 ? '' : _book.filePath.substring(dot).toLowerCase();
    final parser = FormatRegistry.getParser(ext);
    final opening = parser == null ? null : await parser.getOpeningContent(_book.filePath);

    if (!mounted) return;
    if (opening != null && opening.html.isNotEmpty) {
      _openOpening(opening);
    } else {
      _openChapter(_flatChapters.first);
    }
  }

  /// 打开书籍第一页（开头内容，如 EPUB 标题页）
  void _openOpening(RenderedContent opening) {
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
          openingContent: opening.html,
          openingFonts: opening.fonts,
          openingIsVertical: opening.isVertical,
          openingPlainText: opening.plainText,
        ),
      ),
    );
  }

  /// 跳转到指定章节的阅读页面
  void _openChapter(Chapter chapter, {int? initialPage}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterScreen(
          bookId: _book.id,
          chapterIndex: chapter.index,
          chapterTitle: chapter.title,
          filePath: _book.filePath,
          chapters: _flatChapters,
          book: _book,
          initialPage: initialPage,
        ),
      ),
    );
  }

  /// 构建封面图片
  ///
  /// 封面来源：
  /// 1. 如果[_book.coverPath]存在且文件有效，显示实际封面
  /// 2. 否则显示默认封面图标
  Widget _buildCover() {
    const coverSize = 200.0;

    if (_book.coverPath != null && File(_book.coverPath!).existsSync()) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(_book.coverPath!),
          width: coverSize,
          height: coverSize * 1.5,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildDefaultCover(coverSize),
        ),
      );
    }
    return _buildDefaultCover(coverSize);
  }

  /// 构建默认封面（当无封面图片时）
  Widget _buildDefaultCover(double size) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: size,
        height: size * 1.5,
        decoration: BoxDecoration(
          color: Colors.blueGrey[100],
        ),
        child: Center(
          child: Icon(
            Icons.book,
            size: 80,
            color: Colors.blueGrey[300],
          ),
        ),
      ),
    );
  }

  /// 构建章节目录内容
  ///
  /// 显示逻辑：
  /// 1. **加载中**：显示进度指示器
  /// 2. **无章节**：显示"暂无章节信息"
  /// 3. **有章节**：显示层级缩进的章节列表
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

  /// 构建章节列表项
  ///
  /// 章节列表显示规则：
  ///
  /// **缩进规则**：
  /// - 顶层章节(level=0)：无缩进
  /// - 一级子章节(level=1)：缩进16像素
  /// - 二级子章节(level=2)：缩进32像素
  /// - 以此类推...
  ///
  /// **样式规则**：
  /// - 字体大小：15 - level * 1（顶层15px，一级14px...）
  /// - 颜色：子章节使用灰色(Colors.grey[600])，顶层章节使用默认颜色
  /// - 最大显示1行，超出显示省略号
  ///
  /// **交互规则**：
  /// - 只有顶层章节(level=0)可以点击
  /// - 子章节不可点击（onTap为null）
  /// - 点击顶层章节跳转到[ChapterScreen]
  List<Widget> _buildChapterList() {
    final widgets = <Widget>[];
    for (final chapter in _flatChapters) {
      // 根据层级添加缩进（每层缩进16像素）
      final indent = chapter.level * 16.0;

      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: ListTile(
            dense: true,
            title: Text(
              chapter.title,
              style: TextStyle(
                // 字体大小随层级递减
                fontSize: 15 - chapter.level * 1,
                // 子章节颜色较淡
                color: chapter.level > 0 ? Colors.grey[600] : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // 只有顶层章节才能点击进入阅读
            onTap:
                chapter.level == 0 ? () => _openChapter(chapter) : null, // 子章节不可点击
          ),
        ),
      );
    }
    return widgets;
  }
}
