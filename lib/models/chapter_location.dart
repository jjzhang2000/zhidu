/// 章节位置模型
///
/// 用于表示章节在EPUB文件中的位置信息，支持两种定位方式：
/// - **href定位**：通过章节的相对路径引用（如"chapter1.xhtml"）
/// - **页面范围定位**：通过起止页码定位（主要用于PDF）
///
/// 该模型主要用于：
/// 1. 记录用户阅读进度，方便下次打开时恢复位置
/// 2. 在章节导航时定位目标章节
/// 3. 在摘要生成时关联章节内容
///
/// ## 使用示例
///
/// ```dart
/// // 创建基于href的章节位置
/// final location = ChapterLocation(href: 'chapter1.xhtml');
///
/// // 创建基于页码的章节位置
/// final location = ChapterLocation(startPage: 10, endPage: 25);
///
/// // 序列化为JSON
/// final json = location.toJson();
///
/// // 从JSON反序列化
/// final restored = ChapterLocation.fromJson(json);
/// ```
class ChapterLocation {
  /// 章节的相对路径引用
  ///
  /// 在EPUB文件中，每个章节通常对应一个HTML文件。
  /// href指向该HTML文件的相对路径，例如：
  /// - "chapter1.xhtml"
  /// - "OEBPS/chapters/chapter01.html"
  /// - "content/part1/chapter01.xhtml#section2"（带锚点）
  ///
  /// 此字段主要用于EPUB格式的书籍定位。
  final String? href;

  /// 章节起始页码
  ///
  /// 表示章节在PDF文件中的起始页码（从1开始）。
  /// 此字段主要用于PDF格式的书籍定位。
  ///
  /// 例如，如果某章节从第10页开始，则startPage为10。
  final int? startPage;

  /// 章节结束页码
  ///
  /// 表示章节在PDF文件中的结束页码。
  /// 此字段主要用于PDF格式的书籍定位。
  ///
  /// 例如，如果某章节在第25页结束，则endPage为25。
  /// startPage和endPage共同定义了章节的页面范围。
  final int? endPage;

  /// 创建章节位置实例
  ///
  /// 参数说明：
  /// - [href]：章节的相对路径引用（EPUB使用）
  /// - [startPage]：章节起始页码（PDF使用）
  /// - [endPage]：章节结束页码（PDF使用）
  ///
  /// 通常根据书籍格式只使用一种定位方式：
  /// - EPUB书籍：只提供href
  /// - PDF书籍：提供startPage和endPage
  ChapterLocation({
    this.href,
    this.startPage,
    this.endPage,
  });

  /// 将章节位置序列化为JSON
  ///
  /// 返回一个Map，包含所有非空字段。
  /// 可用于保存阅读进度到数据库或本地存储。
  ///
  /// 返回格式示例：
  /// ```json
  /// {
  ///   "href": "chapter1.xhtml",
  ///   "startPage": 10,
  ///   "endPage": 25
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'href': href,
      'startPage': startPage,
      'endPage': endPage,
    };
  }

  /// 从JSON反序列化创建章节位置实例
  ///
  /// 参数 [json] 必须包含以下字段（可选）：
  /// - "href"：章节的相对路径引用
  /// - "startPage"：章节起始页码
  /// - "endPage"：章节结束页码
  ///
  /// 使用示例：
  /// ```dart
  /// final location = ChapterLocation.fromJson({
  ///   'href': 'chapter1.xhtml',
  ///   'startPage': null,
  ///   'endPage': null,
  /// });
  /// ```
  factory ChapterLocation.fromJson(Map<String, dynamic> json) {
    return ChapterLocation(
      href: json['href'],
      startPage: json['startPage'],
      endPage: json['endPage'],
    );
  }
}
