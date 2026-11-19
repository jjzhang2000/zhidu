import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cascadia/cascadia.dart' as cascadia;
import 'package:crypto/crypto.dart' show sha1;
import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'rendered_content.dart';

/// 一条 CSS 声明模板（尚未绑定到具体元素）
class _DeclTemplate {
  final String property;
  final String value;
  final bool important;

  const _DeclTemplate(this.property, this.value, this.important);
}

/// 一条 CSS 规则（选择器组 + 声明列表）
class _CssRule {
  final List<String> selectors;
  final List<_DeclTemplate> declarations;

  const _CssRule(this.selectors, this.declarations);
}

/// 绑定到具体元素上的声明，携带级联比较所需的特异性与源顺序
class _WinningDecl {
  final String value;
  final bool important;
  final cascadia.Specificity specificity;
  final int order;

  const _WinningDecl(this.value, this.important, this.specificity, this.order);

  bool winsOver(_WinningDecl other) {
    if (important != other.important) return important;
    final cmp = specificity.compareTo(other.specificity);
    if (cmp != 0) return cmp > 0;
    return order > other.order;
  }
}

/// EPUB CSS 内联引擎
///
/// 负责将 EPUB 中的外部 CSS 与 <style> 块按级联规则（含特异性、源顺序、
/// !important、@media 基础求值）内联到元素的 style 属性，将图片资源转为
/// data URI，并从 @font-face 提取需运行时注册的字体。
class EpubCssEngine {
  final Archive archive;

  /// EPUB 唯一标识符，用于字体混淆（IDPF）的反混淆
  final String identifier;

  EpubCssEngine(this.archive, {this.identifier = ''});

  /// 对章节 HTML 做渲染前处理，返回内联后的 HTML 与内嵌字体
  RenderedContent render(String chapterHtml) {
    try {
      final document = html_parser.parse(chapterHtml);

      final fonts = <EmbeddedFont>[];
      final cssText = _collectCss(document);
      _extractFonts(cssText, fonts);
      _inlineCss(document, cssText);
      _inlineImages(document);
      _inlineSvgImages(document);
      _removeLinkAndStyle(document);

      final isVertical = _detectVertical(document, cssText);
      return RenderedContent(
        _finalizeHtml(document, chapterHtml),
        fonts: fonts,
        isVertical: isVertical,
        // 纯文本始终提取，供竖排与分页模式复用
        plainText: _extractPlainText(document),
      );
    } catch (_) {
      return RenderedContent(chapterHtml);
    }
  }

  // ---- CSS 收集 ----

  /// 收集 archive 内所有 .css 文件 + 章节 HTML 中的 <style> 块
  String _collectCss(dom.Document document) {
    final buffer = StringBuffer();

    // 外部 CSS（按归档内文件顺序）
    for (final file in archive.files) {
      final name = file.name.toLowerCase();
      if (name.endsWith('.css')) {
        buffer.writeln(utf8.decode(file.readBytes() ?? const <int>[]));
      }
    }

    // 内联 <style> 块
    for (final style in document.querySelectorAll('style')) {
      buffer.writeln(style.text);
    }

    return buffer.toString();
  }

  // ---- 字体提取 ----

  void _extractFonts(String cssText, List<EmbeddedFont> fonts) {
    final re = RegExp(r'@font-face\s*\{([^{}]*)\}', caseSensitive: false);
    for (final m in re.allMatches(cssText)) {
      final block = m.group(1)!;
      final family = _stripQuotes(_extractDecl(block, 'font-family') ?? '');
      final src = _extractDecl(block, 'src') ?? '';
      if (family.isEmpty || src.isEmpty) continue;

      for (final url in _extractUrls(src)) {
        final bytes = _resolveFontBytes(url);
        if (bytes != null) {
          fonts.add(EmbeddedFont(family, _maybeDeobfuscate(bytes)));
          break;
        }
      }
    }
  }

  Uint8List? _resolveFontBytes(String url) {
    final file = _findFileByName(_urlDecode(url));
    return file?.readBytes();
  }

  Uint8List _maybeDeobfuscate(Uint8List data) {
    if (identifier.isEmpty || _hasFontMagic(data)) return data;
    final key = sha1.convert(utf8.encode(identifier)).bytes;
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ key[i % key.length];
    }
    return out;
  }

  bool _hasFontMagic(Uint8List data) {
    if (data.length < 4) return false;
    if (data[0] == 0x00 && data[1] == 0x01 && data[2] == 0x00 && data[3] == 0x00) {
      return true; // TrueType/OpenType
    }
    final sig = ascii.decode(data.sublist(0, 4), allowInvalid: true);
    return const {'OTTO', 'true', 'typ1', 'wOFF', 'wOF2'}.contains(sig);
  }

  // ---- CSS 内联（级联） ----

  void _inlineCss(dom.Document document, String cssText) {
    css.StyleSheet? stylesheet;
    try {
      stylesheet = css_parser.parse(cssText, errors: []);
    } catch (_) {
      return;
    }

    final rules = <_CssRule>[];
    _walkRules(stylesheet.topLevels, rules);

    // 元素 -> 属性 -> 胜出声明
    final computed = <dom.Element, Map<String, _WinningDecl>>{};
    var order = 0;

    for (final rule in rules) {
      for (final selectorText in rule.selectors) {
        final sel = _safeParse(selectorText);
        if (sel == null) continue;
        final specificity = sel.specificity;

        for (final el in document.querySelectorAll('*')) {
          bool matched;
          try {
            matched = sel.match(el);
          } catch (_) {
            matched = false;
          }
          if (!matched) continue;

          final map = computed.putIfAbsent(el, () => {});
          for (final tpl in rule.declarations) {
            final decl = _WinningDecl(
                tpl.value, tpl.important, specificity, order);
            final existing = map[tpl.property];
            if (existing == null || decl.winsOver(existing)) {
              map[tpl.property] = decl;
            }
          }
        }
      }
      order++;
    }

    // 写回 style 属性（原有内联 style 优先级最高，覆盖计算结果）
    for (final entry in computed.entries) {
      final el = entry.key;
      final merged = <String, String>{};
      for (final e in entry.value.entries) {
        merged[e.key] = e.value.value;
      }
      for (final e in _parseInlineDecls(el.attributes['style']).entries) {
        merged[e.key] = e.value;
      }
      if (merged.isNotEmpty) {
        el.attributes['style'] =
            merged.entries.map((e) => '${e.key}: ${e.value}').join('; ');
      }
    }

    // 内联 style 中的 background-image url() 转 data URI
    for (final el in document.querySelectorAll('*')) {
      final style = el.attributes['style'];
      if (style == null) continue;
      final resolved = _resolveBackgroundImages(style);
      if (resolved != style) el.attributes['style'] = resolved;
    }
  }

  void _walkRules(List<css.TreeNode> nodes, List<_CssRule> rules) {
    for (final node in nodes) {
      if (node is css.RuleSet) {
        final rule = _buildRule(node);
        if (rule != null) rules.add(rule);
      } else if (node is css.MediaDirective) {
        if (_mediaMatches(node)) {
          _walkRules(node.rules, rules);
        }
      } else if (node is css.SupportsDirective) {
        _walkRules(node.groupRuleBody, rules);
      } else if (node is css.DocumentDirective) {
        _walkRules(node.groupRuleBody, rules);
      }
      // @import / @font-face / @page / @keyframes 等其余指令忽略
    }
  }

  _CssRule? _buildRule(css.RuleSet node) {
    final group = node.selectorGroup;
    if (group == null) return null;

    final selectors = <String>[];
    for (final s in group.selectors) {
      final text = s.span?.text.trim() ?? '';
      if (text.isNotEmpty) selectors.add(text);
    }
    if (selectors.isEmpty) return null;

    final decls = <_DeclTemplate>[];
    for (final d in node.declarationGroup.declarations) {
      if (d is! css.Declaration) continue;
      final value = d.expression?.span?.text.trim();
      if (value == null || value.isEmpty) continue;
      decls.add(_DeclTemplate(d.property, value, d.important));
    }
    if (decls.isEmpty) return null;

    return _CssRule(selectors, decls);
  }

  bool _mediaMatches(css.MediaDirective directive) {
    const virtualWidth = 1000.0;
    for (final query in directive.mediaQueries) {
      final text = query.span.text.toLowerCase();
      if (text.contains('print')) continue;

      final minW = _extractPx(text, 'min-width');
      final maxW = _extractPx(text, 'max-width');
      if (minW != null && virtualWidth < minW) continue;
      if (maxW != null && virtualWidth > maxW) continue;
      return true;
    }
    return false;
  }

  cascadia.Sel? _safeParse(String selector) {
    try {
      return cascadia.parseLenient(selector);
    } catch (_) {
      try {
        return cascadia.parse(selector);
      } catch (_) {
        return null;
      }
    }
  }

  // ---- 图片处理 ----

  void _inlineImages(dom.Document document) {
    for (final img in document.querySelectorAll('img')) {
      final src = img.attributes['src'];
      if (src == null || src.isEmpty) continue;
      if (src.startsWith('data:') || src.startsWith('http')) continue;
      final dataUri = _resolveImageDataUri(src);
      if (dataUri != null) img.attributes['src'] = dataUri;
    }
  }

  void _inlineSvgImages(dom.Document document) {
    for (final svg in document.querySelectorAll('svg')) {
      final image = svg.querySelector('image');
      String? href;
      if (image != null) {
        // xlink:href 为命名空间属性，package:html 以 AttributeName 作为 key，
        // 无法用字符串直接索引，需遍历匹配。
        for (final entry in image.attributes.entries) {
          final key = entry.key.toString();
          if (key == 'xlink:href' || key == 'href') {
            href = entry.value;
            break;
          }
        }
      }
      if (href == null || href.isEmpty || href.startsWith('data:')) continue;
      final dataUri = _resolveImageDataUri(href);
      if (dataUri == null) continue;

      final img = document.createElement('img');
      img.attributes['src'] = dataUri;
      img.attributes['alt'] = '';
      // 尽量保留 SVG 的宽高，否则退回自适应样式
      final width = svg.attributes['width'];
      final height = svg.attributes['height'];
      if (width != null) img.attributes['width'] = width;
      if (height != null) img.attributes['height'] = height;
      if (width == null && height == null) {
        img.attributes['style'] = 'width:100%;height:auto;';
      }
      svg.replaceWith(img);
    }
  }

  String? _resolveImageDataUri(String src) {
    final file = _findFileByName(_urlDecode(src));
    if (file == null) return null;
    final bytes = file.readBytes();
    if (bytes == null) return null;
    final mime = _mimeFromName(file.name);
    return 'data:$mime;base64,${base64.encode(bytes)}';
  }

  String _resolveBackgroundImages(String style) {
    return style.replaceAllMapped(
      RegExp(r'url\(\s*([\x22\x27]?)([^\x22\x27)]+)\1\s*\)', caseSensitive: false),
      (m) {
        final src = m.group(2)!;
        if (src.startsWith('data:') || src.startsWith('http')) {
          return m.group(0)!;
        }
        final dataUri = _resolveImageDataUri(src);
        return dataUri == null ? m.group(0)! : 'url($dataUri)';
      },
    );
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  // ---- 资源定位 ----

  ArchiveFile? _findFileByName(String name) {
    name = name.replaceAll('\\', '/');
    final lower = name.toLowerCase();

    for (final file in archive.files) {
      if (file.name == name) return file;
    }
    for (final file in archive.files) {
      if (file.name.endsWith('/$name')) return file;
    }
    for (final file in archive.files) {
      if (file.name.toLowerCase() == lower) return file;
    }
    for (final file in archive.files) {
      if (file.name.toLowerCase().endsWith('/$lower')) return file;
    }
    return null;
  }

  // ---- 收尾 ----

  void _removeLinkAndStyle(dom.Document document) {
    for (final el in document.querySelectorAll('link')) {
      el.remove();
    }
    for (final el in document.querySelectorAll('style')) {
      el.remove();
    }
  }

  String _finalizeHtml(dom.Document document, String fallback) {
    final body = document.body;
    final inner = body?.innerHtml ?? fallback;
    final bodyStyle = body?.attributes['style'];
    if (bodyStyle != null && bodyStyle.isNotEmpty) {
      // 保留 body 级样式（如 font-family / text-align），避免内联时丢失
      return '<div style="$bodyStyle">$inner</div>';
    }
    return inner;
  }

  /// 检测是否为竖排排版（writing-mode: vertical-rl/lr）
  ///
  /// EPUB3 竖排书常把 `writing-mode` 或 `-epub-writing-mode` 写在根/body 上。
  /// 同时检查已收集的 CSS 文本与内联后的 style 属性，命中即判定为竖排。
  bool _detectVertical(dom.Document document, String cssText) {
    final re = RegExp(
      r'(?:-epub-|-webkit-)?writing-mode\s*:\s*vertical-(?:rl|lr)',
      caseSensitive: false,
    );
    if (re.hasMatch(cssText)) return true;
    for (final el in document.querySelectorAll('*')) {
      final style = el.attributes['style'];
      if (style != null && re.hasMatch(style)) return true;
    }
    return false;
  }

  /// 提取竖排渲染用的纯文本（按块级元素换行，去掉标签）
  ///
  /// tategaki 的 VerticalText 只接受纯文本，无法渲染图片/富文本；
  /// 这里将段落（p/div/标题/li 等）以换行分隔，尽量保留阅读节奏。
  String _extractPlainText(dom.Document document) {
    final buffer = StringBuffer();
    const blocks = {
      'p', 'div', 'section', 'article', 'blockquote',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'tr',
    };

    void visit(dom.Node node) {
      if (node is dom.Text) {
        buffer.write(node.text);
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        if (tag == 'br') {
          buffer.write('\n');
          return;
        }
        if (blocks.contains(tag)) buffer.write('\n');
        for (final child in node.nodes) {
          visit(child);
        }
        if (blocks.contains(tag)) buffer.write('\n');
      }
    }

    final root = document.body ?? document;
    for (final node in root.nodes) {
      visit(node);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[ \t\r]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }

  // ---- 工具 ----

  String _urlDecode(String src) {
    try {
      return Uri.decodeComponent(src);
    } catch (_) {
      return src;
    }
  }

  String _stripQuotes(String s) {
    s = s.trim();
    if (s.length >= 2 &&
        ((s.startsWith('"') && s.endsWith('"')) ||
            (s.startsWith("'") && s.endsWith("'")))) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  List<String> _extractUrls(String value) {
    final urls = <String>[];
    final re = RegExp(r'url\(\s*([\x22\x27]?)([^\x22\x27)]+)\1\s*\)', caseSensitive: false);
    for (final m in re.allMatches(value)) {
      urls.add(m.group(2)!);
    }
    return urls;
  }

  String? _extractDecl(String block, String name) {
    final m = RegExp('$name\\s*:\\s*([^;]+)', caseSensitive: false)
        .firstMatch(block);
    return m?.group(1)?.trim();
  }

  double? _extractPx(String text, String key) {
    final m = RegExp('$key\\s*:\\s*(\\d+(?:\\.\\d+)?)px').firstMatch(text);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  Map<String, String> _parseInlineDecls(String? style) {
    final map = <String, String>{};
    if (style == null || style.isEmpty) return map;
    for (final part in style.split(';')) {
      final idx = part.indexOf(':');
      if (idx <= 0) continue;
      final key = part.substring(0, idx).trim();
      final value = part.substring(idx + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) map[key] = value;
    }
    return map;
  }
}
