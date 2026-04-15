/// 导出服务
///
/// 提供书籍摘要和数据的导出/导入功能：
/// - 导出书籍摘要为Markdown格式
/// - 导出所有数据为JSON格式（备份）
/// - 从JSON文件导入数据（恢复）
///
/// 采用单例模式，确保全局只有一个实例。
library;

import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../models/book.dart';
import '../models/chapter_summary.dart';
import '../models/app_settings.dart';
import '../services/book_service.dart';
import '../services/summary_service.dart';
import '../services/settings_service.dart';
import '../services/ai_service.dart';
import 'log_service.dart';

/// 导出服务类（单例）
///
/// 负责数据的导出和导入操作，支持以下格式：
/// - Markdown：用于书籍摘要的导出，便于阅读和分享
/// - JSON：用于完整数据备份，包含书籍信息和章节摘要
///
/// 使用示例：
/// ```dart
/// final exportService = ExportService();
///
/// // 导出书籍摘要
/// final path = await exportService.exportBookSummaryToMarkdown(book);
///
/// // 导出所有数据
/// final backupPath = await exportService.exportAllDataToJson();
///
/// // 导入备份
/// final success = await exportService.pickAndImportBackup();
/// ```
class ExportService {
  /// 单例实例
  static final ExportService _instance = ExportService._internal();

  /// 获取单例实例
  factory ExportService() => _instance;

  /// 私有构造函数
  ExportService._internal();

  /// 书籍服务实例
  final _bookService = BookService();

  /// 摘要服务实例
  final _summaryService = SummaryService();

  /// 日志服务实例
  final _log = LogService();

  /// 导出书籍摘要为Markdown格式
  ///
  /// 将指定书籍的所有章节摘要导出为Markdown文件，内容包括：
  /// - 书籍基本信息（标题、作者、导出时间、章节数）
  /// - 每章的客观摘要、AI见解、关键要点
  ///
  /// 参数：
  /// - [book] 要导出的书籍对象
  ///
  /// 返回值：
  /// - 导出成功：返回保存的文件路径
  /// - 导出失败或无摘要：返回null
  ///
  /// Markdown格式示例：
  /// ```markdown
  /// # 书籍标题
  ///
  /// **作者**: 作者名
  /// **导出时间**: 2026-04-14 12:00:00
  /// **章节数**: 10
  ///
  /// ---
  ///
  /// ## 第一章 标题
  ///
  /// ### 客观摘要
  /// ...
  ///
  /// ### AI 见解
  /// ...
  ///
  /// ### 关键要点
  /// - 要点1
  /// - 要点2
  ///
  /// ---
  /// ```
  Future<String?> exportBookSummaryToMarkdown(Book book) async {
    // 获取该书的所有章节摘要
    final summaries = await _summaryService.getSummariesForBook(book.id);

    // 如果没有任何摘要，返回null
    if (summaries.isEmpty) {
      return null;
    }

    // 使用StringBuffer构建Markdown内容
    final buffer = StringBuffer();

    // 写入书籍标题（一级标题）
    buffer.writeln('# ${book.title}');
    buffer.writeln();

    // 写入书籍基本信息
    buffer.writeln('**作者**: ${book.author}');
    buffer.writeln('**导出时间**: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('**章节数**: ${book.totalChapters}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    // 遍历每个章节摘要
    for (final summary in summaries) {
      // 写入章节标题（二级标题）
      buffer.writeln('## ${summary.chapterTitle}');
      buffer.writeln();

      // 写入客观摘要
      buffer.writeln('### 客观摘要');
      buffer.writeln();
      buffer.writeln(summary.objectiveSummary);
      buffer.writeln();

      // 写入AI见解
      buffer.writeln('### AI 见解');
      buffer.writeln();
      buffer.writeln(summary.aiInsight);
      buffer.writeln();

      // 如果有关键要点，写入列表
      if (summary.keyPoints.isNotEmpty) {
        buffer.writeln('### 关键要点');
        buffer.writeln();
        for (final point in summary.keyPoints) {
          buffer.writeln('- $point');
        }
        buffer.writeln();
      }

      // 写入分隔线
      buffer.writeln('---');
      buffer.writeln();
    }

    // 保存到文件
    return await _saveToFile(
      content: buffer.toString(),
      defaultFileName: '${book.title}_摘要.md',
      dialogTitle: '导出书籍摘要',
    );
  }

  /// 导出所有数据为JSON格式
  ///
  /// 将应用中的所有数据（书籍信息、章节摘要和设置）导出为JSON文件，
  /// 用于数据备份和迁移。
  ///
  /// JSON结构：
  /// ```json
  /// {
  ///   "exportTime": "2026-04-14T12:00:00.000",
  ///   "version": "1.0",
  ///   "books": [...],
  ///   "summaries": [...],
  ///   "settings": {...}
  /// }
  /// ```
  ///
  /// 返回值：
  /// - 导出成功：返回保存的文件路径
  /// - 用户取消或失败：返回null
  Future<String?> exportAllDataToJson() async {
    // 获取所有章节摘要
    final summaries = await _summaryService.getAllSummaries();

    // 获取当前设置
    final settings = SettingsService().settings;

    // 构建导出数据结构
    final data = {
      'exportTime': DateTime.now().toIso8601String(),
      'version': '1.0',
      'books': _bookService.books.map((b) => b.toJson()).toList(),
      'summaries': summaries.map((s) => s.toJson()).toList(),
      'settings': settings.toJson(),
    };

    // 使用JsonEncoder格式化输出（缩进2个空格）
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    // 保存到文件
    return await _saveToFile(
      content: jsonString,
      defaultFileName:
          'zhidu_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      dialogTitle: '导出备份数据',
    );
  }

  /// 保存内容到文件
  ///
  /// 弹出文件保存对话框，让用户选择保存位置，然后将内容写入文件。
  ///
  /// 参数：
  /// - [content] 要保存的内容
  /// - [defaultFileName] 默认文件名
  /// - [dialogTitle] 对话框标题
  ///
  /// 返回值：
  /// - 保存成功：返回文件路径
  /// - 用户取消或失败：返回null
  Future<String?> _saveToFile({
    required String content,
    required String defaultFileName,
    required String dialogTitle,
  }) async {
    try {
      String? outputPath;

      // 打开目录选择对话框
      await FilePicker.platform
          .getDirectoryPath(
        dialogTitle: dialogTitle,
      )
          .then((directoryPath) {
        if (directoryPath != null) {
          // 构建完整文件路径
          outputPath = '$directoryPath/$defaultFileName';
        }
      });

      // 用户取消了选择
      if (outputPath == null) {
        return null;
      }

      // 创建文件并写入内容
      final file = File(outputPath!);
      await file.writeAsString(content);

      return outputPath;
    } catch (e) {
      // 记录错误日志
      _log.e('ExportService', '导出失败', e);
      return null;
    }
  }

  /// 从JSON文件导入数据
  ///
  /// 读取指定JSON文件，解析并恢复书籍、摘要数据和设置到数据库。
  ///
  /// 参数：
  /// - [filePath] JSON文件路径
  ///
  /// 返回值：
  /// - 导入成功：返回true
  /// - 文件不存在或解析失败：返回false
  ///
  /// 注意事项：
  /// - 导入会覆盖同ID的现有数据
  /// - 文件格式必须符合exportAllDataToJson的输出格式
  /// - 设置数据会通过SettingsService.updateAllSettings()恢复
  /// - AI配置会通过AIService.reloadConfig()重新加载
  Future<bool> importFromJson(String filePath) async {
    try {
      final file = File(filePath);

      // 检查文件是否存在
      if (!await file.exists()) {
        return false;
      }

      // 读取并解析JSON内容
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // 解析书籍列表
      final books = (data['books'] as List?)
              ?.map((b) => Book.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [];

      // 保存每个书籍到数据库
      for (final book in books) {
        await _bookService.updateBook(book);
      }

      // 解析章节摘要列表
      final summaries = (data['summaries'] as List?)
              ?.map((s) => ChapterSummary.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];

      // 保存每个摘要到数据库
      for (final summary in summaries) {
        await _summaryService.saveSummary(summary);
      }

      // 恢复设置（如果存在）
      if (data['settings'] != null) {
        try {
          final settingsJson = data['settings'] as Map<String, dynamic>;
          final settings = AppSettings.fromJson(settingsJson);
          await _restoreSettings(settings);
        } catch (e) {
          _log.w('ExportService', '设置恢复失败，跳过: $e');
          // 继续处理，不要因为设置恢复失败而中断整个导入
        }
      }

      return true;
    } catch (e) {
      // 记录错误日志
      _log.e('ExportService', '导入失败', e);
      return false;
    }
  }

  /// 恢复设置到SettingsService
  ///
  /// 参数：
  /// - [settings] 要恢复的设置对象
  ///
  /// 恢复过程：
  /// 1. 调用SettingsService.updateAllSettings()更新所有设置
  /// 2. 调用AIService.reloadConfig()重新加载AI配置
  Future<void> _restoreSettings(AppSettings settings) async {
    _log.d('ExportService', '开始恢复设置...');

    // 调用updateAllSettings一次性更新所有设置
    await SettingsService().updateAllSettings(settings);

    // 重新加载AIService配置
    await AIService().reloadConfig();

    _log.d('ExportService', '设置恢复完成');
  }

  /// 选择并导入备份文件
  ///
  /// 弹出文件选择对话框，让用户选择JSON备份文件，然后导入数据。
  /// 这是importFromJson的便捷封装，提供用户友好的文件选择界面。
  ///
  /// 返回值：
  /// - 导入成功：返回导入的文件路径
  /// - 用户取消或导入失败：返回null
  ///
  /// 使用示例：
  /// ```dart
  /// final filePath = await exportService.pickAndImportBackup();
  /// if (filePath != null) {
  ///   print('数据已从 $filePath 恢复');
  /// } else {
  ///   print('导入取消或失败');
  /// }
  /// ```
  Future<String?> pickAndImportBackup() async {
    try {
      // 打开文件选择对话框，只允许选择JSON文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: '选择备份文件',
      );

      // 用户取消选择
      if (result == null || result.files.isEmpty) {
        return null;
      }

      // 获取选中文件的路径
      final filePath = result.files.first.path;
      if (filePath == null) {
        return null;
      }

      // 执行导入
      final success = await importFromJson(filePath);
      return success ? filePath : null;
    } catch (e) {
      // 记录错误日志
      _log.e('ExportService', '选择备份文件失败', e);
      return null;
    }
  }
}
