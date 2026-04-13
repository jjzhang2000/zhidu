import 'book.dart';

class BookMetadata {
  final String title;
  final String author;
  final String? coverPath;
  final int totalChapters;
  final BookFormat format;

  BookMetadata({
    required this.title,
    required this.author,
    this.coverPath,
    required this.totalChapters,
    required this.format,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'coverPath': coverPath,
      'totalChapters': totalChapters,
      'format': format.name,
    };
  }

  factory BookMetadata.fromJson(Map<String, dynamic> json) {
    return BookMetadata(
      title: json['title'],
      author: json['author'],
      coverPath: json['coverPath'],
      totalChapters: json['totalChapters'],
      format: BookFormat.values.firstWhere(
        (e) => e.name == json['format'],
        orElse: () => BookFormat.epub,
      ),
    );
  }
}
