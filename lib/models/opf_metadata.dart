/// OPF元数据模型
///
/// 用于存储从OPF文件解析出的书籍元数据信息
/// 主要用于从Calibre生成的metadata.opf文件中读取书籍信息
class OpfMetadata {
  /// 书籍标题
  final String? title;

  /// 书籍作者
  final String? author;

  /// 书籍语言
  final String? language;

  /// 封面图片路径（相对于OPF文件的路径）
  final String? coverPath;

  /// 出版社
  final String? publisher;

  /// 书籍描述
  final String? description;

  /// 主题/标签列表
  final List<String> subjects;

  /// 构造函数
  OpfMetadata({
    this.title,
    this.author,
    this.language,
    this.coverPath,
    this.publisher,
    this.description,
    this.subjects = const [],
  });

  /// 创建副本，可以选择性修改部分字段
  OpfMetadata copyWith({
    String? title,
    String? author,
    String? language,
    String? coverPath,
    String? publisher,
    String? description,
    List<String>? subjects,
  }) {
    return OpfMetadata(
      title: title ?? this.title,
      author: author ?? this.author,
      language: language ?? this.language,
      coverPath: coverPath ?? this.coverPath,
      publisher: publisher ?? this.publisher,
      description: description ?? this.description,
      subjects: subjects ?? this.subjects,
    );
  }
}