import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

import '../models/chapter_summary.dart';
import '../models/section_summary.dart';
import '../models/book.dart';
import 'ai_service.dart';
import 'epub_service.dart';
import 'log_service.dart';

class SummaryService {
  static final SummaryService _instance = SummaryService._internal();
  factory SummaryService() => _instance;
  SummaryService._internal();

  final Map<String, ChapterSummary> _summaries = {};
  final Map<String, SectionSummary> _sectionSummaries = {};
  String? _summariesDir;
  String? _sectionSummariesDir;
  final _aiService = AIService();
  final _epubService = EpubService();
  final _log = LogService();

  Future<void> init() async {
    _summariesDir = '${Directory.current.path}/Summaries';
    final dir = Directory(_summariesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _sectionSummariesDir = '${Directory.current.path}/SectionSummaries';
    final sectionDir = Directory(_sectionSummariesDir!);
    if (!await sectionDir.exists()) {
      await sectionDir.create(recursive: true);
    }

    // 不再预加载所有摘要，改为按需加载
  }

  /// 从文件按需加载摘要
  Future<ChapterSummary?> _loadSummaryFromFile(
      String bookId, int chapterIndex) async {
    if (_summariesDir == null) return null;

    final fileName = '${bookId}_$chapterIndex.json';
    final file = File('$_summariesDir/$fileName');

    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final summary = ChapterSummary.fromJson(json);
      _summaries['${bookId}_$chapterIndex'] = summary;
      return summary;
    } catch (e) {
      _log.e('SummaryService', '加载摘要失败: $fileName', e);
      return null;
    }
  }

  /// 获取指定章节的摘要（支持缓存和按需加载）
  Future<ChapterSummary?> getSummary(String bookId, int chapterIndex) async {
    _log.v('SummaryService',
        'getSummary 开始执行, bookId: $bookId, chapterIndex: $chapterIndex');
    final key = '${bookId}_$chapterIndex';
    // 先检查内存缓存
    if (_summaries.containsKey(key)) {
      _log.v('SummaryService', 'getSummary 从缓存获取, key: $key');
      return _summaries[key];
    }
    _log.v('SummaryService', 'getSummary 缓存未命中，从文件加载');
    // 按需从文件加载
    final result = await _loadSummaryFromFile(bookId, chapterIndex);
    _log.v('SummaryService',
        'getSummary 加载完成, result: ${result != null ? "有内容" : "空"}');
    return result;
  }

  /// 根据章节标题获取摘要（当索引不匹配时的备选方案）
  Future<ChapterSummary?> getSummaryByTitle(
      String bookId, String chapterTitle) async {
    _log.v('SummaryService',
        'getSummaryByTitle 开始执行, bookId: $bookId, chapterTitle: $chapterTitle');

    // 首先尝试从内存缓存中按标题查找
    for (final summary in _summaries.values) {
      if (summary.bookId == bookId && summary.chapterTitle == chapterTitle) {
        _log.v('SummaryService', 'getSummaryByTitle 从缓存找到匹配摘要: $chapterTitle');
        return summary;
      }
    }

    // 如果缓存中没有，从文件系统加载所有该书的摘要并查找
    final allSummaries = await getSummariesForBook(bookId);
    for (final summary in allSummaries) {
      if (summary.chapterTitle == chapterTitle) {
        _log.v('SummaryService', 'getSummaryByTitle 从文件找到匹配摘要: $chapterTitle');
        return summary;
      }
    }

    _log.v('SummaryService', 'getSummaryByTitle 未找到匹配摘要: $chapterTitle');
    return null;
  }

  /// 同步获取摘要（仅检查内存缓存，用于需要同步的场景）
  ChapterSummary? getSummarySync(String bookId, int chapterIndex) {
    _log.v('SummaryService',
        'getSummarySync 开始执行, bookId: $bookId, chapterIndex: $chapterIndex');
    final result = _summaries['${bookId}_$chapterIndex'];
    _log.v('SummaryService',
        'getSummarySync 执行完成, result: ${result != null ? "有内容" : "空"}');
    return result;
  }

  /// 获取书籍的所有摘要（按需加载）
  Future<List<ChapterSummary>> getSummariesForBook(String bookId) async {
    if (_summariesDir == null) return [];

    final dir = Directory(_summariesDir!);
    if (!await dir.exists()) return [];

    final summaries = <ChapterSummary>[];

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final fileName = entity.path.split('/').last;
          if (fileName.startsWith('${bookId}_')) {
            final content = await entity.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final summary = ChapterSummary.fromJson(json);

            // 验证解析出来的bookId与传入的bookId是否一致，防止加载错误的摘要
            if (summary.bookId == bookId) {
              _summaries['${summary.bookId}_${summary.chapterIndex}'] = summary;
              summaries.add(summary);
            } else {
              _log.w('SummaryService',
                  '摘要文件中的bookId与预期不符, 文件: $fileName, 期望: $bookId, 实际: ${summary.bookId}');
            }
          }
        } catch (e) {
          _log.e('SummaryService', '加载摘要失败: ${entity.path}', e);
        }
      }
    }

    summaries.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    return summaries;
  }

  /// 获取所有摘要（按需从文件加载）
  Future<List<ChapterSummary>> getAllSummaries() async {
    if (_summariesDir == null) return [];

    final dir = Directory(_summariesDir!);
    if (!await dir.exists()) return [];

    final summaries = <ChapterSummary>[];

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final summary = ChapterSummary.fromJson(json);

          // 添加到缓存和列表前验证bookId（在getAllSummaries中不需要过滤）
          _summaries['${summary.bookId}_${summary.chapterIndex}'] = summary;
          summaries.add(summary);
        } catch (e) {
          _log.e('SummaryService', '加载摘要失败: ${entity.path}', e);
        }
      }
    }

    return summaries;
  }

  Future<void> saveSummary(ChapterSummary summary) async {
    if (_summariesDir == null) return;

    _summaries['${summary.bookId}_${summary.chapterIndex}'] = summary;

    final fileName = '${summary.bookId}_${summary.chapterIndex}.json';
    final file = File('$_summariesDir/$fileName');

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary.toJson()),
    );
    _log.d('SummaryService', '摘要已保存: $fileName');
  }

  Future<void> deleteSummary(String bookId, int chapterIndex) async {
    final key = '${bookId}_$chapterIndex';
    _summaries.remove(key);

    final fileName = '${bookId}_$chapterIndex.json';
    final file = File('$_summariesDir/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteAllSummariesForBook(String bookId) async {
    final keysToRemove =
        _summaries.keys.where((k) => k.startsWith(bookId)).toList();

    for (final key in keysToRemove) {
      _summaries.remove(key);
    }

    if (_summariesDir == null) return;
    final dir = Directory(_summariesDir!);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.contains('/${bookId}_')) {
        await entity.delete();
      }
    }
  }

  bool hasSummary(String bookId, int chapterIndex) {
    return _summaries.containsKey('${bookId}_$chapterIndex');
  }

  int getSummaryCount(String bookId) {
    return _summaries.values.where((s) => s.bookId == bookId).length;
  }

  Future<void> generateSummariesForBook(Book book) async {
    if (!_aiService.isConfigured) {
      _log.w('SummaryService', 'AI服务未配置，跳过章节摘要生成');
      return;
    }

    final existingCount = getSummaryCount(book.id);
    _log.d(
        'SummaryService', '开始为书籍生成章节摘要: ${book.title}, 已有摘要: $existingCount');

    try {
      // 获取层级化的章节结构
      final hierarchicalChapters =
          await _epubService.getHierarchicalChapterList(book.filePath);
      _log.d(
          'SummaryService', '获取到层级化章节结构，顶层章节数: ${hierarchicalChapters.length}');

      // 将层级结构扁平化，并建立索引映射
      final flatChapters = _flattenWithIndex(hierarchicalChapters);
      _log.d('SummaryService', '扁平化后共 ${flatChapters.length} 个章节');

      // ========== 第一阶段：按层级顺序生成章节摘要 ==========
      _log.d('SummaryService', '=== 第一阶段：按层级顺序生成章节摘要 ===');

      // 按层级分组章节
      final chaptersByLevel = <int, List<_ChapterWithIndex>>{};
      for (final chapterInfo in flatChapters) {
        final level = chapterInfo.chapter.level;
        chaptersByLevel.putIfAbsent(level, () => []).add(chapterInfo);
      }

      // 先处理前置章节（前言、序言等）
      final prefaceIndices =
          _findPrefaceChapters(flatChapters.map((e) => e.chapter).toList());
      if (prefaceIndices.isNotEmpty) {
        _log.d('SummaryService', '发现前置章节: $prefaceIndices');
        await _generatePrefaceSummary(book, flatChapters, prefaceIndices);
      }

      // 按层级顺序处理：只处理 level 0 和 level 1（最多两级）
      final sortedLevels = chaptersByLevel.keys.toList()..sort();
      for (final level in sortedLevels) {
        // 跳过 level 2 及更深层的章节
        if (level >= 2) {
          _log.d('SummaryService', '=== 跳过层级 $level 及更深层的章节 ===');
          continue;
        }

        final levelChapters = chaptersByLevel[level]!;
        _log.d('SummaryService',
            '=== 处理层级 $level，共 ${levelChapters.length} 个章节 ===');

        for (final chapterInfo in levelChapters) {
          final i = chapterInfo.index;

          // 跳过已处理的前置章节
          if (prefaceIndices.contains(i)) continue;

          if (hasSummary(book.id, i)) {
            _log.d('SummaryService', '章节 $i 已有摘要，跳过');
            continue;
          }

          _log.d('SummaryService',
              '正在生成章节 $i 的摘要: ${chapterInfo.chapter.title} (层级: $level)');

          final content =
              await _epubService.getChapterContent(book.filePath, i);
          if (content == null || content.isEmpty) {
            _log.w('SummaryService', '章节 $i 内容为空或无法读取，跳过');
            continue;
          }
          _log.d('SummaryService', '章节 $i 内容长度: ${content.length}');

          final fullSummary = await _aiService.generateFullChapterSummary(
            content,
            chapterTitle: chapterInfo.chapter.title,
          );

          if (fullSummary != null) {
            final chapterSummary = ChapterSummary(
              bookId: book.id,
              chapterIndex: i,
              chapterTitle: chapterInfo.chapter.title,
              objectiveSummary: fullSummary['objectiveSummary'] ?? '',
              aiInsight: fullSummary['aiInsight'] ?? '',
              keyPoints: List<String>.from(fullSummary['keyPoints'] ?? []),
              createdAt: DateTime.now(),
            );
            await saveSummary(chapterSummary);
            _log.d('SummaryService', '章节 $i 摘要已保存');
          }

          await Future.delayed(const Duration(seconds: 1));
        }
      }
      _log.d('SummaryService', '=== 第一阶段完成：所有章节摘要已生成 ===');

      // ========== 第二阶段：广度优先 - 再生成所有小节摘要 ==========
      _log.d('SummaryService', '=== 第二阶段：生成所有小节摘要 ===');
      await _generateAllSectionSummaries(
          book, flatChapters.map((e) => e.chapter).toList());
      _log.d('SummaryService', '=== 第二阶段完成：所有小节摘要已生成 ===');

      _log.d('SummaryService', '书籍所有摘要生成完成: ${book.title}');
    } catch (e) {
      _log.e('SummaryService', '生成章节摘要失败', e);
    }
  }

  // 将层级化的章节结构扁平化，保持正确的顺序
  List<_ChapterWithIndex> _flattenWithIndex(
      List<ChapterInfo> hierarchicalChapters) {
    final result = <_ChapterWithIndex>[];
    var index = 0;

    void flatten(List<ChapterInfo> chapters) {
      for (final chapter in chapters) {
        result.add(_ChapterWithIndex(chapter, index++));
        if (chapter.children.isNotEmpty) {
          flatten(chapter.children);
        }
      }
    }

    flatten(hierarchicalChapters);
    return result;
  }

  // 检测前置章节（前言、序言、感谢等）
  List<int> _findPrefaceChapters(List<dynamic> chapters) {
    final prefaceKeywords = [
      '前言',
      '序言',
      '序',
      '致谢',
      '感谢',
      '献词',
      '引言',
      '导言',
      '导读',
      'preface',
      'foreword',
      'introduction',
      'acknowledgements',
      'dedication',
    ];

    final indices = <int>[];
    for (int i = 0; i < chapters.length; i++) {
      final title = chapters[i].title.toString().toLowerCase();
      for (final keyword in prefaceKeywords) {
        if (title.contains(keyword.toLowerCase())) {
          indices.add(i);
          break;
        }
      }
    }
    return indices;
  }

  // 合并生成前置章节的摘要
  Future<void> _generatePrefaceSummary(
    Book book,
    List<_ChapterWithIndex> chapters,
    List<int> indices,
  ) async {
    // 检查是否已有前置章节的摘要（使用第一个前置章节的索引）
    if (hasSummary(book.id, indices.first)) {
      _log.d('SummaryService', '前置章节摘要已存在，跳过');
      return;
    }

    _log.d('SummaryService',
        '正在合并生成前置章节摘要: ${indices.map((i) => chapters[i].chapter.title).join(', ')}');

    // 合并所有前置章节的内容
    final combinedContent = StringBuffer();
    final combinedTitle = StringBuffer('前言与导读');

    for (int i = 0; i < indices.length; i++) {
      final index = indices[i];
      final content =
          await _epubService.getChapterContent(book.filePath, index);
      if (content != null && content.isNotEmpty) {
        if (i > 0) combinedContent.write('\n\n---\n\n');
        combinedContent.write('<h2>${chapters[index].chapter.title}</h2>');
        combinedContent.write(content);
      }
    }

    if (combinedContent.isEmpty) {
      _log.w('SummaryService', '前置章节内容为空，跳过');
      return;
    }

    final fullSummary = await _aiService.generateFullChapterSummary(
      combinedContent.toString(),
      chapterTitle: combinedTitle.toString(),
    );

    if (fullSummary != null) {
      // 为第一个前置章节保存合并的摘要
      final chapterSummary = ChapterSummary(
        bookId: book.id,
        chapterIndex: indices.first,
        chapterTitle: combinedTitle.toString(),
        objectiveSummary: fullSummary['objectiveSummary'] ?? '',
        aiInsight: fullSummary['aiInsight'] ?? '',
        keyPoints: List<String>.from(fullSummary['keyPoints'] ?? []),
        createdAt: DateTime.now(),
      );
      await saveSummary(chapterSummary);
      _log.d('SummaryService', '前置章节合并摘要已保存');

      // 为其他前置章节创建空摘要标记（避免重复处理）
      for (int i = 1; i < indices.length; i++) {
        final emptySummary = ChapterSummary(
          bookId: book.id,
          chapterIndex: indices[i],
          chapterTitle: chapters[indices[i]].chapter.title,
          objectiveSummary: '(内容已合并至前言与导读)',
          aiInsight: '',
          keyPoints: [],
          createdAt: DateTime.now(),
        );
        await saveSummary(emptySummary);
      }
    }

    await Future.delayed(const Duration(seconds: 1));
  }

  // 生成所有小节摘要（广度优先：所有章节的小节一起生成）
  Future<void> _generateAllSectionSummaries(
      Book book, List<dynamic> chapters) async {
    // 收集所有需要生成摘要的小节
    final List<_SectionTask> tasks = [];

    for (int chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
      final sections =
          await _epubService.getSectionsInChapter(book.filePath, chapterIndex);

      if (sections.length >= 2) {
        final avgLength =
            sections.fold<int>(0, (sum, s) => sum + s.content.length) ~/
                sections.length;

        // 只有平均长度超过800字符的章节才生成小节摘要
        if (avgLength > 800) {
          for (int sectionIndex = 0;
              sectionIndex < sections.length;
              sectionIndex++) {
            final key = '${book.id}_${chapterIndex}_$sectionIndex';
            if (!_sectionSummaries.containsKey(key)) {
              tasks.add(_SectionTask(
                chapterIndex: chapterIndex,
                sectionIndex: sectionIndex,
                title: sections[sectionIndex].title,
                content: sections[sectionIndex].content,
              ));
            }
          }
        }
      }
    }

    _log.d('SummaryService', '需要生成 ${tasks.length} 个小节摘要');

    // 按顺序生成所有小节摘要
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      _log.d('SummaryService',
          '正在生成小节摘要 [${i + 1}/${tasks.length}]: 章${task.chapterIndex} 节${task.sectionIndex} - ${task.title}');

      final fullSummary = await _aiService.generateFullChapterSummary(
        task.content,
        chapterTitle: task.title,
      );

      if (fullSummary != null) {
        final summary = SectionSummary(
          bookId: book.id,
          chapterIndex: task.chapterIndex,
          sectionIndex: task.sectionIndex,
          sectionTitle: task.title,
          objectiveSummary: fullSummary['objectiveSummary'] ?? '',
          aiInsight: fullSummary['aiInsight'] ?? '',
          keyPoints: List<String>.from(fullSummary['keyPoints'] ?? []),
          createdAt: DateTime.now(),
        );
        await _saveSectionSummary(summary);
        _log.d('SummaryService', '小节摘要已保存: ${task.title}');
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _saveSectionSummary(SectionSummary summary) async {
    if (_sectionSummariesDir == null) return;

    _sectionSummaries[
            '${summary.bookId}_${summary.chapterIndex}_${summary.sectionIndex}'] =
        summary;

    final fileName =
        '${summary.bookId}_${summary.chapterIndex}_${summary.sectionIndex}.json';
    final file = File('$_sectionSummariesDir/$fileName');

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary.toJson()),
    );
    _log.d('SummaryService', '小节摘要文件已保存: $fileName');
  }

  SectionSummary? getSectionSummary(
      String bookId, int chapterIndex, int sectionIndex) {
    return _sectionSummaries['${bookId}_${chapterIndex}_$sectionIndex'];
  }

  Future<List<SectionSummary>> getSectionSummariesForChapter(
      String bookId, int chapterIndex) async {
    if (_sectionSummariesDir == null) return [];

    final dir = Directory(_sectionSummariesDir!);
    if (!await dir.exists()) return [];

    final summaries = <SectionSummary>[];
    final prefix = '${bookId}_${chapterIndex}_';

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final fileName = p.basename(entity.path); // 使用p.basename而不是split
          if (fileName.startsWith(prefix)) {
            final content = await entity.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final summary = SectionSummary.fromJson(json);
            _sectionSummaries[
                    '${summary.bookId}_${summary.chapterIndex}_${summary.sectionIndex}'] =
                summary;
            summaries.add(summary);
          }
        } catch (e) {
          _log.e('SummaryService', '加载小节摘要失败: ${entity.path}', e);
        }
      }
    }

    summaries.sort((a, b) => a.sectionIndex.compareTo(b.sectionIndex));
    return summaries;
  }
}

// 辅助类：带索引的章节信息
class _ChapterWithIndex {
  final ChapterInfo chapter;
  final int index;
  _ChapterWithIndex(this.chapter, this.index);
}

// 辅助类：小节任务
class _SectionTask {
  final int chapterIndex;
  final int sectionIndex;
  final String title;
  final String content;

  _SectionTask({
    required this.chapterIndex,
    required this.sectionIndex,
    required this.title,
    required this.content,
  });
}
