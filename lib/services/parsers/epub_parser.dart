// ============================================================================
// 文件名：epub_parser.dart
// 功能：EPUB格式解析器，用于解析EPUB电子书文件
// ============================================================================
//
// 主要职责：
// - 解析EPUB文件元数据（书名、作者、封面）
// - 提取章节列表（支持多层级目录结构）
// - 获取章节内容（HTML和纯文本）
// - 支持回退解析方案（当EpubReader失败时使用archive直接解析）
//
// 调用方：BookService、SummaryService
//
// 技术要点：
// - 使用epub_plus库进行标准解析
// - 使用archive库处理ZIP解压（EPUB本质是ZIP）
// - 使用xml库解析NCX/NAV导航文件
// - 支持XML命名空间处理

import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import 'dart:convert';

import '../../models/book.dart';
import '../../models/book_metadata.dart';
import '../../models/chapter.dart';
import '../../models/chapter_content.dart';
import '../../models/chapter_location.dart';
import 'book_format_parser.dart';
import '../log_service.dart';

/// 类名：EpubParser
/// 功能：EPUB格式解析器实现类
/// 父类：无
/// 实现接口：BookFormatParser
///
/// 主要职责：
/// - 解析EPUB文件结构和内容
/// - 提取书籍元数据、章节列表、章节内容、封面图片
/// - 支持多种解析策略和回退方案
class EpubParser implements BookFormatParser {
  /// 日志服务实例，用于记录解析过程和错误
  final LogService _log = LogService();

  /// UUID生成器，用于生成章节唯一标识
  final Uuid _uuid = const Uuid();

  /// 方法名：parse
  /// 功能：解析EPUB文件并提取书籍元数据
  ///
  /// 参数：
  /// - filePath: EPUB文件的绝对路径
  ///
  /// 返回值：BookMetadata对象，包含书名、作者、封面路径、章节数等信息
  ///
  /// 调用方：BookService.importBook()
  ///
  /// 算法逻辑：
  /// 1. 读取文件字节
  /// 2. 使用EpubReader解析（首选方案）
  /// 3. 若失败，使用archive直接解析container.xml和opf文件（回退方案）
  /// 4. 提取封面图片并保存到本地
  /// 5. 返回BookMetadata
  @override
  Future<BookMetadata> parse(String filePath) async {
    _log.v('EpubParser', 'parse 开始执行, filePath: $filePath');

    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('EpubParser', '文件不存在: $filePath');
      throw Exception('EPUB file not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    _log.d('EpubParser', '文件大小: ${bytes.length} bytes');

    String? title;
    String? author;
    List<String> chapterTitles = [];

    try {
      // 首选方案：使用EpubReader解析EPUB标准结构
      final epubBook = await EpubReader.readBook(bytes);
      _log.d('EpubParser', 'EPUB解析成功');

      title = epubBook.title;

      if (epubBook.authors?.isNotEmpty == true) {
        author = epubBook.authors!.join(', ');
      }

      if (epubBook.chapters?.isNotEmpty == true) {
        chapterTitles = _extractChapterTitles(epubBook.chapters!);
      }
    } catch (e, stackTrace) {
      _log.e('EpubParser', '使用EpubReader解析失败', e);
      _log.d('EpubParser', '尝试使用archive直接解析EPUB...');

      // 回退方案：使用archive直接解析ZIP结构
      final archive = ZipDecoder().decodeBytes(bytes);

      final containerInfo = _parseContainerXml(archive);
      if (containerInfo != null) {
        title = containerInfo['title'];
        author = containerInfo['author'];
      }

      final opfInfo = _parseOpfFile(archive);
      if (opfInfo != null) {
        title ??= opfInfo['title'];
        author ??= opfInfo['author'];
      }

      chapterTitles = _parseNavigationFile(archive);
    }

    // 最终回退：从文件路径提取书名
    if (title == null || title.isEmpty) {
      title = _extractTitleFromPath(filePath);
    }
    if (author == null || author.isEmpty) {
      author = '未知作者';
    }

    // 提取封面图片
    String? coverPath;
    try {
      coverPath = await extractCover(filePath);
    } catch (e) {
      _log.e('EpubParser', '封面提取失败', e);
    }

    _log.d('EpubParser', '最终书名: $title');
    _log.d('EpubParser', '最终作者: $author');
    _log.d('EpubParser', '章节数: ${chapterTitles.length}');

    return BookMetadata(
      title: title,
      author: author,
      coverPath: coverPath,
      totalChapters: chapterTitles.length,
      format: BookFormat.epub,
    );
  }

  /// 方法名：getChapters
  /// 功能：获取EPUB文件的章节列表
  ///
  /// 参数：
  /// - filePath: EPUB文件的绝对路径
  ///
  /// 返回值：Chapter对象列表，包含章节标题、位置、层级信息
  ///
  /// 调用方：BookDetailScreen、SummaryScreen
  ///
  /// 算法逻辑：
  /// 1. 读取文件字节
  /// 2. 按优先级尝试三种解析来源：
  ///    - toc.ncx导航文件（最准确，含层级）
  ///    - epubBook.chapters列表（中等）
  ///    - content.html文件列表（回退）
  /// 3. 若全部失败，使用archive解析NCX或HTML文件列表
  /// 4. 转换为Chapter模型，保留层级结构
  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    _log.v('EpubParser', 'getChapters 开始执行, filePath: $filePath');

    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('EpubParser', '文件不存在: $filePath');
      return [];
    }

    final bytes = await file.readAsBytes();
    final chapterInfos = <_ChapterInfoInternal>[];

    try {
      final epubBook = await EpubReader.readBook(bytes);

      // 优先从toc.ncx (navigation)提取 - 最准确，包含层级结构
      if (epubBook.schema?.navigation?.navMap != null &&
          epubBook.schema!.navigation!.navMap!.points.isNotEmpty) {
        _log.d('EpubParser', '从navigation提取章节列表');
        chapterInfos.addAll(_extractChapterInfosFromNavigation(
            epubBook.schema!.navigation!.navMap!.points));
        if (chapterInfos.isNotEmpty) {
          return _convertToChapters(chapterInfos);
        }
      }

      // 从chapters提取 - epub_plus库解析的章节列表
      if (epubBook.chapters.isNotEmpty) {
        _log.d('EpubParser', '从epubBook.chapters提取章节列表');
        chapterInfos.addAll(_extractChapterInfos(epubBook.chapters));
        if (chapterInfos.isNotEmpty) {
          return _convertToChapters(chapterInfos);
        }
      }

      // 从content.html提取 - 按spine顺序排列的HTML文件
      if (epubBook.content?.html?.isNotEmpty == true) {
        _log.d('EpubParser', '从content.html提取章节列表');
        chapterInfos.addAll(_extractChapterInfosFromContent(
            epubBook.content!.html!, epubBook.schema?.package?.spine?.items));
        if (chapterInfos.isNotEmpty) {
          return _convertToChapters(chapterInfos);
        }
      }
    } catch (e) {
      _log.e('EpubParser', 'EpubReader解析失败，使用archive回退方案', e);
    }

    // 回退方案：使用archive解析ZIP结构
    final archive = ZipDecoder().decodeBytes(bytes);
    final chaptersFromNcx = _extractChapterInfosFromNcxArchive(archive);
    if (chaptersFromNcx.isNotEmpty) {
      return _convertToChapters(chaptersFromNcx);
    }

    final flatChapters = _extractChapterInfosFromArchive(archive);
    return _convertToChapters(flatChapters);
  }

  /// 方法名：_convertToChapters
  /// 功能：将内部章节信息转换为Chapter模型
  ///
  /// 参数：
  /// - chapterInfos: 内部章节信息列表（_ChapterInfoInternal）
  ///
  /// 返回值：Chapter对象列表
  ///
  /// 调用方：getChapters()
  ///
  /// 算法逻辑：
  /// - 只为顶层章节（level==0）分配递增index，用于摘要生成
  /// - 子章节（level>0）index设为-1，不参与摘要生成
  /// - 保留层级深度信息，用于UI显示缩进
  List<Chapter> _convertToChapters(List<_ChapterInfoInternal> chapterInfos) {
    final chapters = <Chapter>[];
    int topLevelIndex = 0;

    for (final info in chapterInfos) {
      if (info.title.isNotEmpty) {
        final href = info.href;
        if (href != null && href.isNotEmpty) {
          final chapterIndex = info.level == 0 ? topLevelIndex++ : -1;

          chapters.add(Chapter(
            id: _uuid.v4(),
            index: chapterIndex,
            title: info.title,
            location: ChapterLocation(
              href: href,
            ),
            level: info.level,
          ));
        }
      }
    }

    return chapters;
  }

  /// 方法名：getChapterContent
  /// 功能：获取指定章节的内容
  ///
  /// 参数：
  /// - filePath: EPUB文件的绝对路径
  /// - chapter: Chapter对象，包含章节位置信息（href）
  ///
  /// 返回值：ChapterContent对象，包含HTML内容和纯文本
  ///
  /// 调用方：SummaryService.generateSingleSummary()
  ///
  /// 算法逻辑：
  /// 1. 从chapter.location.href获取章节文件路径
  /// 2. 首选方案：使用EpubReader查找对应章节
  /// 3. 回退方案：从archive直接读取HTML文件
  /// 4. 提取纯文本（移除HTML标签）
  @override
  Future<ChapterContent> getChapterContent(
      String filePath, Chapter chapter) async {
    _log.v('EpubParser',
        'getChapterContent 开始执行, filePath: $filePath, chapter: ${chapter.title}');

    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('EpubParser', '文件不存在: $filePath');
      throw Exception('EPUB file not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    final href = chapter.location.href;

    if (href == null || href.isEmpty) {
      _log.w('EpubParser', '章节没有href: ${chapter.title}');
      return ChapterContent(plainText: '');
    }

    // 首选方案：使用EpubReader查找章节内容
    try {
      final epubBook = await EpubReader.readBook(bytes);
      final chapterIndex = chapter.index;
      final epubChapter =
          _findEpubChapterByIndex(epubBook.chapters, chapterIndex);

      if (epubChapter != null) {
        final htmlContent = epubChapter.htmlContent ?? '';
        final plainText = _extractTextFromHtml(htmlContent);
        return ChapterContent(
          plainText: plainText,
          htmlContent: htmlContent,
        );
      }
    } catch (e) {
      _log.e('EpubParser', '使用EpubReader获取章节内容失败', e);
    }

    // 回退方案：从archive直接读取HTML文件
    final htmlContent = await _getChapterHtmlFromArchive(bytes, href);
    if (htmlContent != null) {
      final plainText = _extractTextFromHtml(htmlContent);
      return ChapterContent(
        plainText: plainText,
        htmlContent: htmlContent,
      );
    }

    _log.w('EpubParser', '无法获取章节内容: ${chapter.title}');
    return ChapterContent(plainText: '');
  }

  /// 方法名：extractCover
  /// 功能：提取EPUB封面图片并保存到本地
  ///
  /// 参数：
  /// - filePath: EPUB文件的绝对路径
  ///
  /// 返回值：封面图片的本地保存路径，失败时返回null
  ///
  /// 调用方：parse()
  ///
  /// 算法逻辑：
  /// 1. 首选方案：使用EpubReader查找包含cover或title的图片
  /// 2. 若未找到，使用第一张图片作为封面
  /// 3. 回退方案：从archive查找cover.jpg/cover.png等文件
  /// 4. 保存到本地covers目录
  @override
  Future<String?> extractCover(String filePath) async {
    _log.v('EpubParser', 'extractCover 开始执行, filePath: $filePath');

    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('EpubParser', '文件不存在: $filePath');
      return null;
    }

    final bytes = await file.readAsBytes();

    try {
      // 首选方案：使用EpubReader提取封面
      final epubBook = await EpubReader.readBook(bytes);

      if (epubBook.content?.images?.isNotEmpty == true) {
        EpubByteContentFile? coverImage;

        // 查找包含cover或title的图片
        for (final entry in epubBook.content!.images!.entries) {
          final name = entry.key.toLowerCase();
          if (name.contains('cover') || name.contains('title')) {
            coverImage = entry.value;
            _log.d('EpubParser', '找到封面图片: ${entry.key}');
            break;
          }
        }

        // 若未找到，使用第一张图片
        if (coverImage == null) {
          coverImage = epubBook.content!.images!.values.first;
          _log.d('EpubParser', '使用第一张图片作为封面');
        }

        if (coverImage != null && coverImage.content != null) {
          return await _saveCoverImage(
              coverImage.content!, coverImage.contentMimeType);
        }
      }
    } catch (e) {
      _log.e('EpubParser', '使用EpubReader提取封面失败', e);
    }

    // 回退方案：从archive查找
    return await _extractCoverFromArchive(bytes);
  }

  /// 方法名：_saveCoverImage
  /// 功能：保存封面图片到本地covers目录
  ///
  /// 参数：
  /// - imageBytes: 图片字节数据
  /// - mimeType: 图片类型（image/png或image/jpeg）
  ///
  /// 返回值：保存后的本地路径，失败时返回null
  ///
  /// 调用方：extractCover()、_extractCoverFromArchive()
  Future<String?> _saveCoverImage(
      List<int> imageBytes, String? mimeType) async {
    try {
      final coversDir = await _getCoversDirectory();
      final coverId = _uuid.v4();
      final extension = mimeType?.contains('png') == true ? 'png' : 'jpg';
      final coverPath = p.join(coversDir, '$coverId.$extension');

      final coverFile = File(coverPath);
      await coverFile.writeAsBytes(imageBytes);

      _log.d('EpubParser', '封面保存成功: $coverPath');
      return coverPath;
    } catch (e) {
      _log.e('EpubParser', '保存封面图片失败', e);
      return null;
    }
  }

  /// 方法名：_getCoversDirectory
  /// 功能：获取covers目录路径，若不存在则创建
  ///
  /// 参数：无
  ///
  /// 返回值：covers目录的绝对路径
  ///
  /// 调用方：_saveCoverImage()
  Future<String> _getCoversDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir.path;
  }

  // ==================== 辅助方法 ====================

  /// 方法名：_extractChapterTitles
  /// 功能：从EpubChapter列表递归提取所有章节标题
  ///
  /// 参数：
  /// - chapters: EpubChapter列表（可能包含子章节）
  ///
  /// 返回值：章节标题字符串列表
  ///
  /// 调用方：parse()
  List<String> _extractChapterTitles(List<EpubChapter> chapters) {
    final titles = <String>[];

    void traverseChapters(List<EpubChapter> chapters, int level) {
      for (final chapter in chapters) {
        if (chapter.title?.isNotEmpty == true) {
          titles.add(chapter.title!);
        }
        if (chapter.subChapters?.isNotEmpty == true) {
          traverseChapters(chapter.subChapters!, level + 1);
        }
      }
    }

    traverseChapters(chapters, 0);
    return titles;
  }

  /// 方法名：_extractTitleFromPath
  /// 功能：从文件路径提取书名（作为最终回退方案）
  ///
  /// 参数：
  /// - filePath: 文件路径
  ///
  /// 返回值：提取的书名
  ///
  /// 调用方：parse()
  String _extractTitleFromPath(String filePath) {
    final fileName = p.basenameWithoutExtension(filePath);
    return fileName.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  /// 方法名：_extractTextFromHtml
  /// 功能：从HTML内容提取纯文本
  ///
  /// 参数：
  /// - html: HTML字符串
  ///
  /// 返回值：纯文本字符串（移除标签、脚本、样式）
  ///
  /// 调用方：getChapterContent()、_parseNavigationFile()
  String _extractTextFromHtml(String html) {
    return html
        .replaceAll(
            RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&[a-z]+;'), '')
        .trim();
  }

  // ==================== Archive回退方案 ====================

  /// 方法名：_parseContainerXml
  /// 功能：解析META-INF/container.xml获取OPF文件路径
  ///
  /// 参数：
  /// - archive: EPUB解压后的Archive对象
  ///
  /// 返回值：包含opfPath的Map，失败时返回null
  ///
  /// 调用方：parse()
  ///
  /// 说明：container.xml是EPUB结构的入口文件，指向OPF包文件
  Map<String, String>? _parseContainerXml(Archive archive) {
    try {
      ArchiveFile? containerFile;
      for (final file in archive.files) {
        if (file.name.toLowerCase() == 'meta-inf/container.xml' ||
            file.name == 'META-INF/container.xml') {
          containerFile = file;
          break;
        }
      }

      if (containerFile == null) return null;

      final content = utf8.decode(containerFile.content as List<int>);
      final document = XmlDocument.parse(content);
      final rootfileElement = document.findAllElements('rootfile').firstOrNull;

      if (rootfileElement == null) return null;

      final opfPath = rootfileElement.getAttribute('full-path');
      if (opfPath == null) return null;

      return {'opfPath': opfPath};
    } catch (e) {
      _log.e('EpubParser', '解析container.xml失败', e);
      return null;
    }
  }

  /// 方法名：_parseOpfFile
  /// 功能：解析OPF文件获取书名和作者
  ///
  /// 参数：
  /// - archive: EPUB解压后的Archive对象
  ///
  /// 返回值：包含title和author的Map，失败时返回null
  ///
  /// 调用方：parse()
  ///
  /// 说明：OPF文件包含书籍元数据（dc:title、dc:creator等）
  Map<String, String?>? _parseOpfFile(Archive archive) {
    try {
      String? opfPath;
      ArchiveFile? opfFile;

      final containerInfo = _parseContainerXml(archive);
      if (containerInfo != null && containerInfo['opfPath'] != null) {
        opfPath = containerInfo['opfPath'];
        for (final file in archive.files) {
          if (file.name == opfPath) {
            opfFile = file;
            break;
          }
        }
      }

      if (opfFile == null) {
        for (final file in archive.files) {
          if (file.name.toLowerCase().endsWith('.opf')) {
            opfFile = file;
            break;
          }
        }
      }

      if (opfFile == null) return null;

      final content = utf8.decode(opfFile.content as List<int>);
      final document = XmlDocument.parse(content);

      String? title;
      String? author;

      final titleElements = document.findAllElements('dc:title');
      if (titleElements.isNotEmpty) {
        title = titleElements.first.innerText.trim();
      }

      final creatorElements = document.findAllElements('dc:creator');
      if (creatorElements.isNotEmpty) {
        author = creatorElements.map((e) => e.innerText.trim()).join(', ');
      }

      return {'title': title, 'author': author};
    } catch (e) {
      _log.e('EpubParser', '解析OPF文件失败', e);
      return null;
    }
  }

  /// 方法名：_parseNavigationFile
  /// 功能：解析导航文件（NCX或NAV）获取章节标题列表
  ///
  /// 参数：
  /// - archive: EPUB解压后的Archive对象
  ///
  /// 返回值：章节标题字符串列表
  ///
  /// 调用方：parse()
  ///
  /// 说明：NCX是传统EPUB2导航文件，NAV是EPUB3导航文件
  List<String> _parseNavigationFile(Archive archive) {
    try {
      ArchiveFile? navFile;
      String? navFileType;

      // 查找NCX文件
      for (final file in archive.files) {
        final name = file.name.toLowerCase();
        if (name.endsWith('.ncx')) {
          navFile = file;
          navFileType = 'ncx';
          break;
        }
      }

      // 若无NCX，查找NAV文件
      if (navFile == null) {
        for (final file in archive.files) {
          final name = file.name.toLowerCase();
          if ((name.contains('nav.') && name.endsWith('.html')) ||
              name.endsWith('.xhtml')) {
            if (name.contains('nav')) {
              navFile = file;
              navFileType = 'nav';
              break;
            }
          }
        }
      }

      if (navFile == null) return [];

      final content = utf8.decode(navFile.content as List<int>);
      final chapters = <String>[];

      if (navFileType == 'ncx') {
        final document = XmlDocument.parse(content);
        final navPoints = document.findAllElements('navPoint');

        for (final navPoint in navPoints) {
          final textElements = navPoint.findElements('text');
          if (textElements.isNotEmpty) {
            final text = textElements.first.innerText.trim();
            if (text.isNotEmpty) {
              chapters.add(text);
            }
          }
        }
      } else {
        // NAV文件：解析HTML中的链接
        final aPattern = RegExp(r'<a[^>]*>(.*?)</a>', caseSensitive: false);
        final matches = aPattern.allMatches(content);
        for (final match in matches) {
          final text = _extractTextFromHtml(match.group(1) ?? '').trim();
          if (text.isNotEmpty) {
            chapters.add(text);
          }
        }
      }

      return chapters;
    } catch (e) {
      _log.e('EpubParser', '解析导航文件失败', e);
      return [];
    }
  }

  /// 方法名：_extractCoverFromArchive
  /// 功能：从archive查找并提取封面图片
  ///
  /// 参数：
  /// - bytes: EPUB文件字节
  ///
  /// 返回值：封面图片本地路径，失败时返回null
  ///
  /// 调用方：extractCover()
  Future<String?> _extractCoverFromArchive(Uint8List bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      final coverPatterns = [
        'cover.jpg',
        'cover.jpeg',
        'cover.png',
        'Cover.jpg',
        'Cover.jpeg',
        'Cover.png',
      ];

      ArchiveFile? coverFile;

      // 按文件名模式查找
      for (final pattern in coverPatterns) {
        for (final file in archive.files) {
          if (file.name.toLowerCase().endsWith(pattern.toLowerCase())) {
            coverFile = file;
            break;
          }
        }
        if (coverFile != null) break;
      }

      // 若未找到，查找包含cover或image的图片文件
      if (coverFile == null) {
        for (final file in archive.files) {
          final name = file.name.toLowerCase();
          if ((name.contains('cover') || name.contains('image')) &&
              (name.endsWith('.jpg') ||
                  name.endsWith('.jpeg') ||
                  name.endsWith('.png'))) {
            coverFile = file;
            break;
          }
        }
      }

      if (coverFile != null) {
        final imageBytes = coverFile.content as List<int>;
        final mimeType = coverFile.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        return await _saveCoverImage(imageBytes, mimeType);
      }
    } catch (e) {
      _log.e('EpubParser', '从archive提取封面失败', e);
    }
    return null;
  }

  /// 方法名：_extractChapterInfos
  /// 功能：从EpubChapter列表递归提取章节信息
  ///
  /// 参数：
  /// - chapters: EpubChapter列表
  ///
  /// 返回值：_ChapterInfoInternal列表（含层级信息）
  ///
  /// 调用方：getChapters()
  List<_ChapterInfoInternal> _extractChapterInfos(List<EpubChapter> chapters) {
    final result = <_ChapterInfoInternal>[];

    void traverseChapters(List<EpubChapter> chapters, int level) {
      for (final chapter in chapters) {
        result.add(_ChapterInfoInternal(
          title: chapter.title ?? '未知章节',
          href: chapter.contentFileName,
          level: level,
        ));
        if (chapter.subChapters?.isNotEmpty == true) {
          traverseChapters(chapter.subChapters!, level + 1);
        }
      }
    }

    traverseChapters(chapters, 0);
    return result;
  }

  /// 方法名：_extractChapterInfosFromNavigation
  /// 功能：从EpubNavigationPoint列表提取章节信息
  ///
  /// 参数：
  /// - navPoints: EpubNavigationPoint列表（NCX导航点）
  ///
  /// 返回值：_ChapterInfoInternal列表（含层级信息）
  ///
  /// 调用方：getChapters()
  List<_ChapterInfoInternal> _extractChapterInfosFromNavigation(
      List<EpubNavigationPoint> navPoints) {
    final result = <_ChapterInfoInternal>[];

    void traverseNavPoints(List<EpubNavigationPoint> points, int level) {
      for (final point in points) {
        final title = point.navigationLabels.isNotEmpty
            ? point.navigationLabels.first.text ?? '未知章节'
            : '未知章节';
        final href = point.content?.source;
        result.add(_ChapterInfoInternal(
          title: title,
          href: href,
          level: level,
        ));
        if (point.childNavigationPoints.isNotEmpty) {
          traverseNavPoints(point.childNavigationPoints, level + 1);
        }
      }
    }

    traverseNavPoints(navPoints, 0);
    return result;
  }

  /// 方法名：_extractChapterInfosFromContent
  /// 功能：从content.html文件列表提取章节信息
  ///
  /// 参数：
  /// - htmlFiles: HTML文件映射（文件名 -> 内容）
  /// - spineItems: Spine顺序列表（可选）
  ///
  /// 返回值：_ChapterInfoInternal列表
  ///
  /// 调用方：getChapters()
  ///
  /// 说明：按spine顺序排列，或按文件名排序
  List<_ChapterInfoInternal> _extractChapterInfosFromContent(
      Map<String, EpubTextContentFile> htmlFiles,
      List<EpubSpineItemRef>? spineItems) {
    final result = <_ChapterInfoInternal>[];

    if (spineItems?.isNotEmpty == true) {
      // 按spine顺序提取
      for (final spineItem in spineItems!) {
        final idRef = spineItem.idRef;
        for (final entry in htmlFiles.entries) {
          final fileName = entry.key;
          if (fileName.toLowerCase().contains(idRef?.toLowerCase() ?? '')) {
            result.add(_ChapterInfoInternal(
              title: _extractTitleFromHtmlContent(entry.value.content ?? ''),
              href: fileName,
              level: 0,
            ));
            break;
          }
        }
      }
    } else {
      // 按文件名排序，排除导航文件
      final sortedFiles = htmlFiles.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      for (final entry in sortedFiles) {
        final name = entry.key.toLowerCase();
        if (!name.contains('nav') && !name.contains('toc')) {
          result.add(_ChapterInfoInternal(
            title: _extractTitleFromHtmlContent(entry.value.content ?? ''),
            href: entry.key,
            level: 0,
          ));
        }
      }
    }

    return result;
  }

  /// 方法名：_extractTitleFromHtmlContent
  /// 功能：从HTML内容提取章节标题
  ///
  /// 参数：
  /// - html: HTML字符串
  ///
  /// 返回值：提取的标题，失败时返回'未知章节'
  ///
  /// 调用方：_extractChapterInfosFromContent()
  ///
  /// 算法逻辑：依次尝试提取<title>、<h1>、<h2>
  String _extractTitleFromHtmlContent(String html) {
    final titleMatch =
        RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false)
            .firstMatch(html);
    if (titleMatch != null) {
      final title = titleMatch.group(1)?.trim();
      if (title?.isNotEmpty == true) {
        return title!;
      }
    }

    final h1Match =
        RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false).firstMatch(html);
    if (h1Match != null) {
      final title = _extractTextFromHtml(h1Match.group(1) ?? '').trim();
      if (title.isNotEmpty) {
        return title;
      }
    }

    final h2Match =
        RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false).firstMatch(html);
    if (h2Match != null) {
      final title = _extractTextFromHtml(h2Match.group(1) ?? '').trim();
      if (title.isNotEmpty) {
        return title;
      }
    }

    return '未知章节';
  }

  /// 方法名：_extractChapterInfosFromNcxArchive
  /// 功能：从archive解析NCX文件提取章节信息
  ///
  /// 参数：
  /// - archive: EPUB解压后的Archive对象
  ///
  /// 返回值：_ChapterInfoInternal列表（含层级信息）
  ///
  /// 调用方：getChapters()
  ///
  /// 说明：这是getChapters的回退方案，直接解析XML
  List<_ChapterInfoInternal> _extractChapterInfosFromNcxArchive(
      Archive archive) {
    try {
      ArchiveFile? ncxFile;
      for (final file in archive.files) {
        if (file.name.toLowerCase().endsWith('.ncx')) {
          ncxFile = file;
          break;
        }
      }

      if (ncxFile == null) return [];

      final content = utf8.decode(ncxFile.content as List<int>);
      final document = XmlDocument.parse(content);
      final navMap = document.findAllElements('navMap').firstOrNull;

      if (navMap == null) return [];

      // 递归解析navPoint元素
      List<_ChapterInfoInternal> parseNavPoints(
          Iterable<XmlElement> points, int level) {
        final result = <_ChapterInfoInternal>[];
        for (final navPoint in points) {
          final textElements = navPoint
                  .findElements('navLabel')
                  .firstOrNull
                  ?.findElements('text') ??
              [];
          final contentElements = navPoint.findElements('content');

          if (textElements.isNotEmpty) {
            final title = textElements.first.innerText.trim();
            final href = contentElements.isNotEmpty
                ? contentElements.first.getAttribute('src')
                : null;

            if (title.isNotEmpty) {
              result.add(_ChapterInfoInternal(
                title: title,
                href: href,
                level: level,
              ));

              // 递归处理子导航点
              final childNavPoints = navPoint.findElements('navPoint');
              if (childNavPoints.isNotEmpty) {
                result.addAll(parseNavPoints(childNavPoints, level + 1));
              }
            }
          }
        }
        return result;
      }

      final navPoints = navMap.findElements('navPoint');
      return parseNavPoints(navPoints, 0);
    } catch (e) {
      _log.e('EpubParser', '从archive解析toc.ncx失败', e);
      return [];
    }
  }

  /// 方法名：_extractChapterInfosFromArchive
  /// 功能：从archive提取HTML文件列表作为章节（最终回退方案）
  ///
  /// 参数：
  /// - archive: EPUB解压后的Archive对象
  ///
  /// 返回值：_ChapterInfoInternal列表（无层级，全部level=0）
  ///
  /// 调用方：getChapters()
  ///
  /// 说明：当所有其他方法失败时使用，按文件名排序，排除导航文件
  List<_ChapterInfoInternal> _extractChapterInfosFromArchive(Archive archive) {
    final chapters = <_ChapterInfoInternal>[];
    final htmlFiles = <String>[];

    for (final file in archive.files) {
      final name = file.name.toLowerCase();
      if ((name.endsWith('.html') || name.endsWith('.xhtml')) &&
          !name.contains('nav') &&
          !name.contains('toc')) {
        htmlFiles.add(file.name);
      }
    }

    htmlFiles.sort();

    for (int i = 0; i < htmlFiles.length; i++) {
      chapters.add(_ChapterInfoInternal(
        title: '第 ${i + 1} 章',
        href: htmlFiles[i],
        level: 0,
      ));
    }

    return chapters;
  }

  /// 方法名：_findEpubChapterByIndex
  /// 功能：根据索引在EpubChapter列表中查找对应章节
  ///
  /// 参数：
  /// - chapters: EpubChapter列表
  /// - targetIndex: 目标索引（仅顶层章节计数）
  ///
  /// 返回值：找到的EpubChapter，未找到返回null
  ///
  /// 调用方：getChapterContent()
  EpubChapter? _findEpubChapterByIndex(
      List<EpubChapter>? chapters, int targetIndex) {
    if (chapters == null) return null;

    var currentIndex = 0;
    EpubChapter? result;

    void traverseChapters(List<EpubChapter> chapters) {
      for (final chapter in chapters) {
        if (currentIndex == targetIndex) {
          result = chapter;
          return;
        }
        currentIndex++;
        if (chapter.subChapters?.isNotEmpty == true) {
          traverseChapters(chapter.subChapters!);
          if (result != null) return;
        }
      }
    }

    traverseChapters(chapters);
    return result;
  }

  /// 方法名：_getChapterHtmlFromArchive
  /// 功能：从archive获取指定href的HTML内容
  ///
  /// 参数：
  /// - bytes: EPUB文件字节
  /// - href: 章节文件路径（可能含锚点）
  ///
  /// 返回值：HTML字符串，未找到返回null
  ///
  /// 调用方：getChapterContent()
  ///
  /// 说明：href可能带有#锚点，需要移除；文件名大小写可能不匹配
  Future<String?> _getChapterHtmlFromArchive(
      Uint8List bytes, String href) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final hrefWithoutAnchor = href.split('#').first;
      final hrefWithoutAnchorLower = hrefWithoutAnchor.toLowerCase();

      // 多种匹配方式尝试
      for (final archiveFile in archive.files) {
        final archiveName = archiveFile.name;
        final archiveNameLower = archiveName.toLowerCase();

        final isMatch = archiveName == hrefWithoutAnchor ||
            archiveName.endsWith('/$hrefWithoutAnchor') ||
            archiveNameLower == hrefWithoutAnchorLower ||
            archiveNameLower.endsWith('/$hrefWithoutAnchorLower') ||
            archiveName.endsWith(hrefWithoutAnchor) ||
            archiveNameLower.endsWith(hrefWithoutAnchorLower) ||
            (hrefWithoutAnchor.contains('/') &&
                archiveName.endsWith(hrefWithoutAnchor.split('/').last)) ||
            (hrefWithoutAnchorLower.contains('/') &&
                archiveNameLower
                    .endsWith(hrefWithoutAnchorLower.split('/').last));

        if (isMatch) {
          return utf8.decode(archiveFile.content as List<int>);
        }
      }

      return null;
    } catch (e) {
      _log.e('EpubParser', '从archive获取章节HTML失败', e);
      return null;
    }
  }
}

/// 类名：_ChapterInfoInternal
/// 功能：内部章节信息结构，用于解析过程中的临时存储
///
/// 字段：
/// - title: 章节标题
/// - href: 章节文件路径
/// - level: 层级深度（0为顶层，越大层级越深）
class _ChapterInfoInternal {
  /// 章节标题
  final String title;

  /// 章节文件路径（HTML/XHTML文件的相对路径）
  final String? href;

  /// 层级深度，0表示顶层章节，用于UI显示缩进
  final int level;

  _ChapterInfoInternal({
    required this.title,
    this.href,
    required this.level,
  });
}
