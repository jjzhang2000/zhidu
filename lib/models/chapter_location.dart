class ChapterLocation {
  final String? href;
  final int? startPage;
  final int? endPage;

  ChapterLocation({
    this.href,
    this.startPage,
    this.endPage,
  });

  Map<String, dynamic> toJson() {
    return {
      'href': href,
      'startPage': startPage,
      'endPage': endPage,
    };
  }

  factory ChapterLocation.fromJson(Map<String, dynamic> json) {
    return ChapterLocation(
      href: json['href'],
      startPage: json['startPage'],
      endPage: json['endPage'],
    );
  }
}
