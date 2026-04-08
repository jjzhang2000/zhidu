import 'dart:io';
import 'dart:convert';
import '../models/section_summary.dart';
import '../models/book.dart';
import 'ai_service.dart';
import 'log_service.dart';

class SectionSummaryService {
  static final SectionSummaryService _instance =
      SectionSummaryService._internal();
  factory SectionSummaryService() => _instance;
  SectionSummaryService._internal();

  final Map<String, SectionSummary> _summaries = {};
  String? _summariesDir;
  final _aiService = AIService();
  final _log = LogService();

  Future<void> init() async {
    _summariesDir = '${Directory.current.path}/SectionSummaries';
    final dir = Directory(_summariesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // 不再预加载所有摘要，改为按需加载
  }

  /// 从文件按需加载小节摘要
  Future<SectionSummary?> _loadSectionSummaryFromFile(
      String bookId, int chapterIndex, int sectionIndex) async {
    if (_summariesDir == null) return null;

    final fileName = '${bookId}_${chapterIndex}_$sectionIndex.json';
    final file = File('$_summariesDir/$fileName');

    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final summary = SectionSummary.fromJson(json);
      _summaries['${bookId}_${chapterIndex}_$sectionIndex'] = summary;
      return summary;
    } catch (e) {
      _log.e('SectionSummaryService', '加载小节摘要失败: $fileName', e);
      return null;
    }
  }

  /// 获取指定小节的摘要（支持缓存和按需加载）
  Future<SectionSummary?> getSectionSummary(
      String bookId, int chapterIndex, int sectionIndex) async {
    final key = '${bookId}_${chapterIndex}_$sectionIndex';
    // 先检查内存缓存
    if (_summaries.containsKey(key)) {
      return _summaries[key];
    }
    // 按需从文件加载
    return await _loadSectionSummaryFromFile(
        bookId, chapterIndex, sectionIndex);
  }

  /// 同步获取小节摘要（仅检查内存缓存）
  SectionSummary? getSectionSummarySync(
      String bookId, int chapterIndex, int sectionIndex) {
    return _summaries['${bookId}_${chapterIndex}_$sectionIndex'];
  }

  /// 获取章节的所有小节摘要（按需加载）
  Future<List<SectionSummary>> getSectionSummariesForChapter(
      String bookId, int chapterIndex) async {
    if (_summariesDir == null) return [];

    final dir = Directory(_summariesDir!);
    if (!await dir.exists()) return [];

    final summaries = <SectionSummary>[];
    final prefix = '${bookId}_${chapterIndex}_';

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final fileName = entity.path.split('/').last;
          if (fileName.startsWith(prefix)) {
            final content = await entity.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final summary = SectionSummary.fromJson(json);
            _summaries[
                    '${summary.bookId}_${summary.chapterIndex}_${summary.sectionIndex}'] =
                summary;
            summaries.add(summary);
          }
        } catch (e) {
          _log.e('SectionSummaryService', '加载小节摘要失败: ${entity.path}', e);
        }
      }
    }

    summaries.sort((a, b) => a.sectionIndex.compareTo(b.sectionIndex));
    return summaries;
  }

  Future<void> saveSectionSummary(SectionSummary summary) async {
    if (_summariesDir == null) return;

    _summaries[
            '${summary.bookId}_${summary.chapterIndex}_${summary.sectionIndex}'] =
        summary;

    final fileName =
        '${summary.bookId}_${summary.chapterIndex}_${summary.sectionIndex}.json';
    final file = File('$_summariesDir/$fileName');

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary.toJson()),
    );
    _log.d('SectionSummaryService', '小节摘要已保存: $fileName');
  }

  Future<SectionSummary?> generateSectionSummary(
    Book book,
    int chapterIndex,
    int sectionIndex,
    String sectionTitle,
    String content,
  ) async {
    if (!_aiService.isConfigured) {
      _log.w('SectionSummaryService', 'AI服务未配置，跳过小节摘要生成');
      return null;
    }

    _log.d('SectionSummaryService',
        '正在生成小节摘要: ${book.title} - 章$chapterIndex - 节$sectionIndex');

    try {
      final fullSummary = await _aiService.generateFullChapterSummary(
        content,
        chapterTitle: sectionTitle,
      );

      if (fullSummary != null) {
        final summary = SectionSummary(
          bookId: book.id,
          chapterIndex: chapterIndex,
          sectionIndex: sectionIndex,
          sectionTitle: sectionTitle,
          objectiveSummary: fullSummary['objectiveSummary'] ?? '',
          aiInsight: fullSummary['aiInsight'] ?? '',
          keyPoints: List<String>.from(fullSummary['keyPoints'] ?? []),
          createdAt: DateTime.now(),
        );
        await saveSectionSummary(summary);
        _log.d('SectionSummaryService', '小节摘要已生成: $sectionTitle');
        return summary;
      }
    } catch (e) {
      _log.e('SectionSummaryService', '生成小节摘要失败', e);
    }

    return null;
  }
}
