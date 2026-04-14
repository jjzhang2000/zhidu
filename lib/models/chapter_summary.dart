/// 章节摘要模型
///
/// 表示书籍中单个章节的AI生成摘要，包含客观摘要、AI见解和关键要点。
/// 这是分层阅读体系中的中间层级，介于全书摘要和章节内的小节摘要之间。
///
/// 主要用途：
/// - 存储AI为每个章节生成的摘要内容
/// - 在章节列表界面展示章节概览
/// - 支持JSON序列化以便于数据存储和传输
class ChapterSummary {
  /// 所属书籍的唯一标识符
  ///
  /// 关联到[Book]模型的id字段，用于建立章节与书籍的关系。
  /// 格式通常是UUID字符串。
  final String bookId;

  /// 章节在书籍中的索引位置
  ///
  /// 从0开始计数，用于定位章节在书籍中的顺序。
  /// 与EPUB解析后的章节列表顺序一致。
  final int chapterIndex;

  /// 章节标题
  ///
  /// 从EPUB文件的目录（TOC）或OPF文件中提取的章节名称。
  /// 例如："第一章 引言"、"Chapter 1: Introduction"等。
  final String chapterTitle;

  /// 客观摘要
  ///
  /// AI生成的章节内容概述，保持客观中立，不包含主观评价。
  /// 通常包含：
  /// - 章节主要内容概述
  /// - 核心论点或情节
  /// - 重要信息点
  ///
  /// 用于"读薄"阶段，帮助用户快速了解章节大意。
  final String objectiveSummary;

  /// AI见解
  ///
  /// AI对章节内容的深度分析和见解，可能包含：
  /// - 观点分析
  /// - 写作手法点评
  /// - 与其他章节的关联
  /// - 知识拓展或延伸思考
  ///
  /// 用于"读厚"阶段，帮助用户深入理解章节内涵。
  final String aiInsight;

  /// 关键要点列表
  ///
  /// 从章节中提取的3-5个核心要点，以列表形式存储。
  /// 每个要点应该简洁明了，便于快速浏览。
  ///
  /// 示例：
  /// ```dart
  /// ['人工智能的发展历史', '机器学习的基本概念', '深度学习的应用场景']
  /// ```
  final List<String> keyPoints;

  /// 摘要创建时间
  ///
  /// 记录摘要生成的确切时间，用于：
  /// - 显示摘要的时效性
  /// - 支持按时间排序
  /// - 数据统计和分析
  final DateTime createdAt;

  /// 创建章节摘要实例
  ///
  /// 所有参数都是必需的，确保摘要数据的完整性。
  ///
  /// 参数：
  /// - [bookId]: 所属书籍ID
  /// - [chapterIndex]: 章节索引
  /// - [chapterTitle]: 章节标题
  /// - [objectiveSummary]: 客观摘要内容
  /// - [aiInsight]: AI见解内容
  /// - [keyPoints]: 关键要点列表
  /// - [createdAt]: 创建时间
  ChapterSummary({
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.objectiveSummary,
    required this.aiInsight,
    required this.keyPoints,
    required this.createdAt,
  });

  /// 将章节摘要转换为JSON格式
  ///
  /// 用于数据存储和传输，所有字段都会被序列化。
  /// [createdAt]字段会被转换为ISO 8601格式的字符串。
  ///
  /// 返回：包含所有字段信息的Map，键为字段名，值为字段值。
  ///
  /// 示例：
  /// ```dart
  /// {
  ///   'bookId': '550e8400-e29b-41d4-a716-446655440000',
  ///   'chapterIndex': 0,
  ///   'chapterTitle': '第一章 引言',
  ///   'objectiveSummary': '本章介绍了...',
  ///   'aiInsight': '作者通过...',
  ///   'keyPoints': ['要点1', '要点2', '要点3'],
  ///   'createdAt': '2024-04-14T10:30:00.000Z'
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'objectiveSummary': objectiveSummary,
      'aiInsight': aiInsight,
      'keyPoints': keyPoints,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// 从JSON数据创建章节摘要实例
  ///
  /// 工厂构造函数，用于从数据库或API响应中反序列化数据。
  /// 提供默认值以处理缺失字段的健壮性。
  ///
  /// 参数：
  /// - [json]: 包含章节摘要数据的Map，通常来自数据库查询或API响应
  ///
  /// 返回：新的[ChapterSummary]实例
  ///
  /// 默认值处理：
  /// - 字符串字段：空字符串''
  /// - 整数字段：0
  /// - 列表字段：空列表[]
  /// - 日期字段：无默认值，必须存在
  factory ChapterSummary.fromJson(Map<String, dynamic> json) {
    return ChapterSummary(
      bookId: json['bookId'] ?? '',
      chapterIndex: json['chapterIndex'] ?? 0,
      chapterTitle: json['chapterTitle'] ?? '',
      objectiveSummary: json['objectiveSummary'] ?? '',
      aiInsight: json['aiInsight'] ?? '',
      keyPoints: List<String>.from(json['keyPoints'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
