/// 统一章节模型，适用于 EPUB/PDF 等所有书籍格式
class Chapter {
  /// 所属书籍 ID
  final String bookId;

  /// 章节索引（从 0 开始）
  final int index;

  /// 章节标题
  final String title;

  /// 章节位置（EPUB 用 href，PDF 用页码范围）
  final ChapterLocation location;

  /// 目录层级深度，0 为顶级章节
  final int level;

  /// HTML 格式章节内容
  final String? htmlContent;

  /// AI 生成的章节缩写
  final String? abbreviation;

  Chapter({
    this.bookId = '',
    required this.index,
    required this.title,
    required this.location,
    this.level = 0,
    this.htmlContent,
    this.abbreviation,
  });
}

/// 章节位置，支持 href 定位（EPUB）和页码范围定位（PDF）
class ChapterLocation {
  /// EPUB 章节相对路径
  final String? href;

  /// PDF 起始页码（从 1 开始）
  final int? startPage;

  /// PDF 结束页码
  final int? endPage;

  ChapterLocation({
    this.href,
    this.startPage,
    this.endPage,
  });
}
