/// ============================================================================
/// 文件名：chapter.dart
/// 功能：统一章节模型定义，用于表示所有书籍格式（EPUB/PDF）的章节信息
/// ============================================================================

/// 类名：Chapter
/// 功能：统一章节模型，包含元数据、内容和AI摘要
///
/// 主要用途：
/// - 作为EPUB和PDF书籍章节的统一数据结构
/// - 存储章节的基本信息（索引、标题、位置、层级）
/// - 承载章节的HTML内容
/// - 存储AI生成的章节摘要
///
/// 调用方：
/// - EpubParser：解析EPUB文件时创建Chapter对象
/// - PdfParser：解析PDF文件时创建Chapter对象
/// - BookFormatParser：作为解析器的通用返回类型
/// - SummaryService：生成摘要时获取章节信息
/// - BookScreen：显示书籍目录时读取章节列表
/// - ChapterScreen：显示章节摘要时读取章节信息
/// - PdfReaderScreen：PDF阅读时定位章节
class Chapter {
  /// 所属书籍的唯一标识符
  final String bookId;

  /// 章节在目录中的索引位置（从0开始）
  /// 用途：章节排序、前后章节导航
  final int index;

  /// 章节标题
  /// 来源：EPUB从NCX/Nav解析，PDF从书签或页面内容提取
  final String title;

  /// 章节位置信息
  /// 包含：
  /// - href：EPUB章节文件路径（如"OEBPS/chapter1.xhtml"）
  /// - startPage：PDF起始页码
  /// - endPage：PDF结束页码
  final ChapterLocation location;

  /// 章节层级深度（默认为0）
  /// 用途：表示章节在目录树中的层级，支持多级目录结构
  /// - 0：顶级章节
  /// - 1：一级子章节
  /// - 2：二级子章节
  /// 注意：向后兼容字段，旧数据可能无此字段
  final int level;

  /// 章节的HTML格式内容
  ///
  /// 保留原始HTML格式，包含段落、标题、列表等结构化标签。
  /// 主要用于：
  /// - 在阅读界面保留原始格式（如加粗、斜体）
  /// - 支持富文本展示
  /// - 作为AI摘要生成的输入数据
  /// - 保留章节结构信息
  final String? htmlContent;

  /// AI生成的章节摘要内容
  ///
  /// 客观摘要：AI生成的章节内容概述，保持客观中立。
  final String? objectiveSummary;

  Chapter({
    this.bookId = '',
    required this.index,
    required this.title,
    required this.location,
    this.level = 0,
    this.htmlContent,
    this.objectiveSummary,
  });
}

/// 类名：ChapterLocation
/// 功能：章节位置模型，用于表示章节在文件中的位置信息
///
/// 支持两种定位方式：
/// - **href定位**：通过章节的相对路径引用（如"chapter1.xhtml"）
/// - **页面范围定位**：通过起止页码定位（主要用于PDF）
class ChapterLocation {
  /// 章节的相对路径引用
  ///
  /// 在EPUB文件中，每个章节通常对应一个HTML文件。
  /// href指向该HTML文件的相对路径。
  /// 此字段主要用于EPUB格式的书籍定位。
  final String? href;

  /// 章节起始页码
  ///
  /// 表示章节在PDF文件中的起始页码（从1开始）。
  /// 此字段主要用于PDF格式的书籍定位。
  final int? startPage;

  /// 章节结束页码
  ///
  /// 表示章节在PDF文件中的结束页码。
  /// 此字段主要用于PDF格式的书籍定位。
  final int? endPage;

  ChapterLocation({
    this.href,
    this.startPage,
    this.endPage,
  });
}
