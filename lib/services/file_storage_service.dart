// 文件存储服务：封装 JSON/文本读写、文件与目录删除、目录文件列表等本地 IO

import 'dart:convert';
import 'dart:io';
import 'log_service.dart';

/// 文件存储服务（单例）
///
/// 提供统一的本地文件读写接口，所有方法内部捕获异常并记录日志，
/// 失败时返回 null / false / 空列表，调用方无需额外处理异常。
class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();

  factory FileStorageService() => _instance;

  FileStorageService._internal();

  final _log = LogService();

  /// 读取并解析 JSON 文件
  ///
  /// 文件不存在或解析失败时返回 null。
  Future<Map<String, dynamic>?> readJson(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '读取JSON失败: $filePath', e, stackTrace);
      return null;
    }
  }

  /// 写入 JSON 文件（2 空格缩进，自动创建父目录）
  ///
  /// 写入成功返回 true。
  Future<bool> writeJson(String filePath, Map<String, dynamic> data) async {
    try {
      final file = File(filePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(data), flush: true);
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '写入JSON失败: $filePath', e, stackTrace);
      return false;
    }
  }

  /// 读取文本文件（UTF-8）
  ///
  /// 文件不存在或读取失败时返回 null。
  Future<String?> readText(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '读取文本失败: $filePath', e, stackTrace);
      return null;
    }
  }

  /// 写入文本文件（自动创建父目录，覆盖已有文件）
  ///
  /// 写入成功返回 true。
  Future<bool> writeText(String filePath, String content) async {
    try {
      final file = File(filePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await file.writeAsString(content, flush: true);
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '写入文本失败: $filePath', e, stackTrace);
      return false;
    }
  }

  /// 删除文件
  ///
  /// 文件不存在也视为成功；仅用于删除文件，不能删除目录。
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '删除文件失败: $filePath', e, stackTrace);
      return false;
    }
  }

  /// 递归删除目录及其全部内容
  ///
  /// 目录不存在也视为成功。
  Future<bool> deleteDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '删除目录失败: $dirPath', e, stackTrace);
      return false;
    }
  }

  /// 列出目录下的直接子文件（不递归）
  ///
  /// [extension] 可选，按扩展名过滤（大小写敏感）。目录不存在时返回空列表。
  Future<List<File>> listFiles(String dirPath, {String? extension}) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return [];

      final files = await dir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();

      if (extension != null) {
        return files.where((f) => f.path.endsWith(extension)).toList();
      }
      return files;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '列出文件失败: $dirPath', e, stackTrace);
      return [];
    }
  }
}
