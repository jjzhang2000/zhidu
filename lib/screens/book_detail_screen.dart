/// 书籍详情页面
///
/// 显示书籍的详细信息和AI生成的全书摘要，支持在摘要视图和章节目录之间切换。
///
/// 核心功能：
/// 1. **全书摘要展示**：显示AI生成的书籍概览（Markdown渲染）
/// 2. **章节目录展示**：层级缩进的章节列表
/// 3. **后台预生成**：自动在后台为书籍生成章节摘要
/// 4. **定时刷新**：检测全书摘要生成完成状态
///
/// 用户交互：
/// - 点击摘要内容 → 进入第一章阅读
/// - 点击目录按钮 → 切换到章节列表
/// - 点击顶层章节 → 进入该章节阅读
///
/// 关键机制：
/// - [_startPreGeneration] 后台静默生成章节摘要
/// - [_refreshBookIfNeeded] 定时刷新检测全书摘要状态
/// - [_getChapterTitle] 优先显示提取的章节标题

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/parsers/format_registry.dart';
import '../models/chapter.dart';
import '../services/ai_service.dart';
import '../services/summary_service.dart';
import '../services/log_service.dart';
import 'summary_screen.dart';

/// 书籍详情页面的StatefulWidget
///
/// 接收一个[Book]对象，显示该书籍的详细信息。
class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  /// 书籍管理服务（单例）
  final _bookService = BookService();

  /// AI服务（用于检测是否已配置）
  final _aiService = AIService();

  /// 摘要生成服务（后台预生成用）
  final _summaryService = SummaryService();

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

  /// 当前视图模式：false=全书摘要，true=章节目录
  bool _showChapterStructure = false;

  /// 是否正在后台预生成摘要
  ///
  /// 防止重复启动预生成任务。
  bool _isPreGenerating = false;

  /// 定时刷新计时器
  ///
  /// 每3秒检查一次书籍状态，用于：
  /// - 检测全书摘要是否生成完成
  /// - 更新UI显示最新状态
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    // 获取最新的书籍数据（可能已在其他地方更新）
    _book = _bookService.getBookById(widget.book.id) ?? widget.book;

    // 加载章节列表
    _loadChapters();

    // 启动后台预生成摘要任务
    _startPreGeneration();

    // 启动定时刷新机制
    // 目的：检测全书摘要是否生成完成，及时更新UI
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshBookIfNeeded();
    });
  }

  @override
  void dispose() {
    // 清理定时器，防止内存泄漏
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// 加载书籍章节列表
  ///
  /// 使用格式注册表获取对应的解析器（EPUB/PDF），
  /// 解析书籍结构并获取扁平化的章节列表。
  ///
  /// 章节列表用于：
  /// 1. 在目录视图展示章节结构
  /// 2. 点击章节时跳转到对应位置
  Future<void> _loadChapters() async {
    _log.v('BookDetailScreen', '_loadChapters 开始执行');
    setState(() => _isLoadingChapters = true);

    try {
      // 根据书籍格式获取对应的解析器
      final parser = FormatRegistry.getParser('.${_book.format.name}');
      if (parser == null) {
        _log.e('BookDetailScreen', '不支持的格式: ${_book.format}');
        setState(() => _isLoadingChapters = false);
        return;
      }

      // 解析章节结构
      final chapters = await parser.getChapters(_book.filePath);

      setState(() {
        _flatChapters = chapters;
        _isLoadingChapters = false;
      });

      _log.d('BookDetailScreen', '章节加载完成: ${chapters.length} 个章节');
    } catch (e, stackTrace) {
      _log.e('BookDetailScreen', '加载章节列表失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
        });
      }
    }
  }

  /// 后台静默预生成章节摘要
  ///
  /// 当用户打开书籍详情页时，自动在后台启动摘要生成任务，
  /// 这样用户在浏览全书摘要时，章节摘要已经在后台生成。
  ///
  /// 预生成机制：
  /// 1. 检查AI服务是否已配置
  /// 2. 防止重复启动（通过[_isPreGenerating]标志）
  /// 3. 异步执行，不阻塞UI
  /// 4. 调用[SummaryService.generateSummariesForBook]生成所有章节摘要
  ///
  /// 优点：
  /// - 用户无需等待，摘要提前准备好
  /// - 不影响页面加载速度
  /// - 静默执行，无侵入性
  void _startPreGeneration() {
    // AI未配置则跳过
    if (!_aiService.isConfigured) {
      _log.d('BookDetailScreen', 'AI服务未配置，跳过预生成');
      return;
    }

    // 防止重复启动预生成任务
    if (_isPreGenerating) {
      _log.d('BookDetailScreen', '已在预生成中，跳过');
      return;
    }

    _isPreGenerating = true;

    // 异步执行，不阻塞UI
    Future(() async {
      try {
        _log.d('BookDetailScreen', '开始后台预生成章节摘要');

        // 先刷新一次，因为 generateSummariesForBook 可能在前台已完成前言摘要
        // 避免重复生成或状态不一致
        _refreshBookIfNeeded();

        // 执行摘要生成
        await _summaryService.generateSummariesForBook(_book);
        _log.d('BookDetailScreen', '后台预生成章节摘要完成');

        // 生成完成后再次刷新书籍状态
        _refreshBookIfNeeded();
      } catch (e, stackTrace) {
        _log.e('BookDetailScreen', '后台预生成章节摘要失败', e, stackTrace);
      } finally {
        _isPreGenerating = false;
      }
    });
  }

  /// 按需刷新书籍数据
  ///
  /// 由定时器调用，检测书籍的[aiIntroduction]是否已更新。
  /// 如果全书摘要从null变为有内容，则触发setState更新UI。
  ///
  /// 刷新逻辑：
  /// 1. 从数据库获取最新书籍数据
  /// 2. 比较[aiIntroduction]是否变化
  /// 3. 变化则setState更新UI，否则静默更新_book引用
  ///
  /// 这种设计避免了频繁setState，只在真正需要时更新UI。
  void _refreshBookIfNeeded() {
    final refreshedBook = _bookService.getBookById(_book.id);
    if (refreshedBook != null && mounted) {
      // 全书摘要发生变化，需要更新UI
      if (refreshedBook.aiIntroduction != _book.aiIntroduction) {
        setState(() {
          _book = refreshedBook;
        });
      } else {
        // 无变化，静默更新引用
        _book = refreshedBook;
      }
    }
  }

  /// 获取章节标题
  ///
  /// 标题来源优先级：
  /// 1. **优先**：从[_book.chapterTitles]获取（AI提取的高质量标题）
  /// 2. **回退**：使用[chapter.title]（EPUB原始标题）
  ///
  /// AI提取的标题通常更准确，因为EPUB原始标题可能：
  /// - 包含噪音字符（如"第1章"、"Chapter 1"等）
  /// - 格式不统一
  /// - 层级信息缺失
  ///
  /// 参数：
  /// - [index] 章节索引
  /// - [chapter] 章节对象
  ///
  /// 返回：显示用的章节标题
  String _getChapterTitle(int index, Chapter chapter) {
    // 尝试从书籍的章节标题映射中获取
    final titles = _book.chapterTitles;
    if (titles != null && titles.containsKey(index)) {
      return titles[index]!;
    }
    // 回退到原始标题
    return chapter.title;
  }

  /// 切换视图模式
  ///
  /// 在"全书摘要"和"章节目录"之间切换。
  void _toggleView() {
    setState(() {
      _showChapterStructure = !_showChapterStructure;
    });
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
          // 顶部书籍信息区域：封面、标题、作者、章节数
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildBookHeader(),
          ),
          const Divider(height: 1),
          // 底部内容区域（全书摘要或章节目录）
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildAIIntroduction(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建书籍头部信息
  ///
  /// 包含：封面图片、书名、作者、章节数、添加日期
  Widget _buildBookHeader() {
    return Row(
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 作者
              Text(
                _book.author,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 12),
              // 信息标签：章节数、添加日期
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                      Icons.menu_book,
                      _isLoadingChapters
                          ? '加载中...'
                          : '${_flatChapters.length} 章'),
                  _buildInfoChip(
                      Icons.calendar_today, _formatDate(_book.addedAt)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建封面图片
  ///
  /// 封面来源：
  /// 1. 如果[_book.coverPath]存在且文件有效，显示实际封面
  /// 2. 否则显示默认封面图标
  Widget _buildCover() {
    final coverSize = 120.0;

    if (_book.coverPath != null && File(_book.coverPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_book.coverPath!),
          width: coverSize * 0.7,
          height: coverSize,
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
    return Container(
      width: size * 0.7,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blueGrey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.book,
          size: 40,
          color: Colors.blueGrey[300],
        ),
      ),
    );
  }

  /// 构建信息标签（章节数、日期等）
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建主内容区域（全书摘要/章节目录切换）
  ///
  /// 布局：左侧切换按钮 + 右侧内容卡片
  ///
  /// 切换按钮：
  /// - 图标：星星（摘要模式）或列表（目录模式）
  /// - 点击切换视图
  ///
  /// 内容卡片：
  /// - 显示全书摘要或章节目录
  /// - 根据当前模式切换显示内容
  Widget _buildAIIntroduction() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧切换按钮（在卡片外部）
        Padding(
          padding: const EdgeInsets.only(top: 14, right: 8),
          child: InkWell(
            onTap: _toggleView,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                // 图标与当前模式相反，提示用户点击后切换到什么
                _showChapterStructure
                    ? Icons.auto_awesome
                    : Icons.format_list_numbered,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        // 主内容卡片
        Expanded(
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _showChapterStructure
                            ? Icons.format_list_numbered
                            : Icons.auto_awesome,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _showChapterStructure ? '目录' : '内容介绍',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // 内容区域（可滚动）
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _showChapterStructure
                        ? _buildChapterStructureContent()
                        : _buildAIIntroductionContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建全书摘要内容
  ///
  /// 显示逻辑：
  /// 1. **无摘要**：显示提示信息
  ///    - AI已配置："全书摘要生成中，请稍候..."
  ///    - AI未配置："AI服务未配置，无法生成全书摘要"
  ///
  /// 2. **有摘要**：
  ///    - 将Markdown转换为HTML显示
  ///    - 点击摘要区域可进入第一章阅读
  ///
  /// Markdown渲染：
  /// - 使用[md.markdownToHtml]转换
  /// - 使用[flutter_html]组件渲染
  /// - 自定义标题、段落、列表样式
  Widget _buildAIIntroductionContent() {
    // 没有全书摘要
    if (_book.aiIntroduction == null || _book.aiIntroduction!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              _aiService.isConfigured ? '全书摘要生成中，请稍候...' : 'AI服务未配置，无法生成全书摘要',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 显示全书摘要（Markdown渲染）
    final htmlContent = md.markdownToHtml(_book.aiIntroduction!);
    return GestureDetector(
      // 点击摘要进入第一章阅读
      onTap: _flatChapters.isNotEmpty
          ? () {
              final firstChapter = _flatChapters.first;
              _log.d('BookDetailScreen', '点击全书摘要，进入第一章: ${firstChapter.title}');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SummaryScreen(
                    bookId: _book.id,
                    chapterIndex: firstChapter.index,
                    chapterTitle: firstChapter.title,
                    filePath: _book.filePath,
                    chapters: _flatChapters,
                    book: _book,
                  ),
                ),
              );
            }
          : null,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Html(
            data: htmlContent,
            style: {
              'body': Style(
                fontSize: FontSize(14),
                lineHeight: const LineHeight(1.6),
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'h2': Style(
                fontSize: FontSize(16),
                fontWeight: FontWeight.bold,
                margin: Margins.only(bottom: 8, top: 16),
              ),
              'h3': Style(
                fontSize: FontSize(15),
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
  ///
  /// 章节列表特点：
  /// - 根据层级[level]缩进（每层16像素）
  /// - 字体大小随层级递减
  /// - 子章节颜色较淡
  /// - 只有顶层章节可点击进入阅读
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
  /// - 字体大小：13 - level * 1（顶层13px，一级12px...）
  /// - 颜色：子章节使用灰色(Colors.grey[600])，顶层章节使用默认颜色
  /// - 最大显示1行，超出显示省略号
  ///
  /// **交互规则**：
  /// - 只有顶层章节(level=0)可以点击
  /// - 子章节不可点击（onTap为null）
  /// - 点击顶层章节跳转到[SummaryScreen]
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
              // 使用_getChapterTitle获取标题（优先AI提取的标题）
              _getChapterTitle(chapter.index, chapter),
              style: TextStyle(
                // 字体大小随层级递减
                fontSize: 13 - chapter.level * 1,
                // 子章节颜色较淡
                color: chapter.level > 0 ? Colors.grey[600] : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // 只有顶层章节才能点击进入阅读
            onTap: chapter.level == 0
                ? () {
                    _log.d('BookDetailScreen', '点击章节: ${chapter.title}');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SummaryScreen(
                          bookId: _book.id,
                          chapterIndex: chapter.index,
                          chapterTitle: chapter.title,
                          filePath: _book.filePath,
                          chapters: _flatChapters,
                          book: _book,
                        ),
                      ),
                    );
                  }
                : null, // 子章节不可点击
          ),
        ),
      );
    }
    return widgets;
  }

  /// 格式化日期为 YYYY-MM-DD 格式
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
