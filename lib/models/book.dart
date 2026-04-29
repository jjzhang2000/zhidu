/// ============================================================================
/// 文件名：book.dart
/// 功能：书籍数据模型定义
/// ============================================================================

/// 枚举名：BookFormat
/// 功能：书籍文件格式枚举
///
/// 主要用途：
/// - 定义书籍支持的文件格式类型
/// - 用于区分EPUB和PDF文件的解析方式
enum BookFormat {
  /// PDF格式
  pdf,

  /// EPUB格式（主要支持的格式）
  epub,
}

/// 类名：Book
/// 功能：书籍实体类，表示单本书籍的完整信息
///
/// 主要用途：
/// - 存储书籍的基本信息（标题、作者、文件路径等）
/// - 跟踪阅读进度（当前章节、阅读进度百分比）
/// - 管理AI生成的书籍介绍和章节标题
/// - 提供序列化/反序列化功能用于数据存储
class Book {
  /// 书籍唯一标识符（UUID格式）
  final String id;

  /// 书籍标题
  final String title;

  /// 书籍作者
  final String author;

  /// 封面图片路径（可选）
  final String? coverPath;

  /// 书籍文件在本地存储的完整路径
  final String filePath;

  /// 书籍文件格式（EPUB或PDF）
  final BookFormat format;

  /// 书籍总章节数
  final int totalChapters;

  /// 当前阅读章节索引（从0开始）
  final int currentChapter;

  /// 阅读进度百分比（0.0-1.0）
  final double readingProgress;

  /// 书籍添加到书架的时间
  final DateTime addedAt;

  /// 最后阅读时间（可选）
  final DateTime? lastReadAt;

  /// AI生成的书籍介绍（可选）
  final String? aiIntroduction;

  /// 章节索引到章节标题的映射（可选）
  /// Key: 章节索引（int）
  /// Value: 章节标题（String）
  final Map<int, String>? chapterTitles;
  
  /// 书籍语言（从OPF元数据中获取）
  final String? language;
  
  /// 出版商（从OPF元数据中获取）
  final String? publisher;
  
  /// 书籍描述（从OPF元数据中获取）
  final String? description;
  
  /// 书籍主题/标签列表（从OPF元数据中获取）
  final List<String>? subjects;

  /// 构造函数：创建Book实例
  ///
  /// 必需参数：
  /// - id: 书籍唯一标识
  /// - title: 书籍标题
  /// - author: 书籍作者
  /// - filePath: 文件路径
  /// - format: 文件格式
  /// - addedAt: 添加时间
  ///
  /// 可选参数：
  /// - coverPath: 封面路径，默认为null
  /// - totalChapters: 总章节数，默认为0
  /// - currentChapter: 当前章节，默认为0
  /// - readingProgress: 阅读进度，默认为0.0
  /// - lastReadAt: 最后阅读时间，默认为null
  /// - aiIntroduction: AI介绍，默认为null
  /// - chapterTitles: 章节标题映射，默认为null
  /// - language: 书籍语言，默认为null
  /// - publisher: 出版商，默认为null
  /// - description: 书籍描述，默认为null
  /// - subjects: 书籍主题列表，默认为null
  Book({
    required this.id,
    required this.title,
    required this.author,
    this.coverPath,
    required this.filePath,
    required this.format,
    this.totalChapters = 0,
    this.currentChapter = 0,
    this.readingProgress = 0.0,
    required this.addedAt,
    this.lastReadAt,
    this.aiIntroduction,
    this.chapterTitles,
    this.language,
    this.publisher,
    this.description,
    this.subjects,
  });

  /// 方法名：copyWith
  /// 功能：创建Book的副本，可选择性地修改部分字段
  ///
  /// 参数：
  /// - id: 新的书籍ID（可选）
  /// - title: 新的标题（可选）
  /// - author: 新的作者（可选）
  /// - coverPath: 新的封面路径（可选）
  /// - filePath: 新的文件路径（可选）
  /// - format: 新的文件格式（可选）
  /// - totalChapters: 新的总章节数（可选）
  /// - currentChapter: 新的当前章节（可选）
  /// - readingProgress: 新的阅读进度（可选）
  /// - addedAt: 新的添加时间（可选）
  /// - lastReadAt: 新的最后阅读时间（可选）
  /// - aiIntroduction: 新的AI介绍（可选）
  /// - chapterTitles: 新的章节标题映射（可选）
  /// - language: 新的语言信息（可选）
  /// - publisher: 新的出版商（可选）
  /// - description: 新的描述（可选）
  /// - subjects: 新的主题列表（可选）
  ///
  /// 返回值：新的Book实例，未指定的字段保留原值
  ///
  /// 调用方：BookService（更新书籍信息时）
  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? coverPath,
    String? filePath,
    BookFormat? format,
    int? totalChapters,
    int? currentChapter,
    double? readingProgress,
    DateTime? addedAt,
    DateTime? lastReadAt,
    String? aiIntroduction,
    Map<int, String>? chapterTitles,
    String? language,
    String? publisher,
    String? description,
    List<String>? subjects,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapter: currentChapter ?? this.currentChapter,
      readingProgress: readingProgress ?? this.readingProgress,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      aiIntroduction: aiIntroduction ?? this.aiIntroduction,
      chapterTitles: chapterTitles ?? this.chapterTitles,
      language: language ?? this.language,
      publisher: publisher ?? this.publisher,
      description: description ?? this.description,
      subjects: subjects ?? this.subjects,
    );
  }

  /// 方法名：toJson
  /// 功能：将Book实例序列化为JSON格式Map
  ///
  /// 参数：无
  ///
  /// 返回值：Map<String, dynamic>，包含所有字段的JSON表示
  ///
  /// 调用方：BookService（书籍数据持久化时）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverPath': coverPath,
      'filePath': filePath,
      'format': format.name,
      'totalChapters': totalChapters,
      'currentChapter': currentChapter,
      'readingProgress': readingProgress,
      'addedAt': addedAt.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'aiIntroduction': aiIntroduction,
      'chapterTitles': chapterTitles?.map((k, v) => MapEntry(k.toString(), v)),
      'language': language,
      'publisher': publisher,
      'description': description,
      'subjects': subjects,
    };
  }

  /// 方法名：fromJson
  /// 功能：从JSON格式Map反序列化创建Book实例
  ///
  /// 参数：
  /// - json: 包含书籍数据的Map对象
  ///
  /// 返回值：Book实例
  ///
  /// 调用方：Database（从数据库读取时）、BookService（加载数据时）
  factory Book.fromJson(Map<String, dynamic> json) {
    final chapterTitlesRaw = json['chapterTitles'] as Map<String, dynamic>?;
    final chapterTitles = chapterTitlesRaw?.map(
      (k, v) => MapEntry(int.parse(k), v as String),
    );

    // 解析subjects数组
    final subjectsRaw = json['subjects'] as List<dynamic>?;
    final subjects = subjectsRaw?.cast<String>();

    return Book(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      coverPath: json['coverPath'],
      filePath: json['filePath'],
      format: BookFormat.values.firstWhere(
        (e) => e.name == json['format'],
        orElse: () => BookFormat.epub,
      ),
      totalChapters: json['totalChapters'] ?? 0,
      currentChapter: json['currentChapter'] ?? 0,
      readingProgress: json['readingProgress']?.toDouble() ?? 0.0,
      addedAt: DateTime.parse(json['addedAt']),
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.parse(json['lastReadAt'])
          : null,
      aiIntroduction: json['aiIntroduction'],
      chapterTitles: chapterTitles,
      language: json['language'],
      publisher: json['publisher'],
      description: json['description'],
      subjects: subjects,
    );
  }
}
