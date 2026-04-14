/// 章节内容模型
///
/// 表示EPUB书籍中单个章节的内容，包含纯文本和可选的HTML格式内容。
///
/// 该模型用于：
/// - 存储EPUB解析后的章节内容
/// - 在阅读界面展示章节文本
/// - 作为AI摘要生成的输入数据
/// - 支持内容的序列化和反序列化
///
/// 使用示例：
/// ```dart
/// final content = ChapterContent(
///   plainText: '第一章的内容...',
///   htmlContent: '<p>第一章的内容...</p>',
/// );
/// ```
class ChapterContent {
  /// 章节的纯文本内容
  ///
  /// 从EPUB的HTML内容中提取的纯文本，去除所有HTML标签。
  /// 主要用于：
  /// - AI摘要生成（需要纯文本输入）
  /// - 简单的文本搜索和统计
  /// - 无需格式的文本展示场景
  final String plainText;

  /// 章节的HTML格式内容（可选）
  ///
  /// 保留原始HTML格式，包含段落、标题、列表等结构化标签。
  /// 主要用于：
  /// - 在阅读界面保留原始格式（如加粗、斜体）
  /// - 支持富文本展示
  /// - 保留章节结构信息
  ///
  /// 某些简单格式的EPUB可能没有单独的HTML内容，此时为null。
  final String? htmlContent;

  /// 创建章节内容实例
  ///
  /// [plainText] 是必填参数，表示章节的纯文本内容
  /// [htmlContent] 是可选参数，表示章节的HTML格式内容
  ChapterContent({
    required this.plainText,
    this.htmlContent,
  });

  /// 将章节内容转换为JSON格式的Map
  ///
  /// 用于序列化章节内容，便于：
  /// - 存储到数据库
  /// - 网络传输
  /// - 缓存管理
  ///
  /// 返回包含以下字段的Map：
  /// - 'plainText': 纯文本内容
  /// - 'htmlContent': HTML内容（可能为null）
  Map<String, dynamic> toJson() {
    return {
      'plainText': plainText,
      'htmlContent': htmlContent,
    };
  }

  /// 从JSON格式的Map创建章节内容实例
  ///
  /// 用于反序列化章节内容，通常配合toJson()使用。
  ///
  /// [json] 必须包含'plainText'字段，'htmlContent'字段可选。
  ///
  /// 使用示例：
  /// ```dart
  /// final json = {'plainText': '内容', 'htmlContent': '<p>内容</p>'};
  /// final content = ChapterContent.fromJson(json);
  /// ```
  factory ChapterContent.fromJson(Map<String, dynamic> json) {
    return ChapterContent(
      plainText: json['plainText'],
      htmlContent: json['htmlContent'],
    );
  }
}
