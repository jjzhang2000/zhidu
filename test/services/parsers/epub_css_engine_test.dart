import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/services/parsers/epub_css_engine.dart';

void main() {
  EpubCssEngine engine() => EpubCssEngine(Archive());

  test('检测 <style> 中的 writing-mode: vertical-rl 并提取纯文本', () {
    const html = '''
<html><head><style>body { writing-mode: vertical-rl; }</style></head>
<body><p>春はあけぼの。</p><p>夏は夜。</p></body></html>
''';
    final result = engine().render(html);
    expect(result.isVertical, isTrue);
    expect(result.plainText, contains('春はあけぼの。'));
    expect(result.plainText, contains('夏は夜。'));
    // 段落之间应以换行分隔
    expect(result.plainText, contains('\n'));
  });

  test('检测 -epub-writing-mode: vertical-rl 为竖排', () {
    const html = '''
<html><head><style>body { -epub-writing-mode: vertical-rl; }</style></head>
<body><p>枕草子</p></body></html>
''';
    final result = engine().render(html);
    expect(result.isVertical, isTrue);
  });

  test('无 writing-mode 时为横排，但仍提取纯文本供分页复用', () {
    const html = '<html><body><p>hello world</p></body></html>';
    final result = engine().render(html);
    expect(result.isVertical, isFalse);
    expect(result.plainText, contains('hello world'));
  });

  test('多 token CSS 值完整内联，不被截断', () {
    const html = '''
<html><head><style>
h1 { color: #000000; border-bottom: 1px solid #e8e8e8; margin: 0 0 1rem; }
</style></head>
<body><h1>标题</h1></body></html>
''';
    final result = engine().render(html);
    // 值必须完整保留，而不是被截断成 "color: #" 或 "border-bottom: 1"
    expect(result.html, contains('color: #000000'));
    expect(result.html, contains('border-bottom: 1px solid #e8e8e8'));
    expect(result.html, contains('margin: 0 0 1rem'));
    expect(result.html, isNot(contains('color: #;')));
    expect(result.html, isNot(contains('border-bottom: 1;')));
  });

  test('非法占位符(PrismJS)被消毒，样式表不崩溃', () {
    const html = r'''
<html><head><style>
.token { color: #$$codeBlockColor$$; }
h2 { color: #24292e; }
</style></head>
<body><h2>标题</h2><span class="token">code</span></body></html>
''';
    final result = engine().render(html);
    // csslib 不再因 #$$ 崩溃，其余规则正常内联
    expect(result.html, contains('color: #24292e'));
    // 占位符已被替换为安全色，不再残留 $$
    expect(result.html, isNot(contains('\$\$')));
  });

  test('横排段落自动首行缩进（2em 内联占位）', () {
    const html =
        '<html><body><p>你好世界</p><p>第二段</p></body></html>';
    final result = engine().render(html);
    // 用 inline-block 包裹两个全角空格（U+3000，各 1em）占位，避免依赖 width 属性
    // （width 在 text-align: justify 下可能不生效，导致缩进坍缩为半个字）
    expect(result.html, contains('inline-block">\u3000\u3000</span>你好世界'));
    expect(result.html, contains('inline-block">\u3000\u3000</span>第二段'));
  });

  test('引言等多行段落（br 分隔 + nbsp 缩进）每行都得到 2em 缩进', () {
    const html =
        '<html><body><p class="a">\u00a0\u00a0他为什么<br/>\u00a0\u00a0从西城被捕开始<br/>\u00a0\u00a0即使冒再大的风险</p></body></html>';
    final result = engine().render(html);
    // 三行各自的 nbsp 都被剥离，统一替换为 inline-block 2em 占位
    expect(result.html, contains('inline-block">\u3000\u3000</span>他为什么'));
    expect(result.html, contains('inline-block">\u3000\u3000</span>从西城被捕开始'));
    expect(result.html, contains('inline-block">\u3000\u3000</span>即使冒再大的风险'));
    // 原来的 nbsp 不应残留为行首缩进
    expect(result.html, isNot(contains('\u00a0\u00a0他为什么')));
  });

  test('竖排段落不做首行缩进', () {
    const html = '''
<html><head><style>body { writing-mode: vertical-rl; }</style></head>
<body><p>春はあけぼの。</p></body></html>
''';
    final result = engine().render(html);
    expect(result.isVertical, isTrue);
    expect(result.html, isNot(contains('inline-block')));
  });

  test('图片 src 相对路径(../)与绝对路径(/)均转为 data URI', () {
    final archive = Archive()
      ..addFile(ArchiveFile(
        'OEBPS/images/foo.jpg',
        4,
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      ));
    final e = EpubCssEngine(archive);

    const html = '''
<html><body>
<p><img src="../images/foo.jpg" alt="foo.jpg"/></p>
<p><img src="/images/foo.jpg" alt="foo.jpg"/></p>
</body></html>
''';
    final result = e.render(html);
    // 相对/绝对路径均被解析为内嵌 data URI，不再显示文件名
    expect(result.html, contains('data:image/jpeg;base64,'));
    expect(result.html, isNot(contains('src="../images/foo.jpg"')));
    expect(result.html, isNot(contains('src="/images/foo.jpg"')));
  });
}
