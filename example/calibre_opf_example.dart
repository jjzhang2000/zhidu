/// Calibre OPF 集成示例
/// 
/// 此示例演示了如何使用新增的 Calibre OPF 集成功能
/// 
/// 使用方法:
/// 1. 将此文件放在与项目根目录相同的目录下
/// 2. 在书籍文件所在目录创建 metadata.opf 文件
/// 3. 运行智读应用导入书籍
/// 4. 应用将优先使用 OPF 中的元数据

import 'package:zhidu/services/opf_reader_service.dart';
import 'package:zhidu/models/opf_metadata.dart';

/// 这是一个示例 OPF 文件内容，展示了 Calibre 生成的典型格式
const String sampleCalibreOpf = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="uuid_id" opf:scheme="calibre">12345678-1234-5678-9012-123456789012</dc:identifier>
    <dc:title>三体</dc:title>
    <dc:creator opf:role="aut" opf:file-as="Liu, Cixin">刘慈欣</dc:creator>
    <dc:language>zh-CN</dc:language>
    <dc:publisher>重庆出版社</dc:publisher>
    <dc:description>《三体》是中国科幻作家刘慈欣创作的长篇科幻小说，讲述了文革期间一群科学家经历的一系列故事。</dc:description>
    <dc:subject>科幻小说</dc:subject>
    <dc:subject>中国文学</dc:subject>
    <dc:date opf:event="publication">2006-05-01</dc:date>
    <meta name="calibre:series" content="地球往事三部曲"/>
    <meta name="calibre:series_index" content="1.0"/>
    <meta name="cover" content="cover_image"/>
  </metadata>
  <manifest>
    <item id="cover_image" href="cover.jpg" media-type="image/jpeg"/>
    <item id="titlepage" href="titlepage.xhtml" media-type="application/xhtml+xml"/>
    <item id="stylesheet" href="stylesheet.css" media-type="text/css"/>
  </manifest>
  <spine>
    <itemref idref="titlepage"/>
  </spine>
</package>''';

/// 演示如何直接使用 OPF 读取服务
void demonstrateOpfReading() {
  print('=== Calibre OPF 集成示例 ===\n');
  
  print('1. 智读现在支持读取 Calibre 生成的 metadata.opf 文件');
  print('2. 在导入书籍时，如果同目录存在 metadata.opf，将优先使用其中的元数据');
  print('3. 支持的元数据包括：标题、作者、语言、出版社、描述、封面等\n');
  
  print('示例 OPF 文件结构:');
  print(sampleCalibreOpf.split('\n').take(5).join('\n'));
  print('  ...');
  print('  <dc:title>三体</dc:title>');
  print('  <dc:creator>刘慈欣</dc:creator>');
  print('  ...');
  print('</package>\n');
  
  print('4. 当您从 Calibre 书籍库导入书籍时，智读会自动检测并使用 OPF 元数据');
  print('5. 如果 OPF 文件不存在或格式错误，将回退到原有的 EPUB/PDF 解析逻辑');
}

/// 演示典型的 Calibre 书籍库结构
void demonstrateCalibreStructure() {
  print('\n=== Calibre 书籍库结构示例 ===\n');
  print('calibre_library/');
  print('├── 刘慈欣/');
  print('│   └── 三体 (12345)/');
  print('│       ├── 三体.epub');
  print('│       ├── metadata.opf    ← 智读将读取此文件');
  print('│       └── cover.jpg');
  print('');
  print('当导入 三体.epub 时，智读会自动查找同目录下的 metadata.opf');
  print('如果找到，将使用其中的元数据覆盖默认解析结果');
}

void main() {
  demonstrateOpfReading();
  demonstrateCalibreStructure();
  
  print('\n=== 总结 ===');
  print('• 轻量级集成：最小化代码改动');
  print('• 向后兼容：不破坏现有功能'); 
  print('• 容错处理：OPF错误不影响正常使用');
  print('• 优先级明确：OPF > 原有解析结果');
}