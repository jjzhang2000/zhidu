/// 小节摘要模型
///
/// 表示书籍中某一小节的AI生成摘要，是摘要层级结构中的最细粒度单元。
/// 一个章节可能包含多个小节，每个小节都有独立的摘要信息。
///
/// 在智读的分层阅读体系中，小节摘要是：
/// - 最详细的内容摘要层级
/// - 保留具体知识点和细节
/// - 为"读厚"阶段提供丰富的学习材料
///
/// 与ChapterSummary的区别：
/// - ChapterSummary：章节级摘要，更宏观
/// - SectionSummary：小节级摘要，更详细
class SectionSummary {
  /// 所属书籍的唯一标识符
  ///
  /// 用于关联到具体的Book对象，确保摘要与书籍的正确对应关系。
  /// 与Book.id字段保持一致。
  final String bookId;

  /// 所属章节的索引（从0开始）
  ///
  /// 用于定位该小节所属的章节。
  /// 例如：第2章的小节，此值为1（如果章节索引从0开始）。
  final int chapterIndex;

  /// 小节在章节中的索引（从0开始）
  ///
  /// 用于定位小节在章节内的具体位置。
  /// 例如：某章第3个小节，此值为2。
  /// 与chapterIndex组合可唯一标识书籍中的某个小节。
  final int sectionIndex;

  /// 小节标题
  ///
  /// 从EPUB文档结构中提取的小节标题。
  /// 例如："1.1.3 数据库连接池的配置"
  final String sectionTitle;

  /// 客观摘要
  ///
  /// AI生成的小节内容客观概述，不包含主观评价。
  /// 主要功能：
  /// - 简要概括小节主要内容
  /// - 保持客观中性的叙述风格
  /// - 帮助读者快速了解小节核心内容
  ///
  /// 生成策略：
  /// - 提取小节主要观点
  /// - 保留关键技术术语
  /// - 控制篇幅适中（通常100-300字）
  final String objectiveSummary;

  /// AI洞察
  ///
  /// AI对小节内容的深度分析和主观见解。
  /// 主要功能：
  /// - 提供阅读建议和学习提示
  /// - 关联其他章节或知识点
  /// - 揭示内容背后的深层含义
  /// - 识别可能的学习难点
  ///
  /// 与objectiveSummary的区别：
  /// - objectiveSummary：客观概述，"讲了什么"
  /// - aiInsight：主观分析，"为什么重要，如何学习"
  final String aiInsight;

  /// 关键知识点列表
  ///
  /// 从小节内容中提取的核心知识点要点。
  /// 主要功能：
  /// - 快速定位重要信息
  /// - 便于复习和回顾
  /// - 构建知识体系
  /// - 支持关键词搜索
  ///
  /// 示例：
  /// ```dart
  /// keyPoints = [
  ///   'SQLite是轻量级嵌入式数据库',
  ///   'Drift是Flutter的ORM框架',
  ///   '数据库表需要定义主键',
  /// ];
  /// ```
  final List<String> keyPoints;

  /// 摘要创建时间
  ///
  /// 记录AI生成摘要的时间戳，用于：
  /// - 排序显示（按时间）
  /// - 版本管理和更新判断
  /// - 用户阅读进度追踪
  final DateTime createdAt;

  /// 构造函数
  ///
  /// 所有字段均为必填，确保摘要信息的完整性。
  SectionSummary({
    required this.bookId,
    required this.chapterIndex,
    required this.sectionIndex,
    required this.sectionTitle,
    required this.objectiveSummary,
    required this.aiInsight,
    required this.keyPoints,
    required this.createdAt,
  });

  /// 将小节摘要转换为JSON格式
  ///
  /// 主要用途：
  /// - 数据库存储（通过drift ORM）
  /// - 数据导出（Markdown等格式）
  /// - 跨组件数据传递
  /// - API数据传输
  ///
  /// 返回包含所有字段的Map，其中DateTime类型转换为ISO 8601字符串。
  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'sectionIndex': sectionIndex,
      'sectionTitle': sectionTitle,
      'objectiveSummary': objectiveSummary,
      'aiInsight': aiInsight,
      'keyPoints': keyPoints,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// 从JSON格式创建小节摘要对象
  ///
  /// 工厂构造函数，用于反序列化JSON数据。
  ///
  /// 主要用途：
  /// - 数据库读取（从drift查询结果）
  /// - 导入数据恢复
  /// - API响应解析
  ///
  /// 参数：
  /// - [json] 包含小节摘要数据的Map
  ///
  /// 返回：
  /// - 完整的SectionSummary对象
  ///
  /// 容错处理：
  /// - 字符串字段默认为空字符串
  /// - 整数字段默认为0
  /// - 列表字段默认为空列表
  /// - createdAt字段需要有效的日期字符串
  factory SectionSummary.fromJson(Map<String, dynamic> json) {
    return SectionSummary(
      bookId: json['bookId'] ?? '',
      chapterIndex: json['chapterIndex'] ?? 0,
      sectionIndex: json['sectionIndex'] ?? 0,
      sectionTitle: json['sectionTitle'] ?? '',
      objectiveSummary: json['objectiveSummary'] ?? '',
      aiInsight: json['aiInsight'] ?? '',
      keyPoints: List<String>.from(json['keyPoints'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
