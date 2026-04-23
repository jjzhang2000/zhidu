import 'book.dart';

/// 书籍元数据模型
///
/// 用于存储书籍的基本信息，包括标题、作者、封面、章节数和格式等。
/// 该模型主要用于在文件解析阶段收集和传递书籍的元信息，
/// 与[Book]模型不同，它不包含完整的书籍内容和阅读状态。
///
/// 典型使用场景：
/// - EPUB/PDF文件解析时提取元数据
/// - 书籍导入预览界面展示基本信息
/// - 书籍列表的简化信息展示
///
/// 示例：
/// ```dart
/// final metadata = BookMetadata(
///   title: '三体',
///   author: '刘慈欣',
///   coverPath: '/path/to/cover.jpg',
///   totalChapters: 3,
///   format: BookFormat.epub,
/// );
/// ```
class BookMetadata {
  /// 书籍标题
  ///
  /// 从EPUB的metadata或PDF的文档信息中提取。
  /// 如果源文件未提供标题，通常使用文件名作为默认值。
  final String title;

  /// 书籍作者
  ///
  /// 从EPUB的dc:creator元素或PDF的Author字段提取。
  /// 如果源文件未提供作者信息，可能为空字符串或"未知"。
  final String author;

  /// 封面图片路径
  ///
  /// 封面图片的本地存储路径，可能为null表示无封面。
  /// 对于EPUB文件，通常从OPF文件中提取封面图片并保存到本地。
  /// 对于PDF文件，通常提取第一页作为封面。
  final String? coverPath;

  /// 书籍总章节数
  ///
  /// 表示书籍包含的章节数量。
  /// 对于EPUB文件，从spine或NCX/NAV导航文件中统计。
  /// 对于PDF文件，通常为页数。
  final int totalChapters;

  /// 书籍格式
  ///
  /// 标识书籍文件的格式类型，使用[BookFormat]枚举。
  /// 目前支持EPUB和PDF两种格式。
  final BookFormat format;
  
  /// 书籍语言（从OPF元数据中获取）
  final String? language;
  
  /// 出版商（从OPF元数据中获取）
  final String? publisher;
  
  /// 书籍描述（从OPF元数据中获取）
  final String? description;
  
  /// 书籍主题/标签列表（从OPF元数据中获取）
  final List<String>? subjects;

  /// 创建书籍元数据实例
  ///
  /// 所有必需参数都需要提供，可选参数[coverPath]、[language]、[publisher]、[description]、[subjects]默认为null。
  ///
  /// 参数：
  /// - [title]: 书籍标题，必需
  /// - [author]: 书籍作者，必需
  /// - [coverPath]: 封面图片路径，可选
  /// - [totalChapters]: 总章节数，必需
  /// - [format]: 书籍格式，必需
  /// - [language]: 书籍语言，可选
  /// - [publisher]: 出版商，可选
  /// - [description]: 书籍描述，可选
  /// - [subjects]: 书籍主题列表，可选
  BookMetadata({
    required this.title,
    required this.author,
    this.coverPath,
    required this.totalChapters,
    required this.format,
    this.language,
    this.publisher,
    this.description,
    this.subjects,
  });
}
