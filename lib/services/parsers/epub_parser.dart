import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

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

        if (epubBook.authors.isNotEmpty) {
          author = epubBook.authors.join(', ');
        }

        if (epubBook.chapters.isNotEmpty) {
          totalChapters = _countChapters(epubBook.chapters);
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

      // 解析 OPF 获取出版方与出版时间（EPUB 内部元数据）
      String? publisher;
      String? publishDate;
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        final opfInfo = _parseOpfFile(archive);
        publisher = opfInfo?['publisher'];
        publishDate = opfInfo?['date'];
      } catch (_) {
        _log.w('EpubParser', '解析出版方/出版时间失败');
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
        publisher: publisher,
        publishDate: publishDate,
      );
    } catch (e, stackTrace) {
      _log.e('EpubParser', '解析 EPUB 元数据失败', e, stackTrace);
      return null;
    }
  }

  @override
  Future<BookMetadata?> extractBasicMetadata(String filePath, String bookId) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final opfInfo = _parseOpfFile(archive);
      final title = opfInfo?['title'];
      final author = opfInfo?['author'];
      final language = opfInfo?['language'];
      final publisher = opfInfo?['publisher'];
      final publishDate = opfInfo?['date'];

      final coverPath = await _extractCoverFromArchiveObject(archive, bookId);

      return BookMetadata(
        title: (title == null || title.isEmpty)
            ? _extractTitleFromPath(filePath)
            : title,
        author: (author == null || author.isEmpty) ? '未知作者' : author,
        totalChapters: 0,
        coverPath: coverPath,
        language: language,
        publisher: publisher,
        publishDate: publishDate,
      );
    } catch (e, stackTrace) {
      _log.e('EpubParser', '轻量提取基本信息失败', e, stackTrace);
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

      if (epubBook.content?.html.isNotEmpty == true) {
        chapterInfos.addAll(_extractChapterInfosFromContent(
            epubBook.content!.html, epubBook.schema?.package?.spine?.items));
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
      if (chapter.subChapters.isNotEmpty) {
        count += _countChapters(chapter.subChapters);
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
      String? publisher;
      String? publishDate;

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

      final publisherElements = document.findAllElements('dc:publisher');
      if (publisherElements.isNotEmpty) {
        publisher = publisherElements.first.innerText.trim();
      }

      final dateElements = document.findAllElements('dc:date');
      if (dateElements.isNotEmpty) {
        publishDate = dateElements.first.innerText.trim();
      }

      return {
        'title': title,
        'author': author,
        'language': language,
        'publisher': publisher,
        'date': publishDate,
      };
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

      if (epubBook.content?.images.isNotEmpty == true) {
        EpubByteContentFile? coverImage;

        for (final entry in epubBook.content!.images.entries) {
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
      return await _extractCoverFromArchiveObject(archive, bookId);
    } catch (e) {
      _log.w('EpubParser', 'archive 回退方案也未找到封面');
      return null;
    }
  }

  /// 从已解码的 archive 中提取封面图片（供轻量导入复用，避免重复解压）
  Future<String?> _extractCoverFromArchiveObject(
      Archive archive, String bookId) async {
    try {
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
      _log.w('EpubParser', '从 archive 提取封面失败');
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

  /// 获取顶层章节的完整内容（含其下所有子章节，以第一级章节为边界）
  ///
  /// EPUB 的目录常把同一文件（锚点）或不同文件拆成多级 navPoint。
  /// 阅读与缩写应以第一级章节为最小单位，因此这里将顶层章节与其后连续的
  /// 子章节（level>0）内容按目录顺序合并，避免把子章节拆成独立片段。
  @override
  Future<String?> getChapterContentMerged(
      String filePath, Chapter chapter, List<Chapter> allChapters) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('EpubParser', '文件不存在：$filePath');
      return null;
    }

    final group = _collectChapterGroup(allChapters, chapter);
    if (group.isEmpty) return null;

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final buffer = StringBuffer();
    // 已整文件读取的文件名（小写），用于去重：同一文件内的子章节锚点不再重复提取
    final readFullFiles = <String>{};

    for (final c in group) {
      final href = c.location.href;
      if (href == null || href.isEmpty) continue;

      final parts = href.split('#');
      final fileName = parts[0];
      final anchor = parts.length > 1 ? parts[1] : null;

      // 定位 archive 中对应的文件
      ArchiveFile? archiveFile;
      final fileNameLower = fileName.toLowerCase();
      for (final f in archive.files) {
        final nameLower = f.name.toLowerCase();
        if (nameLower == fileNameLower ||
            nameLower.endsWith('/$fileNameLower') ||
            nameLower.endsWith(fileNameLower)) {
          archiveFile = f;
          break;
        }
      }
      if (archiveFile == null) continue;

      final fullHtml = utf8.decode(archiveFile.content as List<int>);
      final fileKey = archiveFile.name.toLowerCase();

      if (anchor == null || anchor.isEmpty) {
        // 无锚点：整个文件都属于本顶层章节（含其子章节），只读一次
        if (readFullFiles.contains(fileKey)) continue;
        buffer.writeln(_extractBodyHtml(fullHtml));
        readFullFiles.add(fileKey);
      } else {
        // 有锚点：文件已整读则跳过，否则按锚点范围提取片段
        if (readFullFiles.contains(fileKey)) continue;
        final fragment = _extractChapterByAnchor(fullHtml, anchor);
        if (fragment != null && fragment.isNotEmpty) {
          buffer.writeln(fragment);
        }
      }
    }

    final merged = buffer.toString().trim();
    if (merged.isEmpty) return null;
    return _inlineCssAndImages(archive, merged);
  }

  /// 获取书籍第一页（开头）的 HTML 内容
  ///
  /// 解析 content.opf 的 spine 顺序，取第一个内容文档（如标题页）的完整 HTML，
  /// 并内联 CSS 与图片（与章节内容一致的处理）。无开头页时返回 null。
  @override
  Future<String?> getOpeningContent(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('EpubParser', '文件不存在：$filePath');
      return null;
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final fullHtml = _getFirstSpineHtml(archive);
    if (fullHtml == null || fullHtml.isEmpty) return null;
    return _inlineCssAndImages(archive, fullHtml);
  }

  /// 解析 content.opf 的 spine，返回第一个内容文档（HTML/XHTML）的完整 HTML
  String? _getFirstSpineHtml(Archive archive) {
    try {
      ArchiveFile? opfFile;
      for (final f in archive.files) {
        if (f.name.toLowerCase().endsWith('.opf')) {
          opfFile = f;
          break;
        }
      }
      if (opfFile == null) return null;

      final document = XmlDocument.parse(utf8.decode(opfFile.content as List<int>));

      // manifest：id → href
      final manifest = <String, String>{};
      for (final item in document.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) {
          manifest[id] = href;
        }
      }

      // spine 按阅读顺序排列，取第一个内容文档
      for (final itemref in document.findAllElements('itemref')) {
        final idref = itemref.getAttribute('idref');
        final href = idref != null ? manifest[idref] : null;
        if (href == null || href.isEmpty) continue;

        final lower = href.toLowerCase();
        if (!lower.endsWith('.html') &&
            !lower.endsWith('.xhtml') &&
            !lower.endsWith('.htm')) {
          continue;
        }

        ArchiveFile? htmlFile;
        for (final f in archive.files) {
          final n = f.name.toLowerCase();
          if (n == lower || n.endsWith('/$lower') || n.endsWith(lower)) {
            htmlFile = f;
            break;
          }
        }
        if (htmlFile != null) {
          return utf8.decode(htmlFile.content as List<int>);
        }
      }
      return null;
    } catch (e) {
      _log.w('EpubParser', '解析 spine 首文件失败: $e');
      return null;
    }
  }

  /// 收集顶层章节及其后连续的子章节（level>0），直到下一个顶层章节为止
  List<Chapter> _collectChapterGroup(
      List<Chapter> allChapters, Chapter topChapter) {
    final result = <Chapter>[];
    int start = -1;

    for (int i = 0; i < allChapters.length; i++) {
      if (identical(allChapters[i], topChapter)) {
        start = i;
        break;
      }
    }
    // 引用不匹配时回退到 index 定位
    if (start < 0) {
      for (int i = 0; i < allChapters.length; i++) {
        if (allChapters[i].level == 0 &&
            allChapters[i].index == topChapter.index) {
          start = i;
          break;
        }
      }
    }
    if (start < 0) return result;

    result.add(allChapters[start]);
    for (int i = start + 1; i < allChapters.length; i++) {
      if (allChapters[i].level == 0) break;
      result.add(allChapters[i]);
    }
    return result;
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

          final String result;
          if (anchor == null || anchor.isEmpty) {
            result = fullHtml;
          } else {
            final chapterHtml = _extractChapterByAnchor(fullHtml, anchor);
            if (chapterHtml != null) {
              _log.d('EpubParser', '成功提取锚点 #$anchor 对应的章节内容');
              result = chapterHtml;
            } else {
              _log.w('EpubParser', '未找到锚点 #$anchor，返回整个文件内容');
              result = fullHtml;
            }
          }

          return _inlineCssAndImages(archive, result);
        }
      }

      _log.w('EpubParser', '未找到文件：$hrefWithoutAnchor');
      return null;
    } catch (e) {
      _log.e('EpubParser', '从 archive 获取章节 HTML 失败', e);
      return null;
    }
  }

  /// 将章节 HTML 处理为自包含内容：内联 EPUB CSS、图片转 base64、移除 link/style
  ///
  /// EPUB 正文的样式通常依赖外部 CSS 文件与内部图片资源，直接渲染原始 HTML
  /// 会丢失排版效果。这里将 CSS 规则内联到元素的 style 属性、图片转为 data URI，
  /// 使渲染层（flutter_html）能完整还原各种效果。
  String _inlineCssAndImages(Archive archive, String html) {
    try {
      final document = html_parser.parse(html);

      // 1. 收集所有 CSS：EPUB 内全部 .css 文件 + 当前 HTML 的 <style> 块
      final cssBuffer = StringBuffer();
      for (final f in archive.files) {
        if (f.name.toLowerCase().endsWith('.css')) {
          cssBuffer.writeln(utf8.decode(f.content as List<int>));
        }
      }
      for (final styleEl in document.querySelectorAll('style')) {
        cssBuffer.writeln(styleEl.text);
      }

      // 2. 内联 CSS 到匹配元素（保持源顺序，后定义规则覆盖先定义）
      for (final rule in _parseCssRules(cssBuffer.toString())) {
        for (final sel in _splitSelectors(rule.key)) {
          try {
            for (final el in document.querySelectorAll(sel)) {
              final existing = el.attributes['style'];
              el.attributes['style'] = (existing == null || existing.isEmpty)
                  ? rule.value
                  : '$existing; ${rule.value}';
            }
          } catch (_) {
            // 忽略不支持的复杂选择器
          }
        }
      }

      // 3. 图片 src 转 base64 data URI
      for (final img in document.querySelectorAll('img')) {
        final src = img.attributes['src'];
        if (src == null || src.isEmpty || src.startsWith('data:')) continue;
        final dataUri = _resolveImageDataUri(archive, src);
        if (dataUri != null) {
          img.attributes['src'] = dataUri;
        }
      }

      // 3.1 SVG 内嵌图片（如 Calibre 封面 <svg><image xlink:href="cover.jpg"/></svg>）
      // flutter_html 无法渲染 SVG，将含图片的 <svg> 转为 <img> 以显示封面/插图。
      for (final svg in document.querySelectorAll('svg')) {
        final image = svg.querySelector('image');
        String? href;
        if (image != null) {
          // xlink:href 为命名空间属性，package:html 以 AttributeName 作为 key，
          // 无法用字符串直接索引，需遍历匹配。
          for (final entry in image.attributes.entries) {
            final key = entry.key.toString();
            if (key == 'xlink:href' || key == 'href') {
              href = entry.value;
              break;
            }
          }
        }
        if (href == null || href.isEmpty || href.startsWith('data:')) continue;
        final dataUri = _resolveImageDataUri(archive, href);
        if (dataUri == null) continue;

        final replacement = document.createElement('img');
        replacement.attributes['src'] = dataUri;
        replacement.attributes['alt'] = '';
        replacement.attributes['style'] = 'width:100%;height:auto;';
        svg.replaceWith(replacement);
      }

      // 4. 移除 link/style 标签（CSS 已内联，避免无效渲染）
      for (final el in document.querySelectorAll('link')) {
        el.remove();
      }
      for (final el in document.querySelectorAll('style')) {
        el.remove();
      }

      return document.body?.innerHtml ?? html;
    } catch (e) {
      _log.w('EpubParser', '内联 CSS/图片失败，返回原文: $e');
      return html;
    }
  }

  /// 按文件名在 archive 中查找图片并返回 data URI，找不到返回 null
  String? _resolveImageDataUri(Archive archive, String src) {
    // EPUB 中图片 src 常含 URL 编码（如空格 %20），需先解码再按文件名匹配
    final rawName = src.split('/').last.split('\\').last;
    final targetName = _urlDecode(rawName);
    final targetLower = targetName.toLowerCase();
    ArchiveFile? match;
    for (final f in archive.files) {
      final nameLower = f.name.toLowerCase();
      if (nameLower == targetLower || nameLower.endsWith('/$targetLower')) {
        match = f;
        break;
      }
    }
    if (match == null) return null;
    return 'data:${_mimeFromName(targetName)};base64,'
        '${base64Encode(match.content as List<int>)}';
  }

  /// 解析 CSS 文本为规则列表（key=选择器组，value=声明块）
  List<MapEntry<String, String>> _parseCssRules(String css) {
    final rules = <MapEntry<String, String>>[];
    final noComments = css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    for (final block in noComments.split('}')) {
      final braceIndex = block.indexOf('{');
      if (braceIndex < 0) continue;
      final selector = block.substring(0, braceIndex).trim();
      final declarations = block.substring(braceIndex + 1).trim();
      if (selector.isEmpty || declarations.isEmpty) continue;
      if (selector.startsWith('@')) continue; // 跳过 @media/@page/@font-face 等
      rules.add(MapEntry(selector, declarations));
    }
    return rules;
  }

  /// 将逗号分隔的选择器组拆分为单个选择器
  List<String> _splitSelectors(String selector) {
    return selector
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// URL 解码（如空格 %20、中文 %E4%B8%AD），解码失败时返回原文
  String _urlDecode(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }

  /// 根据文件名扩展名推断图片 MIME 类型
  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// 提取 HTML 的 body 内容（无 body 时返回原文）
  String _extractBodyHtml(String html) {
    final bodyMatch = RegExp(r'<body[^>]*>([\s\S]*)</body>', caseSensitive: false)
        .firstMatch(html);
    if (bodyMatch != null) return bodyMatch.group(1)!;
    return html;
  }

  /// 根据锚点 ID 从完整 HTML 中提取该章节的片段
  ///
  /// 返回从锚点元素（通常为标题标签）开始，到下一个标题（h1-h6）之前
  /// 或文件末尾的内容，即该章节的「标题 + 正文」完整范围。
  String? _extractChapterByAnchor(String fullHtml, String anchor) {
    try {
      final anchorPattern = RegExp('(id|name)\\s*=\\s*["\']?$anchor["\']?', caseSensitive: false);
      final anchorMatch = anchorPattern.firstMatch(fullHtml);

      if (anchorMatch == null) {
        _log.w('EpubParser', '未找到锚点：$anchor');
        return null;
      }

      // 定位锚点所属元素的起始标签 <
      int elementStart = anchorMatch.start;
      while (elementStart > 0 && fullHtml[elementStart - 1] != '<') {
        elementStart--;
      }

      // 提取锚点元素的标签名
      final tagNameMatch = RegExp(r'<(\w+)').firstMatch(fullHtml.substring(elementStart));
      if (tagNameMatch == null) {
        _log.w('EpubParser', '无法提取标签名');
        return null;
      }
      final tagName = tagNameMatch.group(1);

      // 锚点元素（标题）结束标签之后即为正文起点
      final endTagPattern = RegExp('</$tagName\\s*>', caseSensitive: false);
      final endTagMatch = endTagPattern.firstMatch(fullHtml.substring(anchorMatch.end));
      final int contentStart;
      if (endTagMatch != null) {
        contentStart = anchorMatch.end + endTagMatch.end;
      } else {
        contentStart = anchorMatch.end;
      }

      // 下一个标题（h1-h6）作为本段正文的结束边界
      final nextHeadingPattern = RegExp(r'<h[1-6][\s>]', caseSensitive: false);
      final nextHeadingMatch = nextHeadingPattern.firstMatch(fullHtml.substring(contentStart));
      final int contentEnd = nextHeadingMatch != null
          ? contentStart + nextHeadingMatch.start
          : fullHtml.length;

      return fullHtml.substring(elementStart, contentEnd);
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
