import 'dart:async';

import 'package:flutter/material.dart';

import '../services/parsers/rendered_content.dart';
import 'html_pagination.dart';

/// 章节内容加载器：index = -1 表示书籍开头页（封面/目录/版权等前置页）
typedef ChapterContentLoader = Future<RenderedContent?> Function(int index);

/// 全书后台分页器。
///
/// 进入阅读页或窗口尺寸变化后，在后台按章节顺序逐章测量并缓存分页结果，
/// 使底部页码可以显示全书页码，并让跨章翻页直接用缓存页列表（无需现场测量）。
///
/// 优先级：当前章 → 下一章 / 上一章 → 当前章之前的章节（拼出正确的页码前缀）
/// → 其余章节。当前可视章节通常由 [PagedReaderController] 自己测量，
/// 测完后经 [adopt] 回填，避免重复测量最大的那一章。
///
/// 测量需要一个离屏列（[BookPaginatorHost]）挂在阅读页的 Stack 上，
/// 由本类驱动：设置待测块 → 等待一帧 → 读取块高度 → 稳定后切页并继续下一章。
class BookPaginator extends ChangeNotifier {
  BookPaginator({
    required TextStyle textStyle,
    this.paragraphSpacingFactor = 0.8,
    required int chapterCount,
    required bool hasOpening,
    required this.loader,
    required this.registerFonts,
  })  : _textStyle = textStyle,
        _chapterCount = chapterCount,
        _hasOpening = hasOpening;

  /// 正文文本样式（与分页阅读一致，可随排版设置更新）
  TextStyle _textStyle;

  /// 段距系数：块间距 = 字号 × 系数
  double paragraphSpacingFactor;

  TextStyle get textStyle => _textStyle;

  /// 章节内容加载器
  final ChapterContentLoader loader;

  /// 注册内嵌字体（测量前必须完成，否则字体度量与实际渲染不一致）
  final void Function(List<EmbeddedFont> fonts) registerFonts;

  int _chapterCount;
  bool _hasOpening;

  double _width = 0;
  double _height = 0;

  /// 当前优先处理的章节（通常是可视章节）
  int _priority = 0;

  /// 已完成分页的章节：index → 结果
  final Map<int, PaginatedBlocks> _paged = {};

  /// 章节 HTML（分页结果本身就是块 HTML，这里保留原文供切换章节时复用）
  final Map<int, String> _html = {};

  /// 已处理但无页的章节（竖排/空内容/加载失败）
  final Set<int> _skipped = {};

  /// 调用方已提供的章节内容（避免重复解析 EPUB）
  final Map<int, RenderedContent> _provided = {};

  /// 分页结果版本号：每次写入新结果自增，供调用方判断是否需要刷新可视章节
  final Map<int, int> _revisions = {};

  /// 暂时排除测量的章节（由控制器负责测量的可视章节）
  final Set<int> _excluded = {};

  // 测量状态
  int? _measuringIndex;
  List<String> _measureBlocks = const [];
  List<GlobalKey> _measureKeys = const [];
  List<double> _lastHeights = const [];
  int _stableCount = 0;
  int _rounds = 0;
  Timer? _timer;
  bool _working = false;
  bool _disposed = false;

  /// 重排代次：整体失效时自增，用于丢弃上一轮仍在加载/测量的过期结果
  int _generation = 0;

  double get measuringWidth => _width;

  List<String> get measuringBlocks => _measureBlocks;

  List<GlobalKey> get measuringKeys => _measureKeys;

  double get blockSpacing =>
      (textStyle.fontSize ?? 16) * paragraphSpacingFactor;

  /// 排版设置变化：更新样式并整体重排（保留已提供的章节内容，不重新解析）
  void updateTypography(TextStyle style, double spacingFactor) {
    if (_disposed) return;
    if (_textStyle == style && paragraphSpacingFactor == spacingFactor) return;
    _textStyle = style;
    paragraphSpacingFactor = spacingFactor;
    _resetAll();
  }

  /// 全书分页是否完成
  bool get isComplete => _naturalIndices.every(_isReady);

  /// 全书已知总页数（后台分页未完成时只统计已完成章节）
  int get totalPages {
    var sum = 0;
    for (final result in _paged.values) {
      sum += result.pageCount;
    }
    return sum;
  }

  List<int> get _naturalIndices => [
        if (_hasOpening) -1,
        for (var i = 0; i < _chapterCount; i++) i,
      ];

  bool _isValid(int index) =>
      index == -1 ? _hasOpening : (index >= 0 && index < _chapterCount);

  bool _isReady(int index) =>
      _paged.containsKey(index) || _skipped.contains(index);

  PaginatedBlocks? pagesFor(int index) => _paged[index];

  String? htmlFor(int index) => _html[index];

  int revisionFor(int index) => _revisions[index] ?? 0;

  /// 当前章之前的累计页数；前缀章尚未全部完成时返回 null
  int? startPageFor(int index) {
    final all = _naturalIndices;
    final pos = all.indexOf(index);
    if (pos < 0) return null;

    var sum = 0;
    for (var i = 0; i < pos; i++) {
      final result = _paged[all[i]];
      if (result != null) {
        sum += result.pageCount;
      } else if (!_skipped.contains(all[i])) {
        return null;
      }
    }
    return sum;
  }

  /// 设置当前可视章节（也作为后台分页的优先目标）
  void setPriority(int index) {
    if (!_isValid(index) || _priority == index) return;
    _priority = index;
    _pump();
  }

  /// 更新章节数量/开头页（章节列表延迟加载时调用）
  void syncCounts({required int chapterCount, required bool hasOpening}) {
    if (_chapterCount == chapterCount && _hasOpening == hasOpening) return;
    _chapterCount = chapterCount;
    _hasOpening = hasOpening;
    _resetAll();
  }

  /// 设置可用测量尺寸：变化时整体失效并重排
  ///
  /// [exclude] 为本次重排暂不测量的章节（正由阅读控制器测量，测完经 [adopt] 回填）。
  void configure(double width, double height, {int? exclude}) {
    if (_disposed || width <= 0 || height <= 0) return;
    if (width == _width && height == _height) return;
    _width = width;
    _height = height;
    _resetAll(exclude: exclude);
  }

  /// 回填由控制器测量的可视章节页列表，避免重复测量与两套页码不一致
  void adopt(int index, PaginatedBlocks result, {String? html}) {
    if (_disposed || !_isValid(index) || result.pages.isEmpty) return;
    _excluded.remove(index);
    if (html != null && html.isNotEmpty) _html[index] = html;
    final existing = _paged[index];
    if (existing != null && _samePages(existing, result)) {
      _pump();
      return;
    }
    _paged[index] = result;
    _skipped.remove(index);
    _bumpRevision(index);
    notifyListeners();
    _pump();
  }

  /// 提供章节内容（调用方已解析时），后台测量直接复用，避免再解析一次
  void provideContent(int index, RenderedContent rendered) {
    if (_disposed || !_isValid(index)) return;
    if (rendered.html.trim().isEmpty || rendered.isVertical) return;
    _provided[index] = rendered;
    _html[index] = rendered.html;
  }

  /// 停止后台分页并清空状态
  void _resetAll({int? exclude}) {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _measuringIndex = null;
    _measureBlocks = const [];
    _measureKeys = const [];
    _lastHeights = const [];
    _stableCount = 0;
    _rounds = 0;
    _working = false;
    _paged.clear();
    _skipped.clear();
    _excluded.clear();
    if (exclude != null && _isValid(exclude)) _excluded.add(exclude);
    // 保留 _html / _provided / _revisions：内容仍可复用，版本号继续递增
    notifyListeners();
    _pump();
  }

  void _bumpRevision(int index) {
    _revisions[index] = (_revisions[index] ?? 0) + 1;
  }

  bool _samePages(PaginatedBlocks a, PaginatedBlocks b) {
    if (a.pages.length != b.pages.length) return false;
    if (a.pageStartBlocks.length != b.pageStartBlocks.length) return false;
    for (var i = 0; i < a.pageStartBlocks.length; i++) {
      if (a.pageStartBlocks[i] != b.pageStartBlocks[i]) return false;
    }
    return true;
  }

  /// 按优先级取下一个待分页章节
  int? _nextIndex() {
    for (final index in _order()) {
      if (_isReady(index) || _excluded.contains(index)) continue;
      if (_measuringIndex == index) continue;
      return index;
    }
    return null;
  }

  /// 优先级顺序：当前章 → 下一章 → 上一章 → 当前章之前的章节 → 其余章节
  List<int> _order() {
    final natural = _naturalIndices;
    final current = _priority;
    final ordered = <int>[];

    void add(int? index) {
      if (index == null || !_isValid(index) || ordered.contains(index)) return;
      ordered.add(index);
    }

    add(current);
    add(current + 1);
    add(current - 1);
    for (final index in natural) {
      if (index < current) add(index);
    }
    for (final index in natural) {
      if (index > current) add(index);
    }
    return ordered;
  }

  void _pump() {
    if (_disposed || _working) return;
    if (_width <= 0 || _height <= 0) return;

    final next = _nextIndex();
    if (next == null) return;

    _working = true;
    unawaited(_measureChapter(next, _generation));
  }

  Future<void> _measureChapter(int index, int generation) async {
    RenderedContent? rendered = _provided.remove(index);
    if (rendered == null) {
      final cachedHtml = _html[index];
      if (cachedHtml != null && cachedHtml.trim().isNotEmpty) {
        // 已解析过（如窗口尺寸变化后的重排）：直接复用，避免再解析一次 EPUB
        rendered = RenderedContent(cachedHtml);
      } else {
        try {
          rendered = await loader(index);
        } catch (_) {
          rendered = null;
        }
      }
    }
    // 加载期间发生了重排（尺寸变化/章节数变化）：放弃本次结果，由新一轮测量接手
    if (_disposed || generation != _generation) return;

    if (rendered == null || rendered.isVertical || rendered.html.trim().isEmpty) {
      _finishWithoutPages(index);
      return;
    }

    _html[index] = rendered.html;
    registerFonts(rendered.fonts);

    final blocks = buildHtmlBlocks(rendered.html);
    if (blocks.isEmpty) {
      _finishWithoutPages(index);
      return;
    }

    // 图片独立页固定占 1 页（与图片像素尺寸无关），不做测量
    if (isImagePageBlocks(blocks)) {
      _finishImagePage(index, blocks);
      return;
    }

    _measuringIndex = index;
    _measureBlocks = blocks;
    _measureKeys = List<GlobalKey>.generate(blocks.length, (_) => GlobalKey());
    _lastHeights = const [];
    _stableCount = 0;
    _rounds = 0;
    notifyListeners();

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _measureRound(index, generation));
  }

  void _measureRound(int index, int generation) {
    if (_disposed || generation != _generation || _measuringIndex != index) {
      return;
    }

    final heights = <double>[];
    for (final key in _measureKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      heights.add(box == null ? 0.0 : box.size.height);
    }

    final changed = !heightsEqual(heights, _lastHeights);
    _lastHeights = heights;
    _rounds++;

    // 全为 0 说明测量列尚未挂载/完成布局，继续等
    final allZero = heights.every((h) => h <= 0);
    if (allZero) {
      _stableCount = 0;
    } else if (changed) {
      _stableCount = 0;
    } else {
      _stableCount++;
    }

    if (_stableCount < 2 && _rounds < 40) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 120), () {
        _measureRound(index, generation);
      });
      return;
    }

    final result = paginateBlocks(_measureBlocks, heights, blockSpacing, _height);
    _paged[index] = result;
    _bumpRevision(index);
    _measuringIndex = null;
    _measureBlocks = const [];
    _measureKeys = const [];
    _working = false;
    notifyListeners();
    _pump();
  }

  /// 图片独立页：直接登记为 1 页，跳过测量
  void _finishImagePage(int index, List<String> blocks) {
    final result = imagePageResult(blocks);
    final existing = _paged[index];
    if (existing == null || !_samePages(existing, result)) {
      _paged[index] = result;
      _skipped.remove(index);
      _bumpRevision(index);
    }
    _measuringIndex = null;
    _measureBlocks = const [];
    _measureKeys = const [];
    _working = false;
    notifyListeners();
    _pump();
  }

  void _finishWithoutPages(int index) {
    _skipped.add(index);
    _measuringIndex = null;
    _measureBlocks = const [];
    _measureKeys = const [];
    _working = false;
    notifyListeners();
    _pump();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// 全书后台分页的离屏测量宿主（挂在阅读页 Stack 顶层，切 Tab 不销毁）
class BookPaginatorHost extends StatelessWidget {
  final BookPaginator paginator;

  const BookPaginatorHost({super.key, required this.paginator});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: paginator,
      builder: (context, _) {
        final blocks = paginator.measuringBlocks;
        final width = paginator.measuringWidth;
        if (blocks.isEmpty || width <= 0) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: width,
          child: HtmlMeasureColumn(
            blocks: blocks,
            keys: paginator.measuringKeys,
            textStyle: paginator.textStyle,
          ),
        );
      },
    );
  }
}
