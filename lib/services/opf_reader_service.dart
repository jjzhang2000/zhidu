import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../models/opf_metadata.dart';
import 'log_service.dart';

/// OPF读取服务
///
/// 用于从外部metadata.opf文件读取书籍元数据
/// 支持Calibre生成的OPF文件格式
class OpfReaderService {
  static final _log = LogService();

  /// 从指定的OPF文件路径读取元数据
  ///
  /// 参数:
  ///   [opfPath]: OPF文件的完整路径
  ///
  /// 返回值:
  ///   成功时返回OpfMetadata对象，失败时返回null
  static Future<OpfMetadata?> readFromOpfFile(String opfPath) async {
    try {
      if (!await File(opfPath).exists()) {
        _log.d('OpfReaderService', 'OPF文件不存在: $opfPath');
        return null;
      }

      final content = await File(opfPath).readAsString();
      return _parseOpfContent(content);
    } catch (e) {
      _log.w('OpfReaderService', '读取OPF文件失败: $opfPath, 错误: $e');
      return null;
    }
  }

  /// 从书籍文件同目录下查找并读取metadata.opf
  ///
  /// 参数:
  ///   [bookFilePath]: 书籍文件的完整路径
  ///
  /// 返回值:
  ///   如果找到metadata.opf并成功解析，返回OpfMetadata对象，否则返回null
  static Future<OpfMetadata?> readFromSameDirectory(String bookFilePath) async {
    final bookDir = p.dirname(bookFilePath);
    final opfPath = p.join(bookDir, 'metadata.opf');

    _log.d('OpfReaderService', '查找OPF文件: $opfPath');
    
    if (await File(opfPath).exists()) {
      _log.d('OpfReaderService', '找到OPF文件: $opfPath');
      return await readFromOpfFile(opfPath);
    }
    
    _log.d('OpfReaderService', '未找到OPF文件: $opfPath');
    return null;
  }

  /// 解析OPF文件内容
  ///
  /// 参数:
  ///   [content]: OPF文件的文本内容
  ///
  /// 返回值:
  ///   解析成功返回OpfMetadata对象，失败返回null
  static OpfMetadata? _parseOpfContent(String content) {
    try {
      final document = XmlDocument.parse(content);

      // 提取metadata部分
      final metadataElement = document.findAllElements('metadata').firstOrNull;
      if (metadataElement == null) {
        _log.w('OpfReaderService', 'OPF文件中未找到metadata元素');
        return null;
      }

      // 提取核心字段
      String? title;
      final titleElements = metadataElement.findAllElements('dc:title');
      if (titleElements.isNotEmpty) {
        title = titleElements.first.innerText.trim();
        _log.d('OpfReaderService', '从OPF获取标题: $title');
      }

      String? author;
      final creatorElements = metadataElement.findAllElements('dc:creator');
      if (creatorElements.isNotEmpty) {
        author = creatorElements.map((e) => e.innerText.trim()).join(', ');
        _log.d('OpfReaderService', '从OPF获取作者: $author');
      }

      String? language;
      final langElements = metadataElement.findAllElements('dc:language');
      if (langElements.isNotEmpty) {
        language = langElements.first.innerText.trim();
        _log.d('OpfReaderService', '从OPF获取语言: $language');
      }

      String? publisher;
      final publisherElements = metadataElement.findAllElements('dc:publisher');
      if (publisherElements.isNotEmpty) {
        publisher = publisherElements.first.innerText.trim();
        _log.d('OpfReaderService', '从OPF获取出版社: $publisher');
      }

      String? description;
      final descElements = metadataElement.findAllElements('dc:description');
      if (descElements.isNotEmpty) {
        description = descElements.first.innerText.trim();
        _log.d('OpfReaderService', '从OPF获取描述长度: ${description?.length ?? 0}');
      }

      List<String> subjects = [];
      final subjectElements = metadataElement.findAllElements('dc:subject');
      if (subjectElements.isNotEmpty) {
        subjects = subjectElements.map((e) => e.innerText.trim()).toList();
        _log.d('OpfReaderService', '从OPF获取主题数量: ${subjects.length}');
      }

      // 提取封面引用
      String? coverPath;
      final metaElements = metadataElement.findElements('meta');
      for (final meta in metaElements) {
        if (meta.getAttribute('name') == 'cover') {
          final coverId = meta.getAttribute('content');
          if (coverId != null) {
            _log.d('OpfReaderService', '找到封面ID: $coverId');
            
            // 在manifest中查找封面文件
            final manifestElements = document.findAllElements('manifest').firstOrNull;
            if (manifestElements != null) {
              final itemElements = manifestElements.findAllElements('item');
              for (final item in itemElements) {
                if (item.getAttribute('id') == coverId) {
                  coverPath = item.getAttribute('href');
                  _log.d('OpfReaderService', '找到封面路径: $coverPath');
                  break;
                }
              }
            }
            break;
          }
        }
      }

      return OpfMetadata(
        title: title,
        author: author,
        language: language,
        coverPath: coverPath,
        publisher: publisher,
        description: description,
        subjects: subjects,
      );
    } catch (e) {
      _log.w('OpfReaderService', '解析OPF内容失败, 错误: $e');
      return null;
    }
  }
}