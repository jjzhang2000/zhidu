// ============================================================================
// 文件名：pdf_service.dart
// 功能：PDF文件解析服务，负责PDF文件的导入、解析和内容提取
//
// 主要职责：
// - 解析PDF文件结构，提取元数据（标题、页数等）
// - 检测PDF中的章节结构（通过正则匹配章节标题）
// - 提取PDF封面图片（渲染第一页为封面）
// - 提供章节页面内容读取接口
//
// 依赖：
// - pdfrx：PDF渲染库，用于打开PDF、渲染页面、提取文本
// - image：图片处理库，用于封面图片编码
// - uuid：UUID生成库
// - storage_config.dart：存储路径配置
// - log_service.dart：日志服务
//
// 调用方：
// - book_service.dart：导入PDF文件时调用parsePdfFile
// - summary_screen.dart：读取章节内容时调用getChapterPages
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import '../models/book.dart';
import 'storage_config.dart';
import 'log_service.dart';
import 'opf_reader_service.dart';

/// 类名：PdfService
/// 功能：PDF文件解析服务单例类
///
/// 主要职责：
/// - 解析PDF文件，创建Book对象
/// - 检测PDF章节结构
/// - 提取PDF封面
/// - 读取PDF页面内容
///
/// 设计模式：
/// - 单例模式：确保全局只有一个PdfService实例
///
/// 使用示例：
/// ```dart
/// final pdfService = PdfService();
/// final book = await pdfService.parsePdfFile('/path/to/file.pdf');
/// ```
class PdfService {
  /// 单例实例
  static final PdfService _instance = PdfService._internal();

  /// 工厂构造函数，返回单例实例
  factory PdfService() => _instance;

  /// 私有构造函数，实现单例模式
  PdfService._internal();

  /// UUID生成器，用于生成书籍唯一ID
  final _uuid = const Uuid();

  /// 日志服务实例
  final _log = LogService();

  /// 方法名：parsePdfFile
  /// 功能：解析PDF文件并创建Book对象
  ///
  /// 参数：
  /// - filePath: PDF文件的完整路径
  ///
  /// 返回值：
  /// - 成功：返回Book对象，包含PDF元数据
  /// - 失败：返回null
  ///
  /// 处理流程：
  /// 1. 使用pdfrx打开PDF文档
  /// 2. 获取总页数
  /// 3. 从文件名提取书籍标题
  /// 4. 检测章节结构
  /// 5. 渲染第一页为封面图片
  /// 6. 创建Book对象并返回
  ///
  /// 异常处理：
  /// - 捕获所有异常，记录日志后返回null
  Future<Book?> parsePdfFile(String filePath) async {
    try {
      _log.d('PdfService', '开始解析PDF: $filePath');

      // 使用pdfrx打开PDF文档
      final document = await PdfDocument.openFile(filePath);

      // 获取PDF总页数
      final totalPages = document.pages.length;
      _log.d('PdfService', 'PDF总页数: $totalPages');

      // 从文件路径提取文件名，去除扩展名作为标题
      // 处理跨平台路径分隔符（Windows用\，其他用/）
      final fileName = filePath.split('/').last.split('\\').last;
      var title = fileName.substring(0, fileName.lastIndexOf('.'));
      _log.d('PdfService', '书名: $title');

      // 生成唯一的书籍ID
      final bookId = _uuid.v4();

      // 检测PDF中的章节结构
      final chapters = await _detectChapters(document);
      _log.d('PdfService', '检测到 ${chapters.length} 个章节');

      // 渲染第一页为封面图片
      final String? coverPath = await _extractCover(document, bookId);
      _log.d('PdfService', '封面路径: $coverPath');

      // 释放PDF文档资源
      await document.dispose();

      // 读取同目录下的metadata.opf文件，优先使用OPF中的元数据
      String? opfLanguage;
      String? opfPublisher;
      String? opfDescription;
      List<String>? opfSubjects;
      var author = 'Unknown'; // PDF通常无法自动提取作者信息
      
      try {
        final opfMetadata = await OpfReaderService.readFromSameDirectory(filePath);
        if (opfMetadata != null) {
          _log.d('PdfService', '使用外部OPF元数据覆盖解析结果');
          title = opfMetadata.title ?? title;
          author = opfMetadata.author ?? author; // 仅在OPF中提供了作者时才更新
          opfLanguage = opfMetadata.language;
          opfPublisher = opfMetadata.publisher;
          opfDescription = opfMetadata.description;
          opfSubjects = opfMetadata.subjects;
        }
      } catch (e) {
        _log.w('PdfService', '读取外部OPF元数据失败: $e');
      }

      // 创建并返回Book对象
      return Book(
        id: bookId,
        title: title,
        author: author,
        filePath: filePath,
        coverPath: coverPath,
        format: BookFormat.pdf,
        totalChapters: chapters.length,
        addedAt: DateTime.now(),
        language: opfLanguage,
        publisher: opfPublisher,
        description: opfDescription,
        subjects: opfSubjects,
      );
    } catch (e, stackTrace) {
      _log.e('PdfService', '解析PDF失败', e, stackTrace);
      return null;
    }
  }

  /// 方法名：_extractCover
  /// 功能：提取PDF封面（渲染第一页为图片）
  ///
  /// 参数：
  /// - document: 已打开的PdfDocument对象
  /// - bookId: 书籍ID，用于生成封面存储路径
  ///
  /// 返回值：
  /// - 成功：返回封面图片的存储路径
  /// - 失败：返回null
  ///
  /// 处理流程：
  /// 1. 检查PDF是否有页面
  /// 2. 计算渲染尺寸（宽度600像素，高度按比例缩放）
  /// 3. 渲染第一页为图片
  /// 4. 处理像素格式（BGRA/RGBA）
  /// 5. 编码为PNG格式
  /// 6. 保存到书籍目录
  ///
  /// 技术细节：
  /// - 使用pdfrx的render方法渲染页面
  /// - 使用image库进行像素格式转换和PNG编码
  /// - 需要处理BGRA8888和RGBA8888两种像素格式
  Future<String?> _extractCover(PdfDocument document, String bookId) async {
    try {
      _log.d('PdfService', '开始渲染PDF第一页为封面');

      // 检查PDF是否有页面
      if (document.pages.isEmpty) {
        _log.w('PdfService', 'PDF没有页面');
        return null;
      }

      // 获取第一页
      final firstPage = document.pages[0];

      // 计算渲染尺寸
      // 宽度固定为600像素，高度按原比例缩放
      final pageWidth = firstPage.width;
      final pageHeight = firstPage.height;
      final targetWidth = 600;
      final targetHeight = (pageHeight * targetWidth / pageWidth).round();

      _log.d('PdfService',
          '页面尺寸: $pageWidth x $pageHeight -> $targetWidth x $targetHeight');

      // 渲染页面为图片
      // backgroundColor设置为白色，避免透明背景问题
      final pdfImage = await firstPage.render(
        width: targetWidth,
        height: targetHeight,
        backgroundColor: 0xFFFFFFFF,
      );

      // 检查渲染结果
      if (pdfImage == null) {
        _log.w('PdfService', '渲染返回空图片');
        return null;
      }

      // 使用image库创建图片对象
      // pdfrx返回的PdfImage需要转换为PNG格式保存
      final image = img.Image(width: targetWidth, height: targetHeight);

      // 获取像素数据
      final pixels = pdfImage.pixels;

      // 遍历每个像素，pdfrx 2.x 返回 RGBA 格式
      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          final offset = (y * pdfImage.width + x) * 4;
          if (offset + 3 < pixels.length) {
            // RGBA格式：R、G、B、A顺序
            final r = pixels[offset];
            final g = pixels[offset + 1];
            final b = pixels[offset + 2];
            final a = pixels[offset + 3];
            // 设置像素颜色
            image.setPixelRgba(x, y, r, g, b, a);
          }
        }
      }

      // 编码为PNG格式
      final pngBytes = Uint8List.fromList(img.encodePng(image));
      _log.d('PdfService', '封面图片大小: ${pngBytes.length} bytes');

      // 获取封面保存路径
      final coverPath =
          await StorageConfig.getCoverSavePath(bookId, 'image/png');
      final coverFile = File(coverPath);

      // 将PNG数据写入文件
      await coverFile.writeAsBytes(pngBytes);

      // 释放pdfImage资源
      pdfImage.dispose();

      _log.info('PdfService', '封面已保存: $coverPath');
      return coverPath;
    } catch (e, stackTrace) {
      _log.e('PdfService', '提取封面失败', e, stackTrace);
      return null;
    }
  }

  /// 方法名：_detectChapters
  /// 功能：检测PDF中的章节结构
  ///
  /// 参数：
  /// - document: 已打开的PdfDocument对象
  ///
  /// 返回值：
  /// - 返回PdfChapter列表，每个章节包含标题和页码范围
  ///
  /// 算法说明：
  /// 1. 遍历所有页面，提取文本内容
  /// 2. 使用正则表达式匹配章节标题模式
  /// 3. 根据匹配结果确定章节边界
  /// 4. 创建章节对象，包含标题和页码范围
  ///
  /// 支持的章节标题格式：
  /// - 中文：第X章、第十章、第一百章
  /// - 数字：第1章、第2章
  /// - 英文：Chapter 1、CHAPTER 1
  /// - 编号：1. Title、Title 1
  Future<List<PdfChapter>> _detectChapters(PdfDocument document) async {
    final chapters = <PdfChapter>[];
    final totalPages = document.pages.length;

    // 收集所有页面的文本内容
    // 用于后续的章节标题匹配
    final pageContents = <String>[];
    for (int i = 0; i < totalPages; i++) {
      final page = document.pages[i];
      final pageText = await page.loadText();
      pageContents.add(pageText?.fullText ?? '');
    }

    // 章节标题正则表达式模式
    // 按优先级排列，先匹配到的优先使用
    final patterns = [
      r'第[一二三四五六七八九十百]+章', // 中文数字章节
      r'第\d+章', // 数字章节
      r'Chapter\s+\d+', // 英文Chapter（首字母大写）
      r'CHAPTER\s+\d+', // 英文CHAPTER（全大写）
      r'^\d+\.\s+[A-Za-z]', // 数字点号开头（如 "1. Introduction"）
      r'^[A-Z][a-z]+\s+\d+', // 英文单词加数字（如 "Part 1"）
    ];

    // 章节边界列表，存储章节起始页面索引
    final chapterBoundaries = <int>[0]; // 第一个章节从第0页开始

    // 检测章节边界
    // 遍历每页内容，检查是否匹配任何章节标题模式
    for (int i = 0; i < pageContents.length; i++) {
      final content = pageContents[i];
      for (final pattern in patterns) {
        final regex = RegExp(pattern, multiLine: true);
        if (regex.hasMatch(content)) {
          // 找到章节边界，记录页面索引
          chapterBoundaries.add(i);
          break; // 匹配到一个模式即可，跳过其他模式
        }
      }
    }

    // 添加最后一页作为边界
    // 确保最后一个章节有结束页
    if (chapterBoundaries.last != totalPages - 1) {
      chapterBoundaries.add(totalPages - 1);
    }

    // 创建章节对象
    // 每两个边界之间是一个章节
    for (int i = 0; i < chapterBoundaries.length - 1; i++) {
      final startIndex = chapterBoundaries[i];
      final endIndex = chapterBoundaries[i + 1];

      // 尝试从页面内容中提取章节标题
      String chapterTitle = '第${i + 1}章'; // 默认标题
      if (startIndex < pageContents.length) {
        final firstPageContent = pageContents[startIndex];
        for (final pattern in patterns) {
          final regex = RegExp(pattern, multiLine: true);
          final match = regex.firstMatch(firstPageContent);
          if (match != null) {
            // 使用匹配到的文本作为章节标题
            chapterTitle = match.group(0) ?? chapterTitle;
            break;
          }
        }
      }

      // 创建章节对象
      // 注意：页码从1开始（用户视角），而索引从0开始（程序视角）
      chapters.add(PdfChapter(
        index: i,
        title: chapterTitle,
        startPage: startIndex + 1, // 转换为1-based页码
        endPage: endIndex + 1, // 转换为1-based页码
      ));
    }

    return chapters;
  }

  /// 方法名：getChapterPages
  /// 功能：获取指定章节的页面内容
  ///
  /// 参数：
  /// - filePath: PDF文件路径
  /// - chapterIndex: 章节索引（0-based）
  ///
  /// 返回值：
  /// - 返回PdfPageContent列表，每个元素包含页码和文本内容
  ///
  /// 使用场景：
  /// - 用户点击章节时，获取该章节所有页面的文本内容
  /// - 用于AI摘要生成或阅读显示
  Future<List<PdfPageContent>> getChapterPages(
      String filePath, int chapterIndex) async {
    // 打开PDF文档
    final document = await PdfDocument.openFile(filePath);

    // 获取章节的页面范围
    final pageRange = await getChapterPageRange(filePath, chapterIndex);

    // 读取每页的文本内容
    final pages = <PdfPageContent>[];
    for (final pageNumber in pageRange) {
      final page = document.pages[pageNumber - 1]; // 转换为0-based索引
      final pageText = await page.loadText();
      pages.add(PdfPageContent(
        pageNumber: pageNumber,
        content: pageText?.fullText ?? '',
      ));
    }

    // 释放文档资源
    await document.dispose();
    return pages;
  }

  /// 方法名：getChapterPageRange
  /// 功能：获取指定章节的页面范围
  ///
  /// 参数：
  /// - filePath: PDF文件路径
  /// - chapterIndex: 章节索引（0-based）
  ///
  /// 返回值：
  /// - 返回页码列表（1-based）
  /// - 如果章节索引无效，返回[1]（默认第一页）
  ///
  /// 使用场景：
  /// - 确定章节包含哪些页面
  /// - 用于页面导航和内容读取
  Future<List<int>> getChapterPageRange(
      String filePath, int chapterIndex) async {
    // 读取PDF文件字节
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // 打开PDF文档
    final document = await PdfDocument.openData(bytes);

    // 检测章节结构
    final chapters = await _detectChapters(document);

    // 释放文档资源
    await document.dispose();

    // 检查章节索引是否有效
    if (chapterIndex < chapters.length) {
      final chapter = chapters[chapterIndex];
      // 生成页码范围列表
      return List.generate(
        chapter.endPage - chapter.startPage + 1,
        (index) => chapter.startPage + index,
      );
    }

    // 章节索引无效，返回第一页
    return [1];
  }

  /// 方法名：getPageContent
  /// 功能：获取指定页面的内容
  ///
  /// 参数：
  /// - filePath: PDF文件路径
  /// - pageNumber: 页码（1-based）
  ///
  /// 返回值：
  /// - 返回PdfPageContent对象，包含页码和文本内容
  ///
  /// 使用场景：
  /// - 获取单个页面的文本内容
  /// - 用于逐页阅读或分析
  Future<PdfPageContent> getPageContent(String filePath, int pageNumber) async {
    // 打开PDF文档
    final document = await PdfDocument.openFile(filePath);

    // 获取指定页面（转换为0-based索引）
    final page = document.pages[pageNumber - 1];

    // 提取页面文本
    final pageText = await page.loadText();

    // 释放文档资源
    await document.dispose();

    // 返回页面内容对象
    return PdfPageContent(
      pageNumber: pageNumber,
      content: pageText?.fullText ?? '',
    );
  }
}

/// 类名：PdfChapter
/// 功能：PDF章节数据模型
///
/// 主要职责：
/// - 封装章节的元数据信息
/// - 包含章节索引、标题、页码范围
///
/// 使用场景：
/// - _detectChapters方法返回章节列表
/// - 用于UI展示章节目录
class PdfChapter {
  /// 章节索引（0-based）
  final int index;

  /// 章节标题
  /// 从PDF页面内容中提取，如"第一章"、"Chapter 1"等
  final String title;

  /// 章节起始页码（1-based）
  final int startPage;

  /// 章节结束页码（1-based）
  final int endPage;

  /// 构造函数：PdfChapter
  /// 功能：创建PDF章节对象
  ///
  /// 参数：
  /// - index: 章节索引
  /// - title: 章节标题
  /// - startPage: 起始页码
  /// - endPage: 结束页码
  PdfChapter({
    required this.index,
    required this.title,
    required this.startPage,
    required this.endPage,
  });
}

/// 类名：PdfPageContent
/// 功能：PDF页面内容数据模型
///
/// 主要职责：
/// - 封装单个页面的内容信息
/// - 包含页码和文本内容
///
/// 使用场景：
/// - getChapterPages方法返回页面内容列表
/// - 用于显示页面内容或生成摘要
class PdfPageContent {
  /// 页码（1-based）
  final int pageNumber;

  /// 页面文本内容
  /// 通过pdfrx的loadText方法提取
  final String content;

  /// 构造函数：PdfPageContent
  /// 功能：创建PDF页面内容对象
  ///
  /// 参数：
  /// - pageNumber: 页码
  /// - content: 页面文本内容
  PdfPageContent({
    required this.pageNumber,
    required this.content,
  });
}
