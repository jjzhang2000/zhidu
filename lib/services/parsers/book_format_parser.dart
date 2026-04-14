/// ============================================================================
/// 文件名：book_format_parser.dart
/// 功能：书籍格式解析器抽象接口定义
/// ============================================================================

import '../../models/book_metadata.dart';
import '../../models/chapter.dart';
import '../../models/chapter_content.dart';

/// 类名：BookFormatParser
/// 功能：书籍格式解析器抽象接口，定义所有书籍解析器必须实现的通用方法
///
/// 设计模式：策略模式（Strategy Pattern）
/// - 将书籍解析行为抽象为接口，不同格式的解析器实现相同的接口
/// - 调用方无需关心具体格式，通过统一接口操作所有解析器
///
/// 主要用途：
/// - 定义书籍解析的通用契约（Contract）
/// - 支持多格式扩展（EPUB、PDF等）
/// - 实现格式无关的书籍处理流程
///
/// 实现类：
/// - EpubParser：EPUB格式解析器
/// - PdfParser：PDF格式解析器
///
/// 调用方：
/// - FormatRegistry：解析器注册表，通过扩展名获取对应解析器
/// - BookService：书籍导入时调用解析器提取元数据和章节
/// - SummaryService：生成摘要时调用解析器获取章节内容
abstract class BookFormatParser {
  /// 方法名：parse
  /// 功能：解析书籍文件，提取元数据信息
  ///
  /// 参数：
  /// - filePath: 书籍文件的完整本地路径
  ///
  /// 返回值：Future<BookMetadata> 包含书籍元数据的对象
  ///   - title: 书籍标题
  ///   - author: 作者名称
  ///   - coverPath: 封面图片路径（可能为null）
  ///   - totalChapters: 总章节数
  ///   - format: 书籍格式（EPUB/PDF）
  ///
  /// 调用方：BookService.importBook()
  ///
  /// 异步原因：需要读取文件系统并解析文件内容
  ///
  /// 使用示例：
  /// ```dart
  /// final parser = EpubParser();
  /// final metadata = await parser.parse('/path/to/book.epub');
  /// print(metadata.title); // 输出书名
  /// ```
  Future<BookMetadata> parse(String filePath);

  /// 方法名：getChapters
  /// 功能：获取书籍的所有章节列表
  ///
  /// 参数：
  /// - filePath: 书籍文件的完整本地路径
  ///
  /// 返回值：Future<List<Chapter>> 按顺序排列的章节列表
  ///   - 每个Chapter包含：id、index、title、location、level
  ///   - EPUB格式：从NCX/Nav导航文件解析章节结构
  ///   - PDF格式：从书签或页面内容提取章节信息
  ///
  /// 调用方：
  /// - BookService.importBook()：导入时获取章节列表
  /// - BookDetailScreen：显示书籍目录
  ///
  /// 异步原因：需要读取文件系统并解析章节结构
  ///
  /// 使用示例：
  /// ```dart
  /// final chapters = await parser.getChapters('/path/to/book.epub');
  /// for (final chapter in chapters) {
  ///   print('第${chapter.index}章: ${chapter.title}');
  /// }
  /// ```
  Future<List<Chapter>> getChapters(String filePath);

  /// 方法名：getChapterContent
  /// 功能：获取指定章节的完整内容
  ///
  /// 参数：
  /// - filePath: 书籍文件的完整本地路径
  /// - chapter: 要获取内容的章节对象（包含位置信息）
  ///
  /// 返回值：Future<ChapterContent> 章节内容对象
  ///   - plainText: 纯文本内容（去除HTML标签）
  ///   - htmlContent: HTML格式内容（保留格式，可能为null）
  ///
  /// 调用方：
  /// - SectionReaderScreen：显示章节内容
  /// - SummaryService：生成AI摘要时获取章节文本
  /// - EpubReaderScreen：EPUB阅读界面
  /// - PdfReaderScreen：PDF阅读界面
  ///
  /// 异步原因：需要读取文件系统并解析章节内容
  ///
  /// 使用示例：
  /// ```dart
  /// final content = await parser.getChapterContent(filePath, chapter);
  /// print(content.plainText); // 输出纯文本内容
  /// ```
  Future<ChapterContent> getChapterContent(String filePath, Chapter chapter);

  /// 方法名：extractCover
  /// 功能：提取书籍封面图片
  ///
  /// 参数：
  /// - filePath: 书籍文件的完整本地路径
  ///
  /// 返回值：Future<String?> 封面图片的存储路径
  ///   - 成功时返回封面图片的本地文件路径
  ///   - 如果书籍没有封面则返回null
  ///
  /// 调用方：
  /// - BookService.importBook()：导入时提取封面
  /// - BookDetailScreen：显示书籍封面
  ///
  /// 实现细节：
  /// - EPUB格式：从OPF文件指定的封面图片提取，或使用第一张图片
  /// - PDF格式：通常提取第一页渲染为图片
  ///
  /// 异步原因：需要读取文件系统、解析图片并保存到本地
  ///
  /// 使用示例：
  /// ```dart
  /// final coverPath = await parser.extractCover('/path/to/book.epub');
  /// if (coverPath != null) {
  ///   // 显示封面图片
  /// }
  /// ```
  Future<String?> extractCover(String filePath);
}
