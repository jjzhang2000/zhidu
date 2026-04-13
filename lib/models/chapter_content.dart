class ChapterContent {
  final String plainText;
  final String? htmlContent;

  ChapterContent({
    required this.plainText,
    this.htmlContent,
  });

  Map<String, dynamic> toJson() {
    return {
      'plainText': plainText,
      'htmlContent': htmlContent,
    };
  }

  factory ChapterContent.fromJson(Map<String, dynamic> json) {
    return ChapterContent(
      plainText: json['plainText'],
      htmlContent: json['htmlContent'],
    );
  }
}
