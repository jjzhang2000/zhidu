import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../models/book.dart';
import '../models/chapter_summary.dart';
import '../services/book_service.dart';
import '../services/summary_service.dart';
import 'log_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final _bookService = BookService();
  final _summaryService = SummaryService();
  final _log = LogService();

  Future<String?> exportBookSummaryToMarkdown(Book book) async {
    final summaries = await _summaryService.getSummariesForBook(book.id);
    if (summaries.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();

    buffer.writeln('# ${book.title}');
    buffer.writeln();
    buffer.writeln('**作者**: ${book.author}');
    buffer.writeln('**导出时间**: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('**章节数**: ${book.totalChapters}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (final summary in summaries) {
      buffer.writeln('## ${summary.chapterTitle}');
      buffer.writeln();

      buffer.writeln('### 客观摘要');
      buffer.writeln();
      buffer.writeln(summary.objectiveSummary);
      buffer.writeln();

      buffer.writeln('### AI 见解');
      buffer.writeln();
      buffer.writeln(summary.aiInsight);
      buffer.writeln();

      if (summary.keyPoints.isNotEmpty) {
        buffer.writeln('### 关键要点');
        buffer.writeln();
        for (final point in summary.keyPoints) {
          buffer.writeln('- $point');
        }
        buffer.writeln();
      }

      buffer.writeln('---');
      buffer.writeln();
    }

    return await _saveToFile(
      content: buffer.toString(),
      defaultFileName: '${book.title}_摘要.md',
      dialogTitle: '导出书籍摘要',
    );
  }

  Future<String?> exportAllDataToJson() async {
    final summaries = await _summaryService.getAllSummaries();
    final data = {
      'exportTime': DateTime.now().toIso8601String(),
      'version': '1.0',
      'books': _bookService.books.map((b) => b.toJson()).toList(),
      'summaries': summaries.map((s) => s.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    return await _saveToFile(
      content: jsonString,
      defaultFileName:
          'zhidu_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      dialogTitle: '导出备份数据',
    );
  }

  Future<String?> _saveToFile({
    required String content,
    required String defaultFileName,
    required String dialogTitle,
  }) async {
    try {
      String? outputPath;

      await FilePicker.platform
          .getDirectoryPath(
        dialogTitle: dialogTitle,
      )
          .then((directoryPath) {
        if (directoryPath != null) {
          outputPath = '$directoryPath/$defaultFileName';
        }
      });

      if (outputPath == null) {
        return null;
      }

      final file = File(outputPath!);
      await file.writeAsString(content);

      return outputPath;
    } catch (e) {
      _log.e('ExportService', '导出失败', e);
      return null;
    }
  }

  Future<bool> importFromJson(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final books = (data['books'] as List?)
              ?.map((b) => Book.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [];

      for (final book in books) {
        await _bookService.updateBook(book);
      }

      final summaries = (data['summaries'] as List?)
              ?.map((s) => ChapterSummary.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];

      for (final summary in summaries) {
        await _summaryService.saveSummary(summary);
      }

      return true;
    } catch (e) {
      _log.e('ExportService', '导入失败', e);
      return false;
    }
  }

  Future<String?> pickAndImportBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: '选择备份文件',
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return null;
      }

      final success = await importFromJson(filePath);
      return success ? filePath : null;
    } catch (e) {
      _log.e('ExportService', '选择备份文件失败', e);
      return null;
    }
  }
}
