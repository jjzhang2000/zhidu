/// 书籍摘要模型
///
/// 表示整本书的摘要信息，包含书籍基本信息和所有章节摘要列表。
/// 用于存储和展示全书级别的知识蒸馏结果，支持导出为Markdown格式。
library;

import 'chapter_summary.dart';

/// 书籍摘要类
///
/// 封装一本书的完整摘要数据，包括：
/// - 书籍元信息（ID、书名、作者）
/// - 时间戳（创建时间、更新时间）
/// - 章节统计信息
/// - 所有章节的摘要列表
///
/// 使用示例：
/// ```dart
/// final summary = BookSummary(
///   bookId: 'book-001',
///   bookTitle: '三体',
///   author: '刘慈欣',
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
///   totalChapters: 3,
///   chapters: [],
/// );
/// ```
class BookSummary {
  /// 书籍唯一标识符
  ///
  /// 与Book模型中的id对应，用于关联原始书籍数据。
  final String bookId;

  /// 书籍标题
  ///
  /// 从EPUB元数据或用户输入获取的书名。
  final String bookTitle;

  /// 书籍作者
  ///
  /// 从EPUB元数据或用户输入获取的作者名。
  final String author;

  /// 摘要创建时间
  ///
  /// 首次生成全书摘要的时间戳。
  final DateTime createdAt;

  /// 摘要最后更新时间
  ///
  /// 最近一次更新摘要内容的时间戳，用于追踪版本。
  final DateTime updatedAt;

  /// 书籍总章节数
  ///
  /// 书籍包含的章节总数，与chapters列表长度可能不同
  /// （例如部分章节尚未生成摘要）。
  final int totalChapters;

  /// 章节摘要列表
  ///
  /// 已生成摘要的章节列表，每个元素是一个[ChapterSummary]对象。
  /// 列表按章节顺序排列。
  final List<ChapterSummary> chapters;

  /// 创建书籍摘要实例
  ///
  /// 所有参数均为必填，确保摘要数据的完整性。
  ///
  /// 参数：
  /// - [bookId]: 书籍唯一标识
  /// - [bookTitle]: 书籍标题
  /// - [author]: 作者名称
  /// - [createdAt]: 创建时间
  /// - [updatedAt]: 更新时间
  /// - [totalChapters]: 总章节数
  /// - [chapters]: 章节摘要列表
  BookSummary({
    required this.bookId,
    required this.bookTitle,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    required this.totalChapters,
    required this.chapters,
  });

  /// 将摘要序列化为JSON格式
  ///
  /// 用于数据持久化存储和API传输。
  /// 时间戳转换为ISO 8601字符串格式。
  ///
  /// 返回包含所有字段的Map对象。
  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'author': author,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'totalChapters': totalChapters,
      'chapters': chapters.map((c) => c.toJson()).toList(),
    };
  }

  /// 从JSON数据创建书籍摘要实例
  ///
  /// 工厂构造函数，用于反序列化存储或API返回的JSON数据。
  ///
  /// 参数：
  /// - [json]: 包含摘要数据的Map对象
  ///
  /// 返回新的[BookSummary]实例。
  ///
  /// 注意：
  /// - [totalChapters]默认值为0
  /// - [chapters]默认为空列表
  factory BookSummary.fromJson(Map<String, dynamic> json) {
    return BookSummary(
      bookId: json['bookId'],
      bookTitle: json['bookTitle'],
      author: json['author'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      totalChapters: json['totalChapters'] ?? 0,
      chapters: (json['chapters'] as List?)
              ?.map((c) => ChapterSummary.fromJson(c))
              .toList() ??
          [],
    );
  }

  /// 生成Markdown格式的摘要内容
  ///
  /// 将全书摘要转换为可导出的Markdown文档，
  /// 包含书籍元信息和各章节摘要。
  ///
  /// Markdown格式结构：
  /// ```markdown
  /// ---
  /// title: 书名
  /// author: 作者
  /// created_at: 时间戳
  /// total_chapters: 章节数
  /// ---
  ///
  /// ## 章节标题
  ///
  /// ### 客观摘要
  /// 摘要内容...
  ///
  /// ### AI见解
  /// AI分析...
  ///
  /// ### 关键要点
  /// - 要点1
  /// - 要点2
  /// ```
  ///
  /// 返回完整的Markdown格式字符串。
  String toMarkdown() {
    final buffer = StringBuffer();

    // YAML前置元数据块
    buffer.writeln('---');
    buffer.writeln('title: $bookTitle');
    buffer.writeln('author: $author');
    buffer.writeln('created_at: ${createdAt.toIso8601String()}');
    buffer.writeln('total_chapters: $totalChapters');
    buffer.writeln('---');
    buffer.writeln();

    // 遍历所有章节，逐个添加摘要内容
    for (final chapter in chapters) {
      buffer.writeln('## ${chapter.chapterTitle}');
      buffer.writeln();

      buffer.writeln('### 客观摘要');
      buffer.writeln(chapter.objectiveSummary);
      buffer.writeln();

      buffer.writeln('### AI见解');
      buffer.writeln(chapter.aiInsight);
      buffer.writeln();

      // 仅当有关键要点时才添加该部分
      if (chapter.keyPoints.isNotEmpty) {
        buffer.writeln('### 关键要点');
        for (final point in chapter.keyPoints) {
          buffer.writeln('- $point');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
