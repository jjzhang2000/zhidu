import '../../models/chapter.dart';

/// 书籍格式解析器抽象接口（策略模式）
///
/// 实现类：EpubParser / PdfParser
/// 调用方：FormatRegistry、BookScreen、ChapterScreen、SummaryService
abstract class BookFormatParser {
  Future<List<Chapter>> getChapters(String filePath);
  Future<Chapter> getChapterContent(String filePath, Chapter chapter);
  Future<String?> extractCover(String filePath);
}

/// 文件格式解析器注册表（注册表模式）
///
/// 扩展名 → 解析器映射，新增格式只需注册新解析器，无需修改现有代码。
/// 应用启动时在 main.dart 中调用 [register]，运行时通过 [getParser] 获取解析器。
class FormatRegistry {
  static final Map<String, BookFormatParser> _parsers = {};

  static void register(String extension, BookFormatParser parser) {
    _parsers[extension.toLowerCase()] = parser;
  }

  static BookFormatParser? getParser(String extension) {
    return _parsers[extension.toLowerCase()];
  }

  static bool isSupported(String extension) {
    return _parsers.containsKey(extension.toLowerCase());
  }

  static List<String> getSupportedFormats() {
    return _parsers.keys.toList();
  }

  static void clear() {
    _parsers.clear();
  }
}
