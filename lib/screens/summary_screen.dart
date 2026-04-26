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
class SummaryScreen extends StatefulWidget {
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String? chapterContent;
  final String? filePath;
  final List<Chapter>? chapters;
  final Book? book;

  const SummaryScreen({
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
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
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

  @override
  void initState() {
    super.initState();

    // 过滤章节列表，只保留第一级章节（level == 0）
    // 这样导航时按章节层级移动，而不是按所有子章节
    if (widget.chapters != null) {
      _chapters = widget.chapters!.where((c) => c.level == 0).toList();
    }

// 初始化流程：先加载内容，再加载摘要
// 使用then链式调用确保顺序执行
_initializeContent().then((_) {
  _loadSummary();
});

// 初始化Tab控制器
_tabController = TabController(length: 2, vsync: this);
_tabController!.addListener(() {
  if (mounted) setState(() {});
});
  }

@override
void dispose() {
  _tabController?.dispose(); // 释放Tab控制器
  _uiRefreshTimer?.cancel(); // 清理UI刷新定时器
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
    // 优先使用已传入的内容（EPUB预加载场景）
    if (widget.chapterContent != null && widget.chapterContent!.isNotEmpty) {
      _content = widget.chapterContent!;
      _title = widget.chapterTitle;
      _checkContentLength();
      if (!mounted) return;
      setState(() => _isLoadingContent = false);
      return;
    }

    // 从文件路径加载内容（延迟加载场景）
    if (widget.filePath != null) {
      if (!mounted) return;
      setState(() => _isLoadingContent = true);
      await _loadChapterContent();
      return;
    }

    // 既没有内容也没有文件路径，报错
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
/// 2. 如果没有摘要，自动切换到原文视图（Tab 1）
void _checkContentLength() {
  final textContent = _extractTextContent(_content);
  final byteLength = utf8.encode(textContent).length;
  _contentTooShort = byteLength < 2000;

  // 内容过短且没有摘要时，默认切换到原文视图
  if (_contentTooShort && _summary == null) {
    _tabController?.animateTo(1);
  }
}

  /// 从文件加载章节内容
  ///
  /// 使用FormatRegistry获取对应格式的解析器，
  /// 解析章节列表并获取指定章节的内容
  Future<void> _loadChapterContent() async {
    try {
      List<Chapter> chapters = widget.chapters ?? [];

      // 如果没有传入章节列表，从文件解析
      if (chapters.isEmpty && widget.filePath != null) {
        _log.d('SummaryScreen', '使用FormatRegistry加载章节列表');

        // 根据文件扩展名获取解析器
        final extension = _getFileExtension(widget.filePath!);
        final parser = FormatRegistry.getParser(extension);

        if (parser != null) {
          chapters = await parser.getChapters(widget.filePath!);
        } else {
          _log.e('SummaryScreen', '不支持的格式: $extension');
        }
      }

      // 过滤出第一级章节
      final topLevelChapters = chapters.where((c) => c.level == 0).toList();
      _chapters = topLevelChapters;

      _log.d('SummaryScreen',
          '第一级章节总数: ${topLevelChapters.length}, 请求索引: ${widget.chapterIndex}');

      // 检查索引有效性
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

      // 使用FormatRegistry获取章节内容
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
        _log.e('SummaryScreen', '获取章节内容失败', e);
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
  /// - 如果有正在生成的Future，注册流式回调监听内容更新
  /// - 如果没有正在生成但没有摘要，自动启动AI生成摘要并进入流式显示
  /// - 如果没有正在生成且有摘要，直接加载已有摘要
  /// - 流式内容会实时更新 _streamingSummary，UI会自动显示
  /// - 防止重复加载：同一个章节只处理一次
  Future<void> _loadSummary() async {
    final chapterKey = '${widget.bookId}_${widget.chapterIndex}';

    // 防止重复加载同一个章节
    if (_hasLoadedSummary && _listeningChapterKey == chapterKey) {
      _log.d('SummaryScreen', '章节 $chapterKey 已加载过，跳过');
      return;
    }

    final generatingFuture =
        _summaryService.getGeneratingFuture(widget.bookId, widget.chapterIndex);

    if (generatingFuture != null) {
      // 有正在后台生成的摘要
      _log.d('SummaryScreen', '章节正在生成中，监听流式内容: $chapterKey');

      _hasLoadedSummary = true;
      _listeningChapterKey = chapterKey;

      setState(() {
        _isGenerating = true;
        _streamingSummary = '';  // 清空，等待流式内容
        _summary = null;  // 清空旧摘要，避免显示旧内容
      });

      // 注册流式回调
      _summaryService.registerStreamingCallback(
        widget.bookId,
        widget.chapterIndex,
        (content) {
          if (!mounted) return;
          // 只有当前章节还在生成时才更新
          if (_summaryService.isGenerating(widget.bookId, widget.chapterIndex)) {
            setState(() {
              _streamingSummary = content;
            });
          }
        },
      );

      // 监听完成事件
      final capturedBookId = widget.bookId;
      final capturedChapterIndex = widget.chapterIndex;
      generatingFuture.then((_) {
        if (!mounted) return;
        // 验证还是同一个章节
        if (capturedBookId != widget.bookId || capturedChapterIndex != widget.chapterIndex) return;

        // 取消回调注册
        _summaryService.unregisterStreamingCallback(capturedBookId, capturedChapterIndex);

        // 加载最终摘要
        _summaryService.getSummary(capturedBookId, capturedChapterIndex).then((summary) {
          if (!mounted) return;
          if (capturedBookId != widget.bookId || capturedChapterIndex != widget.chapterIndex) return;

          setState(() {
            _summary = summary;
            _isGenerating = false;
            _streamingSummary = '';  // 清空流式内容
          });
        });
      }).catchError((e) {
        if (!mounted) return;
        if (capturedBookId != widget.bookId || capturedChapterIndex != widget.chapterIndex) return;

        _summaryService.unregisterStreamingCallback(capturedBookId, capturedChapterIndex);
        setState(() {
          _error = '生成失败: $e';
          _isGenerating = false;
        });
      });

      return;
    }

    // 没有正在生成，检查是否已有摘要
    _hasLoadedSummary = true;
    _listeningChapterKey = chapterKey;

    final summary = await _summaryService.getSummary(widget.bookId, widget.chapterIndex);
    
    if (summary != null) {
      // 已有摘要，直接显示
      if (!mounted) return;
      setState(() {
        _summary = summary;
      });
    } else {
      // 没有摘要，检查是否满足生成条件
      if (_content.isNotEmpty && _aiService.isConfigured) {
        _log.d('SummaryScreen', '没有现有摘要，自动启动AI生成: $chapterKey');
        // 自动启动AI摘要生成，并进入流式显示
        // 先设置生成状态，避免按钮显示
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
      );

      if (!mounted) return;

      if (success) {
        // 加载新生成的摘要
        final summary = await _summaryService.getSummary(
          widget.bookId,
          widget.chapterIndex,
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
  /// 3. 生成中 -> 生成视图（流式内容或加载动画）
  /// 4. 其他 -> 摘要/原文视图
  Widget _buildBody() {
    if (_isLoadingContent) {
      return _buildLoadingView();
    }

    if (_error != null && _content.isEmpty) {
      return _buildErrorView();
    }

    // 生成中时，显示流式内容（如果已有内容）或加载视图
    if (_isGenerating) {
      // 如果已经有流式内容，显示流式视图
      if (_streamingSummary.isNotEmpty) {
        return _buildSummaryContent();
      }
      // 否则显示加载动画
      return _buildGeneratingView();
    }

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
  // 原文视图禁用条件：
  // 1. 内容过短
  // 2. AI未配置且没有摘要
  final bool originalViewDisabled =
      _contentTooShort || (!_aiService.isConfigured && _summary == null);

  // 三层颜色区分（加大色差）
  final selectedColor = Theme.of(context).colorScheme.primary.withAlpha(40);
  final unselectedColor = Colors.grey.withAlpha(80);

  return Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧垂直Tab栏（无整体背景，每个Tab独立背景色）
        Column(
          children: [
            _buildVerticalTab(0, Icons.auto_awesome, selectedColor: selectedColor, unselectedColor: unselectedColor),
            Container(height: 1, width: 60, color: Colors.grey.withAlpha(100)),
            _buildVerticalTab(1, Icons.menu_book, selectedColor: selectedColor, unselectedColor: unselectedColor, disabled: originalViewDisabled),
          ],
        ),
        // 右侧Tab内容区（与选中Tab同色）
        Expanded(
          child: Container(
            color: selectedColor,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryContent(),
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
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI正在生成摘要...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
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
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _title, // 使用当前标题，与AppBar一致
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
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
                    fontFamily: 'monospace',
                    fontSize: FontSize(14),
                  ),
                  'pre': Style(
                    fontFamily: 'monospace',
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
        builder: (context) => SummaryScreen(
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
final isPdfOriginalView = isPdf && (_tabController?.index == 1);

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
