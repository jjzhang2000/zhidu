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

/// EPUB格式解析器实现
/// 用于解析EPUB文件并提取元数据、章节列表和内容
class EpubParser implements BookFormatParser {
  final LogService _log = LogService();
  final Uuid _uuid = const Uuid();

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
      // 尝试使用EpubReader解析
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

      // 回退方案：使用archive直接解析
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

    if (title == null || title.isEmpty) {
      title = _extractTitleFromPath(filePath);
    }
    if (author == null || author.isEmpty) {
      author = '未知作者';
    }

    // 提取封面
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

      // 优先从toc.ncx (navigation)提取
      if (epubBook.schema?.navigation?.navMap != null &&
          epubBook.schema!.navigation!.navMap!.points.isNotEmpty) {
        _log.d('EpubParser', '从navigation提取章节列表');
        chapterInfos.addAll(_extractChapterInfosFromNavigation(
            epubBook.schema!.navigation!.navMap!.points));
        if (chapterInfos.isNotEmpty) {
          return _convertToChapters(chapterInfos);
        }
      }

      // 从chapters提取
      if (epubBook.chapters.isNotEmpty) {
        _log.d('EpubParser', '从epubBook.chapters提取章节列表');
        chapterInfos.addAll(_extractChapterInfos(epubBook.chapters));
        if (chapterInfos.isNotEmpty) {
          return _convertToChapters(chapterInfos);
        }
      }

      // 从content.html提取
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

    // 回退方案：使用archive解析
    final archive = ZipDecoder().decodeBytes(bytes);
    final chaptersFromNcx = _extractChapterInfosFromNcxArchive(archive);
    if (chaptersFromNcx.isNotEmpty) {
      return _convertToChapters(chaptersFromNcx);
    }

    final flatChapters = _extractChapterInfosFromArchive(archive);
    return _convertToChapters(flatChapters);
  }

  /// 将内部章节信息转换为Chapter模型（只返回顶级章节）
  List<Chapter> _convertToChapters(List<_ChapterInfoInternal> chapterInfos) {
    final chapters = <Chapter>[];
    int index = 0;

    for (final info in chapterInfos) {
      // 只返回顶级章节（level == 0）
      if (info.level == 0) {
        chapters.add(Chapter(
          id: _uuid.v4(),
          index: index++,
          title: info.title,
          location: ChapterLocation(
            href: info.href,
          ),
        ));
      }
    }

    return chapters;
  }

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

    // 尝试使用EpubReader
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

    // 回退方案：从archive获取
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
      // 尝试使用EpubReader提取封面
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

        // 如果没有找到，使用第一张图片
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

  /// 保存封面图片到covers目录
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

  /// 获取covers目录路径
  Future<String> _getCoversDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir.path;
  }

  // ==================== 辅助方法 ====================

  /// 提取章节标题列表（递归）
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

  /// 从文件路径提取书名
  String _extractTitleFromPath(String filePath) {
    final fileName = p.basenameWithoutExtension(filePath);
    return fileName.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  /// 从HTML提取纯文本
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

  /// 解析container.xml
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

  /// 解析OPF文件
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

  /// 解析导航文件（NCX或NAV）
  List<String> _parseNavigationFile(Archive archive) {
    try {
      ArchiveFile? navFile;
      String? navFileType;

      for (final file in archive.files) {
        final name = file.name.toLowerCase();
        if (name.endsWith('.ncx')) {
          navFile = file;
          navFileType = 'ncx';
          break;
        }
      }

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

  /// 从archive提取封面
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

      for (final pattern in coverPatterns) {
        for (final file in archive.files) {
          if (file.name.toLowerCase().endsWith(pattern.toLowerCase())) {
            coverFile = file;
            break;
          }
        }
        if (coverFile != null) break;
      }

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

  /// 从EpubChapter列表提取章节信息（递归，包含层级）
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

  /// 从navigation提取章节信息
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

  /// 从content.html提取章节信息
  List<_ChapterInfoInternal> _extractChapterInfosFromContent(
      Map<String, EpubTextContentFile> htmlFiles,
      List<EpubSpineItemRef>? spineItems) {
    final result = <_ChapterInfoInternal>[];

    if (spineItems?.isNotEmpty == true) {
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

  /// 从HTML内容提取标题
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

  /// 从NCX archive提取章节信息
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

  /// 从archive提取章节信息（回退方案）
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

  /// 根据索引查找EpubChapter
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

  /// 从archive获取章节HTML内容
  Future<String?> _getChapterHtmlFromArchive(
      Uint8List bytes, String href) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final hrefWithoutAnchor = href.split('#').first;
      final hrefWithoutAnchorLower = hrefWithoutAnchor.toLowerCase();

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

/// 内部章节信息结构
class _ChapterInfoInternal {
  final String title;
  final String? href;
  final int level;

  _ChapterInfoInternal({
    required this.title,
    this.href,
    required this.level,
  });
}
