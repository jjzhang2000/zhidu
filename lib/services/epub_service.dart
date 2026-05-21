// ============================================================================
// 文件名：epub_service.dart
// 功能：EPUB 电子书解析服务（单例模式）
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../models/book.dart';
import 'log_service.dart';
import 'storage_config.dart';

class EpubService {
  static final EpubService _instance = EpubService._internal();

  factory EpubService() => _instance;

  EpubService._internal();

  final _log = LogService();

  Future<Book?> parseEpubFile(String filePath, String bookId) async {
    try {
      _log.d('EpubService', '开始解析文件 $filePath');
      final file = File(filePath);
      if (!await file.exists()) {
        _log.w('EpubService', '文件不存在: $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();

      String? title;
      String? author;
      List<String> chapterTitles = [];

      try {
        final epubBook = await EpubReader.readBook(bytes);

        title = epubBook.title;

        if (epubBook.authors?.isNotEmpty == true) {
          author = epubBook.authors!.join(', ');
        }

        if (epubBook.chapters?.isNotEmpty == true) {
          chapterTitles = _extractChapterTitles(epubBook.chapters!);
        }
      } catch (_) {
        _log.w('EpubService', 'EpubReader 解析失败，回退到 archive 方案');

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
        _log.d('EpubService', '从导航文件获取章节数: ${chapterTitles.length}');
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
        _log.e('EpubService', '封面提取失败', e);
      }

      return Book(
        id: bookId,
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
        if (chapter.subChapters?.isNotEmpty == true) {
          traverseChapters(chapter.subChapters!, level + 1);
        }
      }
    }

    traverseChapters(chapters, 0);
    return titles;
  }

  String _extractTextFromHtml(String html) {
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

    return text;
  }

  String _extractTitleFromPath(String filePath) {
    final fileName = p.basenameWithoutExtension(filePath);
    return fileName.replaceAll('_', ' ').replaceAll('-', ' ');
  }

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

      return {'opfPath': opfPath};
    } catch (e) {
      _log.e('EpubService', '解析 container.xml 失败', e);
      return null;
    }
  }

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

      return {'title': title, 'author': author};
    } catch (e) {
      _log.e('EpubService', '解析 OPF 文件失败', e);
      return null;
    }
  }

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
          coverImage = epubBook.content!.images!.values.first;
        }

        if (coverImage != null && coverImage.content != null) {
          final extension =
              coverImage.contentMimeType?.contains('png') == true ? 'png' : 'jpg';
          final coverPath = await StorageConfig.getCoverSavePath(
            bookId,
            extension,
          );

          final coverOutputFile = File(coverPath);
          await coverOutputFile.writeAsBytes(coverImage.content!);
          _log.d('EpubService', '封面保存成功: $coverPath');
          return coverPath;
        }
      }
    } catch (e, _) {
      _log.w('EpubService', 'EpubReader 提取封面失败，回退到 archive 方案');
    }

    return await _extractCoverFromArchive(bytes, bookId);
  }

  Future<String?> _extractCoverFromArchive(
      Uint8List bytes, String bookId) async {
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
        final extension = coverFile.name.toLowerCase().endsWith('.png')
            ? 'png'
            : 'jpg';

        final coverPath =
            await StorageConfig.getCoverSavePath(bookId, extension);
        final coverOutputFile = File(coverPath);
        await coverOutputFile.writeAsBytes(coverFile.content as List<int>);
        _log.d('EpubService', '封面保存成功: $coverPath');

        return coverPath;
      }
    } catch (e) {
      _log.w('EpubService', 'archive 回退方案也未找到封面');
    }
    return null;
  }
}
