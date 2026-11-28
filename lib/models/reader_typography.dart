// 书籍原始排版
//
// 从书籍自身 CSS 解析出的正文排版参数，用于：
// 1. 作为阅读页排版的起步值（全局设置仍为默认值时）
// 2. 作为阅读页「重置」的恢复值
// 字段为 null 表示该书未定义该项，回退应用默认值（21 / 1.6 / 0.8）

/// 书籍原始排版（字号 / 行距 / 段距）
class ReaderTypography {
  /// 原书正文字号（px）
  final double? fontSize;

  /// 原书行高倍数（TextStyle.height）
  final double? lineHeight;

  /// 原书段距系数（段落间距 = 字号 × 系数）
  final double? paragraphSpacing;

  const ReaderTypography({
    this.fontSize,
    this.lineHeight,
    this.paragraphSpacing,
  });

  /// 是否三项都未定义
  bool get isEmpty =>
      fontSize == null && lineHeight == null && paragraphSpacing == null;

  @override
  String toString() =>
      'ReaderTypography(fontSize: $fontSize, lineHeight: $lineHeight, '
      'paragraphSpacing: $paragraphSpacing)';
}
