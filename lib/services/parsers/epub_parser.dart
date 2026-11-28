import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../models/chapter.dart';
import '../../models/reader_typography.dart';
import 'book_format_parser.dart';
import 'epub_css_engine.dart';
import 'rendered_content.dart';
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
  Future<List<Chapter>> getChapters(String filePath) {
    // 解压与解析在较大书籍上会占用数百毫秒；放到后台 isolate 执行，
    // 避免阻塞 UI（从书架进入书籍详情页的转场动画期间尤其明显）。
    // isolate 内重新创建解析器：LogService 持有文件句柄，不能跨 isolate 传递。
    if (kIsWeb) return _readChapters(filePath);
    return Isolate.run(() => EpubParser()._readChapters(filePath));
  }

  /// 解析章节列表（在实际执行的 isolate 内完成解压与解析）
  Future<List<Chapter>> _readChapters(String filePath) async {
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
          return _convertToChapters(_injectImageTocEntries(bytes, chapterInfos));
        }
      }

      if (epubBook.content?.html.isNotEmpty == true) {
        chapterInfos.addAll(_extractChapterInfosFromContent(
            epubBook.content!.html, epubBook.schema?.package?.spine?.items));
        if (chapterInfos.isNotEmpty) {
          return _convertToChapters(_injectImageTocEntries(bytes, chapterInfos));
        }
      }
    } catch (e) {
      _log.w('EpubParser', 'EpubReader解析失败，使用archive回退方案');
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final chaptersFromNcx = _extractChapterInfosFromNcxArchive(archive);
    if (chaptersFromNcx.isNotEmpty) {
      return _convertToChapters(_injectImageTocEntries(bytes, chaptersFromNcx));
    }

    final flatChapters = _extractChapterInfosFromArchive(archive);
    return _convertToChapters(_injectImageTocEntries(bytes, flatChapters));
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

        coverImage ??= epubBook.content!.images.values.first;

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

    // 图片类章节（目录项指向独立图片）：直接生成单图页面
    if (_isImageHref(href)) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final page = _renderImageChapterPage(archive, href);
      return Chapter(
        bookId: chapter.bookId,
        index: chapter.index,
        title: chapter.title,
        location: chapter.location,
        level: chapter.level,
        htmlContent: page?.html ?? '',
      );
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
  Future<RenderedContent?> getChapterContentMerged(
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

    // 图片类章节（目录项指向独立图片）：生成单图页面，作为独立一页参与翻页
    final chapterHref = chapter.location.href;
    if (chapterHref != null && _isImageHref(chapterHref)) {
      return _renderImageChapterPage(archive, chapterHref);
    }

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

  /// 获取书籍开头（封面/版权页/插图/目录等前置页）的 HTML 内容
  ///
  /// 解析 content.opf 的 spine 顺序，合并从第一个内容文档到第一个正文顶层章节
  /// 之前的所有文档，使「阅读」按真实阅读顺序呈现前置页，而非只显示封面后直接
  /// 跳到第一章。无前置页（第一个内容文档即第一章）时返回 null，避免与第一章重复。
  @override
  Future<RenderedContent?> getOpeningContent(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('EpubParser', '文件不存在：$filePath');
      return null;
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final spineHrefs = _getSpineHtmlHrefs(archive);
    if (spineHrefs.isEmpty) return null;

    // 第一个「HTML」顶层章节的 href，用于界定前置页范围。
    // 注意跳过图片类章节（目录图片项被注入为独立章节，href 是图片文件而非 spine
    // 文档）；否则会把它当成首章节、导致所有 spine 文档都被当作前置页，整本书
    // 先作为开头页出现、再在图片页之后重复一遍。
    String? firstChapterHref;
    final chapters = await getChapters(filePath);
    for (final c in chapters) {
      final href = c.location.href;
      if (c.level == 0 && href != null && href.isNotEmpty && !_isImageHref(href)) {
        firstChapterHref = href;
        break;
      }
    }

    // 收集前置页：从 spine 第一个文档到第一个章节文档之前（不含）
    final openingHrefs = <String>[];
    if (firstChapterHref == null) {
      openingHrefs.add(spineHrefs.first);
    } else {
      for (final href in spineHrefs) {
        if (_sameFile(href, firstChapterHref)) break;
        openingHrefs.add(href);
      }
      // 第一个内容文档就是第一个章节（无真正的前置页）：返回 null，避免把第一章
      // 同时当作「开头页」和「第一章」重复出现（图片类目录项作为独立章节处理）。
      if (openingHrefs.isEmpty) return null;
    }

    final buffer = StringBuffer();
    for (final href in openingHrefs) {
      final htmlFile = _findHtmlFile(archive, href);
      if (htmlFile == null) continue;
      buffer.writeln(
          _extractBodyHtml(utf8.decode(htmlFile.content as List<int>)));
    }

    final merged = buffer.toString().trim();
    if (merged.isEmpty) return null;
    return _inlineCssAndImages(archive, merged, frontMatter: true);
  }

  /// href 是否指向图片资源
  bool _isImageHref(String href) {
    const imageExts = {
      '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg',
    };
    final lower = href.toLowerCase();
    final hash = lower.indexOf('#');
    final path = hash >= 0 ? lower.substring(0, hash) : lower;
    final dot = path.lastIndexOf('.');
    return dot >= 0 && imageExts.contains(path.substring(dot));
  }

  /// 生成「单张图片」页面 HTML（供图片类章节/独立页使用）
  ///
  /// 带 `data-zhidu-image-page` 标记，分页层据此把该章固定视为 1 页（1 个图片条目
  /// = 1 页，与图片像素尺寸无关，不做测量）；图片本身在阅读视图中以
  /// 「等比缩放填充整页」渲染（见 PagedReadingView），`src` 已内联为 data URI。
  RenderedContent? _renderImageChapterPage(Archive archive, String href) {
    final html = '<html><body>'
        '<div data-zhidu-image-page="1" style="text-align: center">'
        '<img src="$href" />'
        '</div></body></html>';
    return _inlineCssAndImages(archive, html);
  }

  /// 把目录中「指向独立图片」的条目插入章节列表，使其成为可翻页的独立一页
  ///
  /// 部分书籍（Calibre 生成常见）把「封面」等图片作为目录项直接指向图片文件，
  /// 但没有任何 HTML 页面包含它。这里以第一个顶层章节的 HTML 作为目录页，读取其
  /// 链接顺序：图片项插入到「前一个可匹配章节」之后（无则最前），从而在阅读顺序
  /// 中位于上一项末页与下一项首页之间，并作为普通章节参与分页/翻页/页码。
  List<_ChapterInfoInternal> _injectImageTocEntries(
      Uint8List bytes, List<_ChapterInfoInternal> infos) {
    if (infos.isEmpty) return infos;
    final firstTop =
        infos.firstWhere((i) => i.level == 0, orElse: () => infos.first);
    final firstHref = firstTop.href;
    if (firstHref == null || firstHref.isEmpty) return infos;

    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final tocHref = _stripAnchor(firstHref);
      final tocFile = _findHtmlFile(archive, tocHref);
      if (tocFile == null) return infos;

      final doc = html_parser.parse(utf8.decode(tocFile.content as List<int>));
      final tocDir = _dirnameOf(tocHref);

      int matchIndex(String target) {
        final targetAnchor = _anchorOf(target);
        var fallback = -1;
        for (var i = 0; i < infos.length; i++) {
          final h = infos[i].href;
          if (h == null || h.isEmpty || !_sameFile(h, target)) continue;
          if (fallback < 0) fallback = i;
          if (targetAnchor.isNotEmpty && _anchorOf(h) == targetAnchor) return i;
        }
        return fallback;
      }

      final entries = <_TocEntry>[];
      for (final a in doc.querySelectorAll('a')) {
        final href = a.attributes['href'];
        final text = a.text.trim();
        if (href == null || href.isEmpty || text.isEmpty) continue;
        if (_isImageHref(href)) {
          entries
              .add(_TocEntry.image(text, _joinPath(tocDir, _stripAnchor(href))));
        } else {
          final idx = matchIndex(href);
          if (idx >= 0) entries.add(_TocEntry.chapter(idx));
        }
      }
      if (!entries.any((e) => e.isImage)) return infos;

      final insertions = <int, List<_ChapterInfoInternal>>{};
      var lastChapterIdx = -1;
      for (final e in entries) {
        if (e.isImage) {
          final target = lastChapterIdx >= 0 ? lastChapterIdx + 1 : 0;
          insertions.putIfAbsent(target, () => []).add(_ChapterInfoInternal(
              title: e.title!, href: e.imageHref, level: 0));
        } else {
          lastChapterIdx = e.index;
        }
      }
      if (insertions.isEmpty) return infos;

      final result = <_ChapterInfoInternal>[];
      for (var i = 0; i <= infos.length; i++) {
        final add = insertions[i];
        if (add != null) result.addAll(add);
        if (i < infos.length) result.add(infos[i]);
      }
      return result;
    } catch (_) {
      return infos;
    }
  }

  static String _stripAnchor(String href) {
    final h = href.indexOf('#');
    return h >= 0 ? href.substring(0, h) : href;
  }

  static String _anchorOf(String href) {
    final h = href.indexOf('#');
    return h >= 0 ? href.substring(h + 1) : '';
  }

  static String _dirnameOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final i = normalized.lastIndexOf('/');
    return i < 0 ? '' : normalized.substring(0, i);
  }

  static String _joinPath(String dir, String href) {
    if (href.startsWith('/')) return href.substring(1);
    return dir.isEmpty ? href : '$dir/$href';
  }

  /// 解析 content.opf 的 spine，按阅读顺序返回所有内容文档（HTML/XHTML）的 href
  List<String> _getSpineHtmlHrefs(Archive archive) {
    try {
      ArchiveFile? opfFile;
      for (final f in archive.files) {
        if (f.name.toLowerCase().endsWith('.opf')) {
          opfFile = f;
          break;
        }
      }
      if (opfFile == null) return const [];

      final document =
          XmlDocument.parse(utf8.decode(opfFile.content as List<int>));

      // manifest：id → href
      final manifest = <String, String>{};
      for (final item in document.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) {
          manifest[id] = href;
        }
      }

      final result = <String>[];
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
        result.add(href);
      }
      return result;
    } catch (e) {
      _log.w('EpubParser', '解析 spine 失败: $e');
      return const [];
    }
  }

  /// 按 href 在 archive 中定位 HTML/XHTML 文件
  ArchiveFile? _findHtmlFile(Archive archive, String href) {
    final lower = href.toLowerCase();
    for (final f in archive.files) {
      final n = f.name.toLowerCase();
      if (n == lower || n.endsWith('/$lower') || n.endsWith(lower)) {
        return f;
      }
    }
    return null;
  }

  /// 判断两个资源 href 是否指向同一文件（忽略锚点/查询串/大小写/目录前缀差异）
  bool _sameFile(String a, String b) {
    String norm(String s) {
      s = s.replaceAll('\\', '/');
      final hash = s.indexOf('#');
      if (hash >= 0) s = s.substring(0, hash);
      final q = s.indexOf('?');
      if (q >= 0) s = s.substring(0, q);
      return s.toLowerCase();
    }

    final na = norm(a);
    final nb = norm(b);
    if (na == nb) return true;
    return na.endsWith('/$nb') || nb.endsWith('/$na');
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

          return _inlineCssAndImages(archive, result).html;
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
  /// 会丢失排版效果。这里交给 [EpubCssEngine] 完成 CSS 级联内联、图片转 data URI，
  /// 并提取 @font-face 字体，使渲染层（flutter_widget_from_html）能完整还原排版。
  RenderedContent _inlineCssAndImages(Archive archive, String html,
      {bool frontMatter = false}) {
    return EpubCssEngine(archive, identifier: _readUniqueIdentifier(archive))
        .render(html, frontMatter: frontMatter);
  }

  /// 读取 OPF 中由 package 的 unique-identifier 指定的 dc:identifier，
  /// 用于 IDPF 字体混淆的反混淆。
  String _readUniqueIdentifier(Archive archive) {
    try {
      for (final f in archive.files) {
        if (!f.name.toLowerCase().endsWith('.opf')) continue;
        final document = XmlDocument.parse(utf8.decode(f.content as List<int>));

        String? uniqueId;
        for (final packageEl in document.findAllElements('package')) {
          uniqueId = packageEl.getAttribute('unique-identifier');
          if (uniqueId != null) break;
        }

        final identifiers = document.findAllElements('dc:identifier');
        if (uniqueId != null) {
          for (final idEl in identifiers) {
            if (idEl.getAttribute('id') == uniqueId) {
              return idEl.innerText.trim();
            }
          }
        }
        if (identifiers.isNotEmpty) {
          return identifiers.first.innerText.trim();
        }
      }
    } catch (_) {
      // 忽略，无标识符时跳过字体反混淆
    }
    return '';
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
      // 循环停在 '<' 之后的第一个字符，需再回退一格把 '<' 本身包含进来，
      // 否则片段会以标签名开头（如 `a href="...">`），被当作纯文本渲染出源码。
      int elementStart = anchorMatch.start;
      while (elementStart > 0 && fullHtml[elementStart - 1] != '<') {
        elementStart--;
      }
      if (elementStart > 0) elementStart--;

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

  /// 读取书籍原始排版（字号/行距/段距）
  ///
  /// 做法：把一段探针 HTML 交给 EpubCssEngine 套用书籍 CSS，再读取其内联样式。
  /// - 字号：相对单位（em/%/关键字）按应用默认字号 21px 换算，绝对单位取原值
  /// - 行距：无单位倍数或百分比/像素换算为倍数
  /// - 段距：p 的 margin-bottom 换算为「字号 × 系数」
  /// 解析失败或书籍未定义时返回 null（由调用方回退应用默认值）。
  @override
  Future<ReaderTypography?> getReaderTypography(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final result = await Isolate.run(() => _probeTypography(bytes));
      _log.d('EpubParser', '书籍原始排版: $result');
      return result;
    } catch (e) {
      _log.w('EpubParser', '解析书籍原始排版失败: $e');
      return null;
    }
  }

  /// 探针 HTML：用书籍 CSS 计算正文与段落的实际样式（静态方法，可跨 isolate）
  static ReaderTypography? _probeTypography(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final rendered = EpubCssEngine(archive)
        .render('<html><head></head><body><p>正</p></body></html>');

    final doc = html_parser.parse(rendered.html);
    // body 级样式可能被渲染器移到包裹 div 上，两处合并读取
    final bodyStyle = <String, String>{
      ..._inlineDeclarations(doc.body?.attributes['style']),
      ..._inlineDeclarations(doc.querySelector('div[style]')?.attributes['style']),
    };
    final pStyle = _inlineDeclarations(
        doc.querySelector('p')?.attributes['style']);

    // 相对字号以应用默认字号为基准，避免书籍「1em」把正文字号压到 16px
    const appDefaultFont = 21.0;
    final bodyFont = _fontSizePx(bodyStyle['font-size'], appDefaultFont);
    final font = _fontSizePx(pStyle['font-size'], bodyFont ?? appDefaultFont) ??
        bodyFont;

    final lineRaw = pStyle['line-height'] ?? bodyStyle['line-height'];
    final lineHeight = _lineHeightMultiplier(lineRaw, font ?? appDefaultFont);

    final spacing = _paragraphSpacingFactor(pStyle, font ?? appDefaultFont);

    final result = ReaderTypography(
      fontSize: font,
      lineHeight: lineHeight,
      paragraphSpacing: spacing,
    );
    return result.isEmpty ? null : result;
  }

  /// 解析内联 style 属性（并展开 margin 简写）
  static Map<String, String> _inlineDeclarations(String? style) {
    final map = <String, String>{};
    if (style == null || style.isEmpty) return map;

    for (final part in style.split(';')) {
      final index = part.indexOf(':');
      if (index <= 0) continue;
      map[part.substring(0, index).trim().toLowerCase()] =
          part.substring(index + 1).trim();
    }

    final margin = map['margin'];
    if (margin != null) {
      final parts = margin
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        map['margin-bottom'] ??=
            parts.length >= 3 ? parts[2] : parts[0];
      }
    }
    return map;
  }

  /// 字号换算为 px（相对单位基于 [basePx]）
  static double? _fontSizePx(String? raw, double basePx) {
    if (raw == null || raw.isEmpty) return null;

    const keywordRatios = {
      'xx-small': 0.6,
      'x-small': 0.7,
      'small': 0.8,
      'medium': 1.0,
      'large': 1.2,
      'x-large': 1.5,
      'xx-large': 2.0,
    };
    final value = raw.trim().toLowerCase();
    final ratio = keywordRatios[value];
    if (ratio != null) return (basePx * ratio).clamp(12.0, 40.0);

    final px = _resolveLength(value, basePx);
    return px?.clamp(12.0, 40.0);
  }

  /// 行距换算为倍数（无单位 / % / 像素）
  static double? _lineHeightMultiplier(String? raw, double fontPx) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value == 'normal') return null;

    final unitless = double.tryParse(value);
    if (unitless != null) {
      return unitless >= 1.0 && unitless <= 4.0 ? unitless : null;
    }

    final px = _resolveLength(value, fontPx);
    if (px == null || fontPx <= 0) return null;
    final ratio = px / fontPx;
    return ratio >= 1.0 && ratio <= 4.0 ? ratio : null;
  }

  /// 段距系数 = p 的 margin-bottom / 字号
  static double? _paragraphSpacingFactor(
      Map<String, String> pStyle, double fontPx) {
    final raw = pStyle['margin-bottom'];
    if (raw == null) return null;
    final px = _resolveLength(raw, fontPx);
    if (px == null || fontPx <= 0) return null;
    return (px / fontPx).clamp(0.0, 3.0);
  }

  /// CSS 长度换算为 px（相对单位基于 [basePx]，无单位返回 null）
  static double? _resolveLength(String raw, double basePx) {
    final value = raw.trim().toLowerCase();
    final match = RegExp(r'^(-?\d+(?:\.\d+)?)\s*(px|pt|pc|in|cm|mm|em|rem|ex|%)?$')
        .firstMatch(value);
    if (match == null) return null;

    final number = double.parse(match.group(1)!);
    switch (match.group(2)) {
      case 'px':
        return number;
      case 'pt':
        return number * 4 / 3;
      case 'pc':
        return number * 16;
      case 'in':
        return number * 96;
      case 'cm':
        return number * 96 / 2.54;
      case 'mm':
        return number * 96 / 25.4;
      case 'em':
      case 'rem':
        return number * basePx;
      case 'ex':
        return number * basePx * 0.5;
      case '%':
        return number / 100 * basePx;
      default:
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

/// 目录解析中间项：指向图片的条目 或 已匹配到的章节下标
class _TocEntry {
  final String? title;
  final String? imageHref;
  final int index;

  const _TocEntry.image(this.title, this.imageHref) : index = -1;
  const _TocEntry.chapter(this.index)
      : title = null,
        imageHref = null;

  bool get isImage => imageHref != null;
}
