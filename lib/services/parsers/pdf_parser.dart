// ============================================================
// PDF格式解析器
// ============================================================
// 功能说明：
// - 解析PDF文件，提取元数据、章节列表和内容
// - 自动检测封面页（首页文字少于50字符）
// - 智能识别章节边界（支持中文和英文章节标题）
// - 将PDF页面转换为章节结构
//
// 核心特性：
// - 使用pdfrx库进行PDF解析
// - 支持多种章节标题格式识别
// - 自动跳过封面页
// - 纯文本和HTML双重输出格式
//
// 依赖：
// - pdfrx: PDF文档渲染和文本提取
// - path: 文件路径处理
// ============================================================

import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as p;

import '../../models/book.dart';
import '../../models/book_metadata.dart';
import '../../models/chapter.dart';
import '../../models/chapter_content.dart';
import '../../models/chapter_location.dart';
import 'book_format_parser.dart';
import '../log_service.dart';
import '../opf_reader_service.dart';

/// PDF格式解析器实现
///
/// 实现BookFormatParser接口，提供PDF文件的解析能力。
/// 主要职责：
/// 1. 解析PDF文件元数据（标题、页数等）
/// 2. 提取PDF章节结构（基于章节标题检测）
/// 3. 提取章节内容（纯文本和HTML格式）
/// 4. 封面提取（PDF暂不支持，返回null）
///
/// 解析流程：
/// ```
/// 文件存在检查 → 打开PDF文档 → 提取元数据/章节/内容 → 释放资源
/// ```
class PdfParser implements BookFormatParser {
  /// 日志服务实例
  final LogService _log = LogService();

  // ============================================================
  // 元数据解析
  // ============================================================

  /// 解析PDF文件，提取书籍元数据
  ///
  /// 解析流程：
  /// 1. 检查文件是否存在
  /// 2. 使用pdfrx打开PDF文档
  /// 3. 获取总页数
  /// 4. 从文件名提取标题（PDF内部元数据不可靠）
  /// 5. 释放文档资源
  ///
  /// 参数：
  /// - [filePath] PDF文件路径
  ///
  /// 返回：
  /// - BookMetadata对象，包含标题、页数等信息
  ///
  /// 注意：
  /// - PDF的作者信息需要从文件内部元数据提取，但目前使用"Unknown"
  /// - 标题从文件名推导，会替换下划线和连字符为空格
  /// - 总章节数暂时设为1（PDF通常按页处理，不自动分章）
  @override
  Future<BookMetadata> parse(String filePath) async {
    _log.v('PdfParser', 'parse 开始执行, filePath: $filePath');

    // ----------------------------------------------------------
    // 文件存在性检查
    // ----------------------------------------------------------
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('PdfParser', '文件不存在: $filePath');
      throw Exception('PDF file not found: $filePath');
    }

    try {
      // ----------------------------------------------------------
      // 打开PDF文档并提取基本信息
      // ----------------------------------------------------------
      // pdfrx库提供PDF文档的加载和渲染能力
      // openFile是异步方法，返回PdfDocument对象
      final document = await PdfDocument.openFile(filePath);
      final totalPages = document.pages.length;

      // 重要：及时释放文档资源，避免内存泄漏
      // pdfrx使用原生PDF库，需要显式释放
      await document.dispose();

      // ----------------------------------------------------------
      // 标题提取（从文件名）
      // ----------------------------------------------------------
      // PDF文件的内部元数据（标题、作者）通常不可靠
      // 很多PDF没有正确设置元数据，因此使用文件名作为标题
      final fileName = p.basenameWithoutExtension(filePath);

      // 文件名美化处理：
      // - 移除下划线，转换为空格
      // - 移除连字符，转换为空格
      // 例如: "my_book-title.pdf" → "my book title"
      var title = fileName.replaceAll('_', ' ').replaceAll('-', ' ');

      _log.d('PdfParser', '初始书名: $title');
      _log.d('PdfParser', '总页数: $totalPages');

      // 尝试读取同目录下的metadata.opf文件，优先使用OPF中的元数据
      String? opfTitle;
      String? opfAuthor;
      String? opfLanguage;
      String? opfPublisher;
      String? opfDescription;
      List<String>? opfSubjects;
      
      try {
        final opfMetadata = await OpfReaderService.readFromSameDirectory(filePath);
        if (opfMetadata != null) {
          _log.d('PdfParser', '使用外部OPF元数据覆盖解析结果');
          opfTitle = opfMetadata.title;
          opfAuthor = opfMetadata.author;
          opfLanguage = opfMetadata.language;
          opfPublisher = opfMetadata.publisher;
          opfDescription = opfMetadata.description;
          opfSubjects = opfMetadata.subjects;
          
          // 使用OPF元数据覆盖默认值
          title = opfTitle ?? title;
        }
      } catch (e) {
        _log.w('PdfParser', '读取外部OPF元数据失败: $e');
      }

      // ----------------------------------------------------------
      // 构建元数据对象
      // ----------------------------------------------------------
      return BookMetadata(
        title: title,
        author: opfAuthor ?? 'Unknown', // 优先使用OPF中的作者信息
        coverPath: null, // PDF封面提取复杂，暂不支持
        totalChapters: totalPages > 0 ? 1 : 0, // 默认作为单章节处理
        format: BookFormat.pdf,
        language: opfLanguage,
        publisher: opfPublisher,
        description: opfDescription,
        subjects: opfSubjects,
      );
    } catch (e, stackTrace) {
      _log.e('PdfParser', '解析PDF失败', e, stackTrace);
      throw Exception('Failed to parse PDF: $e');
    }
  }

  // ============================================================
  // 章节提取
  // ============================================================

  /// 提取PDF文件的章节列表
  ///
  /// 章节检测算法：
  /// 1. 封面检测：首页文字少于50字符视为封面，跳过
  /// 2. 逐页提取文本内容
  /// 3. 检查每页前5行的章节标题模式
  /// 4. 匹配成功则记录为章节边界
  /// 5. 防止重复章节号（避免误识别）
  ///
  /// 支持的章节标题格式：
  /// - 中文：第X章、第十章等（X为一二三四五六七八九十百零）
  /// - 阿拉伯数字：第1章、第2章等
  /// - 英文：Chapter 1、CHAPTER 1等
  ///
  /// 参数：
  /// - [filePath] PDF文件路径
  ///
  /// 返回：
  /// - Chapter列表，每个章节包含起始页和结束页
  ///
  /// 边界情况处理：
  /// - 无法识别章节时，整个文档作为一个章节
  /// - 跳过封面后无有效页面时，返回空列表
  @override
  Future<List<Chapter>> getChapters(String filePath) async {
    _log.v('PdfParser', 'getChapters 开始执行, filePath: $filePath');

    // ----------------------------------------------------------
    // 文件存在性检查
    // ----------------------------------------------------------
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('PdfParser', '文件不存在: $filePath');
      return [];
    }

    try {
      // ----------------------------------------------------------
      // 打开PDF并提取所有页面文本
      // ----------------------------------------------------------
      final document = await PdfDocument.openFile(filePath);
      final totalPages = document.pages.length;

      if (totalPages == 0) {
        await document.dispose();
        return [];
      }

      // 预先收集所有页面的文本内容
      // 这样可以一次性完成文档读取，避免多次打开
      final pageContents = <String>[];
      for (int i = 0; i < totalPages; i++) {
        final page = document.pages[i];
        final pageText = await page.loadText();
        pageContents.add(pageText?.fullText ?? '');
      }

      // 释放文档资源
      await document.dispose();

      // ----------------------------------------------------------
      // 封面检测逻辑
      // ----------------------------------------------------------
      // PDF首页可能是封面，通常包含图片而非大量文字
      // 检测策略：首页文字少于50字符，认为是封面
      //
      // 封面特征：
      // - 主要是图片或装饰元素
      // - 文字极少（书名、作者名等）
      // - 不包含正文内容
      int startOffset = 0;
      final coverThreshold = 50; // 封面检测阈值：50字符

      if (pageContents.isNotEmpty &&
          pageContents[0].trim().length < coverThreshold) {
        startOffset = 1; // 跳过第一页
        _log.d('PdfParser', '首页文字少于${coverThreshold}字符，识别为封面，跳过');
      }

      // ----------------------------------------------------------
      // 处理跳过封面后的情况
      // ----------------------------------------------------------
      final effectivePages = totalPages - startOffset;
      if (effectivePages <= 0) {
        _log.d('PdfParser', '跳过封面后无有效页面');
        return [];
      }

      // ----------------------------------------------------------
      // 章节标题正则表达式模式
      // ----------------------------------------------------------
      // 定义多种章节标题匹配模式，支持中英文
      // 模式说明：
      // 1. ^第[一二三四五六七八九十百零]+章[：:\s]
      //    - 匹配中文数字章节：第一章、第十二章等
      //    - [：:\s] 匹配中文冒号、英文冒号或空白字符
      //
      // 2. ^第\d+章[：:\s]
      //    - 匹配阿拉伯数字章节：第1章、第12章等
      //
      // 3. ^Chapter\s+\d+[：:\s]
      //    - 匹配英文章节：Chapter 1、Chapter 12等
      //
      // 4. ^CHAPTER\s+\d+[：:\s]
      //    - 匹配大写英文章节：CHAPTER 1等
      final patterns = [
        r'^第[一二三四五六七八九十百零]+章[：:\s]', // 中文数字章节
        r'^第\d+章[：:\s]', // 阿拉伯数字章节
        r'^Chapter\s+\d+[：:\s]', // 英文章节（首字母大写）
        r'^CHAPTER\s+\d+[：:\s]', // 英文章节（全大写）
      ];

      // ----------------------------------------------------------
      // 章节边界检测
      // ----------------------------------------------------------
      // 章节边界：包含章节标题的页面索引
      // 初始包含startOffset（第一个有效页面）
      final chapterBoundaries = <int>[startOffset];

      // 章节标题列表
      // 第一个默认为"全文"（用于无法识别章节时）
      final chapterTitles = <String>['全文'];

      // 上一个章节号，用于防止重复
      // 某些页面可能多次出现同一章节号（如页眉）
      int lastChapterNum = -1;

      // ----------------------------------------------------------
      // 逐页检测章节标题
      // ----------------------------------------------------------
      // 从startOffset开始，遍历每个页面的文本内容
      for (int i = startOffset; i < pageContents.length; i++) {
        final content = pageContents[i];

        // 只检查每页的前5行
        // 章节标题通常出现在页面开头
        // 限制行数可以提高检测效率，减少误判
        final firstLines = content.split('\n').take(5);

        // 检查前5行的每一行
        for (final line in firstLines) {
          // 尝试匹配每个章节标题模式
          for (final pattern in patterns) {
            // 创建正则表达式
            // multiLine: true 允许^匹配每行开头
            // caseSensitive: false 忽略大小写
            final regex =
                RegExp(pattern, multiLine: true, caseSensitive: false);
            final match = regex.firstMatch(line);

            if (match != null) {
              // 提取匹配到的标题文本
              final title = match.group(0)?.trim() ?? '';

              // ----------------------------------------------------------
              // 提取章节号（用于去重）
              // ----------------------------------------------------------
              // 从标题中提取章节编号
              // 例如："第一章 " → "一"
              //      "第12章：" → "12"
              final numMatch = RegExp(r'\d+|[一二三四五六七八九十百零]+').firstMatch(title);
              if (numMatch != null) {
                final chapterNum = numMatch.group(0);

                // ----------------------------------------------------------
                // 验证并记录章节边界
                // ----------------------------------------------------------
                // 条件：
                // 1. i != startOffset: 不是第一个有效页面（已经作为起始点）
                // 2. chapterNum != null: 成功提取章节号
                // 3. !chapterBoundaries.contains(i): 当前页未被记录过
                // 4. lastChapterNum != int.tryParse(chapterNum):
                //    章节号与上一个不同（防止重复）
                if (i != startOffset &&
                    chapterNum != null &&
                    !chapterBoundaries.contains(i) &&
                    lastChapterNum != int.tryParse(chapterNum)) {
                  chapterBoundaries.add(i);
                  chapterTitles.add(title);
                  lastChapterNum = int.tryParse(chapterNum) ?? -1;
                  _log.d('PdfParser', '检测到章节边界: 页$i, 标题: $title');
                }
              }
              break; // 匹配成功，跳出模式循环
            }
          }
        }
      }

      // ----------------------------------------------------------
      // 处理无法识别章节的情况
      // ----------------------------------------------------------
      // 如果只检测到起始边界，说明无法识别章节结构
      // 此时将整个有效文档作为一个章节
      if (chapterBoundaries.length == 1) {
        _log.d('PdfParser', '未检测到章节结构，将有效文档视为一个章节');
        return [
          Chapter(
            id: 'pdf_chapter_0',
            index: 0,
            title: '全文',
            location: ChapterLocation(
              startPage: startOffset + 1, // 转换为1-based页码
              endPage: totalPages,
            ),
            level: 0,
          ),
        ];
      }

      // ----------------------------------------------------------
      // 添加最后一页作为边界
      // ----------------------------------------------------------
      // 章节边界定义的是章节起始页
      // 需要添加文档最后一页，用于定义最后一个章节的结束位置
      if (chapterBoundaries.last != totalPages - 1) {
        chapterBoundaries.add(totalPages - 1);
        chapterTitles.add('结束'); // 占位标题
      }

      // ----------------------------------------------------------
      // 创建章节对象
      // ----------------------------------------------------------
      // 根据边界创建Chapter对象
      // 每个章节从boundary[i]到boundary[i+1]
      final chapters = <Chapter>[];
      for (int i = 0; i < chapterBoundaries.length - 1; i++) {
        final startIndex = chapterBoundaries[i];
        final endIndex = chapterBoundaries[i + 1];
        final title =
            i < chapterTitles.length ? chapterTitles[i] : '第${i + 1}章';

        chapters.add(Chapter(
          id: 'pdf_chapter_$i',
          index: i,
          title: title,
          location: ChapterLocation(
            startPage: startIndex + 1, // 转换为1-based
            endPage: endIndex + 1, // 转换为1-based
          ),
          level: 0, // PDF不支持层级，统一为0
        ));
      }

      _log.d('PdfParser', '检测到 ${chapters.length} 个章节');
      return chapters;
    } catch (e, stackTrace) {
      _log.e('PdfParser', '获取章节列表失败', e, stackTrace);
      return [];
    }
  }

  // ============================================================
  // 章节内容提取
  // ============================================================

  /// 提取指定章节的内容
  ///
  /// 内容提取流程：
  /// 1. 检查文件是否存在
  /// 2. 打开PDF文档
  /// 3. 根据章节的startPage和endPage确定页面范围
  /// 4. 提取页面范围内的所有文本
  /// 5. 将纯文本转换为HTML格式（用<p>包裹段落）
  /// 6. 释放文档资源
  ///
  /// 参数：
  /// - [filePath] PDF文件路径
  /// - [chapter] 要提取的章节对象
  ///
  /// 返回：
  /// - ChapterContent对象，包含plainText和htmlContent
  ///
  /// 注意：
  /// - 页码是1-based（用户视角）
  /// - 内部访问时需要转换为0-based索引
  /// - 空章节返回空的ChapterContent
  @override
  Future<ChapterContent> getChapterContent(
      String filePath, Chapter chapter) async {
    _log.v('PdfParser',
        'getChapterContent 开始执行, filePath: $filePath, chapter: ${chapter.title}');

    // ----------------------------------------------------------
    // 文件存在性检查
    // ----------------------------------------------------------
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('PdfParser', '文件不存在: $filePath');
      throw Exception('PDF file not found: $filePath');
    }

    try {
      // ----------------------------------------------------------
      // 打开PDF文档
      // ----------------------------------------------------------
      final document = await PdfDocument.openFile(filePath);

      // ----------------------------------------------------------
      // 获取章节的页面范围
      // ----------------------------------------------------------
      // startPage和endPage都是1-based（从1开始计数）
      // 例如：startPage=1 表示第一页
      final startPage = chapter.location.startPage;
      final endPage = chapter.location.endPage;

      // 验证页面范围是否存在
      if (startPage == null || endPage == null) {
        await document.dispose();
        _log.w('PdfParser', '章节缺少页面范围信息: ${chapter.title}');
        return ChapterContent(plainText: '', htmlContent: '');
      }

      _log.d('PdfParser', '提取页面范围: $startPage - $endPage');

      // ----------------------------------------------------------
      // 提取页面范围内的所有文本
      // ----------------------------------------------------------
      // 遍历从startPage到endPage的所有页面
      // 注意：document.pages使用0-based索引，需要减1
      final buffer = StringBuffer();
      for (int pageNum = startPage;
          pageNum <= endPage && pageNum <= document.pages.length;
          pageNum++) {
        // 转换为0-based索引
        final page = document.pages[pageNum - 1];
        final pageText = await page.loadText();

        // 页面之间用双换行分隔
        if (buffer.isNotEmpty) {
          buffer.write('\n\n');
        }
        buffer.write(pageText?.fullText ?? '');
      }

      // 释放文档资源
      await document.dispose();

      // ----------------------------------------------------------
      // 处理提取结果
      // ----------------------------------------------------------
      final plainText = buffer.toString().trim();
      _log.d('PdfParser', '章节内容提取成功，长度: ${plainText.length}');

      if (plainText.isEmpty) {
        _log.w('PdfParser', '章节内容为空: ${chapter.title}');
        return ChapterContent(plainText: '', htmlContent: '');
      }

      // ----------------------------------------------------------
      // 将纯文本转换为HTML格式
      // ----------------------------------------------------------
      // PDF文本提取是纯文本，需要转换为HTML以便渲染
      // 转换规则：
      // 1. 按换行符分割为段落
      // 2. 过滤空段落
      // 3. 用<p>标签包裹每个段落
      final paragraphs =
          plainText.split('\n').where((p) => p.trim().isNotEmpty);
      final htmlContent =
          paragraphs.map((p) => '<p>${p.trim()}</p>').join('\n');

      return ChapterContent(
        plainText: plainText,
        htmlContent: htmlContent,
      );
    } catch (e, stackTrace) {
      _log.e('PdfParser', '获取章节内容失败', e, stackTrace);
      return ChapterContent(plainText: '', htmlContent: '');
    }
  }

  // ============================================================
  // 封面提取
  // ============================================================

  /// 提取PDF文件封面
  ///
  /// 实现说明：
  /// PDF文件的封面提取比较复杂，原因如下：
  /// 1. PDF没有像EPUB那样独立的封面图片资源
  /// 2. PDF首页可能是：
  ///    - 纯图片封面（需要渲染第一页为图片）
  ///    - 混合内容（文字+图片）
  ///    - 直接从正文开始（无封面）
  /// 3. 渲染PDF页面为图片需要额外处理，且效果不稳定
  ///
  /// 当前策略：
  /// - 直接返回null
  /// - UI层使用默认封面占位图
  /// - 未来可考虑：渲染第一页为缩略图作为封面
  ///
  /// 参数：
  /// - [filePath] PDF文件路径
  ///
  /// 返回：
  /// - 始终返回null（不支持封面提取）
  @override
  Future<String?> extractCover(String filePath) async {
    _log.v('PdfParser', 'extractCover 开始执行, filePath: $filePath');

    // ----------------------------------------------------------
    // 文件存在性检查
    // ----------------------------------------------------------
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('PdfParser', '文件不存在: $filePath');
      return null;
    }

    // ----------------------------------------------------------
    // PDF封面提取说明
    // ----------------------------------------------------------
    // PDF文件通常没有像EPUB那样的独立封面图片
    // 第一页通常包含内容而非专门的封面设计
    // 因此返回null，让UI层使用默认封面占位图
    //
    // 可能的增强方案：
    // 1. 渲染第一页为图片并保存为封面
    // 2. 使用PDF内嵌的缩略图（如果有）
    // 3. 使用AI识别封面页并渲染
    _log.d('PdfParser', 'PDF不支持封面提取，返回null');
    return null;
  }
}
