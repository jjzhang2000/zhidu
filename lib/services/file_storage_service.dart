// ===========================================================================
// 文件名称: file_storage_service.dart
// 文件描述: 文件存储服务
// 创建日期: 2024
//
// 功能说明:
//   提供本地文件系统的通用操作封装，包括：
//   - JSON文件的读写操作
//   - 文本文件的读写操作（主要用于Markdown导出）
//   - 文件和目录的删除操作
//   - 文件存在性检查
//   - 目录文件列表查询
//
// 设计模式: 单例模式
//   - 使用工厂构造函数确保全局唯一实例
//   - 所有方法均为异步操作，支持非阻塞IO
//
// 使用场景:
//   - AI配置文件的读取（ai_config.json）
//   - Markdown摘要文件的导出
//   - 书籍封面图片的存储
//   - 缓存文件的清理
//
// 依赖关系:
//   - LogService: 提供日志记录功能
//   - dart:io: 提供文件系统操作API
//   - dart:convert: 提供JSON编解码功能
// ===========================================================================

import 'dart:convert';
import 'dart:io';
import 'log_service.dart';

/// 文件存储服务
///
/// 提供统一的文件系统操作接口，封装了常用的文件读写功能。
/// 所有方法都进行了异常捕获和日志记录，确保调用方无需额外处理异常。
///
/// 使用示例:
/// ```dart
/// final fileStorage = FileStorageService();
///
/// // 读取JSON配置
/// final config = await fileStorage.readJson('config.json');
///
/// // 写入Markdown文件
/// await fileStorage.writeText('output.md', '# 标题\n内容');
/// ```
///
/// 线程安全:
///   所有方法都是异步的，可以安全地在多个isolate中并发调用。
///   但对同一文件的并发写入可能导致数据竞争，建议调用方自行控制。
class FileStorageService {
  /// 单例实例
  static final FileStorageService _instance = FileStorageService._internal();

  /// 工厂构造函数，返回单例实例
  factory FileStorageService() => _instance;

  /// 私有构造函数，防止外部实例化
  FileStorageService._internal();

  /// 日志服务实例
  final _log = LogService();

  /// 读取JSON文件
  ///
  /// 从指定路径读取JSON文件并解析为Map对象。
  ///
  /// 参数:
  ///   - filePath: 文件的绝对路径或相对路径
  ///
  /// 返回值:
  ///   - 成功: 返回解析后的Map<String, dynamic>对象
  ///   - 失败: 返回null（文件不存在或解析失败）
  ///
  /// 注意事项:
  ///   - 文件内容必须是有效的JSON格式
  ///   - JSON根元素必须是对象（{}），不能是数组或其他类型
  ///   - 文件不存在时返回null并记录verbose日志
  ///   - 解析失败时记录error日志并返回null
  ///
  /// 使用示例:
  /// ```dart
  /// final config = await fileStorage.readJson('ai_config.json');
  /// if (config != null) {
  ///   print('API Key: ${config['api_key']}');
  /// }
  /// ```
  Future<Map<String, dynamic>?> readJson(String filePath) async {
    try {
      final file = File(filePath);

      // 检查文件是否存在，避免FileNotFound异常
      if (!await file.exists()) {
        _log.v('FileStorageService', '文件不存在: $filePath');
        return null;
      }

      // 读取文件内容并解析JSON
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      // 捕获所有异常（文件读取错误、JSON解析错误等）
      _log.e('FileStorageService', '读取JSON失败: $filePath', e, stackTrace);
      return null;
    }
  }

  /// 写入JSON文件
  ///
  /// 将Map对象序列化为JSON格式并写入文件。
  /// 自动创建不存在的父目录。
  ///
  /// 参数:
  ///   - filePath: 目标文件的绝对路径或相对路径
  ///   - data: 要写入的数据，必须是Map<String, dynamic>类型
  ///
  /// 返回值:
  ///   - true: 写入成功
  ///   - false: 写入失败（权限不足、磁盘空间不足等）
  ///
  /// JSON格式化:
  ///   使用2空格缩进格式化JSON，便于人工阅读和调试。
  ///   示例输出:
  ///   ```json
  ///   {
  ///     "name": "智读",
  ///     "version": "1.0.0"
  ///   }
  ///   ```
  ///
  /// 使用示例:
  /// ```dart
  /// final success = await fileStorage.writeJson(
  ///   'output.json',
  ///   {'name': 'test', 'value': 123},
  /// );
  /// if (!success) {
  ///   print('写入失败');
  /// }
  /// ```
  Future<bool> writeJson(String filePath, Map<String, dynamic> data) async {
    try {
      final file = File(filePath);
      final dir = file.parent;

      // 确保父目录存在，recursive: true 会创建所有必要的中间目录
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 使用JsonEncoder进行格式化输出（2空格缩进）
      const encoder = JsonEncoder.withIndent('  ');
      final content = encoder.convert(data);

      // flush: true 确保数据立即写入磁盘
      await file.writeAsString(content, flush: true);
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '写入JSON失败: $filePath', e, stackTrace);
      return false;
    }
  }

  /// 读取文本文件
  ///
  /// 从指定路径读取文本文件的全部内容。
  /// 主要用于读取Markdown文件。
  ///
  /// 参数:
  ///   - filePath: 文件的绝对路径或相对路径
  ///
  /// 返回值:
  ///   - 成功: 返回文件的完整文本内容
  ///   - 失败: 返回null（文件不存在或读取失败）
  ///
  /// 编码说明:
  ///   默认使用UTF-8编码读取文件。
  ///   如果文件是其他编码（如GBK），可能会出现乱码。
  ///
  /// 使用示例:
  /// ```dart
  /// final content = await fileStorage.readText('summary.md');
  /// if (content != null) {
  ///   print('文件内容长度: ${content.length}');
  /// }
  /// ```
  Future<String?> readText(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '读取文本失败: $filePath', e, stackTrace);
      return null;
    }
  }

  /// 写入文本文件
  ///
  /// 将文本内容写入指定文件。
  /// 主要用于导出Markdown格式的摘要文件。
  ///
  /// 参数:
  ///   - filePath: 目标文件的绝对路径或相对路径
  ///   - content: 要写入的文本内容
  ///
  /// 返回值:
  ///   - true: 写入成功
  ///   - false: 写入失败
  ///
  /// 特性:
  ///   - 自动创建不存在的父目录
  ///   - 使用flush: true确保数据立即写入磁盘
  ///   - 会覆盖已存在的文件
  ///
  /// 使用示例:
  /// ```dart
  /// final markdown = '''# 书籍摘要
  ///
  /// ## 第一章
  /// 这是第一章的摘要内容。
  /// ''';
  /// await fileStorage.writeText('output/summary.md', markdown);
  /// ```
  Future<bool> writeText(String filePath, String content) async {
    try {
      final file = File(filePath);
      final dir = file.parent;

      // 确保父目录存在
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 写入文件，flush确保立即写入磁盘
      await file.writeAsString(content, flush: true);
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '写入文本失败: $filePath', e, stackTrace);
      return false;
    }
  }

  /// 删除文件
  ///
  /// 删除指定路径的文件。
  /// 如果文件不存在，不会报错，直接返回true。
  ///
  /// 参数:
  ///   - filePath: 要删除的文件路径
  ///
  /// 返回值:
  ///   - true: 删除成功或文件不存在
  ///   - false: 删除失败（权限不足等）
  ///
  /// 注意事项:
  ///   - 此方法只能删除文件，不能删除目录
  ///   - 如果传入目录路径，操作会失败
  ///   - 文件不存在时不会抛出异常
  ///
  /// 使用示例:
  /// ```dart
  /// // 删除临时文件
  /// await fileStorage.deleteFile('temp/cache.json');
  /// ```
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

  /// 删除目录及其内容
  ///
  /// 递归删除指定目录及其所有子文件和子目录。
  ///
  /// 参数:
  ///   - dirPath: 要删除的目录路径
  ///
  /// 返回值:
  ///   - true: 删除成功或目录不存在
  ///   - false: 删除失败（权限不足、目录被占用等）
  ///
  /// 危险操作警告:
  ///   此方法会递归删除目录下的所有内容，包括文件和子目录。
  ///   请确保传入正确的路径，避免误删重要数据。
  ///
  /// 使用场景:
  ///   - 清理书籍相关的所有缓存文件
  ///   - 删除导出的临时目录
  ///   - 清理应用缓存
  ///
  /// 使用示例:
  /// ```dart
  /// // 删除书籍的所有缓存
  /// await fileStorage.deleteDirectory('cache/book_123');
  /// ```
  Future<bool> deleteDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        // recursive: true 会删除目录及其所有内容
        await dir.delete(recursive: true);
      }
      return true;
    } catch (e, stackTrace) {
      _log.e('FileStorageService', '删除目录失败: $dirPath', e, stackTrace);
      return false;
    }
  }

  /// 列出目录下的文件
  ///
  /// 获取指定目录下所有文件的列表。
  /// 可选择性地按扩展名过滤。
  ///
  /// 参数:
  ///   - dirPath: 要扫描的目录路径
  ///   - extension: 可选的文件扩展名过滤器（如'.md', '.json'）
  ///
  /// 返回值:
  ///   - 成功: 返回File对象列表
  ///   - 失败: 返回空列表
  ///
  /// 过滤说明:
  ///   - 不传extension参数时，返回目录下所有文件
  ///   - 传入extension时，只返回匹配扩展名的文件
  ///   - 扩展名匹配是大小写敏感的（'.md' 不匹配 '.MD'）
  ///
  /// 注意事项:
  ///   - 只列出直接子文件，不会递归子目录
  ///   - 不包含目录，只包含文件
  ///   - 目录不存在时返回空列表而不是报错
  ///
  /// 使用示例:
  /// ```dart
  /// // 列出所有Markdown文件
  /// final mdFiles = await fileStorage.listFiles('summaries', extension: '.md');
  /// for (final file in mdFiles) {
  ///   print('找到文件: ${file.path}');
  /// }
  ///
  /// // 列出所有文件
  /// final allFiles = await fileStorage.listFiles('cache');
  /// ```
  Future<List<File>> listFiles(String dirPath, {String? extension}) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return [];
      }

      // 列出目录下的所有实体，过滤出文件
      final files = await dir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();

      // 如果指定了扩展名，进一步过滤
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
