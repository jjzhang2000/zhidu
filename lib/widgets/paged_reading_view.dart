import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 分页阅读视图
///
/// 将纯文本按可用宽高用 [TextPainter] 切分为若干页，用 [PageView] 承载。
/// 交互：左右滑动、点击左右 1/3 区域、键盘 ←/→ 翻页；底部居中显示页码。
///
/// 说明：纯文本分页会丢失图片/富文本，故仅作为可选的「分页模式」，
/// 默认仍走滚动模式（保留 HTML 渲染）。
class PagedReadingView extends StatefulWidget {
  final String text;
  final TextStyle textStyle;

  const PagedReadingView({
    super.key,
    required this.text,
    required this.textStyle,
  });

  @override
  State<PagedReadingView> createState() => _PagedReadingViewState();
}

class _PagedReadingViewState extends State<PagedReadingView> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  int _totalPages = 1;

  // 分页结果缓存，避免翻页时重复切分
  List<String> _pages = const [];
  String? _cacheText;
  double? _cacheWidth;
  double? _cacheHeight;

  @override
  void didUpdateWidget(PagedReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _pages = const [];
      _cacheText = null;
      _cacheWidth = null;
      _cacheHeight = null;
      _currentPage = 0;
      _totalPages = 1;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
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

          _pages = _computePages(widget.text, width, height);
          _totalPages = _pages.isEmpty ? 1 : _pages.length;
          if (_currentPage >= _totalPages) _currentPage = _totalPages - 1;

          return Stack(
            children: [
              // 点击左右 1/3 区域翻页
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final w = constraints.maxWidth;
                  if (details.localPosition.dx < w / 3) {
                    _prevPage();
                  } else if (details.localPosition.dx > w * 2 / 3) {
                    _nextPage();
                  }
                },
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _totalPages,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: hPad,
                        vertical: vPad,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          _pages[i],
                          style: widget.textStyle,
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    );
                  },
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _computePages(String text, double width, double height) {
    if (_cacheText == text && _cacheWidth == width && _cacheHeight == height) {
      return _pages;
    }
    _cacheText = text;
    _cacheWidth = width;
    _cacheHeight = height;
    _pages = _paginate(text, width, height);
    return _pages;
  }

  List<String> _paginate(String text, double width, double height) {
    if (text.isEmpty) return const [''];
    final pages = <String>[];
    var remaining = text;
    while (remaining.isNotEmpty) {
      final offset = _fitText(remaining, width, height);
      if (offset <= 0 || offset > remaining.length) break; // 防死循环
      pages.add(remaining.substring(0, offset));
      remaining = remaining.substring(offset);
    }
    return pages;
  }

  /// 返回能放入一页的字符数（按行边界截断，避免切半行）
  int _fitText(String text, double width, double height) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: widget.textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    )..layout(maxWidth: width);

    // 全文高度不超过一页时直接返回全文
    if (tp.height <= height) return text.length;

    final pos = tp.getPositionForOffset(Offset(width, height - 1));
    var offset = pos.offset;
    if (offset <= 0) offset = 1;
    if (offset >= text.length) return text.length;

    // 回退到该行行首，保证页尾是完整行
    final line = tp.getLineBoundary(TextPosition(offset: offset));
    if (line.start > 0) offset = line.start;
    return offset;
  }
}
