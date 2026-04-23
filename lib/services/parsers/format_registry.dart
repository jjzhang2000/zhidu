import 'book_format_parser.dart';
import 'epub_parser.dart';
import 'pdf_parser.dart';

/// 格式注册表
///
/// 用于管理不同文件格式的解析器，采用注册表模式实现解析器的统一管理。
/// 支持运行时动态注册和获取解析器，便于扩展新的文件格式支持。
///
/// ## 设计模式
/// 使用注册表模式（Registry Pattern），将文件扩展名与解析器建立映射关系。
/// 这种设计遵循开闭原则：新增格式只需注册新的解析器，无需修改现有代码。
///
/// ## 单例存储
/// 所有解析器存储在静态Map中，全局共享同一份解析器实例，
/// 避免重复创建解析器对象，节省内存开销。
///
/// ## 使用流程
/// 1. 应用启动时调用 [initialize] 注册所有支持的格式解析器
/// 2. 需要解析文件时，通过 [getParser] 获取对应格式的解析器
/// 3. 使用解析器的接口方法进行文件解析
///
/// ## 使用示例
/// ```dart
/// // 应用启动时初始化（在 main.dart 中调用）
/// FormatRegistry.initialize();
///
/// // 检查是否支持某格式
/// if (FormatRegistry.isSupported('.epub')) {
///   // 获取解析器
///   final parser = FormatRegistry.getParser('.epub');
///   if (parser != null) {
///     final metadata = await parser.parse(filePath);
///     final chapters = await parser.getChapters(filePath);
///   }
/// }
///
/// // 获取所有支持的格式
/// final formats = FormatRegistry.getSupportedFormats();
/// print('支持的格式: $formats');
///
/// // 动态注册新格式（如插件扩展）
/// FormatRegistry.register('.mobi', MobiParser());
/// ```
///
/// ## 扩展新格式
/// 1. 创建实现 [BookFormatParser] 接口的新解析器类
/// 2. 在 [initialize] 方法中注册新解析器
/// 3. 或在运行时通过 [register] 方法动态注册
class FormatRegistry {
  /// 解析器映射表
  ///
  /// 键：文件扩展名（小写，如 '.epub'、'.pdf'）
  /// 值：对应格式的解析器实例
  ///
  /// 使用静态私有变量确保全局只有一个映射表实例。
  /// 扩展名统一转为小写存储，实现大小写不敏感的查找。
  static final Map<String, BookFormatParser> _parsers = {};

  /// 注册指定扩展名的解析器
  ///
  /// 将文件扩展名与解析器建立映射关系。
  /// 如果扩展名已存在，新的解析器会覆盖旧的解析器。
  ///
  /// 参数：
  /// - [extension] 文件扩展名（如 '.epub'、'.pdf'）
  ///   - 扩展名会自动转为小写存储
  ///   - 建议传入带点号的完整扩展名格式
  /// - [parser] 实现 [BookFormatParser] 接口的解析器实例
  ///   - 解析器应为无状态对象，可安全复用
  ///
  /// ## 使用示例
  /// ```dart
  /// // 注册EPUB解析器
  /// FormatRegistry.register('.epub', EpubParser());
  ///
  /// // 注册PDF解析器
  /// FormatRegistry.register('.pdf', PdfParser());
  ///
  /// // 大小写不敏感
  /// FormatRegistry.register('.EPUB', EpubParser()); // 会覆盖之前的注册
  /// ```
  static void register(String extension, BookFormatParser parser) {
    _parsers[extension.toLowerCase()] = parser;
  }

  /// 获取指定扩展名的解析器
  ///
  /// 根据文件扩展名查找对应的解析器实例。
  /// 扩展名查找不区分大小写。
  ///
  /// 参数：
  /// - [extension] 文件扩展名（如 '.epub'、'.pdf'）
  ///   - 扩展名会自动转为小写进行匹配
  ///
  /// 返回值：
  /// - 返回对应的解析器实例
  /// - 如果该格式未注册解析器，返回 `null`
  ///
  /// ## 使用示例
  /// ```dart
  /// final parser = FormatRegistry.getParser('.epub');
  /// if (parser != null) {
  ///   final metadata = await parser.parse(filePath);
  /// }
  ///
  /// // 处理不支持的格式
  /// final parser = FormatRegistry.getParser('.unknown');
  /// if (parser == null) {
  ///   print('不支持的文件格式');
  /// }
  /// ```
  static BookFormatParser? getParser(String extension) {
    return _parsers[extension.toLowerCase()];
  }

  /// 检查是否支持指定格式
  ///
  /// 判断该文件扩展名是否已注册对应的解析器。
  /// 在尝试解析文件前，可先调用此方法检查格式是否支持。
  ///
  /// 参数：
  /// - [extension] 文件扩展名
  ///   - 扩展名会自动转为小写进行匹配
  ///
  /// 返回值：
  /// - `true` 表示该格式已注册解析器
  /// - `false` 表示该格式尚未支持
  ///
  /// ## 使用示例
  /// ```dart
  /// // 在文件选择器中过滤支持的格式
  /// if (FormatRegistry.isSupported(extension)) {
  ///   // 处理文件导入
  /// } else {
  ///   ScaffoldMessenger.of(context).showSnackBar(
  ///     SnackBar(content: Text('不支持的文件格式: $extension')),
  ///   );
  /// }
  /// ```
  static bool isSupported(String extension) {
    return _parsers.containsKey(extension.toLowerCase());
  }

  /// 获取所有已注册的格式扩展名
  ///
  /// 返回当前注册表中支持的所有文件格式扩展名列表。
  /// 可用于在UI中显示支持的格式列表。
  ///
  /// 返回值：
  /// - 已注册解析器的文件扩展名列表
  /// - 扩展名均为小写格式（如 ['.epub', '.pdf', '.txt']）
  /// - 返回的是新的List实例，修改不会影响内部映射表
  ///
  /// ## 使用示例
  /// ```dart
  /// // 获取并显示支持的格式
  /// final formats = FormatRegistry.getSupportedFormats();
  /// print('支持的格式: ${formats.join(", ")}');
  /// // 输出: 支持的格式: .epub, .pdf, .txt
  ///
  /// // 用于文件选择器过滤
  /// final allowedExtensions = FormatRegistry.getSupportedFormats();
  /// FilePicker.platform.pickFiles(
  ///   type: FileType.custom,
  ///   allowedExtensions: allowedExtensions.map((e) => e.replaceAll('.', '')).toList(),
  /// );
  /// ```
  static List<String> getSupportedFormats() {
    return _parsers.keys.toList();
  }

  /// 初始化注册表
  ///
  /// 在应用启动时调用此方法，注册所有支持的格式解析器。
  /// 这是注册解析器的推荐方式，确保所有支持的格式在应用启动时就准备好。
  ///
  /// ## 初始化时机
  /// 应在 `main.dart` 的 `main()` 函数中，所有Service初始化之后调用：
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   // 初始化各种Service...
  ///   await LogService.instance.init();
  ///   await DatabaseService.instance.init();
  ///
  ///   // 初始化格式注册表
  ///   FormatRegistry.initialize();
  ///
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// ## 注册策略
  /// 在此方法内部调用 [register] 注册所有支持的格式：
  /// - EPUB格式：使用EpubParser解析
  /// - PDF格式：使用PdfParser解析
  static void initialize() {
    register('.epub', EpubParser());
    register('.pdf', PdfParser());
  }
  
  /// 清空所有已注册的解析器
  ///
  /// 移除注册表中的所有解析器映射关系。
  /// 主要用于测试场景，在每个测试用例之间重置注册表状态。
  ///
  /// ## 使用场景
  /// 1. **单元测试**：在setUp/tearDown中重置注册表
  /// 2. **插件卸载**：卸载某个插件时清除其注册的解析器
  /// 3. **重新初始化**：需要重新配置解析器时先清空再重新注册
  ///
  /// ## 注意事项
  /// - 调用此方法后，[getParser] 将返回null
  /// - 需要重新调用 [initialize] 或 [register] 注册解析器
  /// - 生产环境中一般不需要调用此方法
  ///
  /// ## 使用示例
  /// ```dart
  /// // 单元测试中使用
  /// setUp(() {
  ///   FormatRegistry.clear();
  /// });
  ///
  /// tearDown(() {
  ///   FormatRegistry.clear();
  /// });
  ///
  /// test('注册解析器', () {
  ///   FormatRegistry.register('.test', MockParser());
  ///   expect(FormatRegistry.isSupported('.test'), isTrue);
  /// });
  /// ```
  static void clear() {
    _parsers.clear();
  }
}
