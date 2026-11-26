import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'svg_widget_factory.dart';

/// 分页阅读视图（HTML 版）
///
/// 将 HTML 内容按块级元素切分，测量各块高度后累积分页，每一页仍用 [HtmlWidget]
/// 渲染，从而在保留分页阅读体验的同时保留 EPUB 排版（加粗/斜体/标题/图片/列表等）。
///
/// [controller] 由父级持有，父级可通过其翻页，也可经 [onPageChanged] 感知当前页/总页数，
/// 从而在到达章节边界时改为主导航（上一章/下一章）。
///
/// 已知限制：单块高度超过一页时（如超大图片/超长表格）会独占一页并可能溢出被裁剪。
class PagedReadingView extends StatefulWidget {
  final String html;
  final TextStyle textStyle;
  final PageController controller;
  final void Function(int page, int totalPages)? onPageChanged;

  /// 内容切换后是否定位到最后一页（用于从下一章翻回上一章时落在其末页）。
  final bool startAtLastPage;

  /// 在当前章节首页再向前翻页时触发（用于跨章到上一章末页）。
  final VoidCallback? onPrevChapter;

  /// 在当前章节末页再向后翻页时触发（用于跨章到下一章）。
  final VoidCallback? onNextChapter;

  /// 初始定位锚点（子章节标题）：内容渲染后定位到该标题所在页
  final String? initialAnchor;

  /// 定位请求序号：内容不变时递增也会触发按 [initialAnchor] 重新定位
  /// （用于同一章节内从目录点击子章节）
  final int positionToken;

  /// 初次渲染时直接定位到的页码（0 起，null 表示首页），用于恢复上次阅读位置
  final int? initialPageIndex;

  const PagedReadingView({
    super.key,
    required this.html,
    required this.textStyle,
    required this.controller,
    this.onPageChanged,
    this.startAtLastPage = false,
    this.onPrevChapter,
    this.onNextChapter,
    this.initialAnchor,
    this.positionToken = 0,
    this.initialPageIndex,
  });

  @override
  State<PagedReadingView> createState() => _PagedReadingViewState();
}

class _PagedReadingViewState extends State<PagedReadingView>
    with AutomaticKeepAliveClientMixin {
  int _currentPage = 0;
  int _totalPages = 1;

  // 上次已通知父级的页码/总页数，避免重复通知（防止父级无条件 setState 引发重建循环）
  int _lastNotifiedPage = -1;
  int _lastNotifiedTotal = -1;

  // 块级元素 HTML 列表（已含 body 级包裹样式）
  List<String> _blocks = [];

  // 每个块的纯文本（去标签、去空白），用于按标题定位子章节起始页
  List<String> _blockTexts = [];

  // 每页起始块的下标（与 _pages 等长），用于把块下标映射到页码
  List<int> _pageStartBlocks = [];

  // 待定位的子章节标题（内容切换时由 initialAnchor 写入，定位后清空）
  String? _anchorTitle;

  // 每个块的测量用 GlobalKey
  final List<GlobalKey> _blockKeys = [];

  // 分页结果：每页为块 HTML 列表（渲染结构与测量完全一致，避免分页溢出）
  List<List<String>> _pages = [];
  double? _measuredWidth;
  double? _measuredHeight;

  // 上次测量的各块高度（用于检测图片异步解码导致的高度变化）
  List<double> _lastHeights = [];

  // 是否仍在测量：图片解码期间块高度会变化，需反复重测直到稳定
  bool _measuring = true;

  // 连续稳定次数（连续两次高度不变即认为稳定，停止测量）
  int _stableCount = 0;

  // 重测轮次上限，防止异常情况下无限重测
  int _measureRounds = 0;

  // 重测定时器
  Timer? _measureTimer;

  // 分页稳定后是否需定位到最后一页（内容切换时由 startAtLastPage 触发）
  bool _jumpToLastPending = false;

  // 切章后 PageView 是否隐藏：定位到目标页（首页/末页）前隐藏，避免 controller
  // 遗留的旧页号先渲染一帧造成闪烁。定位完成后置回 false 显示。
  bool _pageViewHidden = false;

  // 是否已在本轮滑动中触发跨章（防止 overscroll 连续通知重复触发跨章）
  bool _crossChapterTriggered = false;

  /// 待定位页码：内容切换时从 [initialPageIndex] 固化到 State。
  ///
  /// 必须固化而不能在定位时读 `widget.initialPageIndex`：父级在首帧后会把该参数
  /// 重置（清空一次性页码 / 改传当前页 0），延迟读取会拿到 0 而定位到首页。
  int? _pendingPageIndex;

  PageController get _controller => widget.controller;

  /// 分页结果在 Tab 切换时保活：
  /// 否则切到缩写/译文/目录再切回原文，本 State 会被销毁重建，
  /// 当前页归零（并经 onPageChanged 把父级记录的页码覆盖为 0）。
  @override
  bool get wantKeepAlive => true;

  // 块与块之间的间距（段落/标题等块级元素之间），以相对字体大小的 em 表示。
  // fwfh 会剥离 HtmlWidget 根元素的上下外边距，故这里显式插入间距。
  double get _blockSpacing => (widget.textStyle.fontSize ?? 16) * 0.8;

  @override
  void initState() {
    super.initState();
    _prepareBlocks();
    // 带锚点/指定页码打开时先隐藏 PageView，等分页稳定、定位到目标页后再显示，避免闪烁
    _anchorTitle = widget.initialAnchor;
    _pendingPageIndex = widget.initialPageIndex;
    _pageViewHidden =
        _anchorTitle != null || (_pendingPageIndex ?? 0) > 0;
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    _measureTimer = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(PagedReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final htmlChanged = oldWidget.html != widget.html;
    final tokenChanged = oldWidget.positionToken != widget.positionToken;
    if (!htmlChanged && !tokenChanged) return;

    if (htmlChanged) {
      _prepareBlocks();
      // 隐藏 PageView 直至定位到目标页：此时 controller 仍保留上一章的页号，
      // 若直接渲染一帧会先显示错误页（上一章遗留页），再跳目标页即产生闪烁。
      _pageViewHidden = true;
      _jumpToLastPending = widget.startAtLastPage;
      _anchorTitle = widget.initialAnchor;
      _pendingPageIndex = widget.initialPageIndex;
      _crossChapterTriggered = false;
      return;
    }

    // 内容未变、仅请求重新定位（同一章内从目录点击）：分页已就绪，直接跳转。
    // 无锚点（点击当前顶层章节）时回到该章首页。
    final target = widget.initialAnchor == null
        ? 0
        : _pageForAnchor(widget.initialAnchor);
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpToPage(target);
    });
  }

  void _prepareBlocks() {
    final frag = html_parser.parseFragment(widget.html);
    var nodes = _nonBlankNodes(frag.nodes);

    // 单个仅含 style 的 div 包裹（EpubCssEngine 保留的 body 级样式）：解包，样式单独记录
    String? wrapStyle;
    if (nodes.length == 1 && nodes.first is dom.Element) {
      final el = nodes.first as dom.Element;
      if (el.localName == 'div' &&
          el.attributes.keys.every((k) => k == 'style')) {
        wrapStyle = el.attributes['style'];
        nodes = _nonBlankNodes(el.nodes);
      }
    }

    _blocks = [];
    for (final node in _flattenBlocks(nodes)) {
      final String s;
      if (node is dom.Element) {
        s = node.outerHtml;
      } else if (node is dom.Text) {
        s = node.data;
      } else {
        continue; // 注释等跳过
      }
      if (s.trim().isEmpty) continue;
      // body 级样式作为包裹层应用到每个块，保证测量与渲染一致
      _blocks.add(
        wrapStyle != null && wrapStyle.isNotEmpty
            ? '<div style="$wrapStyle">$s</div>'
            : s,
      );
    }

    _blockKeys.clear();
    for (var i = 0; i < _blocks.length; i++) {
      _blockKeys.add(GlobalKey());
    }
    _blockTexts = _blocks.map(_plainTextOf).toList();

    _pages = [];
    _pageStartBlocks = [];
    _measuredWidth = null;
    _measuredHeight = null;
    _lastHeights = [];
    _measuring = true;
    _stableCount = 0;
    _measureRounds = 0;
    _measureTimer?.cancel();
    _measureTimer = null;
    _currentPage = 0;
    _totalPages = 1;
    _lastNotifiedPage = -1;
    _lastNotifiedTotal = -1;
  }

  List<dom.Node> _nonBlankNodes(List<dom.Node> nodes) {
    return nodes
        .where((n) => n is! dom.Text || n.data.trim().isNotEmpty)
        .toList();
  }

  /// 提取块 HTML 的纯文本（去标签、解常见实体、折叠空白）
  String _plainTextOf(String html) {
    var text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 归一化文本：去掉所有空白（含全角空格与不换行空格），用于标题比对
  String _normalizeText(String text) {
    return text.replaceAll(RegExp(r'[\s\u00A0\u3000]+'), '');
  }

  /// 递归展开容器元素，让段落、标题等叶子块级元素成为独立块。
  ///
  /// 正文常把多个段落包在 `<div>` 里（如 calibre 转换出的 `<div class="calibre1">`
  /// 内含多个 `<p>`）。若把整个 div 当作一个块，则块间距只会落在 div 之间，
  /// 而 div 内部的段落因 CSS `margin:0` 会挤在一起。展开后每个段落各成一块，
  /// 块间距即可作用到段落之间。
  List<dom.Node> _flattenBlocks(List<dom.Node> nodes) {
    final result = <dom.Node>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        if (node.data.trim().isNotEmpty) result.add(node);
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        // 容器（div/section/article）若含块级子元素则展开，否则（如仅含图片/文本）整体作为一块
        if (_isContainerTag(tag) && _hasBlockChild(node)) {
          result.addAll(_flattenBlocks(node.nodes));
        } else {
          result.add(node);
        }
      }
    }
    return result;
  }

  bool _isContainerTag(String tag) =>
      tag == 'div' || tag == 'section' || tag == 'article' || tag == 'main';

  bool _hasBlockChild(dom.Element el) {
    for (final child in el.nodes) {
      if (child is dom.Element &&
          _isBlockTag(child.localName?.toLowerCase() ?? '')) {
        return true;
      }
    }
    return false;
  }

  bool _isBlockTag(String tag) {
    const blocks = {
      'p', 'div', 'section', 'article', 'blockquote', 'pre',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'ul', 'ol', 'li', 'table', 'figure', 'hr',
    };
    return blocks.contains(tag);
  }

  void _notify() {
    if (_currentPage == _lastNotifiedPage && _totalPages == _lastNotifiedTotal) {
      return;
    }
    _lastNotifiedPage = _currentPage;
    _lastNotifiedTotal = _totalPages;
    widget.onPageChanged?.call(_currentPage, _totalPages);
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      // 已在章节首页：交由父级跨章到上一章末页
      widget.onPrevChapter?.call();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      // 已在章节末页：交由父级跨章到下一章
      widget.onNextChapter?.call();
    }
  }

  /// 处理 PageView 滚动通知：在章节末页/首页继续滑动（overscroll）时触发跨章。
  ///
  /// 用 _crossChapterTriggered 保证一次滑动只触发一次跨章，避免 overscroll
  /// 连续通知重复调用；每次重新开始拖动（UserScrollNotification）时重置。
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _crossChapterTriggered = false;
    }
    if (notification is OverscrollNotification && !_crossChapterTriggered) {
      if (notification.overscroll < 0) {
        // 末页继续向后滑：跨章到下一章
        _crossChapterTriggered = true;
        widget.onNextChapter?.call();
      } else if (notification.overscroll > 0) {
        // 首页继续向前滑：跨章到上一章末页
        _crossChapterTriggered = true;
        widget.onPrevChapter?.call();
      }
    }
    return false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _prevPage();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _nextPage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // AutomaticKeepAliveClientMixin 要求先调用父类 build
    super.build(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const hPad = 24.0;
          const vPad = 20.0;
          final width = constraints.maxWidth - hPad * 2;
          final height = constraints.maxHeight - vPad * 2;
          if (width <= 0 || height <= 0) {
            return const SizedBox.shrink();
          }

          final needsMeasure = _pages.isEmpty ||
              width != _measuredWidth ||
              height != _measuredHeight;
          // 测量期间（含图片异步解码重测）也保留测量列，直到高度稳定
          final showMeasure = needsMeasure || _measuring;
          if (needsMeasure) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _measureAndPaginate(width, height),
            );
          }

          return Stack(
            children: [
              if (_pages.isNotEmpty)
                Opacity(
                  opacity: _pageViewHidden ? 0.0 : 1.0,
                  child: _buildPageView(constraints.maxWidth, hPad, vPad),
                ),
              if (showMeasure)
                Positioned(
                  left: -100000,
                  top: 0,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _blocks.length; i++)
                          KeyedSubtree(
                            key: _blockKeys[i],
                            child: HtmlWidget(
                              _blocks[i],
                              textStyle: widget.textStyle,
                              factoryBuilder: () => SvgAwareWidgetFactory(),
                              onErrorBuilder: htmlErrorBuilder,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageView(double maxWidth, double hPad, double vPad) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (details.localPosition.dx < maxWidth / 3) {
                _prevPage();
              } else if (details.localPosition.dx > maxWidth * 2 / 3) {
                _nextPage();
              }
            },
            child: PageView.builder(
              controller: _controller,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _totalPages,
              onPageChanged: (i) {
                setState(() => _currentPage = i);
                _notify();
              },
              itemBuilder: (context, i) {
                final blocks = _pages[i];
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: vPad,
                  ),
                  child: SingleChildScrollView(
                    // 单块（如超大图片）超过一页高度时裁剪超出部分，而非出现溢出条纹
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < blocks.length; i++) ...[
                          HtmlWidget(
                            blocks[i],
                            textStyle: widget.textStyle,
                            factoryBuilder: () => SvgAwareWidgetFactory(),
                            onErrorBuilder: htmlErrorBuilder,
                          ),
                          if (i < blocks.length - 1)
                            SizedBox(height: _blockSpacing),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // 底部页码指示（不拦截点击）
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: IgnorePointer(
            child: Center(
              child: Text(
                '${_currentPage + 1} / $_totalPages',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _measureAndPaginate(double width, double height) {
    final heights = <double>[];
    for (var i = 0; i < _blocks.length; i++) {
      final box = _blockKeys[i].currentContext?.findRenderObject() as RenderBox?;
      heights.add(box == null ? 0.0 : box.size.height);
    }

    // 图片异步解码会让块高度随时间增长；高度变化时需重测，稳定后才停止。
    final changed = !_heightsEqual(heights, _lastHeights);
    _lastHeights = heights;

    final pages = <List<String>>[];
    final pageStarts = <int>[];
    var current = <String>[];
    var currentStart = 0;
    var currentHeight = 0.0;
    final gap = _blockSpacing;
    for (var i = 0; i < _blocks.length; i++) {
      final h = heights[i];
      // 与上一块同页时的间距（每页第一块无前导间距）
      final sep = current.isEmpty ? 0.0 : gap;
      if (current.isNotEmpty && currentHeight + sep + h > height) {
        pages.add(current);
        pageStarts.add(currentStart);
        current = <String>[];
        currentHeight = 0.0;
        currentStart = i;
        current.add(_blocks[i]);
        currentHeight = h;
      } else {
        if (current.isEmpty) currentStart = i;
        currentHeight += sep;
        current.add(_blocks[i]);
        currentHeight += h;
      }
    }
    if (current.isNotEmpty) {
      pages.add(current);
      pageStarts.add(currentStart);
    }
    if (pages.isEmpty) {
      pages.add(const <String>[]);
      pageStarts.add(0);
    }

    if (!mounted) return;
    setState(() {
      _pages = pages;
      _pageStartBlocks = pageStarts;
      _totalPages = pages.length;
      if (_currentPage >= _totalPages) _currentPage = _totalPages - 1;
      _measuredWidth = width;
      _measuredHeight = height;
    });
    _notify();

    if (changed) {
      _stableCount = 0;
    } else {
      _stableCount++;
    }

    _measureRounds++;
    if (_stableCount < 2 && _measureRounds < 40) {
      _measureTimer?.cancel();
      _measureTimer = Timer(const Duration(milliseconds: 120), () {
        if (mounted) _measureAndPaginate(width, height);
      });
    } else if (_measuring) {
      _measureTimer?.cancel();
      _measureTimer = null;
      // 分页已稳定（含图片异步解码完成、窗口尺寸稳定），此时才定位目标页并显示。
      // 若在稳定前就定位，后续总页数变化会让当前页变成“中间页”，产生视觉跳动。
      _finalizePosition();
      setState(() => _measuring = false);
    }
  }

  /// 分页稳定后，定位到目标页并显示 PageView。
  ///
  /// 切章后 PageView 一直以 Opacity(0) 隐藏；本方法在 post-frame（PageView 已 attach）
  /// 把控制器 jump 到目标页（翻上一章为末页，带锚点时为该标题所在页，
  /// 其余为首页），再清除隐藏标志。
  /// 跳转全程在不可见状态下完成，用户不会看到“先错误页、再跳目标页”的闪烁。
  void _finalizePosition() {
    if (!_pageViewHidden) return;
    final int target;
    if (_jumpToLastPending) {
      target = _totalPages - 1;
    } else if (_anchorTitle != null) {
      // 有锚点时优先按标题定位，找不到则回退到指定页码
      target = _pageForAnchor(_anchorTitle) ?? (_pendingPageIndex ?? 0);
    } else {
      target = _pendingPageIndex ?? 0;
    }
    _jumpToLastPending = false;
    _anchorTitle = null;
    _pendingPageIndex = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) {
        final last = _totalPages - 1;
        _controller.jumpToPage(target < 0 ? 0 : (target > last ? last : target));
      }
      if (_pageViewHidden) {
        setState(() => _pageViewHidden = false);
      }
    });
  }

  /// 找到标题所在页：块文本与标题一致（忽略空白）优先，其次包含
  int? _pageForAnchor(String? anchor) {
    if (anchor == null) return null;
    final key = _normalizeText(anchor);
    if (key.isEmpty) return null;

    var blockIndex = -1;
    for (var i = 0; i < _blockTexts.length; i++) {
      if (_normalizeText(_blockTexts[i]) == key) {
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

    var page = 0;
    for (var p = 0; p < _pageStartBlocks.length; p++) {
      if (_pageStartBlocks[p] <= blockIndex) {
        page = p;
      } else {
        break;
      }
    }
    return page;
  }

  bool _heightsEqual(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.5) return false;
    }
    return true;
  }
}
