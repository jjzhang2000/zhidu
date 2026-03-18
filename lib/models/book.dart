
class Book {
  final String id;
  final String title;
  final String author;
  final String? coverPath;
  final String filePath;
  final BookFormat format;
  final int totalChapters;
  final int currentChapter;
  final double readingProgress;
  final DateTime addedAt;
  final DateTime? lastReadAt;

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
  });

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
    );
  }

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
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      coverPath: json['coverPath'],
      filePath: json['filePath'],
      format: BookFormat.values.firstWhere(
        (e) => e.name == json['format'],
        orElse: () => BookFormat.pdf,
      ),
      totalChapters: json['totalChapters'] ?? 0,
      currentChapter: json['currentChapter'] ?? 0,
      readingProgress: json['readingProgress']?.toDouble() ?? 0.0,
      addedAt: DateTime.parse(json['addedAt']),
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.parse(json['lastReadAt'])
          : null,
    );
  }
}

enum BookFormat {
  pdf,
  epub,
}