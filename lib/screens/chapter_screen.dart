// 章节阅读界面
//
// 核心阅读界面，左侧垂直 Tab 提供 原文 / 缩写 / 译文 / 目录 四个视图：
// - 原文：EPUB 横排走分页渲染、竖排走 tategaki，PDF 走单页查看器
// - 缩写 / 译文：只读取已缓存内容，不在本页触发 AI 生成
// - 目录：全书章节列表，点击原地跳章

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdfrx/pdfrx.dart';
import 'package:tategaki/tategaki.dart';
import '../models/chapter.dart';
import '../models/book.dart';
import '../models/reader_typography.dart';
import '../services/ai_service.dart';
import '../services/book_service.dart';
import '../services/summary_service.dart';
import '../services/parsers/book_format_parser.dart';
import '../services/parsers/rendered_content.dart';
import '../services/log_service.dart';
import '../services/settings_service.dart';
import '../widgets/chapter_directory.dart';
import '../widgets/book_paginator.dart';
import '../widgets/html_pagination.dart';
import '../widgets/paged_reader_controller.dart';
import '../widgets/paged_reading_view.dart';
import '../widgets/svg_widget_factory.dart';

/// 滚动位置锚点
class ScrollAnchor {
  /// 滚动比例（0.0 = 顶部, 1.0 = 底部）
  final double scrollRatio;

  const ScrollAnchor({
    this.scrollRatio = 0.0,
  });
}

/// 章节阅读界面 Widget
///
/// 参数说明：
/// - [bookId]: 书籍唯一标识
/// - [chapterIndex]: 章节索引（基于第一级章节列表）
/// - [chapterTitle]: 章节标题（默认值，可能被AI更新后的标题覆盖）
/// - [chapterContent]: 章节内容（可选，EPUB时可能预加载）
/// - [filePath]: 文件路径（用于重新加载内容）
/// - [chapters]: 章节列表（用于导航）
/// - [book]: 书籍对象（包含AI更新后的章节标题）
/// - [openingContent]: 书籍开头页 HTML（合并的前置页，可选，用于从开头开始阅读）
/// - [initialPage]: PDF 起始页码（可选，用于「阅读」从第 1 页开始）
class ChapterScreen extends StatefulWidget {
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String? chapterContent;
  final String? filePath;
  final List<Chapter>? chapters;
  final Book? book;

  /// 书籍自身排版（字号/行距/段距）
  ///
  /// 全局设置为默认值时作为起步值，并始终作为「重置」的恢复目标；
  /// 书籍未定义的项回退应用默认值（21 / 1.6 / 0.8）。
  final ReaderTypography? bookTypography;

  final String? openingContent;
  final List<EmbeddedFont>? openingFonts;
  final bool openingIsVertical;
  final String openingPlainText;
  final int? initialPage;

  /// 初始定位锚点（子章节标题）：打开所属顶层章节后定位到该子章节所在页
  final String? initialAnchor;

  /// 初始分页页码（0 起）：恢复上次阅读位置时使用
  final int? initialPagedPage;

  const ChapterScreen({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.chapterContent,
    this.filePath,
    this.chapters,
    this.book,
    this.bookTypography,
    this.openingContent,
    this.openingFonts,
    this.openingIsVertical = false,
    this.openingPlainText = '',
    this.initialPage,
    this.initialAnchor,
    this.initialPagedPage,
  });

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen>
    with TickerProviderStateMixin {
  /// AI服务（用于语言检测与译文生成）
  final _aiService = AIService();

  /// 日志服务
  final _log = LogService();

  /// 缩写服务（用于读取已缓存缩写与译文）
  final _summaryService = SummaryService();

  /// 当前章节的缩写数据
  Chapter? _summaryChapter;

  /// 错误信息
  String? _error;

  /// 是否正在加载章节内容（首次进入时的整页加载）
  bool _isLoadingContent = false;

  /// 章节内容（HTML格式）
  String _content = '';

  /// 是否为竖排排版（writing-mode: vertical-rl/lr）
  bool _isVertical = false;

  /// 纯文本（段落已换行），供竖排与分页模式复用
  String _plainText = '';

  /// 分页阅读控制器（章节内容、页列表、当前页、目标位置与过渡动画全在其内）
  late final PagedReaderController _reader;

  /// 全书后台分页器（页码指示全书化、跨章直接用缓存页列表）
  BookPaginator? _paginator;

  /// 已应用到可视章节的后台分页结果版本号
  int _appliedPagesRevision = 0;

  /// 控制器当前页列表所属的章节（-1 = 开头页），用于避免把旧章页列表回填给新章
  int? _readerChapterIndex;

  /// 上次观察到的分页页码/总页数，仅在页码变化时触发位置保存
  int _observedPage = 0;
  int _observedTotal = 0;

  /// 是否正在切换章节（新章内容加载中）
  ///
  /// 加载期间屏幕上仍是旧章内容，若此时再触发翻页/跨章（用户以为没反应而连点），
  /// 会基于旧章的页码再跳一章，导致跳过整章。加载完成前忽略新的翻章请求。
  bool _switchingChapter = false;

  /// 章节标题（翻章/加载时动态更新）
  String _title = '';

  /// 当前是否显示书籍开头页（封面/目录/版权页等未列入章节的前置页）
  ///
  /// 开头页是位于第一章之前的一个独立位置：第一章首页继续向前翻回到开头页末页，
  /// 开头页末页继续向后翻进入第一章首页。此时 [_currentIndex] 仍为 0（便于复用
  /// 章节相关逻辑），阅读位置按 -1 保存，与第一章区分。
  bool _showingOpening = false;

  /// 当前章节索引（可在本页内切换章节，不触发页面路由）
  int _currentIndex = 0;

  /// PDF 起始页码（仅「阅读」从第一页进入时使用；切换章节后失效）
  int? _initialPage;

  /// 阅读位置保存防抖定时器（翻页频繁时不每次都写文件）
  Timer? _savePositionTimer;

  /// 已写入存储的阅读位置（章节/页码），用于跳过重复写入
  int? _savedChapterIndex;
  int? _savedPageIndex;

  /// Tab控制器（用于垂直Tab布局）
  TabController? _tabController;

  /// 内容是否过短（少于2000字节）
  /// 内容过短时缩写 tab 置灰
  bool _contentTooShort = false;

  /// 第一级章节列表（用于导航）
  /// 注意：只包含level=0的章节，忽略子章节
  List<Chapter> _chapters = [];

  /// 完整章节列表（含子章节）
  /// 合并顶层章节内容时必须用它：顶层章节的正文常分散在其后的子章节中
  /// （如「街 亭」的正文位于子章节「街亭败战」所在的文件），
  /// 若只传 level=0 列表，子章节会被跳过导致整段正文丢失。
  List<Chapter> _allChapters = [];

  /// PDF当前页码（用于PDF原文阅读时的翻页）
  int _pdfCurrentPage = 1;

  /// PDF总页数（从文档加载后设置）
  int _pdfTotalPages = 0;

  /// 译文内容（已缓存的译文）
  String? _translationContent;

  /// 是否正在翻译
  bool _isTranslating = false;

  /// 流式译文内容（实时显示AI翻译的内容）
  String _streamingTranslation = '';

  /// 目标语言代码（用于译文生成）
  String? _targetLang;

  /// 源语言代码（从书籍元数据获取）
  String? _sourceLang;

  /// 摘要语言代码（当前使用的摘要语言）
  String _summaryLang = 'zh';

  /// 译文Tab是否禁用（当书籍语言与目标语言相同时禁用）
  bool _translationTabDisabled = false;

  /// 译文滚动控制器
  ScrollController? _translationScrollController;

  /// 原文滚动控制器（EPUB格式）
  ScrollController? _originalScrollController;

  /// 当前共享的滚动锚点（用于Tab间同步）
  ScrollAnchor _currentScrollAnchor = const ScrollAnchor();

  /// 设置服务（阅读排版设置来自这里，改动后即时重排）
  final _settingsService = SettingsService();

  /// 阅读正文字号（来自设置，阅读页其余字号均由它按比例推导）
  late double _readerFontSize;

  /// 阅读行高倍数（来自设置）
  late double _readerLineHeight;

  /// 阅读段距系数（段落间距 = 字号 × 系数）
  late double _paragraphSpacing;

  /// 摘要/译文/原文通用的正文文本样式
  late TextStyle _contentTextStyle;

  /// 竖排正文相对正文字号的比例
  static const double _verticalScale = 0.86;

  /// 应用默认排版（书籍未定义且全局设置为默认值时使用）
  static const double _defaultFontSize = 21.0;
  static const double _defaultLineHeight = 1.6;
  static const double _defaultParagraphSpacing = 0.8;

  /// 已通过 FontLoader 注册的字体家族（避免重复加载）
  final Set<String> _loadedFontFamilies = {};

  @override
  void initState() {
    super.initState();

    // 生效排版 = 全局覆盖值 → 原书排版 → 应用默认值
    _readerFontSize = _effectiveFontSize(
        _settingsService.readerFontSizeOverride.value);
    _readerLineHeight = _effectiveLineHeight(
        _settingsService.readerLineHeightOverride.value);
    _paragraphSpacing = _effectiveParagraphSpacing(
        _settingsService.readerParagraphSpacingOverride.value);

    _contentTextStyle =
        TextStyle(fontSize: _readerFontSize, height: _readerLineHeight);
    _settingsService.readerFontSizeOverride.addListener(_onTypographyChanged);
    _settingsService.readerLineHeightOverride.addListener(_onTypographyChanged);
    _settingsService.readerParagraphSpacingOverride
        .addListener(_onTypographyChanged);

    _currentIndex = widget.chapterIndex;
    _showingOpening =
        widget.openingContent != null && widget.openingContent!.isNotEmpty;
    _initialPage = widget.initialPage;
    _savedChapterIndex = widget.book?.lastChapterIndex;
    _savedPageIndex = widget.book?.lastPageIndex;
    _title = widget.chapterTitle;

    _reader = PagedReaderController(
      vsync: this,
      textStyle: _contentTextStyle,
      paragraphSpacingFactor: _paragraphSpacing,
      onBoundary: _onReaderBoundary,
      onLayout: _onReaderLayout,
    )..addListener(_onReaderChanged);

    if (widget.chapters != null) {
      _allChapters = List<Chapter>.from(widget.chapters!);
      _chapters = _allChapters.where((c) => c.level == 0).toList();
    }

    // EPUB 等 HTML 书籍启用全书后台分页（PDF 用页码，不走分页）
    final isPdf = widget.book?.format == BookFormat.pdf;
    if (!isPdf) {
      _paginator = BookPaginator(
        textStyle: _contentTextStyle,
        paragraphSpacingFactor: _paragraphSpacing,
        chapterCount: _chapters.length,
        hasOpening: widget.filePath != null ||
            (widget.openingContent != null && widget.openingContent!.isNotEmpty),
        loader: _loadChapterRendered,
        registerFonts: _loadEmbeddedFonts,
      )..addListener(_onPaginatorChanged);
    }

    _translationScrollController = ScrollController();
    _originalScrollController = ScrollController();

    _tabController = TabController(length: 4, vsync: this);
    _tabController!.addListener(() {
      if (mounted) {
        setState(() {});

        if (!_tabController!.indexIsChanging) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncScrollToTab(_tabController!.index);
          });

          if (_tabController!.index == 2) {
            _ensureTranslation();
          }
        } else {
          _captureScrollAnchor(_tabController!.previousIndex);
        }
      }
    });

    _initializeLanguageSettings();

    _initializeContent();
  }

  @override
  void dispose() {
    // 退出阅读时记录位置，下次从书架打开可直接续读
    _savePositionTimer?.cancel();
    _saveReadingPosition();
    _settingsService.readerFontSizeOverride.removeListener(_onTypographyChanged);
    _settingsService.readerLineHeightOverride
        .removeListener(_onTypographyChanged);
    _settingsService.readerParagraphSpacingOverride
        .removeListener(_onTypographyChanged);
    _summaryService.unregisterTranslationCallback(widget.bookId, _currentIndex);
    _translationScrollController?.dispose();
    _originalScrollController?.dispose();
    _paginator
      ?..removeListener(_onPaginatorChanged)
      ..dispose();
    _reader
      ..removeListener(_onReaderChanged)
      ..dispose();
    _tabController?.dispose();
    super.dispose();
  }

  /// 初始化章节内容
  ///
  /// 内容来源优先级：
  /// 1. 已传入的 openingContent（书籍第一页，用于「阅读」从开头开始）
  /// 2. 已传入的 chapterContent（预加载的内容）
  /// 3. 从文件路径重新加载（通过FormatRegistry解析）
  ///
  /// 同时检查内容长度，内容过短时自动切换到原文视图
  Future<void> _initializeContent() async {
    // 恢复上次阅读位置：把一次性页码转成「打开意图」交给控制器消费
    final initialTarget = PagedOpenTarget.page(widget.initialPagedPage ?? 0);

    if (widget.openingContent != null && widget.openingContent!.isNotEmpty) {
      _content = widget.openingContent!;
      _title = widget.chapterTitle;
      _isVertical = widget.openingIsVertical;
      _plainText = widget.openingPlainText;
      _loadEmbeddedFonts(widget.openingFonts ?? const []);
      _paginator?.provideContent(
        -1,
        RenderedContent(
          _content,
          fonts: widget.openingFonts ?? const [],
          isVertical: widget.openingIsVertical,
          plainText: widget.openingPlainText,
        ),
      );
      _checkContentLength();
      _readerChapterIndex = -1;
      _reader.open(_content, target: initialTarget);
      _updateBookPaging();
      if (!mounted) return;
      setState(() => _isLoadingContent = false);
      return;
    }

    if (widget.chapterContent != null && widget.chapterContent!.isNotEmpty) {
      _content = widget.chapterContent!;
      _title = widget.chapterTitle;
      _paginator?.provideContent(_currentIndex, RenderedContent(_content));
      _checkContentLength();
      _readerChapterIndex = _currentIndex;
      _reader.open(_content, target: initialTarget);
      _updateBookPaging();
      if (!mounted) return;
      setState(() => _isLoadingContent = false);
      return;
    }

    if (widget.filePath != null) {
      if (!mounted) return;
      setState(() => _isLoadingContent = true);
      await _loadChapterContent(target: initialTarget);
      return;
    }

    if (!mounted) return;
    setState(() {
      _error = '未提供章节内容或文件路径';
      _isLoadingContent = false;
    });
  }

  /// 检查内容长度
  ///
  /// 内容不超过一页（约 2000 字节）时标记为过短，置灰缩写 Tab。
  void _checkContentLength() {
    final textContent = _summaryService.stripHtml(_content);
    _contentTooShort = !_summaryService.shouldAbbreviate(textContent);
  }

  /// 运行时注册 EPUB 内嵌字体（通过 FontLoader）
  ///
  /// 字体家族已注册过则跳过，避免重复加载同一字体。
  void _loadEmbeddedFonts(List<EmbeddedFont> fonts) {
    for (final font in fonts) {
      final family = font.family.trim();
      if (family.isEmpty || _loadedFontFamilies.contains(family)) continue;
      _loadedFontFamilies.add(family);

      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(font.bytes.buffer)));
      loader.load();
    }
  }

  /// 初始化语言设置
  ///
  /// 确定源语言和目标语言，判断译文Tab是否禁用
  Future<void> _initializeLanguageSettings() async {
    final langSettings = SettingsService().settings.languageSettings;

    _sourceLang = await _aiService.detectSourceLanguage(bookLanguage: widget.book?.language, content: _content, bookId: widget.book?.id);

    _targetLang = _aiService.resolveOutputLanguage(langSettings);

    _summaryLang = _targetLang ?? 'zh';
    _translationTabDisabled = _sourceLang == _targetLang;

    _log.d('ChapterScreen', '源语言=$_sourceLang, 目标语言=$_targetLang, 摘要语言=$_summaryLang, 译文Tab禁用=$_translationTabDisabled');

    _loadAbbreviation();
  }

  /// 读取已缓存的章节缩写并显示（仅读缓存，不生成、不调用AI）
  Future<void> _loadAbbreviation() async {
    final abbreviation = await _summaryService.getChapterAbbreviation(
      widget.bookId, _currentIndex,
      language: _summaryLang,
    );
    if (!mounted) return;
    setState(() => _summaryChapter = abbreviation);
  }

  /// 从文件加载章节内容
  ///
  /// 使用FormatRegistry获取对应格式的解析器，
  /// 解析章节列表并获取指定章节的内容
  Future<void> _loadChapterContent({
    PagedOpenTarget target = PagedOpenTarget.first,
  }) async {
    try {
      // 合并章节内容需要完整章节列表（含子章节），否则顶层章节的正文会丢失
      List<Chapter> chapters =
          _allChapters.isNotEmpty ? _allChapters : (widget.chapters ?? []);

      if (chapters.isEmpty && widget.filePath != null) {
        final extension = _getFileExtension(widget.filePath!);
        final parser = FormatRegistry.getParser(extension);

        if (parser != null) {
          chapters = await parser.getChapters(widget.filePath!);
        } else {
          _log.e('ChapterScreen', '不支持的格式: $extension');
        }
      }

      _allChapters = chapters;
      final topLevelChapters = chapters.where((c) => c.level == 0).toList();
      _chapters = topLevelChapters;
      // 章节列表延迟加载时同步给后台分页器
      _paginator?.syncCounts(
        chapterCount: topLevelChapters.length,
        hasOpening: widget.filePath != null ||
            (widget.openingContent != null && widget.openingContent!.isNotEmpty),
      );

      if (_currentIndex < 0 ||
          _currentIndex >= topLevelChapters.length) {
        if (!mounted) return;
        setState(() {
          _error =
              '章节索引超出范围: $_currentIndex, 总章节数: ${topLevelChapters.length}';
          _isLoadingContent = false;
        });
        return;
      }

      final chapter = topLevelChapters[_currentIndex];
      _title = chapter.title;

      RenderedContent? rendered;
      try {
        if (widget.filePath != null) {
          final extension = _getFileExtension(widget.filePath!);
          final parser = FormatRegistry.getParser(extension);

          if (parser != null) {
            rendered = await parser.getChapterContentMerged(
              widget.filePath!,
              chapter,
              chapters,
            );
          }
        }
      } catch (e) {
        _log.e('ChapterScreen', '获取章节内容失败', e);
      }

      if (rendered == null || rendered.html.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = '章节内容为空';
          _isLoadingContent = false;
        });
        return;
      }

      _loadEmbeddedFonts(rendered.fonts);
      _paginator?.provideContent(_currentIndex, rendered);

      final content = rendered.html;
      final isVertical = rendered.isVertical;
      final renderedPlainText = rendered.plainText;
      if (!mounted) return;
      setState(() {
        _content = content;
        _isVertical = isVertical;
        _plainText = renderedPlainText;
        _isLoadingContent = false;
      });
      _checkContentLength();
      // 内容就绪后把「打开到某位置」的意图交给分页控制器，由其分页稳定后定位
      _readerChapterIndex = _currentIndex;
      _reader.open(content, target: target);
      _updateBookPaging();
      // 新内容渲染后重置滚动到顶部（翻章后新章节从顶部开始阅读）
      _resetScrollAfterChapterChange();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载章节内容失败: $e';
        _isLoadingContent = false;
      });
    }
  }

  /// 获取文件扩展名（包含点，如 .epub）
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filePath.substring(lastDot).toLowerCase();
  }

  /// 翻章后把滚动条复位到顶部
  void _resetScrollAfterChapterChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_originalScrollController?.hasClients == true) {
        _originalScrollController!.jumpTo(0);
      }
      if (_translationScrollController?.hasClients == true) {
        _translationScrollController!.jumpTo(0);
      }
      _currentScrollAnchor = const ScrollAnchor();
    });
  }

  /// 后台分页内容加载器：index = -1 为书籍开头页
  Future<RenderedContent?> _loadChapterRendered(int index) async {
    final filePath = widget.filePath;
    if (index < 0) {
      if (widget.openingContent != null && widget.openingContent!.isNotEmpty) {
        return RenderedContent(
          widget.openingContent!,
          fonts: widget.openingFonts ?? const [],
          isVertical: widget.openingIsVertical,
          plainText: widget.openingPlainText,
        );
      }
      if (filePath == null) return null;
      final parser = FormatRegistry.getParser(_getFileExtension(filePath));
      return parser?.getOpeningContent(filePath);
    }

    if (filePath == null || index >= _chapters.length) return null;
    final parser = FormatRegistry.getParser(_getFileExtension(filePath));
    if (parser == null) return null;
    final chapters =
        _allChapters.isNotEmpty ? _allChapters : (widget.chapters ?? []);
    return parser.getChapterContentMerged(filePath, _chapters[index], chapters);
  }

  /// 分页阅读控制器上报可用尺寸：驱动全书后台分页按同一几何尺寸重排
  void _onReaderLayout(double width, double height) {
    final paginator = _paginator;
    if (paginator == null) return;
    final visible = _showingOpening ? -1 : _currentIndex;
    paginator.setPriority(visible);
    paginator.configure(
      width,
      height,
      // 当前章正由控制器测量，后台先跳过它，测完经 adopt 回填，避免重复测最大的一章
      exclude: _reader.usesExternalPages ? null : visible,
    );
  }

  /// 后台分页进度变化：刷新全书页码；界面重排后替换可视章节页列表
  void _onPaginatorChanged() {
    if (!mounted) return;
    final paginator = _paginator;
    if (paginator == null) return;

    final index = _showingOpening ? -1 : _currentIndex;
    if (_reader.usesExternalPages) {
      final revision = paginator.revisionFor(index);
      if (revision != 0 && revision != _appliedPagesRevision) {
        final result = paginator.pagesFor(index);
        if (result != null && result.pages.isNotEmpty) {
          _appliedPagesRevision = revision;
          _reader.replacePages(
            result.pages,
            pageStartBlocks: result.pageStartBlocks,
            blockTexts: result.blockTexts,
          );
        }
      }
    }
    _updateBookPaging();
  }

  /// 把后台分页进度同步到页码指示（前缀未知时回退章节内页码）
  void _updateBookPaging() {
    final paginator = _paginator;
    if (paginator == null) return;
    final index = _showingOpening ? -1 : _currentIndex;
    _reader.updateBookPaging(
      pageStart: paginator.startPageFor(index),
      totalPages: paginator.totalPages,
    );
  }

  /// 控制器测完可视章节后，把结果回填给后台分页器（避免重复测量、页码统一）
  void _adoptVisibleChapter() {
    final paginator = _paginator;
    if (paginator == null) return;
    if (_reader.usesExternalPages || _reader.isMeasuring) return;
    if (_reader.pages.isEmpty) return;
    final index = _showingOpening ? -1 : _currentIndex;
    if (_readerChapterIndex != index) return;
    paginator.adopt(
      index,
      PaginatedBlocks(
        pages: _reader.pages,
        pageStartBlocks: _reader.pageStartBlocks,
        blockTexts: _reader.blockTexts,
      ),
      html: _content,
    );
  }

  /// 捕获指定Tab的滚动锚点到共享变量
  void _captureScrollAnchor(int tabIndex) {
    ScrollController? controller;

    switch (tabIndex) {
      case 0:
        controller = _originalScrollController;
        break;
      case 2:
        controller = _translationScrollController;
        break;
      default:
        return;
    }

    if (controller == null || !controller.hasClients) {
      return;
    }

    final maxScroll = controller.position.maxScrollExtent;
    if (maxScroll > 0) {
      _currentScrollAnchor = ScrollAnchor(
        scrollRatio: controller.offset / maxScroll,
      );
    }
  }

  /// 将共享的滚动锚点恢复到指定Tab
  void _syncScrollToTab(int tabIndex) {
    if (tabIndex == 1) return;

    ScrollController? controller;

    switch (tabIndex) {
      case 0:
        controller = _originalScrollController;
        break;
      case 2:
        controller = _translationScrollController;
        break;
      default:
        return;
    }

    if (controller == null || !controller.hasClients) {
      return;
    }

    final maxScroll = controller.position.maxScrollExtent;
    final targetOffset = _currentScrollAnchor.scrollRatio * maxScroll;
    controller.jumpTo(targetOffset.clamp(0.0, maxScroll));
  }

  /// 清理 <code> 和 <pre> 标签中多余的反斜杠
  String _cleanCodeBackslashes(String html) {
    return html.replaceAllMapped(
      RegExp(r'(<code[^>]*>)([\s\S]*?)(</code>)|(<pre[^>]*>)([\s\S]*?)(</pre>)',
          caseSensitive: false),
      (match) {
        if (match.group(0)!.startsWith('<code') ||
            match.group(0)!.startsWith('<CODE')) {
          final content = match.group(2)!;
          return '${match.group(1)}${content.replaceAll(r'\\', r'\')}${match.group(3)}';
        } else {
          final content = match.group(5)!;
          return '${match.group(4)}${content.replaceAll(r'\\', r'\')}${match.group(6)}';
        }
      },
    );
  }

  /// 将HTML中的代码块替换为唯一占位符
  ///
  /// 返回处理后的HTML与原始代码块列表。
  (String, List<String>) _extractCodeBlocksToPlaceholders(String html) {
    final codeBlocks = <String>[];
    final codeRegex = RegExp(
        r'(<code[^>]*>[\s\S]*?</code>)|(<pre[^>]*>[\s\S]*?</pre>)',
        caseSensitive: false,
        dotAll: true);

    int index = 0;
    final result = html.replaceAllMapped(codeRegex, (match) {
      codeBlocks.add(match.group(0)!);
      return '%%ZHIDU_CODE_BLOCK_${index++}%%';
    });

    return (result, codeBlocks);
  }

  /// 将占位符替换回原始代码块
  String _restorePlaceholdersToCodeBlocks(
      String html, List<String> codeBlocks) {
    final placeholderRegex = RegExp(r'%%ZHIDU_CODE_BLOCK_(\d+)%%');
    return html.replaceAllMapped(placeholderRegex, (match) {
      final index = int.tryParse(match.group(1)!) ?? -1;
      if (index >= 0 && index < codeBlocks.length) {
        return codeBlocks[index];
      }
      return match.group(0)!;
    });
  }

  /// 确保章节译文存在（加载缓存或触发流式生成）
  Future<void> _ensureTranslation() async {
    if (_translationTabDisabled) return;
    if (_targetLang == null || _content.isEmpty) return;

    if (!_aiService.isConfigured) return;

    try {
      setState(() {
        _isTranslating = true;
        _streamingTranslation = '';
      });

      final (contentWithPlaceholders, codeBlocks) =
          _extractCodeBlocksToPlaceholders(_content);

      _summaryService.registerTranslationCallback(widget.bookId, _currentIndex, (content) {
        if (mounted) {
          _captureScrollAnchor(2);
          setState(() { _streamingTranslation = _restorePlaceholdersToCodeBlocks(content, codeBlocks); });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncScrollToTab(2);
          });
        }
      });

      final translation = await _summaryService.ensureChapterTranslation(
        bookId: widget.bookId,
        chapterIndex: _currentIndex,
        content: contentWithPlaceholders,
        chapterTitle: _title,
        sourceLang: _sourceLang ?? 'zh',
        targetLang: _targetLang!,
      );

      if (!mounted) return;
      setState(() {
        _translationContent = translation != null
            ? _restorePlaceholdersToCodeBlocks(_cleanCodeBackslashes(translation), codeBlocks)
            : null;
        _isTranslating = false;
        _streamingTranslation = '';
      });
    } catch (e, stackTrace) {
      _log.e('ChapterScreen', '翻译失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isTranslating = false;
          _streamingTranslation = '';
        });
      }
    }
  }

  /// 排版设置变化（字号/行距/段距）：更新样式并就地重新分页
  void _onTypographyChanged() {
    if (!mounted) return;
    final font = _effectiveFontSize(
        _settingsService.readerFontSizeOverride.value);
    final line = _effectiveLineHeight(
        _settingsService.readerLineHeightOverride.value);
    final spacing = _effectiveParagraphSpacing(
        _settingsService.readerParagraphSpacingOverride.value);
    if (font == _readerFontSize &&
        line == _readerLineHeight &&
        spacing == _paragraphSpacing) {
      return;
    }

    _readerFontSize = font;
    _readerLineHeight = line;
    _paragraphSpacing = spacing;
    _contentTextStyle = TextStyle(fontSize: font, height: line);

    _reader.updateTypography(_contentTextStyle, spacing);
    _paginator?.updateTypography(_contentTextStyle, spacing);

    // 分页视图：保留当前页重新分页（不播放跨章过渡）；竖排只需重建
    if (!_isVertical && _content.isNotEmpty) {
      _reader.open(
        _content,
        target: PagedOpenTarget.page(_reader.currentPage),
        animate: false,
      );
    }
    setState(() {});
  }

  /// 生效值 = 全局覆盖值 → 原书排版 → 应用默认值
  double _effectiveFontSize(double? override) =>
      override ?? widget.bookTypography?.fontSize ?? _defaultFontSize;

  double _effectiveLineHeight(double? override) =>
      override ?? widget.bookTypography?.lineHeight ?? _defaultLineHeight;

  double _effectiveParagraphSpacing(double? override) =>
      override ??
      widget.bookTypography?.paragraphSpacing ??
      _defaultParagraphSpacing;

  /// 调整字号（步长 2，范围 12~40）
  void _adjustFontSize(double delta) {
    final value = (_readerFontSize + delta).clamp(12.0, 40.0);
    _settingsService.setReaderFontSize(value);
  }

  /// 调整行距（步长 0.1，范围 1.1~2.4）
  void _adjustLineHeight(double delta) {
    final value =
        (((_readerLineHeight + delta) * 10).round() / 10).clamp(1.1, 2.4);
    _settingsService.setReaderLineHeight(value);
  }

  /// 调整段距（步长 0.2，范围 0~2.0，系数相对字号）
  void _adjustParagraphSpacing(double delta) {
    final value =
        (((_paragraphSpacing + delta) * 10).round() / 10).clamp(0.0, 2.0);
    _settingsService.setReaderParagraphSpacing(value);
  }

  /// 排版设置菜单（文字 / 行距 / 段距 三组，各含 +、-、重置）
  Widget _buildTypographyMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypographyRow(
            '文字',
            Icons.text_fields,
            onIncrease: () => _adjustFontSize(2),
            onDecrease: () => _adjustFontSize(-2),
            // 清除全局覆盖，回到当前书籍原书排版（未定义则应用默认值）
            onReset: () => _settingsService.setReaderFontSize(null),
          ),
          const Divider(height: 10),
          _buildTypographyRow(
            '行距',
            Icons.format_line_spacing,
            onIncrease: () => _adjustLineHeight(0.1),
            onDecrease: () => _adjustLineHeight(-0.1),
            onReset: () => _settingsService.setReaderLineHeight(null),
          ),
          const Divider(height: 10),
          _buildTypographyRow(
            '段距',
            Icons.space_bar,
            onIncrease: () => _adjustParagraphSpacing(0.2),
            onDecrease: () => _adjustParagraphSpacing(-0.2),
            onReset: () =>
                _settingsService.setReaderParagraphSpacing(null),
          ),
        ],
      ),
    );
  }

  /// 一组排版操作：标签 + 字体/行距/段距图标 + 加/减/重置
  Widget _buildTypographyRow(
    String label,
    IconData icon, {
    required VoidCallback onIncrease,
    required VoidCallback onDecrease,
    required VoidCallback onReset,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        SizedBox(
          width: 34,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          tooltip: '$label +',
          onPressed: onIncrease,
        ),
        IconButton(
          icon: const Icon(Icons.remove),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          tooltip: '$label -',
          onPressed: onDecrease,
        ),
        IconButton(
          icon: const Icon(Icons.settings_backup_restore),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          tooltip: '$label 重置',
          onPressed: onReset,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                // 显式取 AppBar 前景色：textTheme 自带 onSurface 颜色，浅色模式下
                // 会让主色背景上的标题变黑、难以辨认
                color: Theme.of(context).appBarTheme.foregroundColor,
              ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 排版设置：点击后弹出文字/行距/段距三组调节项
          MenuAnchor(
            builder: (context, controller, child) => IconButton(
              icon: const Icon(Icons.format_size),
              tooltip: '排版设置',
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
            menuChildren: [_buildTypographyMenu()],
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          // 章节导航按钮：多个章节时才显示
          if (_chapters.length > 1) _buildNavigationButtons(),
          // 全书后台分页的离屏测量列（不参与显示与点击）
          if (_paginator != null)
            Positioned(
              left: -100000,
              top: 0,
              child: IgnorePointer(
                child: BookPaginatorHost(paginator: _paginator!),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建主体内容
  ///
  /// 根据状态显示不同视图：
  /// 1. 加载中 -> 加载视图
  /// 2. 有错误且无内容 -> 错误视图
  /// 3. 其他 -> 带Tab布局的原文/缩写/译文视图
  Widget _buildBody() {
    if (_isLoadingContent) {
      return _buildLoadingView();
    }

    if (_error != null && _content.isEmpty) {
      return _buildErrorView();
    }

    // 始终使用Tab布局，无摘要/有缓存摘要状态在缩写 Tab 内部处理
    return _buildSummaryView();
  }

  /// 构建加载视图
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '正在加载章节内容...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建错误视图
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
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '出错了',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建章节阅读主视图（垂直Tab布局）
  ///
  /// 布局说明：
  /// - 左侧：垂直Tab栏（原文/缩写/译文切换）
  /// - 右侧：TabBarView内容区
  ///
  /// PDF原文阅读功能：
  /// - PDF格式的书籍在原文模式下使用PdfDocumentViewBuilder
  /// - 支持单页PDF查看，配合翻页按钮
  Widget _buildSummaryView() {
    final bool abbreviationDisabled = _contentTooShort;

    final selectedColor = Theme.of(context).colorScheme.primary.withAlpha(40);
    final unselectedColor =
        Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(40);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _buildVerticalTab(0, Icons.menu_book,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor),
              Container(
                  height: 1,
                  width: 44,
                  color: Theme.of(context).colorScheme.outlineVariant),
              _buildVerticalTab(1, Icons.auto_awesome,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  disabled: abbreviationDisabled),
              Container(
                  height: 1,
                  width: 44,
                  color: Theme.of(context).colorScheme.outlineVariant),
              _buildVerticalTab(2, Icons.translate,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  disabled: _translationTabDisabled),
              Container(
                  height: 1,
                  width: 44,
                  color: Theme.of(context).colorScheme.outlineVariant),
              _buildVerticalTab(3, Icons.toc,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor),
            ],
          ),
          Expanded(
            child: Container(
              color: selectedColor,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOriginalTextView(),
                  _buildSummaryContent(),
                  _buildTranslationView(),
                  _buildDirectoryView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建目录视图：封面 + 全书章节列表（复用书籍详情页的封面与列表样式）
  Widget _buildDirectoryView() {
    final chapters = _allChapters.isNotEmpty ? _allChapters : _chapters;
    return ChapterDirectory(
      book: widget.book,
      chapters: chapters,
      currentChapterIndex: _currentIndex,
      onChapterTap: _jumpFromDirectory,
    );
  }

  /// 目录点击：跳到目标章节（子章节定位到其标题所在页），并切回原文 Tab
  void _jumpFromDirectory(Chapter chapter) {
    _gotoChapterNode(chapter);
    _tabController?.animateTo(0);
  }

  /// 跳转到章节节点：顶层章节跳首页，子章节跳到其标题所在页
  ///
  /// 目录点击与正文内链接点击共用此逻辑。
  void _gotoChapterNode(Chapter chapter) {
    final top = _topLevelChapterOf(chapter);
    final index = _chapters.indexWhere((c) => c.index == top.index);
    if (index < 0) return;

    final anchor = chapter.level > 0 ? chapter.title : null;
    if (!_showingOpening && index == _currentIndex) {
      // 同一章内定位：无需重新加载内容，控制器直接按锚点重新定位
      _reader.retarget(
        anchor == null ? PagedOpenTarget.first : PagedOpenTarget.atAnchor(anchor),
      );
    } else {
      _navigateToChapter(index, anchor: anchor);
    }
  }

  /// 阅读正文中点击链接：解析 href 并跳到对应章节/锚点位置
  ///
  /// 支持相对路径（如 `text00001.html`、`text00005.html#bw1`）与同文件锚点
  /// （`#anchor`）：锚点若命中某个子章节，定位到该子章节标题所在页；否则按锚点
  /// id 在目标章节中取文本，定位到该文本所在页（如章节标题链接回目录的对应条目）。
  /// 指向图片的目录项已在解析阶段作为独立章节，普通匹配即可跳转。
  void _onLinkTap(String href) {
    final lower = href.toLowerCase();
    const externalPrefixes = [
      'http://', 'https://', 'mailto:', 'tel:', 'javascript:',
    ];
    if (lower.isEmpty || externalPrefixes.any(lower.startsWith)) return;

    final resolved = _resolveHref(_currentChapterFile(), href);
    if (resolved == null) return;
    final targetFile = resolved.$1.toLowerCase();
    final targetAnchor = resolved.$2;

    final list = _allChapters.isNotEmpty ? _allChapters : _chapters;
    Chapter? fileMatch;
    Chapter? anchorMatch;
    for (final c in list) {
      final parts = _splitHref(c.location.href);
      if (parts == null) continue;
      if (parts.$1.toLowerCase() != targetFile) continue;

      fileMatch ??= c;
      if (targetAnchor.isNotEmpty &&
          parts.$2.toLowerCase() == targetAnchor.toLowerCase()) {
        anchorMatch = c;
        break;
      }
    }

    if (anchorMatch != null) {
      _gotoChapterNode(anchorMatch);
      return;
    }
    if (fileMatch == null) return;
    if (targetAnchor.isEmpty) {
      _gotoChapterNode(fileMatch);
      return;
    }
    unawaited(_gotoChapterAnchor(fileMatch, targetAnchor));
  }

  /// 跳到「文件内锚点」位置：按锚点 id 从源文件取文本，再按文本定位到所在页
  Future<void> _gotoChapterAnchor(Chapter chapter, String anchorId) async {
    final top = _topLevelChapterOf(chapter);
    final index = _chapters.indexWhere((c) => c.index == top.index);
    if (index < 0) return;

    String? anchorText;
    final filePath = widget.filePath;
    final chapterHref = chapter.location.href;
    if (filePath != null && chapterHref != null) {
      final parser = FormatRegistry.getParser(_getFileExtension(filePath));
      anchorText =
          await parser?.getAnchorText(filePath, chapterHref, anchorId);
    }
    if (!mounted) return;

    final text = (anchorText != null && anchorText.trim().isNotEmpty)
        ? anchorText.trim()
        : null;
    if (!_showingOpening && index == _currentIndex) {
      _reader.retarget(
        text == null ? PagedOpenTarget.first : PagedOpenTarget.atAnchor(text),
      );
    } else {
      _navigateToChapter(index, anchor: text);
    }
  }

  /// 当前正文所对应的文件（用于解析相对 href）
  ///
  /// 开头页由多个前置文件合并，无法精确回溯来源，按首个章节所在目录近似解析。
  String? _currentChapterFile() {
    if (_showingOpening) {
      final first = _allChapters.isNotEmpty ? _allChapters.first : null;
      return _splitHref(first?.location.href)?.$1;
    }
    if (_currentIndex >= 0 && _currentIndex < _chapters.length) {
      return _splitHref(_chapters[_currentIndex].location.href)?.$1;
    }
    return null;
  }

  /// 拆分 href 为「文件路径 + 锚点」（均未规范化）
  (String, String)? _splitHref(String? href) {
    if (href == null || href.isEmpty) return null;
    final hash = href.indexOf('#');
    if (hash < 0) return (href, '');
    return (href.substring(0, hash), href.substring(hash + 1));
  }

  /// 将 [href] 相对 [currentFile] 解析为「规范化文件路径 + 锚点」
  (String, String)? _resolveHref(String? currentFile, String href) {
    final parts = _splitHref(href);
    if (parts == null) return null;
    final targetFile = parts.$1;
    final anchor = parts.$2;

    final String resolvedFile;
    if (targetFile.isEmpty) {
      resolvedFile = _normalizePath(currentFile ?? '');
    } else if (targetFile.startsWith('/')) {
      resolvedFile = _normalizePath(targetFile.substring(1));
    } else {
      final base = _dirname(currentFile ?? '');
      resolvedFile = _normalizePath(base.isEmpty ? targetFile : '$base/$targetFile');
    }
    return (resolvedFile, anchor);
  }

  /// 取路径所在目录（不含末尾文件名）
  String _dirname(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  /// 规范化路径：统一分隔符并折叠 `.` / `..` 段
  String _normalizePath(String path) {
    final segments = <String>[];
    for (final seg in path.replaceAll('\\', '/').split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (segments.isNotEmpty) segments.removeLast();
        continue;
      }
      segments.add(seg);
    }
    return segments.join('/');
  }

  /// 找到章节所属的顶层章节（level==0）
  Chapter _topLevelChapterOf(Chapter chapter) {
    if (chapter.level == 0) return chapter;
    final index = _allChapters.indexWhere((c) => identical(c, chapter));
    for (var i = index; i >= 0; i--) {
      if (_allChapters[i].level == 0) return _allChapters[i];
    }
    return _chapters.isNotEmpty ? _chapters.first : chapter;
  }

  /// 构建垂直Tab按钮（仅图标）
  ///
  /// 颜色层级：
  /// - 未选中：灰色背景（与页面有明显区分）
  /// - 选中：主题色背景（与右侧内容框同色）
  Widget _buildVerticalTab(int index, IconData icon,
      {required Color selectedColor,
      required Color unselectedColor,
      bool disabled = false}) {
    final isSelected = _tabController?.index == index;
    return InkWell(
      onTap: disabled ? null : () => _tabController?.animateTo(index),
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: isSelected ? selectedColor : unselectedColor,
        child: Icon(
          icon,
          size: 24,
          color: disabled
              ? Theme.of(context).colorScheme.onSurface.withAlpha(90)
              : isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 构建 HTML 渲染组件（统一启用 SVG 图片与错误兜底）
  ///
  /// [onLinkTap] 非空时启用链接点击跳转（正文原文用；缩写/译文不传）。
  Widget _buildHtml(String html, {void Function(String href)? onLinkTap}) {
    return HtmlWidget(
      html,
      textStyle: _contentTextStyle,
      factoryBuilder: () => SvgAwareWidgetFactory(),
      onErrorBuilder: htmlErrorBuilder,
      onTapUrl: onLinkTap == null
          ? null
          : (url) {
              onLinkTap(url);
              return true;
            },
    );
  }

  /// 构建缩写内容视图
  ///
  /// 将Markdown格式的缩写转换为HTML并渲染
  /// 使用flutter_widget_from_html_core组件显示，支持丰富的文本样式
  Widget _buildSummaryContent() {
    // 章节较短，无需缩写
    if (_contentTooShort) {
      return _buildNoAbbreviationView();
    }

    // 显示已缓存的缩写
    if (_summaryChapter != null && _summaryChapter!.abbreviation != null) {
      final htmlContent = md.markdownToHtml(_summaryChapter!.abbreviation!);
      return _buildNormalSummaryView(htmlContent);
    }

    // 无缓存缩写，显示空状态
    return _buildEmptySummaryView();
  }

  /// 章节较短无需缩写视图
  ///
  /// 章节内容不超过一页时显示，提示用户直接阅读原文。
  Widget _buildNoAbbreviationView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '章节较短，无需缩写',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  /// 正常缩写视图
  ///
  /// 显示已缓存的完整缩写内容
  Widget _buildNormalSummaryView(String htmlContent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHtml(htmlContent),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 空缩写视图
  ///
  /// 当没有缩写时显示的空状态
  Widget _buildEmptySummaryView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '暂无缩写',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  /// 打字动画指示器（用于译文流式生成时展示）
  Widget _buildTypingIndicator() {
    return Row(
      children: [
        _typingDot(),
        const SizedBox(width: 4),
        _typingDot(),
        const SizedBox(width: 4),
        _typingDot(),
      ],
    );
  }

  Widget _typingDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
    );
  }

  /// 构建译文视图
  Widget _buildTranslationView() {
    // 如果译文Tab被禁用，显示提示
    if (_translationTabDisabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.translate,
                  size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                '书籍语言与译文语言相同',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '无需翻译',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // 翻译中或已有流式内容时，显示流式视图
    if (_isTranslating || _streamingTranslation.isNotEmpty) {
      return _buildStreamingTranslationView();
    }

    // 有译文内容（翻译完成后的最终显示）
    if (_translationContent != null && _translationContent!.isNotEmpty) {
      // AI返回的是HTML内容，直接渲染，无需Markdown转换
      return _buildTranslationHtmlView(_translationContent!);
    }

    // 无译文（翻译启动中）
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '翻译中，可能需要几秒钟...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 流式译文视图
  Widget _buildStreamingTranslationView() {
    final htmlContent = _cleanCodeBackslashes(_streamingTranslation);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _translationScrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHtml(htmlContent),
                  const SizedBox(height: 16),
                  _buildTypingIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 译文HTML渲染视图
  Widget _buildTranslationHtmlView(String htmlContent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _translationScrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHtml(htmlContent),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建原文视图
  ///
  /// 根据书籍格式显示不同的原文内容：
  /// - PDF：使用PdfPageView显示单页PDF，支持翻页
  /// - EPUB/其他：使用HtmlWidget组件渲染HTML内容
  Widget _buildOriginalTextView() {
    final isPdf = widget.book != null && widget.book!.format == BookFormat.pdf;

    if (isPdf && widget.filePath != null) {
      // PDF格式：显示单页PDF查看器
      // 获取当前章节信息以确定页码范围
      final currentChapter =
          _chapters.isNotEmpty ? _chapters[_currentIndex] : null;
      // 起始页：优先用传入的初始页码（「阅读」从第 1 页开始），否则用章节起始页
      final startPage = _initialPage ?? currentChapter?.location.startPage ?? 1;

      // 初始化当前页码为章节起始页
      if (_pdfCurrentPage < startPage) {
        _pdfCurrentPage = startPage;
      }

      // 使用 pdfrx 库的 PdfDocumentViewBuilder 加载 PDF
      return PdfDocumentViewBuilder.file(
        widget.filePath!,
        builder: (context, document) {
          if (document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _pdfTotalPages = document.pages.length;
          return PdfPageView(
            document: document,
            // 页码限制在有效范围内
            pageNumber: _pdfCurrentPage.clamp(1, _pdfTotalPages),
          );
        },
      );
    }

    // EPUB 竖排：writing-mode: vertical-rl/lr，改用 tategaki 竖排渲染
    if (_isVertical && _plainText.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _originalScrollController,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: VerticalText(
                  _plainText,
                  style: VerticalTextStyle(
                    baseStyle: TextStyle(
                      fontSize: _readerFontSize * _verticalScale,
                      height: _readerLineHeight,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // EPUB 分页：HTML 按块级元素切页，保留排版
    if (_content.isNotEmpty) {
      return PagedReadingView(controller: _reader, onLinkTap: _onLinkTap);
    }

    // EPUB/其他格式：显示 HTML 内容（背景由父 Container 提供）
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _originalScrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              // 样式已内联到 HTML（EPUB 的 CSS 与图片已转 data URI），
              // textStyle 仅作为无内联样式时的兜底，不影响 EPUB 原有排版。
              child: _buildHtml(_content, onLinkTap: _onLinkTap),
            ),
          ),
        );
      },
    );
  }

  /// 保存当前阅读位置（章节 + 页码），供下次从书架打开时续读
  ///
  /// 开头页不属于任何章节，按 -1 保存，与第一章（0）区分。
  void _saveReadingPosition() {
    final book = widget.book;
    if (book == null) return;

    // PDF 用 1 起的 _pdfCurrentPage，统一转成 0 起存储；
    // 换章内容加载中控制器仍是旧章页码，按新章首页记录，避免串位
    final page = _pdfTotalPages > 0
        ? _pdfCurrentPage - 1
        : (_switchingChapter ? 0 : _reader.currentPage);
    final chapterKey = _showingOpening ? -1 : _currentIndex;
    // 与已写入的位置相同则跳过，避免翻页时反复写文件
    if (_savedChapterIndex == chapterKey && _savedPageIndex == page) {
      return;
    }
    _savedChapterIndex = chapterKey;
    _savedPageIndex = page;

    final progress = _computeProgress(page, chapterKey);
    _log.d('ChapterScreen',
        '保存阅读位置: 章节 $chapterKey 页 $page 进度 ${progress.toStringAsFixed(3)}');
    BookService()
        .saveReadingPosition(book.id, chapterKey, page, progress: progress);
  }

  /// 全书阅读进度（0.0~1.0）：已读章节 + 当前章节内页占比
  ///
  /// 开头页位于全书最前面，进度固定为 0。
  double _computeProgress(int page, int chapterIndex) {
    if (chapterIndex < 0) return 0;
    final total = _chapters.length;
    if (total <= 0) return 0;
    final pagesInChapter = _reader.totalPages <= 0 ? 1 : _reader.totalPages;
    final fraction = (page / pagesInChapter).clamp(0.0, 1.0);
    return ((chapterIndex + fraction) / total).clamp(0.0, 1.0);
  }

  /// 翻页后延迟保存阅读位置（防抖，避免每翻一页都写文件）
  void _scheduleSaveReadingPosition() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer(const Duration(seconds: 2), _saveReadingPosition);
  }

  /// 分页控制器到达章节边界时的回调：翻到相邻章节
  ///
  /// 向后翻章落在新章首页；向前翻章落在上一章末页。
  /// 开头页（目录/版权等前置页）是第一章之前的一段：
  /// 第一章首页向前翻 → 开头页末页；开头页末页向后翻 → 第一章首页。
  void _onReaderBoundary(int delta) {
    if (_showingOpening) {
      // 开头页之前没有内容，向前翻不做事
      if (delta > 0) _navigateToChapter(0);
      return;
    }
    if (delta < 0 && _currentIndex == 0) {
      _openOpeningPage(lastPage: true);
      return;
    }
    _navigateToChapter(_currentIndex + delta, lastPage: delta < 0);
  }

  /// 打开书籍开头页（封面/目录/版权页等未列入章节的前置页）
  ///
  /// [lastPage] 为 true 时定位到开头页末页（从第一章首页向前翻时使用）。
  /// 优先复用 BookScreen 传入的开头内容，避免每次回到开头都重新解压解析。
  Future<void> _openOpeningPage({bool lastPage = false}) async {
    if (_switchingChapter) return;

    // 记录离开第一章时的位置（此时仍属于第一章，尚未进入开头页）
    _saveReadingPosition();

    if (widget.openingContent != null && widget.openingContent!.isNotEmpty) {
      _applyOpeningContent(
        widget.openingContent!,
        fonts: widget.openingFonts ?? const [],
        isVertical: widget.openingIsVertical,
        plainText: widget.openingPlainText,
        lastPage: lastPage,
      );
      return;
    }

    final filePath = widget.filePath;
    if (filePath == null) return;
    final parser = FormatRegistry.getParser(_getFileExtension(filePath));
    if (parser == null) return;

    _switchingChapter = true;
    try {
      final opening = await parser.getOpeningContent(filePath);
      if (!mounted) return;
      if (opening == null || opening.html.isEmpty) return;
      _applyOpeningContent(
        opening.html,
        fonts: opening.fonts,
        isVertical: opening.isVertical,
        plainText: opening.plainText,
        lastPage: lastPage,
      );
    } catch (e) {
      _log.e('ChapterScreen', '加载书籍开头页失败', e);
    } finally {
      _switchingChapter = false;
    }
  }

  /// 用开头页内容替换当前正文，并交给分页控制器渲染
  void _applyOpeningContent(
    String html, {
    required List<EmbeddedFont> fonts,
    required bool isVertical,
    required String plainText,
    required bool lastPage,
  }) {
    _loadEmbeddedFonts(fonts);

    setState(() {
      _showingOpening = true;
      _content = html;
      _isVertical = isVertical;
      _plainText = plainText;
      _title = widget.book?.title ?? widget.chapterTitle;
      _summaryChapter = null;
      _translationContent = null;
      _streamingTranslation = '';
      _isTranslating = false;
      _error = null;
      _pdfCurrentPage = 1;
      _pdfTotalPages = 0;
    });
    _checkContentLength();
    final target = lastPage ? PagedOpenTarget.last : PagedOpenTarget.first;
    final paginator = _paginator;
    paginator?.provideContent(
      -1,
      RenderedContent(
        html,
        fonts: fonts,
        isVertical: isVertical,
        plainText: plainText,
      ),
    );
    paginator?.setPriority(-1);

    final cached = paginator?.pagesFor(-1);
    if (cached != null && cached.pages.isNotEmpty && !isVertical) {
      _readerChapterIndex = -1;
      _reader.openPages(
        cached.pages,
        target: target,
        pageStartBlocks: cached.pageStartBlocks,
        blockTexts: cached.blockTexts,
      );
      _appliedPagesRevision = paginator!.revisionFor(-1);
    } else {
      _readerChapterIndex = -1;
      _reader.open(html, target: target);
    }
    _updateBookPaging();
  }

  /// 分页控制器状态变化：仅在页码/总页数变化时延迟保存阅读位置
  ///
  /// 定位中（已换章但未定位到目标页）不保存，避免把临时页码写进存储。
  void _onReaderChanged() {
    if (!mounted || _reader.isPositioning) return;
    // 可视章节测完后回填给后台分页器（全书页码据此计算）
    _adoptVisibleChapter();
    if (_reader.currentPage == _observedPage &&
        _reader.totalPages == _observedTotal) {
      return;
    }
    _observedPage = _reader.currentPage;
    _observedTotal = _reader.totalPages;
    _scheduleSaveReadingPosition();
  }

  /// 在本页内切换到指定章节（不触发页面路由，避免页面切换动画）
  ///
  /// 切换逻辑：
  /// - 更新当前章节索引与标题
  /// - 保留当前内容、后台加载新章节内容，加载完成后替换（避免闪动）
  /// - 重置摘要/译文等状态
  ///
  /// 注意：只导航到第一级章节（level=0）
  void _navigateToChapter(int index, {bool lastPage = false, String? anchor}) {
    if (index < 0 || index >= _chapters.length) return;
    // 上一次切章的内容还没加载完：忽略本次请求，避免基于旧章页码再跳一章
    if (_switchingChapter) return;

    // 记录离开前的阅读位置，供下次续读
    _saveReadingPosition();

    // 注销旧章节的译文回调
    _summaryService.unregisterTranslationCallback(widget.bookId, _currentIndex);

    _currentIndex = index;
    _title = _chapters[index].title;
    _initialPage = null; // 切换章节后不再从第一页开始，改用章节自身页码

    final target = lastPage
        ? PagedOpenTarget.last
        : (anchor != null ? PagedOpenTarget.atAnchor(anchor) : PagedOpenTarget.first);

    setState(() {
      // 保留 _content（旧章节内容）直到新内容加载完成，后台加载无闪动
      _showingOpening = false;
      _summaryChapter = null;
      _translationContent = null;
      _streamingTranslation = '';
      _isTranslating = false;
      _error = null;
      _pdfCurrentPage = 1;
      _pdfTotalPages = 0;
    });

    final paginator = _paginator;
    paginator?.setPriority(index);
    final cached = paginator?.pagesFor(index);

    if (cached != null && cached.pages.isNotEmpty) {
      // 后台分页已完成该章：直接采用缓存页列表，省去测量等待（跨章无白屏）
      setState(() {
        _content = paginator!.htmlFor(index) ??
            cached.pages.expand((page) => page).join();
        _isVertical = false;
        _plainText = '';
      });
      _checkContentLength();
      _readerChapterIndex = index;
      _reader.openPages(
        cached.pages,
        target: target,
        pageStartBlocks: cached.pageStartBlocks,
        blockTexts: cached.blockTexts,
      );
      _appliedPagesRevision = paginator!.revisionFor(index);
      _switchingChapter = false;
      _updateBookPaging();
      _resetScrollAfterChapterChange();
      _loadAbbreviation();
      return;
    }

    _switchingChapter = true;
    _loadChapterContent(target: target).whenComplete(() {
      if (!mounted) return;
      _switchingChapter = false;
      _updateBookPaging();
    });
    _loadAbbreviation();
  }

  /// 构建 PDF 原文页的页码翻页按钮
  ///
  /// EPUB 分页模式已支持「点击左右 1/3 区域 / 方向键 / 鼠标滚轮 / 滑动」翻页，
  /// 不再显示底部大圆按钮；仅 PDF 原文保留 < > 页码翻页。
  Widget _buildNavigationButtons() {
    final isPdf = widget.book != null && widget.book!.format == BookFormat.pdf;
    final isPdfOriginalView = isPdf && (_tabController?.index == 0);
    if (!isPdfOriginalView) return const SizedBox.shrink();

    final currentChapter =
        _chapters.isNotEmpty ? _chapters[_currentIndex] : null;
    final startPage = currentChapter?.location.startPage ?? 1;
    final endPage = currentChapter?.location.endPage ?? startPage;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPdfPageButton(
            icon: Icons.chevron_left,
            enabled: _pdfCurrentPage > startPage,
            onPressed: () => setState(() => _pdfCurrentPage--),
          ),
          _buildPdfPageButton(
            icon: Icons.chevron_right,
            enabled: _pdfCurrentPage < endPage,
            onPressed: () => setState(() => _pdfCurrentPage++),
          ),
        ],
      ),
    );
  }

  /// PDF 页码翻页按钮（< / >）
  Widget _buildPdfPageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(76),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          icon,
          color: enabled ? Colors.white : Colors.grey.shade600,
          size: 28,
        ),
      ),
    );
  }
}

