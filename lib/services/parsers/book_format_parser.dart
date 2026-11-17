import '../../models/chapter.dart';

/// 书籍元数据解析结果（parseMetadata 返回值）
///
/// 仅包含导入时需要的轻量信息，不包含章节内容。
class BookMetadata {
  final String title;
  final String author;
  final int totalChapters;
  final String? coverPath;
  final String? language;

  BookMetadata({
    required this.title,
    required this.author,
    required this.totalChapters,
    this.coverPath,
    this.language,
  });
}

/// 书籍格式解析器抽象接口（策略模式）
///
/// 实现类：EpubParser / PdfParser
/// 调用方：FormatRegistry、BookService（parseMetadata）、BookScreen、ChapterScreen、SummaryService（getChapters/getChapterContent）
abstract class BookFormatParser {
  /// 解析书籍元数据（轻量导入阶段）
  ///
  /// 提取标题、作者、封面、章节数等基本信息，不读取章节内容。
  ///
  /// [filePath] 文件本地路径
  /// [bookId] 书籍唯一标识符（用于封面保存路径）
  /// 返回 [BookMetadata]，解析失败返回 null
  Future<BookMetadata?> parseMetadata(String filePath, String bookId);

  /// 轻量提取书籍基本信息（批量导入阶段）
  ///
  /// 只读书名、作者、封面三项，不解析章节结构与正文内容，
  /// 以降低批量导入时的 I/O 与 CPU 压力。
  Future<BookMetadata?> extractBasicMetadata(String filePath, String bookId);

  /// 获取所有章节列表（含 index、title、location、level）
  Future<List<Chapter>> getChapters(String filePath);

  /// 获取指定章节的完整 HTML 内容
  Future<Chapter> getChapterContent(String filePath, Chapter chapter);
}

/// 文件格式解析器注册表（注册表模式）
///
/// 扩展名 → 解析器映射，新增格式只需注册新解析器，无需修改现有代码。
/// 在 main.dart 中调用 [register]，运行时通过 [getParser] 获取解析器。
class FormatRegistry {
  /// 扩展名（小写）→ 解析器实例
  static final Map<String, BookFormatParser> _parsers = {};

  /// 注册解析器，同名扩展名会被覆盖
  static void register(String extension, BookFormatParser parser) {
    _parsers[extension.toLowerCase()] = parser;
  }

  /// 获取解析器，未注册时返回 null，查找不区分大小写
  static BookFormatParser? getParser(String extension) {
    return _parsers[extension.toLowerCase()];
  }

  /// 检查指定格式是否已注册
  static bool isSupported(String extension) {
    return _parsers.containsKey(extension.toLowerCase());
  }

  /// 获取所有已注册的格式扩展名列表
  static List<String> getSupportedFormats() {
    return _parsers.keys.toList();
  }

  /// 清空所有解析器（主要用于测试）
  static void clear() {
    _parsers.clear();
  }
}
