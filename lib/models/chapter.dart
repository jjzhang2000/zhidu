import 'chapter_location.dart';

class Chapter {
  final String id;
  final int index;
  final String title;
  final ChapterLocation location;

  Chapter({
    required this.id,
    required this.index,
    required this.title,
    required this.location,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'index': index,
      'title': title,
      'location': location.toJson(),
    };
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      index: json['index'],
      title: json['title'],
      location: ChapterLocation.fromJson(json['location']),
    );
  }
}
