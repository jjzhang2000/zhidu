import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;

/// 渲染失败时的兜底：显示元素的纯文本，而非 fwfh 默认的 ❌ 占位。
///
/// EPUB 的 CSS 里可能存在无法被 fwfh 处理的非法值，导致某个块渲染失败。此回调
/// 让失败块降级为纯文本展示，避免整页出现红色大叉。
Widget? htmlErrorBuilder(
  BuildContext context,
  dom.Element element,
  dynamic error,
) {
  final text = element.text.trim();
  if (text.isNotEmpty) return Text(text);
  return const SizedBox.shrink();
}

/// 支持 SVG 图片的 [WidgetFactory]
///
/// Flutter 原生无法解码 SVG，EPUB 中内联为 `data:image/svg+xml` 的图片（封面、矢量
/// 插图等）会解码失败，触发 fwfh 默认的 ❌ 占位。此工厂拦截 SVG data URI，改用
/// flutter_svg 渲染，其余图片走 fwfh 默认逻辑。
class SvgAwareWidgetFactory extends WidgetFactory {
  @override
  Widget? buildImageWidget(BuildTree tree, ImageSource src) {
    final url = src.url;
    if (url.startsWith('data:image/svg+xml')) {
      final bytes = bytesFromDataUri(url);
      if (bytes != null) {
        return SvgPicture.memory(
          bytes,
          fit: BoxFit.fill,
        );
      }
    }
    return super.buildImageWidget(tree, src);
  }
}
