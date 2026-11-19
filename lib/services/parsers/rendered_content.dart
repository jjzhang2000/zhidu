import 'dart:typed_data';

/// EPUB 内嵌字体（由 @font-face 提取，运行时通过 FontLoader 注册）
class EmbeddedFont {
  /// 字体家族名（去除引号）
  final String family;

  /// 字体文件字节（已反混淆）
  final Uint8List bytes;

  const EmbeddedFont(this.family, this.bytes);
}

/// EPUB 内容渲染结果：内联 CSS/图片后的 HTML + 需运行时加载的字体
class RenderedContent {
  final String html;
  final List<EmbeddedFont> fonts;

  /// 是否为竖排（writing-mode: vertical-rl/lr），命中时改用竖排渲染
  final bool isVertical;

  /// 竖排渲染用的纯文本（已按段落换行）；横排内容为空字符串
  final String plainText;

  const RenderedContent(
    this.html, {
    this.fonts = const [],
    this.isVertical = false,
    this.plainText = '',
  });
}
