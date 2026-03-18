
class ChapterSummary {
  final String chapterId;
  final String chapterTitle;
  final List<String> keyPoints;
  final List<String> keyArguments;
  final String aiEvaluation;
  final DateTime createdAt;

  ChapterSummary({
    required this.chapterId,
    required this.chapterTitle,
    required this.keyPoints,
    required this.keyArguments,
    required this.aiEvaluation,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'chapterId': chapterId,
      'chapterTitle': chapterTitle,
      'keyPoints': keyPoints,
      'keyArguments': keyArguments,
      'aiEvaluation': aiEvaluation,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChapterSummary.fromJson(Map<String, dynamic> json) {
    return ChapterSummary(
      chapterId: json['chapterId'],
      chapterTitle: json['chapterTitle'],
      keyPoints: List<String>.from(json['keyPoints'] ?? []),
      keyArguments: List<String>.from(json['keyArguments'] ?? []),
      aiEvaluation: json['aiEvaluation'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}