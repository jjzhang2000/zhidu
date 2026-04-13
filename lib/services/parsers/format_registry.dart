import 'book_format_parser.dart';

/// 格式注册表
/// 用于管理不同文件格式的解析器，支持运行时注册和获取解析器
///
/// 使用示例:
/// ```dart
/// // 初始化注册表（在应用启动时调用一次）
/// FormatRegistry.initialize();
///
/// // 获取解析器
/// final parser = FormatRegistry.getParser('.epub');
/// if (parser != null) {
///   final metadata = await parser.parse(filePath);
/// }
/// ```
class FormatRegistry {
  static final Map<String, BookFormatParser> _parsers = {};

  /// 注册指定扩展名的解析器
  ///
  /// [extension] 文件扩展名（如 '.epub'、'.pdf'），会自动转为小写
  /// [parser] 实现 [BookFormatParser] 接口的解析器实例
  static void register(String extension, BookFormatParser parser) {
    _parsers[extension.toLowerCase()] = parser;
  }

  /// 获取指定扩展名的解析器
  ///
  /// [extension] 文件扩展名（如 '.epub'、'.pdf'），会自动转为小写
  /// 返回对应的解析器实例，如果没有注册则返回 null
  static BookFormatParser? getParser(String extension) {
    return _parsers[extension.toLowerCase()];
  }

  /// 检查是否支持指定格式
  ///
  /// [extension] 文件扩展名
  /// 返回 true 如果该格式已注册解析器
  static bool isSupported(String extension) {
    return _parsers.containsKey(extension.toLowerCase());
  }

  /// 获取所有已注册的格式扩展名
  ///
  /// 返回支持的文件扩展名列表
  static List<String> getSupportedFormats() {
    return _parsers.keys.toList();
  }

  /// 初始化注册表
  ///
  /// 在应用启动时调用此方法，注册所有支持的格式解析器
  /// 后续task中将在此方法中注册具体的解析器实现
  static void initialize() {
    // 将在后续task中注册解析器
    // 例如:
    // register('.epub', EpubParser());
    // register('.pdf', PdfParser());
    // register('.txt', TxtParser());
  }

  /// 清空所有已注册的解析器
  ///
  /// 主要用于测试场景
  static void clear() {
    _parsers.clear();
  }
}
