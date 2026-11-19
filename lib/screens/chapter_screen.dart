// 章节阅读界面
//
// 这是应用的核心阅读界面，提供以下功能：
// 1. 查看章节原文（EPUB: HTML渲染，PDF: 单页查看器）
// 2. 查看章节缩写（已缓存，Markdown渲染）
// 3. 查看章节译文
// 4. 章节导航（上一章/下一章）
// 5. PDF页码翻页（在原文模式下）
//
// 界面切换逻辑：
// - 左侧垂直Tab：原文/缩写/译文
// - 原文视图：EPUB显示HTML内容，PDF显示单页PDF查看器
// - 缩写视图：显示已缓存的章节缩写
// - 译文视图：显示AI生成的章节译文
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdfrx/pdfrx.dart';
import 'package:tategaki/tategaki.dart';
import '../models/chapter.dart';
import '../models/book.dart';
import '../services/ai_service.dart';
import '../services/summary_service.dart';
import '../services/parsers/book_format_parser.dart';
import '../services/parsers/rendered_content.dart';
import '../services/log_service.dart';
import '../services/settings_service.dart';
import '../widgets/paged_reading_view.dart';

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
/// - [openingContent]: 书籍第一页（开头）HTML（可选，用于「阅读」从第一页开始）
/// - [initialPage]: PDF 起始页码（可选，用于「阅读」从第 1 页开始）
class ChapterScreen extends StatefulWidget {
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String? chapterContent;
  final String? filePath;
  final List<Chapter>? chapters;
  final Book? book;
  final String? openingContent;
  final List<EmbeddedFont>? openingFonts;
  final bool openingIsVertical;
  final String openingPlainText;
  final int? initialPage;

  const ChapterScreen({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.chapterContent,
    this.filePath,
    this.chapters,
    this.book,
    this.openingContent,
    this.openingFonts,
    this.openingIsVertical = false,
    this.openingPlainText = '',
    this.initialPage,
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

  /// 是否处于分页阅读模式（仅 EPUB 横排原文可选，默认分页）
  bool _pagedMode = true;

  /// 章节标题（翻章/加载时动态更新）
  String _title = '';

  /// 当前章节索引（可在本页内切换章节，不触发页面路由）
  int _currentIndex = 0;

  /// PDF 起始页码（仅「阅读」从第一页进入时使用；切换章节后失效）
  int? _initialPage;

  /// Tab控制器（用于垂直Tab布局）
  TabController? _tabController;

  /// 内容是否过短（少于2000字节）
  /// 内容过短时缩写 tab 置灰
  bool _contentTooShort = false;

  /// 第一级章节列表（用于导航）
  /// 注意：只包含level=0的章节，忽略子章节
  List<Chapter> _chapters = [];

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

  /// 上一章按钮是否处于鼠标悬停状态
  bool _hoverPrev = false;

  /// 下一章按钮是否处于鼠标悬停状态
  bool _hoverNext = false;

  /// 译文滚动控制器
  ScrollController? _translationScrollController;

  /// 原文滚动控制器（EPUB格式）
  ScrollController? _originalScrollController;

  /// 当前共享的滚动锚点（用于Tab间同步）
  ScrollAnchor _currentScrollAnchor = const ScrollAnchor();

  /// 摘要/译文/原文通用的正文文本样式
  static const TextStyle _contentTextStyle = TextStyle(fontSize: 14, height: 1.6);

  /// 已通过 FontLoader 注册的字体家族（避免重复加载）
  final Set<String> _loadedFontFamilies = {};

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.chapterIndex;
    _initialPage = widget.initialPage;
    _title = widget.chapterTitle;

    if (widget.chapters != null) {
      _chapters = widget.chapters!.where((c) => c.level == 0).toList();
    }

    _translationScrollController = ScrollController();
    _originalScrollController = ScrollController();

    _tabController = TabController(length: 3, vsync: this);
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
    _summaryService.unregisterTranslationCallback(widget.bookId, _currentIndex);
    _translationScrollController?.dispose();
    _originalScrollController?.dispose();
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
    if (widget.openingContent != null && widget.openingContent!.isNotEmpty) {
      _content = widget.openingContent!;
      _title = widget.chapterTitle;
      _isVertical = widget.openingIsVertical;
      _plainText = widget.openingPlainText;
      _loadEmbeddedFonts(widget.openingFonts ?? const []);
      _checkContentLength();
      if (!mounted) return;
      setState(() => _isLoadingContent = false);
      return;
    }

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
  Future<void> _loadChapterContent() async {
    try {
      List<Chapter> chapters =
          _chapters.isNotEmpty ? _chapters : (widget.chapters ?? []);

      if (chapters.isEmpty && widget.filePath != null) {
        final extension = _getFileExtension(widget.filePath!);
        final parser = FormatRegistry.getParser(extension);

        if (parser != null) {
          chapters = await parser.getChapters(widget.filePath!);
        } else {
          _log.e('ChapterScreen', '不支持的格式: $extension');
        }
      }

      final topLevelChapters = chapters.where((c) => c.level == 0).toList();
      _chapters = topLevelChapters;

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
      // 新内容渲染后重置滚动到顶部（翻章后新章节从顶部开始阅读）
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
  /// 返回包含两个元素的列表：[处理后的HTML, 原始代码块列表]
  List<dynamic> _extractCodeBlocksToPlaceholders(String html) {
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

    return [result, codeBlocks];
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

      final bookFormat = widget.book?.format.name ?? 'epub';
      final extractedResult = _extractCodeBlocksToPlaceholders(_content);
      final contentWithPlaceholders = extractedResult[0] as String;
      final codeBlocks = List<String>.from(extractedResult[1]);

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
        bookFormat: bookFormat,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _buildBody(),
          // 章节导航按钮：多个章节时才显示
          if (_chapters.length > 1) _buildNavigationButtons(),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
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
    final unselectedColor = Colors.grey.withAlpha(80);

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
                  height: 1, width: 44, color: Colors.grey.withAlpha(100)),
              _buildVerticalTab(1, Icons.auto_awesome,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  disabled: abbreviationDisabled),
              Container(
                  height: 1, width: 44, color: Colors.grey.withAlpha(100)),
              _buildVerticalTab(2, Icons.translate,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  disabled: _translationTabDisabled),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
              ? Colors.grey.withAlpha(100)
              : isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
        ),
      ),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '章节较短，无需缩写',
          style: TextStyle(fontSize: 16, color: Colors.grey),
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
                  HtmlWidget(htmlContent, textStyle: _contentTextStyle),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '暂无缩写',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
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
      decoration: const BoxDecoration(
        color: Colors.blue,
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
              Icon(Icons.translate, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                '书籍语言与译文语言相同',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '无需翻译',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
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
                  HtmlWidget(htmlContent, textStyle: _contentTextStyle),
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
                  HtmlWidget(htmlContent, textStyle: _contentTextStyle),
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

// 使用pdfrx库的PdfDocumentViewBuilder加载PDF
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
                  style: const VerticalTextStyle(
                    baseStyle: TextStyle(fontSize: 18, height: 1.8),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

// EPUB 分页：可选的「分页模式」，纯文本按可用高度切页左右翻页
    if (_pagedMode && _plainText.isNotEmpty) {
      return PagedReadingView(
        text: _plainText,
        textStyle: _contentTextStyle,
      );
    }

// EPUB/其他格式：显示HTML内容（背景由父Container提供）
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
              child: HtmlWidget(_content, textStyle: _contentTextStyle),
            ),
          ),
        );
      },
    );
  }

  /// 在本页内切换到指定章节（不触发页面路由，避免页面切换动画）
  ///
  /// 切换逻辑：
  /// - 更新当前章节索引与标题
  /// - 保留当前内容、后台加载新章节内容，加载完成后替换（避免闪动）
  /// - 重置摘要/译文等状态
  ///
  /// 注意：只导航到第一级章节（level=0）
  void _navigateToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;

    // 注销旧章节的译文回调
    _summaryService.unregisterTranslationCallback(widget.bookId, _currentIndex);

    _currentIndex = index;
    _title = _chapters[index].title;
    _initialPage = null; // 切换章节后不再从第一页开始，改用章节自身页码

    setState(() {
      // 保留 _content（旧章节内容）直到新内容加载完成，后台加载无闪动
      _summaryChapter = null;
      _translationContent = null;
      _streamingTranslation = '';
      _isTranslating = false;
      _error = null;
      _pdfCurrentPage = 1;
      _pdfTotalPages = 0;
    });

    _loadChapterContent();
    _loadAbbreviation();
  }

  /// 构建导航按钮
  ///
  /// 按钮布局（从左到右）：
  /// 1. << 上一章（章节导航）
  /// 2. < 上一页（仅PDF原文模式，页码翻页）
  /// 3. > 下一页（仅PDF原文模式，页码翻页）
  /// 4. >> 下一章（章节导航）
  ///
  /// PDF翻页逻辑：
  /// - 只能在当前章节的页码范围内翻页
  /// - 起始页：chapter.location.startPage
  /// - 结束页：chapter.location.endPage
  Widget _buildNavigationButtons() {
    // 判断边界条件
    final isFirst = _currentIndex <= 0;
    final isLast = _currentIndex >= _chapters.length - 1;

// 判断是否为PDF原文模式
    final isPdf = widget.book != null && widget.book!.format == BookFormat.pdf;
    final isPdfOriginalView = isPdf && (_tabController?.index == 0);

    // 计算PDF页码翻页范围（仅PDF原文阅读时有效）
    final currentChapter =
        _chapters.isNotEmpty ? _chapters[_currentIndex] : null;
    final startPage = currentChapter?.location.startPage ?? 1;
    final endPage = currentChapter?.location.endPage ?? startPage;

    // 判断是否可以翻页
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
          MouseRegion(
            onEnter: (_) => setState(() => _hoverPrev = true),
            onExit: (_) => setState(() => _hoverPrev = false),
            child: Opacity(
              opacity: isFirst ? 0.0 : 1.0,
              child: Padding(
                padding: const EdgeInsets.only(left: 45),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(_hoverPrev ? 102 : 51),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onPressed: isFirst
                        ? null
                        : () => _navigateToChapter(_currentIndex - 1),
                    icon: Icon(
                      Icons.keyboard_arrow_left,
                      color: _hoverPrev
                          ? Colors.deepOrange.withAlpha(179)
                          : Colors.white.withAlpha(89),
                      size: 56,
                    ),
                  ),
                ),
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
                        setState(() { _pdfCurrentPage--; });
                      }
                    : null,
                icon: Icon(
                  Icons.chevron_left,
                  color: canPrevPage ? Colors.white : Colors.grey.shade600,
                  size: 28,
                ),
              ),
            ),
          // 空位填充（当不显示翻页按钮时保持布局平衡）
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
                        setState(() { _pdfCurrentPage++; });
                      }
                    : null,
                icon: Icon(
                  Icons.chevron_right,
                  color: canNextPage ? Colors.white : Colors.grey.shade600,
                  size: 28,
                ),
              ),
            ),
          // 空位填充（当不显示翻页按钮时保持布局平衡）
          if (!isPdfOriginalView) const SizedBox(width: 48),
          // >> 下一章按钮
          MouseRegion(
            onEnter: (_) => setState(() => _hoverNext = true),
            onExit: (_) => setState(() => _hoverNext = false),
            child: Opacity(
              opacity: isLast ? 0.0 : 1.0,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(_hoverNext ? 102 : 51),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onPressed: isLast
                      ? null
                      : () => _navigateToChapter(_currentIndex + 1),
                  icon: Icon(
                    Icons.keyboard_arrow_right,
                    color: _hoverNext
                        ? Colors.deepOrange.withAlpha(179)
                        : Colors.white.withAlpha(89),
                    size: 56,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
