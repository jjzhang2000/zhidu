
import 'chapter_summary.dart';

class BookSummary {
  final String bookId;
  final String bookTitle;
  final String author;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalChapters;
  final List<ChapterSummary> chapters;

  BookSummary({
    required this.bookId,
    required this.bookTitle,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    required this.totalChapters,
    required this.chapters,
  });

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

  String toMarkdown() {
    final buffer = StringBuffer();
    
    buffer.writeln('---');
    buffer.writeln('title: $bookTitle');
    buffer.writeln('author: $author');
    buffer.writeln('created_at: ${createdAt.toIso8601String()}');
    buffer.writeln('total_chapters: $totalChapters');
    buffer.writeln('---');
    buffer.writeln();
    
    for (final chapter in chapters) {
      buffer.writeln('## ${chapter.chapterTitle}');
      buffer.writeln();
      
      buffer.writeln('### 客观摘要');
      buffer.writeln(chapter.objectiveSummary);
      buffer.writeln();
      
      buffer.writeln('### AI见解');
      buffer.writeln(chapter.aiInsight);
      buffer.writeln();
      
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

  factory BookSummary.fromMarkdown(String markdown, String bookId) {
    // TODO: 实现从Markdown解析
    throw UnimplementedError('从Markdown解析功能待实现');
  }
}