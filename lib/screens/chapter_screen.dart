/// 章节摘要阅读界面
///
/// 这是应用的核心阅读界面，提供以下功能：
/// 1. 显示AI生成的章节摘要（Markdown渲染）
/// 2. 查看章节原文（EPUB: HTML渲染，PDF: 单页查看器）
/// 3. 一键生成章节摘要
/// 4. 章节导航（上一章/下一章）
/// 5. PDF页码翻页（在原文模式下）
///
/// 界面切换逻辑：
/// - 左侧图标按钮：切换"摘要视图"与"原文视图"
/// - 摘要视图：显示AI生成的章节摘要
/// - 原文视图：EPUB显示HTML内容，PDF显示单页PDF查看器
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdfrx/pdfrx.dart';
import '../models/chapter_summary.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/ai_service.dart';
import '../services/summary_service.dart';
import '../services/book_service.dart';
import '../services/parsers/format_registry.dart';
import '../services/log_service.dart';
import '../services/settings_service.dart';

/// 滚动位置锚点
class ScrollAnchor {
  /// 滚动比例（0.0 = 顶部, 1.0 = 底部）
  final double scrollRatio;
  
  const ScrollAnchor({
    this.scrollRatio = 0.0,
  });
}

/// 章节摘要界面 Widget
///
/// 参数说明：
/// - [bookId]: 书籍唯一标识
/// - [chapterIndex]: 章节索引（基于第一级章节列表）
/// - [chapterTitle]: 章节标题（默认值，可能被AI更新后的标题覆盖）
/// - [chapterContent]: 章节内容（可选，EPUB时可能预加载）
/// - [filePath]: 文件路径（用于重新加载内容）
/// - [chapters]: 章节列表（用于导航）
/// - [book]: 书籍对象（包含AI更新后的章节标题）
class ChapterScreen extends StatefulWidget {
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String? chapterContent;
  final String? filePath;
  final List<Chapter>? chapters;
  final Book? book;

  const ChapterScreen({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.chapterContent,
    this.filePath,
    this.chapters,
    this.book,
  });

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen>
    with TickerProviderStateMixin {
  /// AI服务（用于检查配置状态）
  final _aiService = AIService();

  /// 日志服务
  final _log = LogService();

  /// 摘要服务（用于加载/生成摘要）
  final _summaryService = SummaryService();

  /// 书籍服务（用于获取更新后的书籍信息）
  final _bookService = BookService();

  /// 当前章节的摘要数据
  ChapterSummary? _summary;

  /// 是否正在生成摘要
  bool _isGenerating = false;

  /// 错误信息
  String? _error;

  /// 是否正在加载章节内容
  bool _isLoadingContent = false;

  /// 章节内容（HTML格式）
  String _content = '';

/// 章节标题（动态更新，可能被AI生成的标题覆盖）
String _title = '';

/// Tab控制器（用于垂直Tab布局）
TabController? _tabController;

  /// 内容是否过短（少于2000字节）
  /// 内容过短时，默认显示原文视图，且摘要按钮禁用
  bool _contentTooShort = false;

  /// 第一级章节列表（用于导航）
  /// 注意：只包含level=0的章节，忽略子章节
  List<Chapter> _chapters = [];

  /// PDF当前页码（用于PDF原文阅读时的翻页）
  int _pdfCurrentPage = 1;

  /// PDF总页数（从文档加载后设置）
  int _pdfTotalPages = 0;

  /// 流式摘要内容（实时显示AI生成的内容）
  String _streamingSummary = '';

  /// UI刷新定时器（控制UI更新频率，避免过于频繁的更新）
  Timer? _uiRefreshTimer;

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

  /// 获取当前摘要语言
  String _getCurrentSummaryLanguage() {
    final langSettings = SettingsService().settings.languageSettings;
    switch (langSettings.aiLanguageMode) {
      case 'system':
        return _detectSystemLanguage();
      case 'manual':
        return langSettings.aiOutputLanguage;
      case 'book':
      default:
        return widget.book?.language ?? 'zh';
    }
  }

  /// 更新目标语言设置
  ///
  /// 每次切换到译文Tab时调用，确保使用最新的AI输出语言设置
  Future<void> _updateTargetLanguage() async {
    final langSettings = SettingsService().settings.languageSettings;
    
    // 根据AI语言模式确定目标语言
    switch (langSettings.aiLanguageMode) {
      case 'system':
        _targetLang = _detectSystemLanguage();
        _log.d('ChapterScreen', '跟随系统语言，目标语言: $_targetLang');
        break;
      case 'manual':
        _targetLang = langSettings.aiOutputLanguage;
        _log.d('ChapterScreen', '用户自选语言，目标语言: $_targetLang');
        break;
      case 'book':
      default:
        // 跟随书籍语言时，不需要翻译（保持原文语言）
        _targetLang = _sourceLang;
        _log.d('ChapterScreen', '跟随书籍语言，目标语言: $_targetLang');
        break;
    }

    _translationTabDisabled = _sourceLang == _targetLang;
    _log.d('ChapterScreen', '更新目标语言: $_targetLang, 源语言: $_sourceLang, 禁用: $_translationTabDisabled');
  }

  /// 检测系统语言
  String _detectSystemLanguage() {
    try {
      final locale = Platform.localeName;
      _log.d('ChapterScreen', '系统 locale: $locale');
      
      if (locale.startsWith('zh') || locale.contains('_CN') || locale.contains('_TW') || locale.contains('_HK')) {
        return 'zh';
      } else if (locale.startsWith('ja') || locale.contains('_JP')) {
        return 'ja';
      } else if (locale.startsWith('en') || locale.contains('_US') || locale.contains('_GB')) {
        return 'en';
      } else if (locale.startsWith('ko') || locale.contains('_KR')) {
        return 'ko';
      }
      
      return 'zh';
    } catch (e) {
      _log.w('ChapterScreen', '检测系统语言失败: $e，使用默认中文');
      return 'zh';
    }
  }

  @override
  void initState() {
    super.initState();

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
          
          if (_tabController!.index == 1) {
            _updateTargetLanguage().then((_) {
              _loadTranslation();
            });
          }
        } else {
          _captureScrollAnchor(_tabController!.previousIndex);
        }
      }
    });

    _initializeLanguageSettings();

    // 初始化章节内容，在首次build完成后加载摘要
    // 这样垂直Tab框架已就绪，流式摘要可显示在正确的页面布局中
    _initializeContent().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSummary();
      });
    });
  }

@override
void dispose() {
  _translationScrollController?.dispose();
  _originalScrollController?.dispose();
  _tabController?.dispose();
  _uiRefreshTimer?.cancel();
  super.dispose();
}

  /// 初始化章节内容
  ///
  /// 内容来源优先级：
  /// 1. 已传入的 chapterContent（预加载的内容）
  /// 2. 从文件路径重新加载（通过FormatRegistry解析）
  ///
  /// 同时检查内容长度，内容过短时自动切换到原文视图
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

/// 检查内容长度
  ///
  /// 内容少于2000字节时：
  /// 1. 标记为过短，禁用摘要生成按钮
  /// 2. 如果没有摘要，自动切换到原文视图（Tab 2）
  void _checkContentLength() {
    final textContent = _extractTextContent(_content);
    final byteLength = utf8.encode(textContent).length;
    _contentTooShort = byteLength < 2000;

    // 内容过短且没有摘要时，默认切换到原文视图
    if (_contentTooShort && _summary == null) {
      _tabController?.animateTo(2);
    }
  }

  /// 初始化语言设置
  ///
  /// 确定源语言和目标语言，判断译文Tab是否禁用
  Future<void> _initializeLanguageSettings() async {
    _log.d('ChapterScreen', '开始初始化语言设置，book: ${widget.book?.title}, book.language: ${widget.book?.language}');
    
    final langSettings = SettingsService().settings.languageSettings;
    _log.d('ChapterScreen', '语言设置：aiLanguageMode=${langSettings.aiLanguageMode}, aiOutputLanguage=${langSettings.aiOutputLanguage}');
    
    _sourceLang = widget.book?.language;

    if (_sourceLang != null && _sourceLang!.isNotEmpty) {
      _sourceLang = _convertLanguageCodeToStandard(_sourceLang!);
    } else {
      _sourceLang = _aiService.detectLanguageFromContent(_content);
    }

    _log.d('ChapterScreen', '源语言: $_sourceLang');

    // 根据AI语言模式确定目标语言
    switch (langSettings.aiLanguageMode) {
      case 'system':
        _targetLang = _detectSystemLanguage();
        _log.d('ChapterScreen', '跟随系统语言，目标语言: $_targetLang');
        break;
      case 'manual':
        _targetLang = langSettings.aiOutputLanguage;
        _log.d('ChapterScreen', '用户自选语言，目标语言: $_targetLang');
        break;
      case 'book':
      default:
        // 跟随书籍语言时，目标语言=源语言，翻译自动禁用
        _targetLang = _sourceLang;
        _log.d('ChapterScreen', '跟随书籍语言，目标语言(同源语言): $_targetLang');
        break;
    }

    // 同步更新摘要语言（摘要语言和翻译目标语言保持一致）
    _summaryLang = _targetLang ?? 'zh';

    // 跟随书籍语言时，_targetLang == _sourceLang，翻译自动禁用
    _translationTabDisabled = _sourceLang == _targetLang;

    _log.d('ChapterScreen', '译文Tab禁用: $_translationTabDisabled');
  }

  /// 将语言代码转换为标准格式
  String _convertLanguageCodeToStandard(String languageCode) {
    if (languageCode.contains('-')) {
      return languageCode.split('-')[0];
    } else if (languageCode.contains('_')) {
      return languageCode.split('_')[0];
    }
    return languageCode;
  }


  /// 从文件加载章节内容
  ///
  /// 使用FormatRegistry获取对应格式的解析器，
  /// 解析章节列表并获取指定章节的内容
  Future<void> _loadChapterContent() async {
    try {
      List<Chapter> chapters = widget.chapters ?? [];

      if (chapters.isEmpty && widget.filePath != null) {
        _log.d('ChapterScreen', '使用FormatRegistry加载章节列表');

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

      _log.d('ChapterScreen',
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

      String? content;
      try {
        if (widget.filePath != null) {
          final extension = _getFileExtension(widget.filePath!);
          final parser = FormatRegistry.getParser(extension);

          if (parser != null) {
            final chapterContent = await parser.getChapterContent(
              widget.filePath!,
              chapter,
            );
            content = chapterContent.htmlContent;
          }
        }
      } catch (e) {
        _log.e('ChapterScreen', '获取章节内容失败', e);
      }

      if (content == null || content.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = '章节内容为空';
          _isLoadingContent = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _content = content ?? '';
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

  /// 是否已加载过摘要（防止重复加载）
  bool _hasLoadedSummary = false;

  /// 当前监听的章节key（用于防止重复监听）
  String? _listeningChapterKey;

  /// 加载章节摘要
  ///
  /// 核心逻辑：
  /// - 如果有正在后台生成的摘要（来自BookScreen），等待其完成，然后加载最终结果
  /// - 如果没有正在生成但没有摘要，自动启动AI生成摘要并进入流式显示
  /// - 如果没有正在生成且有摘要，直接加载已有摘要
  /// - 防止重复加载：同一个章节只处理一次
  Future<void> _loadSummary() async {
    final chapterKey = '${widget.bookId}_${widget.chapterIndex}';

    // 防止重复加载同一个章节
    if (_hasLoadedSummary && _listeningChapterKey == chapterKey) {
      _log.d('ChapterScreen', '章节 $chapterKey 已加载过，跳过');
      return;
    }

    final generatingFuture =
        _summaryService.getGeneratingFuture(widget.bookId, widget.chapterIndex);

    if (generatingFuture != null) {
      // 后台正在生成（来自BookScreen），等待其完成，不尝试监听流式内容
      // 因为 addPostFrameCallback 延迟导致回调注册时 chunk 可能已到达，
      // 直接 await 后台 completion 比 registerStreamingCallback 更可靠
      _log.d('ChapterScreen', '后台正在生成中，等待完成: $chapterKey');

      _hasLoadedSummary = true;
      _listeningChapterKey = chapterKey;

      setState(() {
        _isGenerating = true;
        _streamingSummary = '';
        _summary = null;
      });

      final capturedBookId = widget.bookId;
      final capturedChapterIndex = widget.chapterIndex;

      try {
        await generatingFuture;
      } catch (e) {
        _log.w('ChapterScreen', '后台生成失败: $e');
      }

      if (!mounted) return;
      if (capturedBookId != widget.bookId || capturedChapterIndex != widget.chapterIndex) return;

      // 加载最终摘要
      final summary = await _summaryService.getSummary(
          capturedBookId, capturedChapterIndex, language: _summaryLang);

      if (!mounted) return;
      if (capturedBookId != widget.bookId || capturedChapterIndex != widget.chapterIndex) return;

      setState(() {
        _summary = summary;
        _isGenerating = false;
        _streamingSummary = '';
      });
      return;
    }

    // 没有正在生成，检查是否已有摘要
    _hasLoadedSummary = true;
    _listeningChapterKey = chapterKey;

    final summary = await _summaryService.getSummary(widget.bookId, widget.chapterIndex, language: _summaryLang);
    
    if (summary != null) {
      // 已有摘要，直接显示
      if (!mounted) return;
      setState(() {
        _summary = summary;
      });
    } else {
      // 没有摘要，检查是否满足生成条件
      if (_content.isNotEmpty && _aiService.isConfigured) {
        _log.d('ChapterScreen', '没有现有摘要，自动启动AI生成: $chapterKey');
        setState(() {
          _isGenerating = true;
          _streamingSummary = '';
        });
        _generateSummaryWithStreaming();
      } else {
        // 不满足生成条件，仅加载摘要（可能是空的）
        if (!mounted) return;
        setState(() {
          _summary = summary;
        });
      }
    }
  }

  /// 生成章节摘要
  ///
  /// 流程：
  /// 1. 提取纯文本内容（去除HTML标签）
  /// 2. 调用SummaryService生成摘要
  /// 3. 生成成功后，刷新标题（AI可能更新了章节标题）
  ///
  /// 标题刷新逻辑：
  /// - AI生成摘要时可能同时更新章节标题（更准确的标题）
  /// - 从BookService获取更新后的Book对象
  /// - 读取chapterTitles映射中的新标题
  Future<void> _generateSummary() async {
    if (_content.isEmpty) {
      setState(() {
        _error = '无法生成摘要：章节内容为空';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _streamingSummary = '';  // 初始化流式摘要
    });

    try {
      // 提取纯文本内容用于AI处理
      final plainText = _extractTextContent(_content);

      // 调用摘要服务生成摘要
      final success = await _summaryService.generateSingleSummary(
        widget.bookId,
        widget.chapterIndex,
        _title,
        plainText,
        language: _summaryLang,
      );

      if (!mounted) return;

      if (success) {
        // 加载新生成的摘要
        final summary = await _summaryService.getSummary(
          widget.bookId,
          widget.chapterIndex,
          language: _summaryLang,
        );

        // 检查AI是否更新了章节标题
        // AI生成摘要时可能同时生成更准确的章节标题
        final updatedBook = _bookService.getBookById(widget.bookId);
        if (updatedBook != null) {
          // 从chapterTitles映射获取新标题
          final newTitle = updatedBook.chapterTitles?[widget.chapterIndex];
          setState(() {
            _summary = summary;
            _title = newTitle ?? _title; // 使用新标题或保持原标题
            _isGenerating = false;
            _streamingSummary = '';  // 清空流式内容
          });
        } else {
          setState(() {
            _summary = summary;
            _isGenerating = false;
            _streamingSummary = '';  // 清空流式内容
          });
        }
      } else {
        setState(() {
          _error = '生成摘要失败';
          _isGenerating = false;
          _streamingSummary = '';  // 清空流式内容
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '生成摘要失败: $e';
        _isGenerating = false;
        _streamingSummary = '';  // 清空流式内容
      });
    }
  }

  /// 生成章节摘要（流式）
  ///
  /// 流程：
  /// 1. 提取纯文本内容（去除HTML标签）
  /// 2. 调用SummaryService流式生成摘要
  /// 3. 实时更新内容（1-2秒更新一次）
  /// 4. 生成成功后，刷新标题（AI可能更新了章节标题）
  ///
  /// 实时更新逻辑：
  /// - 通过onContentUpdate回调接收AI生成的内容片段
  /// - 使用Timer控制更新频率，避免UI过度频繁更新
  /// - 在生成完成后加载最终摘要并更新状态
  Future<void> _generateSummaryWithStreaming() async {
    if (_content.isEmpty) {
      if (mounted) {
        setState(() {
          _error = '无法生成摘要：章节内容为空';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isGenerating = true;
        _error = null;
        _streamingSummary = '';  // 初始化流式摘要
      });
    }

    try {
      final plainText = _extractTextContent(_content);

      // 使用流式生成方法，带有实时更新回调
      final success = await _summaryService.generateSingleSummaryStream(
        widget.bookId,
        widget.chapterIndex,
        _title,
        plainText,
        language: _summaryLang,
        onContentUpdate: (content) {
          // 立即更新UI状态，不使用延迟
          if (mounted) {
            setState(() {
              _streamingSummary = content;  // 更新流式内容
            });
          }
        },
      );

      if (!mounted) return;

      if (success) {
        // 生成完成，加载最终摘要
        final summary = await _summaryService.getSummary(
          widget.bookId,
          widget.chapterIndex,
          language: _summaryLang,
        );

        final updatedBook = _bookService.getBookById(widget.bookId);
        if (updatedBook != null) {
          final newTitle = updatedBook.chapterTitles?[widget.chapterIndex];
          if (mounted) {
            setState(() {
              _summary = summary;
              _title = newTitle ?? _title;
              _streamingSummary = '';  // 清空流式内容，显示最终摘要
              _isGenerating = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _summary = summary;
              _streamingSummary = '';
              _isGenerating = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = '生成摘要失败';
            _streamingSummary = '';
            _isGenerating = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '生成摘要失败: $e';
        _streamingSummary = '';
        _isGenerating = false;
      });
    }
  }

  /// 从HTML中提取纯文本
  ///
  /// 1. 移除所有HTML标签
  /// 2. 解码HTML实体（&nbsp;, &lt;, &gt;等）
  /// 用于将HTML内容转换为纯文本供AI处理
  String _extractTextContent(String html) {
    // 使用正则表达式移除HTML标签
    final text = html.replaceAll(RegExp(r'<[^>]+>'), '');
    // 解码HTML实体
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
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
      case 1:
        controller = _translationScrollController;
        break;
      case 2:
        controller = _originalScrollController;
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
    if (tabIndex == 0) return;
    
    ScrollController? controller;
    
    switch (tabIndex) {
      case 1:
        controller = _translationScrollController;
        break;
      case 2:
        controller = _originalScrollController;
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
      RegExp(r'(<code[^>]*>)([\s\S]*?)(</code>)|(<pre[^>]*>)([\s\S]*?)(</pre>)', caseSensitive: false),
      (match) {
        if (match.group(0)!.startsWith('<code') || match.group(0)!.startsWith('<CODE')) {
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
    final codeRegex = RegExp(r'(<code[^>]*>[\s\S]*?</code>)|(<pre[^>]*>[\s\S]*?</pre>)', caseSensitive: false, dotAll: true);

    int index = 0;
    final result = html.replaceAllMapped(codeRegex, (match) {
      codeBlocks.add(match.group(0)!);
      return '%%ZHIDU_CODE_BLOCK_${index++}%%';
    });

    return [result, codeBlocks];
  }

  /// 将占位符替换回原始代码块
  String _restorePlaceholdersToCodeBlocks(String html, List<String> codeBlocks) {
    final placeholderRegex = RegExp(r'%%ZHIDU_CODE_BLOCK_(\d+)%%');
    return html.replaceAllMapped(placeholderRegex, (match) {
      final index = int.tryParse(match.group(1)!) ?? -1;
      if (index >= 0 && index < codeBlocks.length) {
        return codeBlocks[index];
      }
      return match.group(0)!;
    });
  }

  /// 加载译文
  ///
  /// 检查是否已有译文缓存，有则直接显示，无则自动生成
  Future<void> _loadTranslation() async {
    if (_translationTabDisabled) return;
    if (_targetLang == null || _content.isEmpty) return;

    try {
      // 检查是否已有译文缓存（使用当前目标语言）
      final cachedTranslation = await _summaryService.getTranslation(
          widget.bookId, widget.chapterIndex, _targetLang!);

      if (cachedTranslation != null && cachedTranslation.isNotEmpty) {
        if (mounted) {
          setState(() {
            String processedTranslation = _cleanCodeBackslashes(cachedTranslation);
            if (processedTranslation.contains('%%ZHIDU_CODE_BLOCK_')) {
              final extractedResult = _extractCodeBlocksToPlaceholders(_content);
              final codeBlocks = extractedResult[1] as List<String>;
              processedTranslation = _restorePlaceholdersToCodeBlocks(processedTranslation, codeBlocks);
            }
            _translationContent = processedTranslation;
            _isTranslating = false;
            _streamingTranslation = '';
          });
        }
      } else if (_aiService.isConfigured && _content.isNotEmpty) {
        _log.d('ChapterScreen', '无译文缓存，自动开始翻译');
        if (mounted) {
          setState(() {
            _translationContent = null;
            _isTranslating = true;
            _streamingTranslation = '';
          });
        }
        _generateTranslationWithStreaming();
      } else {
        if (mounted) {
          setState(() {
            _translationContent = null;
            _isTranslating = false;
            _streamingTranslation = '';
          });
        }
      }
    } catch (e) {
      _log.e('ChapterScreen', '加载译文失败', e);
    }
  }

  /// 流式生成译文
  Future<void> _generateTranslationWithStreaming() async {
    _log.d('ChapterScreen', '开始生成译文，_content.isEmpty: ${_content.isEmpty}, _sourceLang: $_sourceLang, _targetLang: $_targetLang, isConfigured: ${_aiService.isConfigured}');
    
    if (_content.isEmpty) {
      _log.w('ChapterScreen', '章节内容为空，无法生成译文');
      return;
    }

    if (_targetLang == null) {
      _log.w('ChapterScreen', '目标语言为空，无法生成译文');
      return;
    }

    if (mounted) {
      setState(() {
        _isTranslating = true;
        _streamingTranslation = '';
      });
    }

    try {
      final bookFormat = widget.book?.format.name ?? 'epub';

      final extractedResult = _extractCodeBlocksToPlaceholders(_content);
      final contentWithPlaceholders = extractedResult[0] as String;
      final codeBlocks = List<String>.from(extractedResult[1]);

      _log.d('ChapterScreen', '提取了 ${codeBlocks.length} 个代码块');

      final success = await _summaryService.generateTranslationStream(
        bookId: widget.bookId,
        chapterIndex: widget.chapterIndex,
        content: contentWithPlaceholders,
        chapterTitle: _title,
        sourceLang: _sourceLang ?? 'zh',
        targetLang: _targetLang!,
        bookFormat: bookFormat,
        onContentUpdate: (content) {
          if (mounted) {
            _captureScrollAnchor(1);
            
            setState(() {
              _streamingTranslation = _restorePlaceholdersToCodeBlocks(content, codeBlocks);
            });
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _syncScrollToTab(1);
            });
          }
        },
      );

      _log.d('ChapterScreen', '翻译完成，success: $success');

      if (!mounted) return;

      if (success) {
        final translation = await _summaryService.getTranslation(
            widget.bookId, widget.chapterIndex, _targetLang!);
        setState(() {
          _translationContent = translation != null ? _restorePlaceholdersToCodeBlocks(_cleanCodeBackslashes(translation), codeBlocks) : null;
          _isTranslating = false;
          _streamingTranslation = '';
        });
      } else {
        _log.w('ChapterScreen', 'AI返回空译文');
        setState(() {
          _isTranslating = false;
          _streamingTranslation = '';
        });
      }
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

  /// 获取章节标题
  ///
  /// AppBar标题显示逻辑：
  /// 1. 优先从Book对象的chapterTitles映射获取（AI更新后的标题）
  /// 2. 如果没有，使用传入的默认标题
  ///
  /// 这样设计的原因：
  /// - AI生成摘要时可能同时更新章节标题（更准确的标题）
  /// - chapterTitles存储在Book对象中，持久化到数据库
  /// - 下次进入时可以显示更新后的标题
  String _getChapterTitle(int index, String defaultTitle) {
    if (widget.book != null) {
      final titles = widget.book!.chapterTitles;
      if (titles != null && titles.containsKey(index)) {
        return titles[index]!;
      }
    }
    return defaultTitle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // 标题显示逻辑：
        // 使用_getChapterTitle获取标题，优先显示AI更新后的标题
        title: Text(
          _getChapterTitle(widget.chapterIndex, widget.chapterTitle),
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 生成摘要按钮：仅在以下条件满足时显示
          // 1. 没有摘要
          // 2. 没有正在生成
          // 3. 有内容可用
          // 4. AI服务已配置
          if (_summary == null && !_isGenerating && _content.isNotEmpty && _aiService.isConfigured)
            TextButton.icon(
              onPressed: _generateSummaryWithStreaming,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text('生成摘要'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
        ],
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
  /// 3. 其他 -> 带Tab布局的摘要/原文/译文视图（生成中状态在Tab 0内显示）
  Widget _buildBody() {
    if (_isLoadingContent) {
      return _buildLoadingView();
    }

    if (_error != null && _content.isEmpty) {
      return _buildErrorView();
    }

    // 始终使用Tab布局，生成中/流式/无摘要状态在 Tab 0 内部处理
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

  /// 构建生成中视图
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateSummaryWithStreaming,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

/// 构建摘要/原文视图（垂直Tab布局）
///
/// 布局说明：
/// - 左侧：垂直Tab栏（摘要/原文切换）
/// - 右侧：TabBarView内容区
///
/// PDF原文阅读功能：
/// - PDF格式的书籍在原文模式下使用PdfDocumentViewBuilder
/// - 支持单页PDF查看，配合翻页按钮
Widget _buildSummaryView() {
  final bool originalViewDisabled =
      _contentTooShort || (!_aiService.isConfigured && _summary == null);

  final selectedColor = Theme.of(context).colorScheme.primary.withAlpha(40);
  final unselectedColor = Colors.grey.withAlpha(80);

  return Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _buildVerticalTab(0, Icons.auto_awesome, selectedColor: selectedColor, unselectedColor: unselectedColor),
            Container(height: 1, width: 60, color: Colors.grey.withAlpha(100)),
            _buildVerticalTab(1, Icons.translate, selectedColor: selectedColor, unselectedColor: unselectedColor, disabled: _translationTabDisabled),
            Container(height: 1, width: 60, color: Colors.grey.withAlpha(100)),
            _buildVerticalTab(2, Icons.menu_book, selectedColor: selectedColor, unselectedColor: unselectedColor, disabled: originalViewDisabled),
          ],
        ),
        Expanded(
          child: Container(
            color: selectedColor,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryContent(),
                _buildTranslationView(),
                _buildOriginalTextView(),
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
Widget _buildVerticalTab(int index, IconData icon, {required Color selectedColor, required Color unselectedColor, bool disabled = false}) {
  final isSelected = _tabController?.index == index;
  return InkWell(
    onTap: disabled ? null : () => _tabController?.animateTo(index),
    child: Container(
      width: 60,
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

  /// 构建摘要内容视图
  ///
  /// 将Markdown格式的摘要转换为HTML并渲染
  /// 使用flutter_html组件显示，支持丰富的文本样式
  Widget _buildSummaryContent() {
    // 如果在生成过程中，显示流式内容
    if (_isGenerating && _streamingSummary.isNotEmpty) {
      return _buildStreamingSummaryView();
    }

    // 如果正在生成但还没有流式内容，在Tab 0内显示加载提示
    if (_isGenerating && _streamingSummary.isEmpty) {
      return _buildGeneratingView();
    }
    
    // 否则显示正常摘要
    if (_summary != null) {
      final htmlContent = md.markdownToHtml(_summary!.objectiveSummary);
      return _buildNormalSummaryView(htmlContent);
    }
    
    // 如果都没有，显示空状态
    return _buildEmptySummaryView();
  }

/// 流式摘要视图
///
/// 显示AI正在生成摘要的过程，实时展示AI生成的内容
Widget _buildStreamingSummaryView() {
  final htmlContent = md.markdownToHtml(_streamingSummary);
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
                    'code': Style(
                      fontFamily: 'Consolas',
                      fontSize: FontSize(13),
                    ),
                    'pre': Style(
                      fontFamily: 'Consolas',
                      fontSize: FontSize(13),
                      padding: HtmlPaddings.all(8),
                      margin: Margins.only(bottom: 12),
                    ),
                  },
                ),
                const SizedBox(height: 16),
                // 显示"正在打字"动画效果
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 正常摘要视图
///
/// 显示已生成的完整摘要内容
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
                    'code': Style(
                      fontFamily: 'Consolas',
                      fontSize: FontSize(13),
                    ),
                    'pre': Style(
                      fontFamily: 'Consolas',
                      fontSize: FontSize(13),
                      padding: HtmlPaddings.all(8),
                      margin: Margins.only(bottom: 12),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  /// 空摘要视图
  ///
  /// 当没有摘要时显示的空状态
  Widget _buildEmptySummaryView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '暂无摘要',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
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

    // 无译文且未生成（翻译启动中）
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
                  Html(
                    data: htmlContent,
                    style: {
                      'body': Style(
                        fontSize: FontSize(14),
                        lineHeight: const LineHeight(1.6),
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                      ),
                      'p': Style(
                        fontSize: FontSize(14),
                        lineHeight: const LineHeight(1.6),
                        margin: Margins.only(bottom: 8),
                      ),
                      'code': Style(
                        fontFamily: 'Consolas',
                        fontSize: FontSize(13),
                      ),
                      'pre': Style(
                        fontFamily: 'Consolas',
                        fontSize: FontSize(13),
                        padding: HtmlPaddings.all(8),
                        margin: Margins.only(bottom: 12),
                      ),
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
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
                      'code': Style(
                        fontFamily: 'Consolas',
                        fontSize: FontSize(13),
                      ),
                      'pre': Style(
                        fontFamily: 'Consolas',
                        fontSize: FontSize(13),
                        padding: HtmlPaddings.all(8),
                        margin: Margins.only(bottom: 12),
                      ),
                    },
                  ),
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
  /// - EPUB/其他：使用Html组件渲染HTML内容
  Widget _buildOriginalTextView() {
    final isPdf = widget.book != null && widget.book!.format == BookFormat.pdf;

    if (isPdf && widget.filePath != null) {
      // PDF格式：显示单页PDF查看器
      // 获取当前章节信息以确定页码范围
      final currentChapter =
          _chapters.isNotEmpty ? _chapters[widget.chapterIndex] : null;
      final startPage = currentChapter?.location.startPage ?? 1;

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
                  'code': Style(
                    fontFamily: 'Consolas',
                    fontSize: FontSize(14),
                  ),
                  'pre': Style(
                    fontFamily: 'Consolas',
                    fontSize: FontSize(14),
                    padding: HtmlPaddings.all(8),
                    margin: Margins.only(bottom: 16),
                  ),
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 导航到指定章节
  ///
  /// 章节导航逻辑：
  /// - 使用Navigator.pushReplacement替换当前页面
  /// - 传入新的章节索引和标题
  /// - 保持文件路径和章节列表不变
  ///
  /// 注意：只导航到第一级章节（level=0）
  void _navigateToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;

    final chapter = _chapters[index];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterScreen(
          bookId: widget.bookId,
          chapterIndex: index,
          chapterTitle: chapter.title,
          filePath: widget.filePath,
          chapters: _chapters,
          book: widget.book,
        ),
      ),
    );
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
    final isFirst = widget.chapterIndex <= 0;
    final isLast = widget.chapterIndex >= _chapters.length - 1;

// 判断是否为PDF原文模式
final isPdf = widget.book != null && widget.book!.format == BookFormat.pdf;
final isPdfOriginalView = isPdf && (_tabController?.index == 2);

    // 计算PDF页码翻页范围（仅PDF原文阅读时有效）
    final currentChapter =
        _chapters.isNotEmpty ? _chapters[widget.chapterIndex] : null;
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
                Icons.keyboard_double_arrow_left,
                color: isFirst ? Colors.grey.shade600 : Colors.white,
                size: 28,
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
                        setState(() {
                          _pdfCurrentPage--;
                        });
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
                        setState(() {
                          _pdfCurrentPage++;
                        });
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
                Icons.keyboard_double_arrow_right,
                color: isLast ? Colors.grey.shade600 : Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
