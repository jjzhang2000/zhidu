import '../../models/book_metadata.dart';
import '../../models/chapter.dart';
import '../../models/chapter_content.dart';

/// 书籍格式解析器抽象接口
/// 所有具体格式解析器（EPUB、PDF等）都需要实现此接口
abstract class BookFormatParser {
  /// 解析书籍元数据（标题、作者、封面等）
  ///
  /// [filePath] 书籍文件的完整路径
  /// 返回包含书籍元数据的 [BookMetadata] 对象
  Future<BookMetadata> parse(String filePath);

  /// 获取书籍的所有章节列表
  ///
  /// [filePath] 书籍文件的完整路径
  /// 返回按顺序排列的章节列表
  Future<List<Chapter>> getChapters(String filePath);

  /// 获取指定章节的完整内容
  ///
  /// [filePath] 书籍文件的完整路径
  /// [chapter] 要获取内容的章节对象
  /// 返回包含章节HTML内容和纯文本内容的 [ChapterContent] 对象
  Future<ChapterContent> getChapterContent(String filePath, Chapter chapter);

  /// 提取书籍封面图片
  ///
  /// [filePath] 书籍文件的完整路径
  /// 返回封面图片的字节数据（Base64编码或文件路径），如果没有封面则返回null
  Future<String?> extractCover(String filePath);
}
