// HTML 分页公共逻辑
//
// 分页阅读（PagedReaderController）与全书后台分页（BookPaginator）共用同一套
// 「HTML → 块列表 → 按测量高度累积切页」的算法，保证两条通道得到完全一致的页码，
// 避免可视章节与后台预分页结果对不上（页码指示错位）。
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'svg_widget_factory.dart';

/// 一个章节的分页结果
class PaginatedBlocks {
  /// 每页为块 HTML 列表
  final List<List<String>> pages;

  /// 每页起始块的下标（与 [pages] 等长），用于按块反查页、按标题定位
  final List<int> pageStartBlocks;

  /// 每个块的纯文本（去标签、折叠空白）
  final List<String> blockTexts;

  const PaginatedBlocks({
    required this.pages,
    required this.pageStartBlocks,
    required this.blockTexts,
  });

  /// 总页数
  int get pageCount => pages.length;
}

/// 图片独立页标记：解析器为「目录图片项」生成的单图页会带此属性
const String kImagePageMarker = 'data-zhidu-image-page';

/// 是否为「图片独立页」：单个块且带 [kImagePageMarker] 标记
///
/// 图片页按「1 个图片条目 = 1 页」固定建模，与图片像素尺寸无关，
/// 因此无需测量块高度，直接认定为 1 页。
bool isImagePageBlocks(List<String> blocks) =>
    blocks.length == 1 && blocks.first.contains(kImagePageMarker);

/// 图片独立页的固定分页结果：恰好 1 页，内容为该图片块
PaginatedBlocks imagePageResult(List<String> blocks) => PaginatedBlocks(
      pages: [blocks],
      pageStartBlocks: const [0],
      blockTexts: const [''],
    );

/// 匹配行内样式里的 line-height 声明（含可选分号）
final RegExp _lineHeightDecl =
    RegExp("line-height\\s*:\\s*[^;\"']+\\s*;?", caseSensitive: false);

/// 去掉 HTML 中的 line-height 声明
///
/// 书籍 CSS 常把行高写死（如 `line-height:1.5`），会覆盖 HtmlWidget 的
/// `textStyle.height`，导致「行距」设置无效。统一剥离后行高由阅读设置控制。
String _stripLineHeight(String html) =>
    html.replaceAll(_lineHeightDecl, '');

/// 把章节 HTML 拆成块级元素列表（已应用 body 级包裹样式）
///
/// 正文常把多个段落包在 `<div>` 里（如 calibre 转换出的 `<div class="calibre1">`
/// 内含多个 `<p>`）。若把整个 div 当作一个块，块间距只会落在 div 之间，
/// 而 div 内部的段落因 CSS `margin:0` 会挤在一起。展开后每个段落各成一块。
List<String> buildHtmlBlocks(String html) {
  final frag = html_parser.parseFragment(html);
  var nodes = _nonBlankNodes(frag.nodes);

  // 单个仅含 style 的 div 包裹（EpubCssEngine 保留的 body 级样式）：解包，样式单独记录
  String? wrapStyle;
  if (nodes.length == 1 && nodes.first is dom.Element) {
    final el = nodes.first as dom.Element;
    if (el.localName == 'div' &&
        el.attributes.keys.every((k) => k == 'style')) {
      final rawWrap = el.attributes['style'];
      wrapStyle = rawWrap == null ? null : _stripLineHeight(rawWrap);
      nodes = _nonBlankNodes(el.nodes);
    }
  }

  final blocks = <String>[];
  for (final node in _flattenBlocks(nodes)) {
    final String s;
    if (node is dom.Element) {
      s = _stripLineHeight(node.outerHtml);
    } else if (node is dom.Text) {
      s = node.data;
    } else {
      continue; // 注释等跳过
    }
    if (s.trim().isEmpty) continue;
    // body 级样式作为包裹层应用到每个块，保证测量与渲染一致
    blocks.add(
      wrapStyle != null && wrapStyle.isNotEmpty
          ? '<div style="$wrapStyle">$s</div>'
          : s,
    );
  }
  return blocks;
}

/// 按块高度累积切页
///
/// [blockTexts] 可由调用方预计算并复用（测量会重复切页，避免每轮都重新提取）。
PaginatedBlocks paginateBlocks(
  List<String> blocks,
  List<double> heights,
  double spacing,
  double maxHeight, {
  List<String>? blockTexts,
}) {
  final pages = <List<String>>[];
  final pageStarts = <int>[];
  var current = <String>[];
  var currentStart = 0;
  var currentHeight = 0.0;

  for (var i = 0; i < blocks.length; i++) {
    final h = heights[i];
    // 与上一块同页时的间距（每页第一块无前导间距）
    final sep = current.isEmpty ? 0.0 : spacing;
    if (current.isNotEmpty && currentHeight + sep + h > maxHeight) {
      pages.add(current);
      pageStarts.add(currentStart);
      current = <String>[blocks[i]];
      currentHeight = h;
      currentStart = i;
    } else {
      if (current.isEmpty) currentStart = i;
      currentHeight += sep;
      current.add(blocks[i]);
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

  return PaginatedBlocks(
    pages: pages,
    pageStartBlocks: pageStarts,
    blockTexts: blockTexts ?? blocks.map(plainTextOf).toList(),
  );
}

/// 块下标落在第几页：最后一页起始块不大于该块的页
int pageIndexForBlock(List<int> pageStartBlocks, int blockIndex) {
  var page = 0;
  for (var p = 0; p < pageStartBlocks.length; p++) {
    if (pageStartBlocks[p] <= blockIndex) {
      page = p;
    } else {
      break;
    }
  }
  return page;
}

/// 高度序列是否稳定（单块误差 0.5px 内视为未变化）
bool heightsEqual(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 0.5) return false;
  }
  return true;
}

/// 提取块 HTML 的纯文本（去标签、解常见实体、折叠空白）
String plainTextOf(String html) {
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
String normalizeText(String text) {
  return text.replaceAll(RegExp(r'[\s\u00A0\u3000]+'), '');
}

/// 离屏测量列：按给定宽度铺排块，供分页读取各块高度
///
/// 分页阅读视图与全书后台分页共用，保证测量参数（样式、SVG 工厂、错误兜底）
/// 与真实渲染一致。
class HtmlMeasureColumn extends StatelessWidget {
  final List<String> blocks;
  final List<GlobalKey> keys;
  final TextStyle textStyle;

  const HtmlMeasureColumn({
    super.key,
    required this.blocks,
    required this.keys,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++)
          KeyedSubtree(
            key: keys[i],
            child: HtmlWidget(
              blocks[i],
              textStyle: textStyle,
              factoryBuilder: () => SvgAwareWidgetFactory(),
              onErrorBuilder: htmlErrorBuilder,
            ),
          ),
      ],
    );
  }
}

List<dom.Node> _nonBlankNodes(List<dom.Node> nodes) {
  return nodes
      .where((n) => n is! dom.Text || n.data.trim().isNotEmpty)
      .toList();
}

/// 递归展开容器元素，让段落、标题等叶子块级元素成为独立块。
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
  const blockTags = {
    'p',
    'div',
    'section',
    'article',
    'blockquote',
    'pre',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'ul',
    'ol',
    'li',
    'table',
    'figure',
    'hr',
  };
  return blockTags.contains(tag);
}
