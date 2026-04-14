/// 小节摘要服务
///
/// 负责管理书籍小节摘要的生成、存储、读取和缓存。
/// 采用"按需加载"策略，避免一次性加载所有摘要导致内存占用过高。
///
/// ## 存储结构
/// 小节摘要以JSON文件形式存储在 `SectionSummaries` 目录下：
/// - 文件命名格式：`{bookId}_{chapterIndex}_{sectionIndex}.json`
/// - 示例：`abc123_0_2.json` 表示书籍abc123第1章第3节的摘要
///
/// ## 缓存策略
/// - **内存缓存**：使用 [_summaries] Map缓存已加载的摘要
/// - **按需加载**：首次访问时从文件加载，后续直接从缓存读取
/// - **同步/异步访问**：提供同步方法 [getSectionSummarySync]（仅缓存）
///   和异步方法 [getSectionSummary]（缓存+文件）
///
/// ## 摘要生成流程
/// 1. 用户点击小节进入阅读界面
/// 2. 检查是否已有摘要，没有则调用 [generateSectionSummary]
/// 3. AI生成摘要后保存为JSON文件
/// 4. 同时更新内存缓存
///
/// ## 与章节摘要的区别
/// - 章节摘要（SummaryService）：一个章节一个摘要文件
/// - 小节摘要（SectionSummaryService）：一个章节可能包含多个小节
///   每个小节一个独立的摘要文件
library;

import 'dart:io';
import 'dart:convert';
import '../models/section_summary.dart';
import '../models/book.dart';
import 'ai_service.dart';
import 'log_service.dart';

/// 小节摘要管理服务（单例模式）
///
/// 提供小节摘要的CRUD操作和AI生成功能。
/// 采用文件存储+内存缓存的双重存储策略。
class SectionSummaryService {
  /// 单例实例
  static final SectionSummaryService _instance =
      SectionSummaryService._internal();

  /// 工厂构造函数，返回单例实例
  factory SectionSummaryService() => _instance;

  /// 私有构造函数
  SectionSummaryService._internal();

  /// 内存缓存，存储已加载的小节摘要
  ///
  /// Key格式：`{bookId}_{chapterIndex}_{sectionIndex}`
  /// Value：[SectionSummary] 小节摘要对象
  ///
  /// 示例：
  /// ```dart
  /// // bookId为"abc123"，第1章第3节
  /// _summaries['abc123_0_2'] // 对应的SectionSummary对象
  /// ```
  final Map<String, SectionSummary> _summaries = {};

  /// 摘要文件存储目录路径
  ///
  /// 在 [init] 方法中初始化，指向项目根目录下的 `SectionSummaries` 文件夹。
  /// 所有摘要文件都以JSON格式存储在此目录下。
  String? _summariesDir;

  /// AI服务，用于调用大模型生成摘要
  final _aiService = AIService();

  /// 日志服务
  final _log = LogService();

  /// 初始化服务
  ///
  /// 创建摘要存储目录（如果不存在）。
  /// 采用懒加载策略，不预加载任何摘要文件。
  ///
  /// 存储位置：`{项目根目录}/SectionSummaries/`
  Future<void> init() async {
    _summariesDir = '${Directory.current.path}/SectionSummaries';
    final dir = Directory(_summariesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // 不再预加载所有摘要，改为按需加载
  }

  /// 从文件按需加载小节摘要
  ///
  /// 尝试从文件系统加载指定小节的摘要。
  /// 加载成功后会自动更新内存缓存。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引（从0开始）
  /// - [sectionIndex]：小节索引（从0开始）
  ///
  /// 返回：小节摘要对象，不存在或读取失败则返回null
  ///
  /// 文件路径：`{_summariesDir}/{bookId}_{chapterIndex}_{sectionIndex}.json`
  ///
  /// 错误处理：
  /// - 文件不存在：返回null
  /// - JSON解析失败：记录错误日志，返回null
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
  ///
  /// 首先检查内存缓存，如果缓存中没有则从文件加载。
  /// 这是获取小节摘要的主要方法。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引（从0开始）
  /// - [sectionIndex]：小节索引（从0开始）
  ///
  /// 返回：小节摘要对象，不存在则返回null
  ///
  /// 查找顺序：
  /// 1. 检查内存缓存 [_summaries]
  /// 2. 如果缓存未命中，调用 [_loadSectionSummaryFromFile] 从文件加载
  ///
  /// 示例：
  /// ```dart
  /// final summary = await service.getSectionSummary('book123', 0, 2);
  /// if (summary != null) {
  ///   print('摘要：${summary.objectiveSummary}');
  /// }
  /// ```
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
  ///
  /// 仅检查内存缓存，不进行文件读取。
  /// 适用于需要快速判断摘要是否存在的场景。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  /// - [sectionIndex]：小节索引
  ///
  /// 返回：缓存中的小节摘要对象，未缓存则返回null
  ///
  /// 注意：
  /// - 此方法不会触发文件加载
  /// - 如果需要确保获取最新摘要，请使用异步方法 [getSectionSummary]
  ///
  /// 示例：
  /// ```dart
  /// // 快速检查缓存（非阻塞）
  /// final cached = service.getSectionSummarySync('book123', 0, 2);
  /// if (cached == null) {
  ///   // 缓存未命中，需要异步加载
  ///   final summary = await service.getSectionSummary('book123', 0, 2);
  /// }
  /// ```
  SectionSummary? getSectionSummarySync(
      String bookId, int chapterIndex, int sectionIndex) {
    return _summaries['${bookId}_${chapterIndex}_$sectionIndex'];
  }

  /// 获取章节的所有小节摘要（按需加载）
  ///
  /// 从存储目录中查找指定章节的所有小节摘要文件。
  /// 加载的摘要会自动缓存到内存中。
  ///
  /// 参数：
  /// - [bookId]：书籍唯一标识
  /// - [chapterIndex]：章节索引
  ///
  /// 返回：小节摘要列表，按小节索引升序排列
  ///
  /// 文件匹配规则：
  /// 遍历 [_summariesDir] 目录下所有 `.json` 文件，
  /// 筛选文件名以 `{bookId}_{chapterIndex}_` 开头的文件。
  ///
  /// 示例：
  /// 对于 bookId="abc123", chapterIndex=0：
  /// - `abc123_0_0.json` → 匹配（第1节）
  /// - `abc123_0_1.json` → 匹配（第2节）
  /// - `abc123_1_0.json` → 不匹配（第2章）
  /// - `def456_0_0.json` → 不匹配（不同书籍）
  ///
  /// 错误处理：
  /// - 目录不存在：返回空列表
  /// - 单个文件解析失败：跳过该文件，继续处理其他文件
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

  /// 保存小节摘要
  ///
  /// 将小节摘要同时保存到内存缓存和文件系统。
  /// 文件以格式化的JSON格式存储（带缩进），便于调试和手动查看。
  ///
  /// 参数：
  /// - [summary]：要保存的小节摘要对象
  ///
  /// 存储操作：
  /// 1. 更新内存缓存 [_summaries]
  /// 2. 写入JSON文件到 [_summariesDir] 目录
  ///
  /// 文件格式：
  /// ```json
  /// {
  ///   "bookId": "abc123",
  ///   "chapterIndex": 0,
  ///   "sectionIndex": 2,
  ///   "sectionTitle": "设计模式概述",
  ///   "objectiveSummary": "...",
  ///   "aiInsight": "",
  ///   "keyPoints": [],
  ///   "createdAt": "2026-04-14T10:30:00.000Z"
  /// }
  /// ```
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

  /// 生成小节摘要
  ///
  /// 调用AI服务为指定小节生成摘要内容。
  /// 生成成功后自动保存到文件系统。
  ///
  /// 参数：
  /// - [book]：书籍对象（用于获取书籍标题等信息）
  /// - [chapterIndex]：章节索引
  /// - [sectionIndex]：小节索引
  /// - [sectionTitle]：小节标题（用于AI提示词）
  /// - [content]：小节正文内容
  ///
  /// 返回：生成的摘要对象，失败则返回null
  ///
  /// 前置条件：
  /// - AI服务必须已配置（检查 [_aiService.isConfigured]）
  ///
  /// 生成流程：
  /// 1. 检查AI配置状态
  /// 2. 调用 [_aiService.generateFullChapterSummary] 生成摘要
  /// 3. 构建SectionSummary对象
  /// 4. 调用 [saveSectionSummary] 保存
  ///
  /// 注意：
  /// - 此方法复用了AI服务的章节摘要生成能力
  /// - 小节和章节使用相同的生成逻辑，只是粒度不同
  ///
  /// 示例：
  /// ```dart
  /// final summary = await service.generateSectionSummary(
  ///   book,
  ///   0,  // 第1章
  ///   2,  // 第3节
  ///   '设计模式概述',
  ///   '设计模式是软件开发中...',
  /// );
  /// ```
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
      final markdownSummary = await _aiService.generateFullChapterSummary(
        content,
        chapterTitle: sectionTitle,
      );

      if (markdownSummary != null) {
        final summary = SectionSummary(
          bookId: book.id,
          chapterIndex: chapterIndex,
          sectionIndex: sectionIndex,
          sectionTitle: sectionTitle,
          objectiveSummary: markdownSummary,
          aiInsight: '',
          keyPoints: [],
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
