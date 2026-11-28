import 'dart:async';

import 'package:flutter/material.dart';

import 'html_pagination.dart';

/// 打开分页阅读器时请求定位的目标位置。
///
/// 父级只用它表达「打开到某位置」的意图，控制器在分页稳定后自行消费并清空，
/// 不再需要父级传一次性页码、也不必由子级回传结果来同步状态。
class PagedOpenTarget {
  /// 目标页码（0 起）
  final int? pageIndex;

  /// 是否定位到最后一页（向前翻章时落在上一章末尾）
  final bool lastPage;

  /// 目标标题（子章节锚点）
  final String? anchor;

  const PagedOpenTarget._({this.pageIndex, this.lastPage = false, this.anchor});

  /// 打开到首页
  static const PagedOpenTarget first = PagedOpenTarget._(pageIndex: 0);

  /// 打开到末页
  static const PagedOpenTarget last = PagedOpenTarget._(lastPage: true);

  /// 打开到指定页
  const PagedOpenTarget.page(int index) : this._(pageIndex: index);

  /// 打开到标题所在页
  const PagedOpenTarget.atAnchor(String title) : this._(anchor: title);
}

/// 章节边界回调：delta 为 -1 表示向前翻章，+1 表示向后翻章。
typedef PagedBoundaryCallback = void Function(int delta);

/// 视图布局回调：把测量用的可用宽高上报给父级（用于全书后台分页）
typedef PagedLayoutCallback = void Function(double width, double height);

/// 全书页码信息（底部页码指示用）
///
/// [pageStart] 为本章之前的累计页数，-1 表示前缀章尚未完成分页；[totalPages]
/// 为全书已知总页数，0 表示尚未就绪。两者都就绪时页码指示显示全书页码，
/// 否则回退为当前章节内的页码，避免显示错误的全书页码。
class BookPageInfo {
  final int pageStart;
  final int totalPages;

  const BookPageInfo({this.pageStart = -1, this.totalPages = 0});

  bool get isReady => pageStart >= 0 && totalPages > 0;

  @override
  bool operator ==(Object other) =>
      other is BookPageInfo &&
      other.pageStart == pageStart &&
      other.totalPages == totalPages;

  @override
  int get hashCode => Object.hash(pageStart, totalPages);
}

/// 分页阅读控制器。
///
/// 统一持有章节内容、块列表、页列表、当前页与待定位目标，并负责分页测量结果的
/// 累积计算与跨章过渡动画。视图（[PagedReadingView]）只做三件事：渲染页、
/// 渲染离屏测量列并在尺寸变化时请求重新测量、把各种输入转成 [turnPage]。
///
/// 页列表有两种来源：
/// - [open]：控制器自己测量离线列得到页列表（首次打开、后台分页尚未覆盖的章节）；
/// - [openPages]：直接采用调用方（[BookPaginator]）传入的页列表，无需测量，
///   跨章时不再有「测量白屏」等待。
///
/// 状态收敛为三个：
/// - [isMeasuring]：分页测量尚未稳定；
/// - [isPositioning]：已换章但还没定位到目标页（此时视图隐藏并忽略输入）；
/// - [exitingBlocks] 非空：跨章过渡进行中（旧页滑出、新页滑入）。
class PagedReaderController extends ChangeNotifier {
  PagedReaderController({
    required TickerProvider vsync,
    required TextStyle textStyle,
    this.paragraphSpacingFactor = 0.8,
    this.onBoundary,
    this.onLayout,
  }) : _textStyle = textStyle {
    _pageController = PageController();
    _transition = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 260),
    );
    _transitionCurve = CurvedAnimation(
      parent: _transition,
      curve: Curves.easeOutCubic,
    );
    _transition.addListener(_notify);
    _transition.addStatusListener(_onTransitionStatus);
  }

  /// 正文文本样式（同时决定块间距，保证测量与渲染一致）
  TextStyle _textStyle;

  TextStyle get textStyle => _textStyle;

  /// 段距系数：块间距 = 字号 × 系数
  double paragraphSpacingFactor;

  /// 章节边界回调，由父级处理翻章（返回后经 [open] 送入新章内容）
  final PagedBoundaryCallback? onBoundary;

  /// 测量尺寸上报回调（每次视图可用宽高变化时触发一次）
  final PagedLayoutCallback? onLayout;

  late final PageController _pageController;
  late final AnimationController _transition;
  late final CurvedAnimation _transitionCurve;

  /// 全书页码信息（由父级按后台分页进度更新），页码指示监听它
  final ValueNotifier<BookPageInfo> bookPaging =
      ValueNotifier(const BookPageInfo());

  /// 当前章节 HTML
  String _html = '';

  /// 块级元素 HTML 列表（已含 body 级包裹样式）
  List<String> _blocks = [];

  /// 每个块的测量用 GlobalKey
  List<GlobalKey> _blockKeys = [];

  /// 每个块的纯文本（去标签、去空白），用于按标题定位子章节起始页
  List<String> _blockTexts = [];

  /// 分页结果：每页为块 HTML 列表
  List<List<String>> _pages = [];

  /// 每页起始块的下标（与 [_pages] 等长）
  List<int> _pageStartBlocks = [];

  int _currentPage = 0;
  int _totalPages = 0;

  // 测量状态
  double? _measuredWidth;
  double? _measuredHeight;
  List<double> _lastHeights = [];
  bool _measuring = false;
  int _stableCount = 0;
  int _measureRounds = 0;
  Timer? _measureTimer;

  // 视图上报的可用宽高（去重后经 [onLayout] 通知父级）
  double? _reportedWidth;
  double? _reportedHeight;

  /// 页列表是否来自外部（[openPages]）：此时控制器不再自行测量
  bool _usesExternalPages = false;

  // 待定位目标（非空表示定位中）
  PagedOpenTarget? _target;
  bool _positioning = false;

  // 跨章过渡：旧页快照 + 滑动方向。非空表示过渡进行中。
  List<String>? _exitingBlocks;
  int _slideDirection = 1;

  /// 排版重排中：旧页快照仅用于遮盖测量期间，完成后直接切换，不播放滑动过渡
  bool _reflowing = false;

  bool _disposed = false;

  /// 批量更新中：暂停通知，避免父级在「章节已切换但页列表尚未替换」的中间态读取到旧页
  bool _updating = false;

  PageController get pageController => _pageController;

  Animation<double> get transitionAnimation => _transitionCurve;

  String get html => _html;

  List<String> get blocks => _blocks;

  List<GlobalKey> get blockKeys => _blockKeys;

  List<List<String>> get pages => _pages;

  /// 每页起始块下标（供父级回填给后台分页，保证两套页码一致）
  List<int> get pageStartBlocks => _pageStartBlocks;

  /// 每块的纯文本
  List<String> get blockTexts => _blockTexts;

  int get currentPage => _currentPage;

  int get totalPages => _totalPages;

  double? get measuredWidth => _measuredWidth;

  double? get measuredHeight => _measuredHeight;

  bool get isMeasuring => _measuring;

  /// 页列表是否由外部（后台分页）提供：此时视图不再请求控制器测量
  bool get usesExternalPages => _usesExternalPages;

  /// 已换章但尚未定位到目标页：视图隐藏 PageView 并忽略翻页输入
  bool get isPositioning => _positioning;

  /// 过渡中滑出的旧页，为 null 时无过渡层
  List<String>? get exitingBlocks => _exitingBlocks;

  /// 过渡方向：1 = 向后翻（新章从右进），-1 = 向前翻（新章从左进）
  int get slideDirection => _slideDirection;

  /// 块与块之间的间距：fwfh 会剥离 HtmlWidget 根元素的上下外边距，故显式插入
  double get blockSpacing =>
      (textStyle.fontSize ?? 16) * paragraphSpacingFactor;

  /// 排版设置变化：更新样式（由父级随后调用 [open] 重新分页）
  void updateTypography(TextStyle style, double spacingFactor) {
    if (_disposed) return;
    _textStyle = style;
    paragraphSpacingFactor = spacingFactor;
  }

  /// 打开新内容并定位到 [target]。
  ///
  /// 若当前已有分页结果，会把当前页快照为过渡中滑出的旧页；新内容测量期间
  /// 继续显示该快照，测量稳定后播放「旧页滑出 + 新页滑入」过渡。
  void open(
    String html, {
    PagedOpenTarget target = PagedOpenTarget.first,
    bool animate = true,
  }) {
    if (_disposed) return;

    _updating = true;
    // 记录当前页作为过渡的旧页；若上一章仍在测量（无页），保留已有快照避免白屏。
    // 排版调整时不播放过渡（animate=false），直接原地重排。
    if (animate && _pages.isNotEmpty) {
      _exitingBlocks = _pages[_currentPage.clamp(0, _pages.length - 1)];
      _reflowing = false;
    } else if (!animate && _pages.isNotEmpty) {
      // 排版调整：保留旧页快照遮盖测量期，稳定后直接切换到新分页
      _exitingBlocks = _pages[_currentPage.clamp(0, _pages.length - 1)];
      _reflowing = true;
    } else {
      _exitingBlocks = null;
      _reflowing = false;
    }
    final hasExit = _exitingBlocks != null;
    _transition.stop();
    // 复位过渡进度：结束后 controller 停在 1.0，不复位会让旧页快照整体移出屏幕
    _transition.value = 0;
    _slideDirection = target.lastPage ? -1 : 1;

    _usesExternalPages = false;
    _html = html;
    _prepareBlocks();

    _target = target;
    // 只有确实需要定位（换章过渡 / 末页 / 锚点 / 指定页）才隐藏 PageView；
    // 首次打开到首页时直接显示，避免测量期间白屏，也不拦截用户输入。
    _positioning = hasExit ||
        target.lastPage ||
        target.anchor != null ||
        (target.pageIndex ?? 0) > 0;
    _measuring = true;
    _stableCount = 0;
    _measureRounds = 0;
    _lastHeights = const [];
    _measureTimer?.cancel();
    _measureTimer = null;

    _updating = false;
    _notify();
  }

  /// 直接采用外部页列表（全书后台分页结果），不做测量。
  ///
  /// 换章时同样把当前页快照为过渡旧页并播放滑动过渡，只是省去了新章测量等待。
  void openPages(
    List<List<String>> pages, {
    PagedOpenTarget target = PagedOpenTarget.first,
    List<int> pageStartBlocks = const [],
    List<String> blockTexts = const [],
  }) {
    if (_disposed) return;

    _updating = true;
    if (_pages.isNotEmpty) {
      _exitingBlocks = _pages[_currentPage.clamp(0, _pages.length - 1)];
    }
    final hasExit = _exitingBlocks != null;
    _transition.stop();
    _transition.value = 0;
    _slideDirection = target.lastPage ? -1 : 1;

    _usesExternalPages = true;
    _html = '';
    _blocks = const [];
    _blockKeys = const [];
    _blockTexts = blockTexts;
    _pages = pages;
    _pageStartBlocks = pageStartBlocks;
    _totalPages = pages.length;
    _measuredWidth = null;
    _measuredHeight = null;
    _measuring = false;
    _reflowing = false;
    _measureTimer?.cancel();
    _measureTimer = null;

    _target = target;
    _positioning = hasExit ||
        target.lastPage ||
        target.anchor != null ||
        (target.pageIndex ?? 0) > 0;

    if (_totalPages == 0) {
      _currentPage = 0;
      _positioning = false;
      _updating = false;
      _notify();
      return;
    }
    // 无旧页（首次打开）时从首页开始，避免沿用上一章遗留的页码
    if (!hasExit) _currentPage = 0;
    _updating = false;
    _finalizePosition();
  }

  /// 原地替换页列表（窗口尺寸变化后后台重排完成时使用）。
  ///
  /// 不播放过渡，按当前页起始块映射到新页列表中的对应页，保持阅读位置。
  void replacePages(
    List<List<String>> pages, {
    List<int> pageStartBlocks = const [],
    List<String> blockTexts = const [],
  }) {
    if (_disposed || pages.isEmpty) return;

    int? startBlock;
    if (_currentPage < _pageStartBlocks.length) {
      startBlock = _pageStartBlocks[_currentPage];
    }

    _usesExternalPages = true;
    _pages = pages;
    _pageStartBlocks = pageStartBlocks;
    if (blockTexts.isNotEmpty) _blockTexts = blockTexts;
    _totalPages = pages.length;

    var page = _currentPage;
    if (startBlock != null && pageStartBlocks.isNotEmpty) {
      page = pageIndexForBlock(pageStartBlocks, startBlock);
    }
    _currentPage = page.clamp(0, _totalPages - 1);
    _notify();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !_pageController.hasClients) return;
      if (_pageController.page?.round() != _currentPage) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  /// 更新全书页码信息（页码前缀未知时传 null）
  void updateBookPaging({int? pageStart, required int totalPages}) {
    if (_disposed) return;
    final info = BookPageInfo(
      pageStart: pageStart ?? -1,
      totalPages: totalPages,
    );
    if (bookPaging.value == info) return;
    bookPaging.value = info;
  }

  /// 视图布局上报：尺寸变化时通知父级（全书后台分页据此重排）
  ///
  /// 在 build 期间调用，回调延迟到帧末执行，避免在构建过程中触发布局/通知。
  void reportLayout(double width, double height) {
    if (_disposed) return;
    if (width == _reportedWidth && height == _reportedHeight) return;
    _reportedWidth = width;
    _reportedHeight = height;
    final callback = onLayout;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      callback(width, height);
    });
  }

  /// 内容不变时重新定位（同一章内从目录点击子章节 / 点击当前顶层章节回首页）。
  void retarget(PagedOpenTarget target) {
    if (_disposed) return;
    final page = _resolvePage(target);
    if (page == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !_pageController.hasClients) return;
      _pageController.jumpToPage(page);
    });
    // 通知视图重建以确保下一帧存在（addPostFrameCallback 本身不调度帧，
    // 若此时恰好没有待绘制帧，回调将不会执行，定位就失效）
    _notify();
  }

  /// 唯一翻页入口：点击区域、键盘、滚轮、滑动越界、翻章都走这里。
  ///
  /// 章内翻页与跨章是同一个动作的两种结果：页列表还有相邻页就翻页，
  /// 已到章节边界则交给 [onBoundary] 打开相邻章节（章节只是页序列的分段）。
  void turnPage(int delta) {
    if (delta == 0 || _disposed) return;
    // 定位中 / 过渡中不接受输入，避免作用于隐藏中的新页
    if (_positioning || _exitingBlocks != null) return;
    if (_totalPages == 0) return;

    if (delta > 0) {
      if (_currentPage < _totalPages - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        onBoundary?.call(1);
      }
    } else {
      if (_currentPage > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        onBoundary?.call(-1);
      }
    }
  }

  /// PageView 的页码变化回调（用户滑动/程序翻页）
  void onPageViewPageChanged(int index) {
    if (_disposed || _positioning || index == _currentPage) return;
    _currentPage = index;
    _notify();
  }

  /// 视图布局回调：尺寸变化时重新测量分页。
  ///
  /// 视图只在「没有本轮尺寸的测量结果」时调用（首次打开、窗口尺寸变化），
  /// 后续的图片解码重测由控制器内部定时器驱动，无需视图参与。
  void layout(double width, double height) {
    if (_disposed) return;
    // 页列表来自外部时不做测量：否则会用空块列表算出单页，覆盖后台分页结果
    if (_usesExternalPages) return;
    if (width == _measuredWidth &&
        height == _measuredHeight &&
        _totalPages > 0) {
      return;
    }
    _stableCount = 0;
    _measureRounds = 0;
    _lastHeights = const [];
    _measuring = true;
    _measureAndPaginate(width, height);
  }

  /// 读取离屏测量列中各块高度并累积分页，高度稳定后定位目标页。
  ///
  /// 图片异步解码会让块高度随时间增长，因此高度仍在变化时用 120ms 定时器
  /// 重测，直到连续两次不变（或达到轮次上限）才认为稳定。
  void _measureAndPaginate(double width, double height) {
    if (_disposed || !_measuring) return;

    // 图片独立页固定占 1 页（与图片像素尺寸无关），不做测量
    if (isImagePageBlocks(_blocks)) {
      _applyPages(imagePageResult(_blocks));
      _measuredWidth = width;
      _measuredHeight = height;
      _currentPage = 0;
      _notify();
      _measureTimer?.cancel();
      _measureTimer = null;
      _finalizePosition();
      return;
    }

    final heights = <double>[];
    for (final key in _blockKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      heights.add(box == null ? 0.0 : box.size.height);
    }

    final changed = !heightsEqual(heights, _lastHeights);
    _lastHeights = heights;

    _applyPages(paginateBlocks(
      _blocks,
      heights,
      blockSpacing,
      height,
      blockTexts: _blockTexts,
    ));
    _measuredWidth = width;
    _measuredHeight = height;
    if (_currentPage >= _totalPages) _currentPage = _totalPages - 1;
    _notify();

    if (changed) {
      _stableCount = 0;
    } else {
      _stableCount++;
    }
    _measureRounds++;

    if (_stableCount < 2 && _measureRounds < 40) {
      // 图片异步解码会让块高度继续增长，稍后再量一轮
      _measureTimer?.cancel();
      _measureTimer = Timer(const Duration(milliseconds: 120), () {
        _measureAndPaginate(width, height);
      });
      return;
    }

    _measureTimer?.cancel();
    _measureTimer = null;
    _finalizePosition();
  }

  void _applyPages(PaginatedBlocks result) {
    _pages = result.pages;
    _pageStartBlocks = result.pageStartBlocks;
    _totalPages = result.pages.length;
  }

  /// 分页稳定后定位目标页。
  ///
  /// - 初次打开到首页：无需跳转，直接显示；
  /// - 仅尺寸变化重排：保持当前页，不显示定位遮罩；
  /// - 其余情况（换章 / 指定页 / 锚点 / 末页）：先在隐藏状态下跳转，再显示并播放过渡。
  void _finalizePosition() {
    final target = _target;
    final hasExit = _exitingBlocks != null;

    _target = null;
    _measuring = false;

    if (_totalPages <= 0) {
      _currentPage = 0;
      _positioning = false;
      _notify();
      return;
    }

    final page = (target == null ? _currentPage : (_resolvePage(target) ?? 0))
        .clamp(0, _totalPages - 1);

    // 排版重排：旧页快照遮盖测量期，定位完成后直接显示新页，不播放滑动过渡
    if (_reflowing) {
      _currentPage = page;
      _positioning = true;
      _notify();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        if (_pageController.hasClients) _pageController.jumpToPage(page);
        _positioning = false;
        _reflowing = false;
        _exitingBlocks = null;
        _notify();
      });
      return;
    }

    final openAtFirst = target != null &&
        !hasExit &&
        !target.lastPage &&
        target.anchor == null &&
        (target.pageIndex ?? 0) == 0;

    if (openAtFirst) {
      // 首次打开到首页：分页结果已可直接显示（页码保持测量期间用户翻到的位置）
      _positioning = false;
      _notify();
      return;
    }

    if (target == null && !_positioning) {
      // 仅尺寸变化重排：保持当前页，不显示定位遮罩
      _currentPage = page;
      _notify();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !_pageController.hasClients) return;
        _pageController.jumpToPage(page);
      });
      return;
    }

    _currentPage = page;
    _positioning = true;
    _notify();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (_pageController.hasClients) _pageController.jumpToPage(page);
      _positioning = false;
      _notify();
      if (hasExit) _transition.forward(from: 0);
    });
  }

  /// 目标 -> 页码；无页列表时返回 null
  int? _resolvePage(PagedOpenTarget target) {
    if (_pages.isEmpty) return null;
    final last = _totalPages - 1;
    if (target.lastPage) return last;
    if (target.anchor != null) {
      final anchorPage = _pageForAnchor(target.anchor);
      return (anchorPage ?? target.pageIndex ?? 0).clamp(0, last);
    }
    return (target.pageIndex ?? 0).clamp(0, last);
  }

  /// 找到标题所在页：块文本与标题一致（忽略空白）优先，其次包含
  int? _pageForAnchor(String? anchor) {
    if (anchor == null) return null;
    final key = normalizeText(anchor);
    if (key.isEmpty) return null;

    var blockIndex = -1;
    for (var i = 0; i < _blockTexts.length; i++) {
      if (normalizeText(_blockTexts[i]) == key) {
        blockIndex = i;
        break;
      }
    }
    if (blockIndex < 0) {
      for (var i = 0; i < _blockTexts.length; i++) {
        if (_blockTexts[i].contains(anchor)) {
          blockIndex = i;
          break;
        }
      }
    }
    if (blockIndex < 0) return null;

    return pageIndexForBlock(_pageStartBlocks, blockIndex);
  }

  void _prepareBlocks() {
    final blocks = buildHtmlBlocks(_html);

    _blocks = blocks;
    _blockKeys = List<GlobalKey>.generate(blocks.length, (_) => GlobalKey());
    _blockTexts = blocks.map(plainTextOf).toList();

    _pages = [];
    _pageStartBlocks = [];
    _totalPages = 0;
    _currentPage = 0;
    _measuredWidth = null;
    _measuredHeight = null;
  }

  void _onTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // 过渡结束：以 PageView 的实际页码校正控制器记录，避免任何重建导致的页码漂移
    if (_pageController.hasClients) {
      final page = _pageController.page?.round();
      if (page != null && page != _currentPage) _currentPage = page;
    }
    if (_exitingBlocks != null) _exitingBlocks = null;
    _notify();
  }

  void _notify() {
    if (!_disposed && !_updating) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _measureTimer?.cancel();
    _measureTimer = null;
    bookPaging.dispose();
    _transition.removeListener(_notify);
    _transition.removeStatusListener(_onTransitionStatus);
    _transitionCurve.dispose();
    _transition.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
