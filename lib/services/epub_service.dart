import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import '../models/book.dart';
import 'log_service.dart';

class EpubService {
  static final EpubService _instance = EpubService._internal();
  factory EpubService() => _instance;
  EpubService._internal();

  final _log = LogService();
  final _uuid = const Uuid();

  Future<Book?> parseEpubFile(String filePath) async {
    _log.v('EpubService', 'parseEpubFile 开始执行, filePath: $filePath');
    try {
      _log.d('EpubService', '开始解析文件 $filePath');
      final file = File(filePath);
      if (!await file.exists()) {
        _log.w('EpubService', '文件不存在: $filePath');
        return null;
      }

      _log.d('EpubService', '读取文件字节...');
      final bytes = await file.readAsBytes();
      _log.d('EpubService', '文件大小: ${bytes.length} bytes');

      _log.d('EpubService', '解析EPUB结构...');

      String? title;
      String? author;
      List<String> chapterTitles = [];

      try {
        final epubBook = await EpubReader.readBook(bytes);
        _log.d('EpubService', 'EPUB解析成功');
        _log.d('EpubService', 'epubBook.title = ${epubBook.title}');
        _log.d('EpubService', 'epubBook.authors = ${epubBook.authors}');
        _log.d(
            'EpubService', 'epubBook.chapters = ${epubBook.chapters?.length}');
        _log.d('EpubService', 'epubBook.schema = ${epubBook.schema != null}');
        _log.d('EpubService', 'epubBook.content = ${epubBook.content != null}');
        _log.d('EpubService',
            'epubBook.content?.images = ${epubBook.content?.images?.length}');
        _log.d('EpubService',
            'epubBook.content?.html = ${epubBook.content?.html?.length}');

        // 从 epubBook 获取元数据
        title = epubBook.title;

        // 获取作者
        if (epubBook.authors?.isNotEmpty == true) {
          author = epubBook.authors!.join(', ');
        }

        // 从 chapters 获取章节标题
        if (epubBook.chapters?.isNotEmpty == true) {
          chapterTitles = _extractChapterTitles(epubBook.chapters!);
        }

        _log.d('EpubService', '从EPUB元数据获取标题: $title');
        _log.d('EpubService', '从EPUB元数据获取作者: $author');
        _log.d('EpubService', '从导航获取章节数: ${chapterTitles.length}');
      } catch (e, stackTrace) {
        _log.e('EpubService', '使用EpubReader解析失败', e);
        _log.e('EpubService', '堆栈', stackTrace);
        _log.d('EpubService', '尝试使用archive直接解析EPUB...');

        // 回退方案：使用 archive 直接解析 EPUB
        final archive = ZipDecoder().decodeBytes(bytes);

        // 解析 container.xml 获取元数据
        final containerInfo = _parseContainerXml(archive);
        if (containerInfo != null) {
          title = containerInfo['title'];
          author = containerInfo['author'];
          _log.d('EpubService', '从container.xml获取标题: $title');
          _log.d('EpubService', '从container.xml获取作者: $author');
        }

        // 解析 OPF 文件获取元数据
        final opfInfo = _parseOpfFile(archive);
        if (opfInfo != null) {
          title ??= opfInfo['title'];
          author ??= opfInfo['author'];
          _log.d('EpubService', '从OPF获取标题: $title');
          _log.d('EpubService', '从OPF获取作者: $author');
        }

        // 解析 NCX/NAV 文件获取章节列表
        chapterTitles = _parseNavigationFile(archive);
        _log.d('EpubService', '从导航文件获取章节数: ${chapterTitles.length}');
      }

      if (title == null || title.isEmpty) {
        title = _extractTitleFromPath(filePath);
      }
      if (author == null || author.isEmpty) {
        author = '未知作者';
      }

      _log.d('EpubService', '最终书名: $title');
      _log.d('EpubService', '最终作者: $author');

      String? coverPath;
      try {
        coverPath = await _extractCover(bytes, filePath);
      } catch (e) {
        _log.e('EpubService', '封面提取失败', e);
      }
      _log.d('EpubService', '封面路径: $coverPath');

      return Book(
        id: _uuid.v4(),
        title: title,
        author: author,
        coverPath: coverPath,
        filePath: filePath,
        format: BookFormat.epub,
        totalChapters: chapterTitles.length,
        addedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      _log.e('EpubService', '解析EPUB文件失败', e);
      _log.e('EpubService', '堆栈', stackTrace);
      return null;
    }
  }

  List<String> _extractChapterTitles(List<EpubChapter> chapters) {
    final titles = <String>[];

    void traverseChapters(List<EpubChapter> chapters, int level) {
      for (final chapter in chapters) {
        if (chapter.title?.isNotEmpty == true) {
          titles.add(chapter.title!);
        }
        // 递归处理子章节
        if (chapter.subChapters?.isNotEmpty == true) {
          traverseChapters(chapter.subChapters!, level + 1);
        }
      }
    }

    traverseChapters(chapters, 0);
    return titles;
  }

  Future<String?> extractPrefaceContent(String filePath) async {
    _log.v('EpubService', 'extractPrefaceContent 开始执行, filePath: $filePath');
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();

      try {
        final epubBook = await EpubReader.readBook(bytes);

        final prefacePatterns = [
          '前言',
          '序言',
          '序',
          '自序',
          '代序',
          '引言',
          '导言',
          'preface',
          'introduction',
          'prologue',
        ];

        final List<String> foundContents = [];

        if (epubBook.chapters?.isNotEmpty == true) {
          for (final chapter in epubBook.chapters!) {
            final title = chapter.title?.toLowerCase() ?? '';
            for (final pattern in prefacePatterns) {
              if (title.contains(pattern.toLowerCase())) {
                final content = _extractTextFromHtml(chapter.htmlContent ?? '');
                if (content.isNotEmpty && content.length > 100) {
                  foundContents.add(content);
                  _log.d('EpubService', '找到前言/序言内容: ${chapter.title}');
                  break;
                }
              }
            }
          }
        }

        if (foundContents.isNotEmpty) {
          final combined = foundContents.take(3).join('\n\n');
          if (combined.length > 5000) {
            return combined.substring(0, 5000);
          }
          return combined;
        }
      } catch (e) {
        _log.e('EpubService', '使用EpubReader提取前言失败', e);
        _log.d('EpubService', '尝试使用archive回退方案...');
      }

      return await _extractPrefaceFromArchive(bytes);
    } catch (e) {
      _log.e('EpubService', '提取前言内容失败', e);
      return null;
    }
  }

  Future<String?> _extractPrefaceFromArchive(Uint8List bytes) async {
    _log.v('EpubService',
        '_extractPrefaceFromArchive 开始执行, bytes length: ${bytes.length}');
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      final prefacePatterns = [
        '前言',
        '序言',
        '序',
        '自序',
        '代序',
        '引言',
        '导言',
        'preface',
        'introduction',
        'prologue',
      ];

      final htmlFiles = <ArchiveFile>[];
      for (final file in archive.files) {
        final name = file.name.toLowerCase();
        if ((name.endsWith('.html') || name.endsWith('.xhtml')) &&
            !name.contains('nav') &&
            !name.contains('toc')) {
          htmlFiles.add(file);
        }
      }

      for (final htmlFile in htmlFiles) {
        final content = utf8.decode(htmlFile.content as List<int>);
        final title = _extractTitleFromHtml(content).toLowerCase();

        for (final pattern in prefacePatterns) {
          if (title.contains(pattern.toLowerCase())) {
            final text = _extractTextFromHtml(content);
            if (text.isNotEmpty && text.length > 100) {
              _log.d('EpubService', '从archive找到前言内容: $title');
              if (text.length > 5000) {
                return text.substring(0, 5000);
              }
              return text;
            }
          }
        }
      }

      return null;
    } catch (e) {
      _log.e('EpubService', '从archive提取前言失败', e);
      return null;
    }
  }

  String _extractTextFromHtml(String html) {
    _log.v('EpubService',
        '_extractTextFromHtml 开始执行, html length: ${html.length}');
    var text = html
        .replaceAll(
            RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&[a-z]+;'), '')
        .trim();

    _log.v('EpubService',
        '_extractTextFromHtml 执行完成, extracted text length: ${text.length}');
    return text;
  }

  String _extractTitleFromPath(String filePath) {
    _log.v('EpubService', '_extractTitleFromPath 开始执行, filePath: $filePath');
    final fileName = p.basenameWithoutExtension(filePath);
    final result = fileName.replaceAll('_', ' ').replaceAll('-', ' ');
    _log.v(
        'EpubService', '_extractTitleFromPath 执行完成, extracted title: $result');
    return result;
  }

  Map<String, String>? _parseContainerXml(Archive archive) {
    _log.v('EpubService',
        '_parseContainerXml 开始执行, archive files count: ${archive.files.length}');
    try {
      ArchiveFile? containerFile;
      for (final file in archive.files) {
        if (file.name.toLowerCase() == 'meta-inf/container.xml' ||
            file.name == 'META-INF/container.xml') {
          containerFile = file;
          break;
        }
      }

      if (containerFile == null) {
        _log.d('EpubService', '未找到 container.xml');
        return null;
      }

      final content = utf8.decode(containerFile.content as List<int>);
      final document = XmlDocument.parse(content);

      final rootfileElement = document.findAllElements('rootfile').firstOrNull;
      if (rootfileElement == null) {
        _log.d('EpubService', 'container.xml 中未找到 rootfile 元素');
        return null;
      }

      final opfPath = rootfileElement.getAttribute('full-path');
      if (opfPath == null) {
        _log.d('EpubService', '未找到 OPF 文件路径');
        return null;
      }

      _log.d('EpubService', 'OPF 文件路径: $opfPath');
      return {'opfPath': opfPath};
    } catch (e) {
      _log.e('EpubService', '解析 container.xml 失败', e);
      return null;
    }
  }

  Map<String, String?>? _parseOpfFile(Archive archive) {
    _log.v('EpubService',
        '_parseOpfFile 开始执行, archive files count: ${archive.files.length}');
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

      if (opfFile == null) {
        _log.d('EpubService', '未找到 OPF 文件');
        return null;
      }

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

      _log.d('EpubService', 'OPF 解析结果 - 标题: $title, 作者: $author');
      return {'title': title, 'author': author};
    } catch (e) {
      _log.e('EpubService', '解析 OPF 文件失败', e);
      return null;
    }
  }

  List<String> _parseNavigationFile(Archive archive) {
    _log.v('EpubService',
        '_parseNavigationFile 开始执行, archive files count: ${archive.files.length}');
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
          if (name.contains('nav.') && name.endsWith('.html') ||
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
        _log.d('EpubService', '未找到导航文件 (NCX 或 NAV)');
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
        final h1Pattern =
            RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>', caseSensitive: false);
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

      _log.d('EpubService', '从导航文件解析到 ${chapters.length} 个章节');
      return chapters;
    } catch (e) {
      _log.e('EpubService', '解析导航文件失败', e);
      return [];
    }
  }

  Future<String?> _extractCover(Uint8List bytes, String filePath) async {
    _log.v('EpubService',
        '_extractCover 开始执行, bytes length: ${bytes.length}, filePath: $filePath');
    try {
      _log.d('EpubService', '开始提取封面...');
      final epubBook = await EpubReader.readBook(bytes);
      _log.d('EpubService', 'EPUB解析成功，检查图片...');
      _log.d('EpubService', 'content = ${epubBook.content != null}');
      _log.d('EpubService',
          'content.images = ${epubBook.content?.images?.length}');

      if (epubBook.content?.images?.isNotEmpty == true) {
        _log.d('EpubService', '找到 ${epubBook.content!.images!.length} 张图片');

        for (final entry in epubBook.content!.images!.entries) {
          _log.d('EpubService', '图片文件: ${entry.key}');
        }

        EpubByteContentFile? coverImage;

        for (final entry in epubBook.content!.images!.entries) {
          final name = entry.key.toLowerCase();
          if (name.contains('cover') || name.contains('title')) {
            coverImage = entry.value;
            _log.d('EpubService', '找到封面图片: ${entry.key}');
            break;
          }
        }

        if (coverImage == null) {
          coverImage = epubBook.content!.images!.values.first;
          _log.d('EpubService', '使用第一张图片作为封面');
        }

        if (coverImage != null && coverImage.content != null) {
          _log.d('EpubService', '封面图片大小: ${coverImage.content!.length} bytes');
          _log.d('EpubService', '封面图片类型: ${coverImage.contentMimeType}');

          final appDir = Directory.current.path;
          final coversDir = '$appDir/Covers';

          final coversDirectory = Directory(coversDir);
          if (!await coversDirectory.exists()) {
            await coversDirectory.create(recursive: true);
          }

          final bookId = _uuid.v4();
          final extension = coverImage.contentMimeType?.contains('png') == true
              ? 'png'
              : 'jpg';
          final coverPath = '$coversDir/$bookId.$extension';

          final coverOutputFile = File(coverPath);
          await coverOutputFile.writeAsBytes(coverImage.content!);
          _log.d('EpubService', '封面保存成功: $coverPath');
          return coverPath;
        } else {
          _log.d('EpubService', '封面图片内容为空');
        }
      } else {
        _log.d('EpubService', '未找到任何图片');
      }
    } catch (e, stackTrace) {
      _log.e('EpubService', '提取封面失败', e);
      _log.e('EpubService', '堆栈', stackTrace);
    }

    _log.d('EpubService', '尝试从archive查找封面...');
    return await _extractCoverFromArchive(bytes, filePath);
  }

  Future<String?> _extractCoverFromArchive(
      Uint8List bytes, String filePath) async {
    _log.v('EpubService',
        '_extractCoverFromArchive 开始执行, bytes length: ${bytes.length}, filePath: $filePath');
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
        final appDir = Directory.current.path;
        final coversDir = '$appDir/Covers';

        final coversDirectory = Directory(coversDir);
        if (!await coversDirectory.exists()) {
          await coversDirectory.create(recursive: true);
        }

        final bookId = _uuid.v4();
        final extension =
            coverFile.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
        final coverPath = '$coversDir/$bookId.$extension';

        final coverOutputFile = File(coverPath);
        await coverOutputFile.writeAsBytes(coverFile.content as List<int>);

        return coverPath;
      }
    } catch (e) {
      _log.e('EpubService', '从archive提取封面失败', e);
    }
    return null;
  }

  Future<EpubBook?> loadEpubBook(String filePath) async {
    _log.v('EpubService', 'loadEpubBook 开始执行, filePath: $filePath');
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _log.v('EpubService', 'loadEpubBook 文件不存在, filePath: $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      _log.v(
          'EpubService', 'loadEpubBook 读取文件完成, bytes length: ${bytes.length}');
      final result = await EpubReader.readBook(bytes);
      _log.v('EpubService', 'loadEpubBook EPUB解析完成');
      return result;
    } catch (e) {
      _log.e('EpubService', '加载EPUB文件失败', e);
      return null;
    }
  }

  Future<EpubBook?> loadEpubFromBytes(Uint8List bytes) async {
    _log.v(
        'EpubService', 'loadEpubFromBytes 开始执行, bytes length: ${bytes.length}');
    try {
      final result = await EpubReader.readBook(bytes);
      _log.v('EpubService', 'loadEpubFromBytes 执行完成');
      return result;
    } catch (e) {
      _log.e('EpubService', '从字节加载EPUB失败', e);
      return null;
    }
  }

  Future<List<ChapterInfo>> getChapterList(String filePath) async {
    _log.v('EpubService', 'getChapterList 开始执行, filePath: $filePath');
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _log.v('EpubService', 'getChapterList 文件不存在, filePath: $filePath');
        return [];
      }

      final bytes = await file.readAsBytes();
      _log.v('EpubService',
          'getChapterList 读取文件完成, bytes length: ${bytes.length}');

      try {
        final epubBook = await EpubReader.readBook(bytes);

        if (epubBook.chapters.isNotEmpty) {
          final chapters = _extractChapterInfos(epubBook.chapters);
          if (chapters.isNotEmpty) {
            return chapters;
          }
        }

        if (epubBook.schema?.navigation?.navMap != null &&
            epubBook.schema!.navigation!.navMap!.points.isNotEmpty) {
          final chapters = _extractChapterInfosFromNavigation(
              epubBook.schema!.navigation!.navMap!.points);
          if (chapters.isNotEmpty) {
            return chapters;
          }
        }

        if (epubBook.content?.html?.isNotEmpty == true) {
          final chapters = _extractChapterInfosFromContent(
              epubBook.content!.html!, epubBook.schema?.package?.spine?.items);
          if (chapters.isNotEmpty) {
            return chapters;
          }
        }
      } catch (e) {
        // EpubReader解析失败，使用archive回退方案
      }

      final archive = ZipDecoder().decodeBytes(bytes);
      final chaptersFromNcx = _extractChapterInfosFromNcxArchive(archive);
      if (chaptersFromNcx.isNotEmpty) {
        return chaptersFromNcx;
      }
      return _extractChapterInfosFromArchive(archive);
    } catch (e) {
      _log.e('EpubService', '获取章节列表失败', e);
      return [];
    }
  }

  List<ChapterInfo> _extractChapterInfosFromNcxArchive(Archive archive) {
    try {
      ArchiveFile? ncxFile;
      for (final file in archive.files) {
        if (file.name.toLowerCase().endsWith('.ncx')) {
          ncxFile = file;
          break;
        }
      }

      if (ncxFile == null) {
        return [];
      }

      final content = utf8.decode(ncxFile.content as List<int>);
      final document = XmlDocument.parse(content);
      final allNavPoints = document.findAllElements('navPoint');

      final chapters = <ChapterInfo>[];

      void parseNavPoints(Iterable<XmlElement> points) {
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
              chapters.add(ChapterInfo(
                title: title,
                href: href,
                level: 0,
                children: [],
              ));
            }
          }

          final childNavPoints = navPoint.findElements('navPoint');
          if (childNavPoints.isNotEmpty) {
            parseNavPoints(childNavPoints);
          }
        }
      }

      if (allNavPoints.isNotEmpty) {
        parseNavPoints(allNavPoints);
      }

      return chapters;
    } catch (e) {
      _log.e('EpubService', '从archive解析toc.ncx失败', e);
      return [];
    }
  }

  List<ChapterInfo> _extractChapterInfosFromNavigation(
      List<EpubNavigationPoint> navPoints) {
    _log.v('EpubService',
        '_extractChapterInfosFromNavigation 开始执行, navPoints count: ${navPoints.length}');
    final result = <ChapterInfo>[];

    void traverseNavPoints(List<EpubNavigationPoint> points, int level) {
      for (final point in points) {
        final title = point.navigationLabels.isNotEmpty
            ? point.navigationLabels.first.text ?? '未知章节'
            : '未知章节';
        final href = point.content?.source;
        result.add(ChapterInfo(
          title: title,
          href: href,
          level: level,
          children: [],
        ));
        // 递归处理子导航点
        if (point.childNavigationPoints.isNotEmpty) {
          traverseNavPoints(point.childNavigationPoints, level + 1);
        }
      }
    }

    traverseNavPoints(navPoints, 0);
    return result;
  }

  List<ChapterInfo> _extractChapterInfosFromContent(
      Map<String, EpubTextContentFile> htmlFiles,
      List<EpubSpineItemRef>? spineItems) {
    _log.v('EpubService',
        '_extractChapterInfosFromContent 开始执行, htmlFiles count: ${htmlFiles.length}, spineItems count: ${spineItems?.length ?? 0}');
    final result = <ChapterInfo>[];

    // 如果有 spine，按照 spine 的顺序
    if (spineItems?.isNotEmpty == true) {
      for (final spineItem in spineItems!) {
        final idRef = spineItem.idRef;
        // 在 htmlFiles 中查找对应的文件
        for (final entry in htmlFiles.entries) {
          // 这里需要根据 idRef 找到对应的文件
          // 简化处理：使用文件名
          final fileName = entry.key;
          if (fileName.toLowerCase().contains(idRef?.toLowerCase() ?? '')) {
            result.add(ChapterInfo(
              title: _extractTitleFromHtml(entry.value.content ?? ''),
              href: fileName,
              level: 0,
              children: [],
            ));
            break;
          }
        }
      }
    } else {
      // 没有 spine，按文件名排序
      final sortedFiles = htmlFiles.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      for (final entry in sortedFiles) {
        // 排除 nav 和 toc 文件
        final name = entry.key.toLowerCase();
        if (!name.contains('nav') && !name.contains('toc')) {
          result.add(ChapterInfo(
            title: _extractTitleFromHtml(entry.value.content ?? ''),
            href: entry.key,
            level: 0,
            children: [],
          ));
        }
      }
    }

    return result;
  }

  String _extractTitleFromHtml(String html) {
    // 尝试从 HTML 中提取 title
    final titleMatch =
        RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false)
            .firstMatch(html);
    if (titleMatch != null) {
      final title = titleMatch.group(1)?.trim();
      if (title?.isNotEmpty == true) {
        return title!;
      }
    }

    // 尝试从 h1 标签提取
    final h1Match =
        RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false).firstMatch(html);
    if (h1Match != null) {
      final title = _extractTextFromHtml(h1Match.group(1) ?? '').trim();
      if (title.isNotEmpty) {
        return title;
      }
    }

    // 尝试从 h2 标签提取
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

  Future<List<ChapterInfo>> getHierarchicalChapterList(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return [];

      final bytes = await file.readAsBytes();

      try {
        final epubBook = await EpubReader.readBook(bytes);

        _log.d('EpubService', 'EPUB解析成功');

        // 优先从 toc.ncx (navigation) 提取章节顺序
        if (epubBook.schema?.navigation?.navMap != null &&
            epubBook.schema!.navigation!.navMap!.points.isNotEmpty) {
          _log.d('EpubService', '从 toc.ncx (navigation) 提取章节列表');
          final chapters = _extractChapterInfosFromNavigation(
              epubBook.schema!.navigation!.navMap!.points);
          if (chapters.isNotEmpty) {
            return chapters;
          }
        }

        // 如果没有 navigation，尝试从 chapters 提取
        if (epubBook.chapters.isNotEmpty) {
          _log.d('EpubService', '从 epubBook.chapters 提取章节列表');
          final chapters = _extractChapterInfos(epubBook.chapters);
          if (chapters.isNotEmpty) {
            return chapters;
          }
        }

        // 最后尝试从 content 提取
        if (epubBook.content?.html?.isNotEmpty == true) {
          _log.d('EpubService', '从 content.html 提取章节列表');
          final chapters = _extractChapterInfosFromContent(
              epubBook.content!.html!, epubBook.schema?.package?.spine?.items);
          if (chapters.isNotEmpty) {
            return chapters;
          }
        }
      } catch (e) {
        _log.e('EpubService', 'EpubReader解析失败，使用archive回退方案', e);
      }

      // 回退方案：使用archive解析，优先从toc.ncx提取
      final archive = ZipDecoder().decodeBytes(bytes);
      final chaptersFromNcx = _extractChapterInfosFromNcxArchive(archive);

      if (chaptersFromNcx.isNotEmpty) {
        return chaptersFromNcx;
      }

      // 如果toc.ncx解析失败，使用文件名排序作为最终回退
      final flatChapters = _extractChapterInfosFromArchive(archive);

      // 将扁平化章节转换为层级化结构（所有章节都设为同一层级）
      final hierarchicalChapters = <ChapterInfo>[];
      for (final chapter in flatChapters) {
        hierarchicalChapters.add(ChapterInfo(
          title: chapter.title,
          href: chapter.href,
          level: 0,
          children: [],
        ));
      }

      return hierarchicalChapters;
    } catch (e) {
      _log.e('EpubService', '获取层级章节列表失败', e);
      return [];
    }
  }

  List<ChapterInfo> _extractChapterInfos(List<EpubChapter> chapters) {
    final result = <ChapterInfo>[];

    void traverseChapters(List<EpubChapter> chapters, int level) {
      for (final chapter in chapters) {
        result.add(ChapterInfo(
          title: chapter.title ?? '未知章节',
          href: chapter.contentFileName,
          level: level,
          children: [],
        ));
        // 递归处理子章节
        if (chapter.subChapters?.isNotEmpty == true) {
          traverseChapters(chapter.subChapters!, level + 1);
        }
      }
    }

    traverseChapters(chapters, 0);
    return result;
  }

  List<ChapterInfo> _extractHierarchicalChapterInfos(
      List<EpubChapter> chapters) {
    final result = <ChapterInfo>[];

    for (final chapter in chapters) {
      final children = chapter.subChapters?.isNotEmpty == true
          ? _extractHierarchicalChapterInfos(chapter.subChapters!)
          : <ChapterInfo>[];

      result.add(ChapterInfo(
        title: chapter.title ?? '未知章节',
        href: chapter.contentFileName,
        level: 0, // 顶层章节
        children: children,
      ));
    }

    return result;
  }

  // 将层级化的章节列表扁平化（用于兼容现有代码）
  List<ChapterInfo> flattenChapters(List<ChapterInfo> hierarchicalChapters) {
    final flat = <ChapterInfo>[];

    void flatten(List<ChapterInfo> chapters) {
      for (final chapter in chapters) {
        flat.add(chapter);
        if (chapter.children.isNotEmpty) {
          flatten(chapter.children);
        }
      }
    }

    flatten(hierarchicalChapters);
    return flat;
  }

  List<ChapterInfo> _extractChapterInfosFromArchive(Archive archive) {
    final chapters = <ChapterInfo>[];
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
      chapters.add(ChapterInfo(title: '第 ${i + 1} 章', href: htmlFiles[i]));
    }

    return chapters;
  }

  Future<String?> getChapterContent(String filePath, int chapterIndex) async {
    try {
      final chapters = await getChapterList(filePath);
      if (chapterIndex < 0 || chapterIndex >= chapters.length) return null;

      final chapter = chapters[chapterIndex];
      final href = chapter.href;
      if (href == null) return null;

      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();

      try {
        final epubBook = await EpubReader.readBook(bytes);

        final epubChapter =
            _findEpubChapterByIndex(epubBook.chapters, chapterIndex);
        if (epubChapter != null) {
          return _extractTextFromHtml(epubChapter.htmlContent ?? '');
        }
      } catch (e) {
        _log.e('EpubService', '使用EpubReader获取章节内容失败', e);
        _log.d('EpubService', '尝试使用archive回退方案...');
      }

      final result = await _getChapterContentFromArchive(bytes, href);
      if (result == null) {
        _log.w('EpubService',
            '从archive获取章节内容失败, chapterIndex: $chapterIndex, href: $href');
      }
      return result;
    } catch (e) {
      _log.e('EpubService', '获取章节内容失败', e);
      return null;
    }
  }

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

  Future<String?> _getChapterContentFromArchive(
      Uint8List bytes, String href) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 移除 href 中的锚点部分
      final hrefWithoutAnchor = href.split('#').first;
      final hrefWithoutAnchorLower = hrefWithoutAnchor.toLowerCase();

      _log.d('EpubService', '查找章节文件: href=$href, 去除锚点后=$hrefWithoutAnchor');

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
          _log.d('EpubService', '找到章节文件: $archiveName');
          final content = utf8.decode(archiveFile.content as List<int>);
          return _extractTextFromHtml(content);
        }
      }

      _log.d('EpubService', '未找到章节文件: href=$hrefWithoutAnchor');
      return null;
    } catch (e) {
      _log.e('EpubService', '从archive获取章节内容失败', e);
      return null;
    }
  }

  Future<List<SectionInfo>> getSectionsInChapter(
      String filePath, int chapterIndex) async {
    try {
      final chapters = await getChapterList(filePath);
      if (chapterIndex < 0 || chapterIndex >= chapters.length) return [];

      final chapter = chapters[chapterIndex];
      final href = chapter.href;
      if (href == null) return [];

      final file = File(filePath);
      if (!await file.exists()) return [];

      final bytes = await file.readAsBytes();

      try {
        final epubBook = await EpubReader.readBook(bytes);

        final epubChapter =
            _findEpubChapterByIndex(epubBook.chapters, chapterIndex);
        if (epubChapter != null) {
          return _extractSectionsFromHtml(epubChapter.htmlContent ?? '');
        }
      } catch (e) {
        // 静默处理EpubReader错误，使用回退方案
      }

      final htmlContent = await _getChapterHtmlFromArchive(bytes, href);
      if (htmlContent == null) return [];

      return _extractSectionsFromHtml(htmlContent);
    } catch (e) {
      _log.e('EpubService', '获取章节内小节失败', e);
      return [];
    }
  }

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
      _log.e('EpubService', '从archive获取章节HTML失败', e);
      return null;
    }
  }

  List<SectionInfo> _extractSectionsFromHtml(String html) {
    final sections = <SectionInfo>[];

    final h2Pattern = RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false);
    final h3Pattern = RegExp(r'<h3[^>]*>(.*?)</h3>', caseSensitive: false);

    final h2Matches = h2Pattern.allMatches(html).toList();

    if (h2Matches.length >= 2) {
      for (int i = 0; i < h2Matches.length; i++) {
        final title = _extractTextFromHtml(h2Matches[i].group(1) ?? '');
        final startPos = h2Matches[i].end;
        final endPos =
            i < h2Matches.length - 1 ? h2Matches[i + 1].start : html.length;
        final sectionHtml = html.substring(startPos, endPos);
        final content = _extractTextFromHtml(sectionHtml);

        sections.add(SectionInfo(
          title: title.isEmpty ? '第 ${i + 1} 节' : title,
          content: content,
          level: 2,
        ));
      }
    } else {
      final h3Matches = h3Pattern.allMatches(html).toList();
      if (h3Matches.length >= 2) {
        for (int i = 0; i < h3Matches.length; i++) {
          final title = _extractTextFromHtml(h3Matches[i].group(1) ?? '');
          final startPos = h3Matches[i].end;
          final endPos =
              i < h3Matches.length - 1 ? h3Matches[i + 1].start : html.length;
          final sectionHtml = html.substring(startPos, endPos);
          final content = _extractTextFromHtml(sectionHtml);

          sections.add(SectionInfo(
            title: title.isEmpty ? '第 ${i + 1} 节' : title,
            content: content,
            level: 3,
          ));
        }
      }
    }

    return sections;
  }

  Future<String?> getSectionContent(
      String filePath, int chapterIndex, int sectionIndex) async {
    final sections = await getSectionsInChapter(filePath, chapterIndex);
    if (sectionIndex < 0 || sectionIndex >= sections.length) return null;
    return sections[sectionIndex].content;
  }

  Future<String?> getChapterHtml(String filePath, int chapterIndex) async {
    try {
      final chapters = await getChapterList(filePath);
      if (chapterIndex < 0 || chapterIndex >= chapters.length) return null;

      final chapter = chapters[chapterIndex];
      final href = chapter.href;
      if (href == null) return null;

      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();

      try {
        final epubBook = await EpubReader.readBook(bytes);

        final epubChapter =
            _findEpubChapterByIndex(epubBook.chapters, chapterIndex);
        if (epubChapter != null) {
          return epubChapter.htmlContent;
        }
      } catch (e) {
        _log.e('EpubService', '使用EpubReader获取章节HTML失败', e);
        _log.d('EpubService', '尝试使用archive回退方案...');
      }

      return await _getChapterHtmlFromArchive(bytes, href);
    } catch (e) {
      _log.e('EpubService', '获取章节HTML失败', e);
      return null;
    }
  }

  Future<String?> getSectionHtml(
      String filePath, int chapterIndex, int sectionIndex) async {
    try {
      final chapters = await getChapterList(filePath);
      if (chapterIndex < 0 || chapterIndex >= chapters.length) return null;

      final chapter = chapters[chapterIndex];
      final href = chapter.href;
      if (href == null) return null;

      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final htmlContent = await _getChapterHtmlFromArchive(bytes, href);

      if (htmlContent == null) return null;

      final h2Pattern = RegExp(r'<h2[^>]*>', caseSensitive: false);
      final h3Pattern = RegExp(r'<h3[^>]*>', caseSensitive: false);

      final h2Matches = h2Pattern.allMatches(htmlContent).toList();

      if (h2Matches.length >= 2) {
        if (sectionIndex >= 0 && sectionIndex < h2Matches.length) {
          final startPos = h2Matches[sectionIndex].start;
          final endPos = sectionIndex < h2Matches.length - 1
              ? h2Matches[sectionIndex + 1].start
              : htmlContent.length;
          return htmlContent.substring(startPos, endPos);
        }
      } else {
        final h3Matches = h3Pattern.allMatches(htmlContent).toList();
        if (h3Matches.length >= 2) {
          if (sectionIndex >= 0 && sectionIndex < h3Matches.length) {
            final startPos = h3Matches[sectionIndex].start;
            final endPos = sectionIndex < h3Matches.length - 1
                ? h3Matches[sectionIndex + 1].start
                : htmlContent.length;
            return htmlContent.substring(startPos, endPos);
          }
        }
      }

      return null;
    } catch (e) {
      _log.e('EpubService', '获取小节HTML失败', e);
      return null;
    }
  }
}

class ChapterInfo {
  final String title;
  final String? href;
  final int level; // 层级深度，0为顶级
  final List<ChapterInfo> children; // 子章节

  ChapterInfo({
    required this.title,
    this.href,
    this.level = 0,
    this.children = const [],
  });
}

class SectionInfo {
  final String title;
  final String content;
  final int level;

  SectionInfo({
    required this.title,
    required this.content,
    required this.level,
  });
}
