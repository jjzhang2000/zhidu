/// ============================================================================
/// 文件名：chapter.dart
/// 功能：统一章节模型定义，用于表示所有书籍格式（EPUB/PDF）的章节信息
/// ============================================================================

import 'chapter_location.dart';

/// 类名：Chapter
/// 功能：统一章节模型，用于表示书籍中的一个章节
///
/// 主要用途：
/// - 作为EPUB和PDF书籍章节的统一数据结构
/// - 存储章节的基本信息（ID、索引、标题、位置、层级）
/// - 支持JSON序列化/反序列化，用于数据持久化和传输
///
/// 调用方：
/// - EpubParser：解析EPUB文件时创建Chapter对象
/// - PdfParser：解析PDF文件时创建Chapter对象
/// - BookFormatParser：作为解析器的通用返回类型
/// - SummaryService：生成摘要时获取章节信息
/// - BookDetailScreen：显示书籍目录时读取章节列表
/// - SummaryScreen：显示章节摘要时读取章节信息
/// - PdfReaderScreen：PDF阅读时定位章节
class Chapter {
  /// 章节唯一标识符
  /// 格式：EPUB使用"chapter_序号"，PDF使用"page_页码"
  /// 用途：数据库主键、章节查找、摘要关联
  final String id;

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

  /// 构造函数：Chapter
  /// 功能：创建章节对象
  ///
  /// 参数：
  /// - id: 章节唯一标识符（必填）
  /// - index: 章节索引位置（必填）
  /// - title: 章节标题（必填）
  /// - location: 章节位置信息（必填）
  /// - level: 章节层级深度（可选，默认0）
  Chapter({
    required this.id,
    required this.index,
    required this.title,
    required this.location,
    this.level = 0,
  });

  /// 方法名：toJson
  /// 功能：将Chapter对象转换为JSON格式的Map
  ///
  /// 返回值：Map<String, dynamic> 包含所有字段的JSON对象
  ///
  /// 用途：
  /// - 数据库存储时序列化
  /// - 数据传输时格式转换
  ///
  /// 调用方：SummaryService、数据库持久化层
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'index': index,
      'title': title,
      'location': location.toJson(),
      'level': level,
    };
  }

  /// 方法名：fromJson
  /// 功能：从JSON格式的Map创建Chapter对象（工厂构造函数）
  ///
  /// 参数：
  /// - json: 包含章节数据的Map对象
  ///
  /// 返回值：Chapter 新创建的章节对象
  ///
  /// 用途：
  /// - 数据库读取时反序列化
  /// - API响应解析
  ///
  /// 调用方：SummaryService、数据库持久化层
  ///
  /// 注意：
  /// - level字段兼容旧数据，缺失时默认为0
  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      index: json['index'],
      title: json['title'],
      location: ChapterLocation.fromJson(json['location']),
      level: json['level'] ?? 0,
    );
  }
}
