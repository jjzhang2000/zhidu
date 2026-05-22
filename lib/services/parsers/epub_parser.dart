import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../models/book.dart';
import '../../models/chapter.dart';
import 'book_format_parser.dart';
import '../log_service.dart';
import '../storage_config.dart';

/// EPUB 格式解析器
///
/// 章节提取优先级：NCX 导航 → content.html（spine 顺序）→ archive NCX → 扁平文件列表
/// 章节内容提取：archive 直读 href → epub_plus 按 index 回退
/// 元数据解析：EpubReader → archive 回退（container.xml + OPF + 导航文件）
class EpubParser implements BookFormatParser {
  final LogService _log = LogService();

  @override
  Future<BookMetadata?> parseMetadata(String filePath, String bookId) async {
    try {
      _log.d('EpubParser', '开始解析元数据: $filePath');
      final file = File(filePath);
      if (!await file.exists()) {
        _log.w('EpubParser', '文件不存在: $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();

      String? title;
      String? author;
      String? language;
      int totalChapters = 0;

      try {
        final epubBook = await EpubReader.readBook(bytes);

        title = epubBook.title;

        if (epubBook.authors?.isNotEmpty == true) {
          author = epubBook.authors!.join(', ');
        }

        if (epubBook.chapters?.isNotEmpty == true) {
          totalChapters = _countChapters(epubBook.chapters!);
        }
      } catch (_) {
        _log.w('EpubParser', 'EpubReader 解析失败，回退到 archive 方案');

        final archive = ZipDecoder().decodeBytes(bytes);

        final opfInfo = _parseOpfFile(archive);
        if (opfInfo != null) {
          title ??= opfInfo['title'];
          author ??= opfInfo['author'];
          language ??= opfInfo['language'];
        }

        final navChapters = _parseNavigationFile(archive);
        totalChapters = navChapters.length;
      }

      if (title == null || title.isEmpty) {
        title = _extractTitleFromPath(filePath);
      }
      if (author == null || author.isEmpty) {
        author = '未知作者';
      }

      String? coverPath;
      try {
        coverPath = await _extractCover(bytes, bookId);
      } catch (e) {
        _log.w('EpubParser', '封面提取失败: $e');
      }

      return BookMetadata(
        title: title,
        author: author,
        totalChapters: totalChapters,
        coverPath: coverPath,
        language: language,
      );
    } catch (e, stackTrace) {
      _log.e('EpubParser', '解析 EPUB 元数据失败', e, stackTrace);
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('EpubParser', '文件不存在: $filePath');
      return [];
    }

    final bytes = await file.readAsBytes();
    final chapterInfos = <_ChapterInfoInternal>[];

    try {
      final epubBook = await EpubReader.readBook(bytes);

      if (epubBook.schema?.navigation?.navMap != null &&
          epubBook.schema!.navigation!.navMap!.points.isNotEmpty) {
        _log.d('EpubParser', '从navigation提取章节列表');
        chapterInfos.addAll(_extractChapterInfosFromNavigation(
            epubBook.schema!.navigation!.navMap!.points));
        if (chapterInfos.isNotEmpty) {
          return _convertToChapters(chapterInfos);
        }
      }

      if (epubBook.content?.html?.isNotEmpty == true) {
        chapterInfos.addAll(_extractChapterInfosFromContent(
            epubBook.content!.html!, epubBook.schema?.package?.spine?.items));
        if (chapterInfos.isNotEmpty) {
          return _convertToChapters(chapterInfos);
        }
      }
    } catch (e) {
      _log.w('EpubParser', 'EpubReader解析失败，使用archive回退方案');
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final chaptersFromNcx = _extractChapterInfosFromNcxArchive(archive);
    if (chaptersFromNcx.isNotEmpty) {
      return _convertToChapters(chaptersFromNcx);
    }

    final flatChapters = _extractChapterInfosFromArchive(archive);
    return _convertToChapters(flatChapters);
  }

  /// 统计章节数量（递归遍历 subChapters）
  int _countChapters(List<EpubChapter> chapters) {
    int count = 0;
    for (final chapter in chapters) {
      count++;
      if (chapter.subChapters?.isNotEmpty == true) {
        count += _countChapters(chapter.subChapters!);
      }
    }
    return count;
  }

  /// 从文件路径提取书籍标题（回退方案）
  String _extractTitleFromPath(String filePath) {
    final fileName = p.basenameWithoutExtension(filePath);
    return fileName.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  /// 解析 OPF 包文件，提取标题、作者、语言（archive 回退方案）
  Map<String, String?>? _parseOpfFile(Archive archive) {
    try {
      ArchiveFile? opfFile;
      for (final file in archive.files) {
        if (file.name.toLowerCase().endsWith('.opf')) {
          opfFile = file;
          break;
        }
      }

      if (opfFile == null) {
        return null;
      }

      final content = utf8.decode(opfFile.content as List<int>);
      final document = XmlDocument.parse(content);

      String? title;
      String? author;
      String? language;

      final titleElements = document.findAllElements('dc:title');
      if (titleElements.isNotEmpty) {
        title = titleElements.first.innerText.trim();
      }

      final creatorElements = document.findAllElements('dc:creator');
      if (creatorElements.isNotEmpty) {
        author = creatorElements.map((e) => e.innerText.trim()).join(', ');
      }

      final languageElements = document.findAllElements('dc:language');
      if (languageElements.isNotEmpty) {
        language = languageElements.first.innerText.trim();
      }

      return {'title': title, 'author': author, 'language': language};
    } catch (e) {
      _log.e('EpubParser', '解析 OPF 文件失败', e);
      return null;
    }
  }

  /// 解析导航文件（NCX 或 NAV），提取章节标题列表（archive 回退方案）
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

      if (navFile == null) {
        return [];
      }

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
        final h1Pattern = RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>', caseSensitive: false);
        final liPattern = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false);
        final aPattern = RegExp(r'<a[^>]*>(.*?)</a>', caseSensitive: false);

        final liMatches = liPattern.allMatches(content);
        for (final match in liMatches) {
          final liContent = match.group(1) ?? '';
          final aMatch = aPattern.firstMatch(liContent);
          if (aMatch != null) {
            final text = _extractTextFromHtml(aMatch.group(1) ?? '').trim();
            if (text.isNotEmpty) {
              chapters.add(text);
            }
          } else {
            final text = _extractTextFromHtml(liContent).trim();
            if (text.isNotEmpty) {
              chapters.add(text);
            }
          }
        }

        if (chapters.isEmpty) {
          final hMatches = h1Pattern.allMatches(content);
          for (final match in hMatches) {
            final text = _extractTextFromHtml(match.group(1) ?? '').trim();
            if (text.isNotEmpty) {
              chapters.add(text);
            }
          }
        }
      }

      return chapters;
    } catch (e) {
      _log.e('EpubParser', '解析导航文件失败', e);
      return [];
    }
  }

  /// 从 HTML 内容提取纯文本（用于导航文件解析）
  String _extractTextFromHtml(String html) {
    return html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&[a-z]+;'), '')
        .trim();
  }

  /// 提取 EPUB 封面图片（EpubReader 优先 → archive 回退）
  Future<String?> _extractCover(Uint8List bytes, String bookId) async {
    try {
      final epubBook = await EpubReader.readBook(bytes);

      if (epubBook.content?.images?.isNotEmpty == true) {
        EpubByteContentFile? coverImage;

        for (final entry in epubBook.content!.images!.entries) {
          final name = entry.key.toLowerCase();
          if (name.contains('cover') || name.contains('title')) {
            coverImage = entry.value;
            break;
          }
        }

        if (coverImage == null) {
          coverImage = epubBook.content!.images.values.first;
        }

        if (coverImage.content != null) {
          final extension = coverImage.contentMimeType?.contains('png') == true ? 'png' : 'jpg';
          final coverPath = await StorageConfig.getCoverSavePath(bookId, extension);

          final coverOutputFile = File(coverPath);
          await coverOutputFile.writeAsBytes(coverImage.content!);
          return coverPath;
        }
      }
    } catch (e, _) {
      _log.w('EpubParser', 'EpubReader 提取封面失败，回退到 archive 方案');
    }

    return await _extractCoverFromArchive(bytes, bookId);
  }

  /// 提取 EPUB 封面图片（archive 回退方案）
  Future<String?> _extractCoverFromArchive(Uint8List bytes, String bookId) async {
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
        final extension = coverFile.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';

        final coverPath = await StorageConfig.getCoverSavePath(bookId, extension);
        final coverOutputFile = File(coverPath);
        await coverOutputFile.writeAsBytes(coverFile.content as List<int>);

        return coverPath;
      }
    } catch (e) {
      _log.w('EpubParser', 'archive 回退方案也未找到封面');
    }
    return null;
  }

  /// 内部章节信息 → Chapter 列表，顶层章节分配递增 index，子章节 index=-1
  List<Chapter> _convertToChapters(List<_ChapterInfoInternal> chapterInfos) {
    final chapters = <Chapter>[];
    int topLevelIndex = 0;

    for (final info in chapterInfos) {
      if (info.title.isNotEmpty) {
        final href = info.href;
        if (href != null && href.isNotEmpty) {
          final chapterIndex = info.level == 0 ? topLevelIndex++ : -1;

          chapters.add(Chapter(
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

  /// 获取章节 HTML 内容：优先 archive 直读 href，回退 epub_plus 按 index 查找
  @override
  Future<Chapter> getChapterContent(
      String filePath, Chapter chapter) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('EpubParser', '文件不存在：$filePath');
      throw Exception('EPUB file not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    final href = chapter.location.href;

    if (href == null || href.isEmpty) {
      _log.w('EpubParser', '章节没有 href: ${chapter.title}');
      return chapter;
    }

    _log.d('EpubParser', '准备提取章节内容，href: $href');

    try {
      final htmlContent = await _getChapterHtmlFromArchive(bytes, href);
      if (htmlContent != null && htmlContent.isNotEmpty) {
        _log.d('EpubParser', '✓ 从 archive 提取章节内容，href: $href, len=${htmlContent.length}');
        return Chapter(
          bookId: chapter.bookId,
          index: chapter.index,
          title: chapter.title,
          location: chapter.location,
          level: chapter.level,
          htmlContent: htmlContent,
        );
      } else {
        _log.w('EpubParser', '从 archive 提取的内容为空');
      }
    } catch (e) {
      _log.w('EpubParser', '从 archive 提取章节内容失败');
    }

    try {
      final epubBook = await EpubReader.readBook(bytes);

      if (chapter.index >= 0 && chapter.index < epubBook.chapters.length) {
        final epubChapter = epubBook.chapters[chapter.index];
        final htmlContent = epubChapter.htmlContent ?? '';
        if (htmlContent.isNotEmpty) {
          _log.d('EpubParser', '✓ 使用 EpubReader 获取章节内容，索引：${chapter.index}, 内容长度：${htmlContent.length}');
          return Chapter(
            bookId: chapter.bookId,
            index: chapter.index,
            title: chapter.title,
            location: chapter.location,
            level: chapter.level,
            htmlContent: htmlContent,
          );
        }
      }
    } catch (e) {
      _log.w('EpubParser', '使用 EpubReader 获取章节内容失败');
    }

    _log.w('EpubParser', '无法获取章节内容：${chapter.title}, href: $href');
    return chapter;
  }

  /// 从 NCX 导航点递归提取章节信息（含层级，最准确）
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

  /// 从 content.html 文件列表按 spine 顺序提取章节信息
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

  /// 从 HTML 内容提取章节标题（title → h1 → h2 优先级）
  String _extractTitleFromHtmlContent(String html) {
    final doc = html_parser.parse(html);

    final titleEl = doc.querySelector('title');
    if (titleEl != null && titleEl.text.trim().isNotEmpty) {
      return titleEl.text.trim();
    }

    final h1El = doc.querySelector('h1');
    if (h1El != null && h1El.text.trim().isNotEmpty) {
      return h1El.text.trim();
    }

    final h2El = doc.querySelector('h2');
    if (h2El != null && h2El.text.trim().isNotEmpty) {
      return h2El.text.trim();
    }

    return '未知章节';
  }

  /// archive 回退：解析 NCX XML 提取章节信息（含层级）
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

  /// 最终回退：archive 内 HTML/XHTML 文件按文件名排序，作为扁平章节列表
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

  /// 从 archive 按 href 查找并提取章节 HTML，支持 #锚点片段提取
  Future<String?> _getChapterHtmlFromArchive(
      Uint8List bytes, String href) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      final hrefParts = href.split('#');
      final hrefWithoutAnchor = hrefParts[0];
      final anchor = hrefParts.length > 1 ? hrefParts[1] : null;
      final hrefWithoutAnchorLower = hrefWithoutAnchor.toLowerCase();

      _log.d('EpubParser', '从 archive 提取章节：href=$href, anchor=$anchor');

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
          final fullHtml = utf8.decode(archiveFile.content as List<int>);

          if (anchor == null || anchor.isEmpty) {
            return fullHtml;
          }

          final chapterHtml = _extractChapterByAnchor(fullHtml, anchor);
          if (chapterHtml != null) {
            _log.d('EpubParser', '成功提取锚点 #$anchor 对应的章节内容');
            return chapterHtml;
          } else {
            _log.w('EpubParser', '未找到锚点 #$anchor，返回整个文件内容');
            return fullHtml;
          }
        }
      }

      _log.w('EpubParser', '未找到文件：$hrefWithoutAnchor');
      return null;
    } catch (e) {
      _log.e('EpubParser', '从 archive 获取章节 HTML 失败', e);
      return null;
    }
  }

  /// 根据锚点 ID 从完整 HTML 中提取对应元素的片段
  String? _extractChapterByAnchor(String fullHtml, String anchor) {
    try {
      final anchorPattern = RegExp('(id|name)\\s*=\\s*["\']?$anchor["\']?', caseSensitive: false);
      final anchorMatch = anchorPattern.firstMatch(fullHtml);

      if (anchorMatch == null) {
        _log.w('EpubParser', '未找到锚点：$anchor');
        return null;
      }

      final startPos = anchorMatch.start;

      int elementStart = startPos;
      int searchCount = 0;
      while (elementStart > 0 && fullHtml[elementStart - 1] != '<' && searchCount < 500) {
        elementStart--;
        searchCount++;
      }

      if (searchCount >= 500) {
        _log.w('EpubParser', '向前查找开始标签超时，使用当前位置');
      }

      int elementEnd = startPos;
      searchCount = 0;
      while (elementEnd < fullHtml.length && fullHtml[elementEnd] != '>' && searchCount < 500) {
        elementEnd++;
        searchCount++;
      }
      elementEnd++;

      if (searchCount >= 500) {
        _log.w('EpubParser', '向后查找结束标签超时');
      }

      final tagContent = fullHtml.substring(elementStart, elementEnd);

      final isSelfClosing = tagContent.endsWith('/>');

      if (isSelfClosing) {
        return tagContent;
      }

      final tagNameMatch = RegExp(r'<(\w+)').firstMatch(tagContent);
      if (tagNameMatch == null) {
        _log.w('EpubParser', '无法提取标签名');
        return null;
      }
      final tagName = tagNameMatch.group(1);

      final endTagPattern = RegExp('</$tagName\\s*>', caseSensitive: false);
      final endTagMatch = endTagPattern.firstMatch(fullHtml.substring(elementEnd));

      if (endTagMatch != null) {
        final chapterContent = fullHtml.substring(elementStart, elementEnd + endTagMatch.end);
        return chapterContent;
      } else {
        _log.w('EpubParser', '未找到结束标签，返回从锚点到文件末尾的内容');
        return fullHtml.substring(elementStart);
      }
    } catch (e) {
      _log.e('EpubParser', '提取锚点内容失败：anchor=$anchor', e);
      return null;
    }
  }
}

/// 内部章节信息（解析过程中的临时结构）
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
