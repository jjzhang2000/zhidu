// 书籍数据模型：Book / BookFormat / OpfMetadata

/// 书籍文件格式
enum BookFormat {
  /// PDF 格式
  pdf,

  /// EPUB 格式（主要支持的格式）
  epub,
}

/// 书籍实体，包含基本信息、阅读进度与出版元数据
class Book {
  /// 书籍唯一标识符（UUID 格式）
  final String id;

  /// 书籍标题
  final String title;

  /// 书籍作者
  final String author;

  /// 封面图片路径（可选）
  final String? coverPath;

  /// 书籍文件在本地存储的完整路径
  final String filePath;

  /// 书籍文件格式（EPUB 或 PDF）
  final BookFormat format;

  /// 书籍总章节数
  final int totalChapters;

  /// 当前阅读章节索引（从 0 开始）
  final int currentChapter;

  /// 阅读进度百分比（0.0-1.0）
  final double readingProgress;

  /// 书籍添加到书架的时间
  final DateTime addedAt;

  /// 最后阅读时间（可选）
  final DateTime? lastReadAt;

  /// 书籍语言（从 OPF 元数据中获取）
  final String? language;

  /// 出版方（从 OPF 元数据中获取）
  final String? publisher;

  /// 出版时间（从 OPF 元数据中获取）
  final String? publishDate;

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
    this.language,
    this.publisher,
    this.publishDate,
  });

  /// 创建副本，可选地修改部分字段
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
    String? language,
    String? publisher,
    String? publishDate,
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
      language: language ?? this.language,
      publisher: publisher ?? this.publisher,
      publishDate: publishDate ?? this.publishDate,
    );
  }

  /// 序列化为 JSON
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
      'language': language,
      'publisher': publisher,
      'publishDate': publishDate,
    };
  }

  /// 从 JSON 反序列化
  factory Book.fromJson(Map<String, dynamic> json) {
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
      language: json['language'],
      publisher: json['publisher'],
      publishDate: json['publishDate'],
    );
  }
}

/// OPF 元数据模型，用于存储从 Calibre metadata.opf 解析出的书籍信息
class OpfMetadata {
  /// 书籍标题
  final String? title;

  /// 书籍作者
  final String? author;

  /// 书籍语言
  final String? language;

  /// 封面图片路径（相对于 OPF 文件的路径）
  final String? coverPath;

  /// 出版方
  final String? publisher;

  /// 出版时间
  final String? publishDate;

  OpfMetadata({
    this.title,
    this.author,
    this.language,
    this.coverPath,
    this.publisher,
    this.publishDate,
  });

  /// 创建副本，可选地修改部分字段
  OpfMetadata copyWith({
    String? title,
    String? author,
    String? language,
    String? coverPath,
    String? publisher,
    String? publishDate,
  }) {
    return OpfMetadata(
      title: title ?? this.title,
      author: author ?? this.author,
      language: language ?? this.language,
      coverPath: coverPath ?? this.coverPath,
      publisher: publisher ?? this.publisher,
      publishDate: publishDate ?? this.publishDate,
    );
  }
}
