class SectionSummary {
  final String bookId;
  final int chapterIndex;
  final int sectionIndex;
  final String sectionTitle;
  final String objectiveSummary;
  final String aiInsight;
  final List<String> keyPoints;
  final DateTime createdAt;

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
