import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import 'html_pagination.dart';
import 'paged_reader_controller.dart';
import 'svg_widget_factory.dart';

/// 分页阅读视图（HTML 版）。
///
/// 只负责渲染与输入：页列表、当前页、目标位置、章节内容与过渡动画都由
/// [PagedReaderController] 持有。视图做三件事：
/// 1. 渲染当前页列表（PageView）与过渡中滑出的旧页；
/// 2. 渲染离屏测量列，并在布局尺寸变化时通知控制器重新测量；
/// 3. 把点击左右区域/键盘/滚轮/滑动越界统一转成 [PagedReaderController.turnPage]。
///
/// 已知限制：单块高度超过一页时（如超大图片/超长表格）会独占一页并可能溢出被裁剪。
class PagedReadingView extends StatefulWidget {
  final PagedReaderController controller;

  const PagedReadingView({
    super.key,
    required this.controller,
  });

  @override
  State<PagedReadingView> createState() => _PagedReadingViewState();
}

class _PagedReadingViewState extends State<PagedReadingView>
    with AutomaticKeepAliveClientMixin {
  /// 鼠标滚轮翻页的最小间隔：一次手势会产生连续多个信号，需节流
  static const _wheelInterval = Duration(milliseconds: 180);

  /// 滑动越界判定阈值：越过章节边界超过该像素才翻章，避免回弹抖动误触发
  static const _boundaryThreshold = 12.0;

  DateTime? _lastWheelAt;

  /// 是否已安排本轮布局测量，避免同一帧内重复调度
  bool _layoutScheduled = false;

  /// 本次手势是否还可触发跨章（触发一次后置 false，新手势重新置 true）
  bool _boundaryArmed = true;

  /// 本次手势累计的越界距离。
  ///
  /// [ClampingScrollPhysics] 下页面不会随越界位移（这正是消除「切章瞬间跳回原位」
  /// 的关键），因此不能再像 Bouncing 那样看 pixels 是否越界，只能累计越界量：
  /// 超过阈值才认为用户确实要把页面推出边界，避免轻微抖动就翻章。
  double _overscrollAccum = 0;

  /// 按下位置与指针 id，用于判定一次点击（而非拖动）
  Offset? _tapDownPosition;
  int? _tapPointer;

  PagedReaderController get _controller => widget.controller;

  /// Tab 切换时保活，避免重新测量导致原 Tab 回来时闪动
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 视图重建（如 Tab 切回）后 PageView 会从第 0 页重新附着，
    // 首帧后跳回控制器记录的当前页
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pageController = _controller.pageController;
      if (!pageController.hasClients) return;
      if (pageController.page?.round() != _controller.currentPage) {
        pageController.jumpToPage(_controller.currentPage);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // AutomaticKeepAliveClientMixin 要求先调用父类 build
    super.build(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Listener(
          onPointerSignal: _onPointerSignal,
          child: Focus(
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
                return _buildStack(width, height, hPad, vPad);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStack(double width, double height, double hPad, double vPad) {
    // 把可用宽高上报给控制器（其 onLayout 会通知全书后台分页重排）
    _controller.reportLayout(width, height);

    // 页列表由后台分页直接提供时不再测量：否则空块列表会算出单页并覆盖结果
    final needsMeasure = !_controller.usesExternalPages &&
        (_controller.measuredWidth != width ||
            _controller.measuredHeight != height);
    if (needsMeasure) _scheduleLayout(width, height);

    final exiting = _controller.exitingBlocks;
    final sliding = exiting != null;

    Widget? currentLayer;
    if (_controller.pages.isNotEmpty) {
      // 关键：无论是否处于过渡，都要保留同一层级的 SlideTransition。
      // 若按「过渡中有/无」增删 SlideTransition，PageView 会在树中换位置而被
      // 重新创建，滚动位置回到第 0 页——表现为跨章滑动结束后突然跳回第一页，
      // 且控制器记录的页码与实际显示不一致，后续翻页随之跳错章。
      final position = sliding
          ? Tween<Offset>(
              begin: Offset(_controller.slideDirection.toDouble(), 0),
              end: Offset.zero,
            ).animate(_controller.transitionAnimation)
          : const AlwaysStoppedAnimation<Offset>(Offset.zero);
      currentLayer = Opacity(
        opacity: _controller.isPositioning ? 0.0 : 1.0,
        child: SlideTransition(
          position: position,
          child: _buildPageView(hPad, vPad),
        ),
      );
    }

    // 测量期间（含图片异步解码重测）也保留测量列，直到高度稳定
    final showMeasure = needsMeasure || _controller.isMeasuring;

    return Stack(
      children: [
        if (currentLayer != null) currentLayer,
        // 旧页快照：向相反方向滑出（不拦截点击）。
        // 不铺不透明底色：过渡时旧页与新页恰好相邻铺满屏幕，铺底色反而会露出
        // 与阅读区不同的颜色（白页闪过）。
        if (exiting != null)
          Positioned.fill(
            child: IgnorePointer(
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(-_controller.slideDirection.toDouble(), 0),
                ).animate(_controller.transitionAnimation),
                child: _buildPageContent(exiting, hPad, vPad),
              ),
            ),
          ),
        if (showMeasure && _controller.blocks.isNotEmpty)
          Positioned(
            left: -100000,
            top: 0,
            child: SizedBox(
              width: width,
              child: HtmlMeasureColumn(
                blocks: _controller.blocks,
                keys: _controller.blockKeys,
                textStyle: _controller.textStyle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPageView(double hPad, double vPad) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: LayoutBuilder(
            // 用原始指针事件判定「点击左右 1/3 翻页」，而不是 GestureDetector：
            // HTML 里的 <a> 会被 fwfh 包上 GestureDetector，在手势竞技场中抢走点击，
            // 导致目录、版权等含链接的页面点左右区域毫无反应（翻不动页）。
            builder: (context, constraints) => Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerUp: (event) => _onPointerUp(event, constraints.maxWidth),
              onPointerCancel: (_) {
                _tapDownPosition = null;
                _tapPointer = null;
              },
              child: PageView.builder(
                controller: _controller.pageController,
                // 用 Clamping 而非 Bouncing：越界时页面停在原处（不随拖动位移），
                // 跨章切换瞬间旧页快照与页面位置完全一致，不会出现「首页先被拖开
                // 再跳回原位」的跳动；越界由 OverscrollNotification 判定。
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: _controller.totalPages,
                onPageChanged: _controller.onPageViewPageChanged,
                itemBuilder: (context, i) =>
                    _buildPageContent(_controller.pages[i], hPad, vPad),
              ),
            ),
          ),
        ),
        // 底部页码指示（不拦截点击）
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: IgnorePointer(
            child: Center(child: _PageIndicator(controller: _controller)),
          ),
        ),
      ],
    );
  }

  /// 构建单页内容（分页渲染与跨章滑动的旧页快照共用，保证两者版式一致）
  Widget _buildPageContent(List<String> blocks, double hPad, double vPad) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
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
                textStyle: _controller.textStyle,
                factoryBuilder: () => SvgAwareWidgetFactory(),
                onErrorBuilder: htmlErrorBuilder,
              ),
              if (i < blocks.length - 1)
                SizedBox(height: _controller.blockSpacing),
            ],
          ],
        ),
      ),
    );
  }

  /// 记录按下位置，供 [Listener.onPointerUp] 判定是否为点击
  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    _tapDownPosition = event.localPosition;
    _tapPointer = event.pointer;
  }

  /// 指针抬起：位移小于触摸阈值视为点击，按左右 1/3 区域翻页
  void _onPointerUp(PointerUpEvent event, double width) {
    final down = _tapDownPosition;
    final pointer = _tapPointer;
    _tapDownPosition = null;
    _tapPointer = null;
    if (down == null || pointer != event.pointer) return;
    if ((event.localPosition - down).distance > kTouchSlop) return;

    final dx = event.localPosition.dx;
    if (dx < width / 3) {
      _controller.turnPage(-1);
    } else if (dx > width * 2 / 3) {
      _controller.turnPage(1);
    }
  }

  /// 通知控制器按当前布局尺寸重新测量分页（控制器负责读取块高度与重测）
  void _scheduleLayout(double width, double height) {
    if (_layoutScheduled) return;
    _layoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutScheduled = false;
      if (!mounted) return;
      _controller.layout(width, height);
    });
  }

  /// 处理 PageView 滚动通知：在章节首页/末页继续滑动时翻章。
  ///
  /// 当前 PageView 使用 [ClampingScrollPhysics]：越界时页面不位移，只产生
  /// [OverscrollNotification]（负值 = 越过开头，正值 = 越过末尾），累计超过
  /// [_boundaryThreshold] 才翻章。同时保留 [ScrollUpdateNotification] 的 pixels
  /// 越界判断，兼容 Bouncing 物理平台（越界时 pixels 会越出范围且无 overscroll 通知）。
  ///
  /// 方向约定：越过开头 → 上一章（-1），越过末尾 → 下一章（+1）。
  /// 用 [_boundaryArmed] 保证一次手势只翻一次章。
  bool _onScrollNotification(ScrollNotification notification) {
    if (_controller.isPositioning) return false;

    if (notification is ScrollStartNotification ||
        (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle)) {
      _boundaryArmed = true;
      _overscrollAccum = 0;
    }

    var delta = 0;
    if (notification is OverscrollNotification) {
      _overscrollAccum += notification.overscroll;
      if (_overscrollAccum < -_boundaryThreshold) {
        delta = -1;
      } else if (_overscrollAccum > _boundaryThreshold) {
        delta = 1;
      }
    } else if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      if (metrics.pixels < metrics.minScrollExtent - _boundaryThreshold) {
        delta = -1;
      } else if (metrics.pixels >
          metrics.maxScrollExtent + _boundaryThreshold) {
        delta = 1;
      }
    }

    if (delta != 0 && _boundaryArmed) {
      _boundaryArmed = false;
      _controller.turnPage(delta);
    }
    return false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _controller.turnPage(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _controller.turnPage(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 鼠标滚轮翻页：向下滚到下一页，向上滚到上一页（到边界时翻章）
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;

    final now = DateTime.now();
    final last = _lastWheelAt;
    if (last != null && now.difference(last) < _wheelInterval) return;
    _lastWheelAt = now;

    _controller.turnPage(dy > 0 ? 1 : -1);
  }
}

/// 底部页码指示
///
/// 全书页码信息就绪时显示全书页码（本章之前累计页数 + 页内偏移 / 全书总页数），
/// 否则回退为章节内页码。单独抽成 widget 并只监听页码信息，
/// 避免后台分页进度刷新时重建整个阅读视图（图片重新解码会造成闪动）。
class _PageIndicator extends StatelessWidget {
  final PagedReaderController controller;

  const _PageIndicator({required this.controller});

  /// 底部页码相对正文字号的比例（随阅读字号设置缩放）
  static const double _pageLabelScale = 0.57;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.bookPaging]),
      builder: (context, _) {
        final info = controller.bookPaging.value;
        final int page;
        final int total;
        if (info.isReady) {
          page = info.pageStart + controller.currentPage + 1;
          total = info.totalPages;
        } else {
          page = controller.currentPage + 1;
          total = controller.totalPages;
        }
        if (total <= 0) return const SizedBox.shrink();
        // 相对正文字号，随阅读字号设置一起缩放；颜色跟随主题，深色模式自动变浅
        final baseFontSize = controller.textStyle.fontSize;
        return Text(
          '$page / $total',
          style: TextStyle(
            fontSize:
                baseFontSize == null ? null : baseFontSize * _pageLabelScale,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
