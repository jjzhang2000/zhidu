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
  ///
  /// [frontMatter] 为 true 表示处理书籍开头页（封面/版权/目录等前置页）：
  /// 只调整目录条目——可点击文字字号偏大（书籍常用 >1em，相对正文 21px 会到
  /// 23~26px），且分级缩进常用行首空格/`&nbsp;` 表示，会被 HTML 折叠掉。
  /// 版权页等非链接文字保持原样。
  RenderedContent render(String chapterHtml, {bool frontMatter = false}) {
    try {
      final document = html_parser.parse(chapterHtml);

      final fonts = <EmbeddedFont>[];
      final cssText = _sanitizeCss(_collectCss(document));
      _extractFonts(cssText, fonts);
      _inlineCss(document, cssText, convertRem: frontMatter);

      // 目录条目归一化必须在段落缩进处理之前：需要先读取行首空白作为分级缩进
      if (frontMatter) {
        _normalizeTocEntries(document);
      }

      _normalizeLinkColors(document);

      final isVertical = _detectVertical(document, cssText);
      if (!isVertical) {
        _applyReaderTypography(document);
      }

      _inlineImages(document);
      _inlineSvgImages(document);
      _removeLinkAndStyle(document);

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

  /// 清理会让 csslib 解析器崩溃的非法 CSS 片段。
  ///
  /// 部分生成工具（如 PrismJS）会在 CSS 中留下未替换的占位符
  /// （如 `color: #$$codeBlockColor$$`）。csslib 在解析 `#` 后跟 `$` 这类
  /// 非十六进制、非标识符字符时，会在 `_parseHex` 中对空 `processTerm()`
  /// 强转 `LiteralTerm` 而抛异常，导致整个样式表解析失败、CSS 全部失效。
  /// 这里把此类占位符替换为安全颜色，保证其余样式仍能内联。
  String _sanitizeCss(String cssText) {
    return cssText.replaceAll(
      RegExp(r'#\$\$[^;\s{}]*'),
      '#000000',
    );
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

  void _inlineCss(dom.Document document, String cssText,
      {bool convertRem = false}) {
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
        merged[e.key] = _convertUnits(e.value.value, convertRem);
      }
      for (final e in _parseInlineDecls(el.attributes['style']).entries) {
        merged[e.key] = _convertUnits(e.value, convertRem);
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
      final value = _declValue(d);
      if (value == null || value.isEmpty) continue;
      if (_isInvalidColorValue(d.property, value)) continue;
      decls.add(_DeclTemplate(d.property, value, d.important));
    }
    if (decls.isEmpty) return null;

    return _CssRule(selectors, decls);
  }

  /// 提取声明的完整值文本。
  ///
  /// csslib 的 `expression.span.text` 只覆盖首个词法单元（如 `#000000` 只剩 `#`、
  /// `1px solid #eee` 只剩 `1`），导致多 token 值被截断。改用声明整体 `span`（含
  /// `属性: 值` 与可选的 `!important`），去掉属性名与 `!important` 后得到完整值。
  String? _declValue(css.Declaration d) {
    final text = d.span.text.trim();
    final colon = text.indexOf(':');
    if (colon < 0) return null;
    return text
        .substring(colon + 1)
        .replaceAll(RegExp(r'!\s*important\s*$', caseSensitive: false), '')
        .trim();
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
    name = _normalizeResourcePath(name);
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
    // 折叠后仍可能因归档内目录层级不同而匹配失败（如资源位于 META-INF 之外的
    // 其它目录），退化为按最后一段文件名匹配。
    final basename = name.split('/').last;
    if (basename.isEmpty || basename == name) return null;
    final baseLower = basename.toLowerCase();
    for (final file in archive.files) {
      if (file.name.endsWith('/$basename')) return file;
    }
    for (final file in archive.files) {
      if (file.name.toLowerCase().endsWith('/$baseLower')) return file;
    }
    return null;
  }

  /// 规范化资源引用路径。
  ///
  /// EPUB 正文里的 `<img src>` / `url()` 是相对章节文件而言的，常见形如
  /// `../images/foo.jpg`、`/images/foo.jpg` 或 `./images/foo.jpg`；而归档内
  /// 文件路径是全局的。这里统一分隔符、去掉锚点/查询串、折叠 `.` 与 `..` 段，
  /// 得到纯目录相对路径，便于与归档内路径做前缀匹配。
  String _normalizeResourcePath(String name) {
    name = name.replaceAll('\\', '/');
    final hash = name.indexOf('#');
    if (hash >= 0) name = name.substring(0, hash);
    final query = name.indexOf('?');
    if (query >= 0) name = name.substring(0, query);

    final segments = <String>[];
    for (final seg in name.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (segments.isNotEmpty) segments.removeLast();
        continue;
      }
      segments.add(seg);
    }
    return segments.join('/');
  }

  // ---- 收尾 ----

  /// 应用阅读器默认排版，弥补 flutter_widget_from_html 对 `text-indent` 的不支持。
  ///
  /// 主流 EPUB 阅读器普遍为正文段落做首行缩进（中文习惯为 2em）。fwfh 不识别
  /// `text-indent`，这里改为在段落的每个"行首"（段落开头 + 每个 <br> 之后）插入
  /// 一个 2em 宽的内联占位，从而只缩进该行、换行后的后续行不缩进。
  ///
  /// 占位用 `display: inline-block` 包裹两个全角空格（U+3000，每个天然 1em），
  /// 宽度取自空格字形本身而非 `width` 属性：fwfh 对 `display: inline-block`
  /// 上的 `width` 依赖 `_sizingInline` 的特殊分支，在 `text-align: justify`
  /// 等场景下可能不生效，此时占位会坍缩到内部空格的自然宽度（U+00A0 仅约
  /// 0.3em），导致缩进从 2em 变成半个字。inline-block 使全角空格脱离正文行内
  /// 文本，避免两端对齐剥离行首空白；两个全角空格保证宽度稳定为 2em。
  ///
  /// 同时剥离行首的空白（ASCII 空格 + U+00A0 不间断空格 + U+3000 全角空格）：
  /// 部分 EPUB（如 calibre 转换）用 `&nbsp;` 做段首/行首缩进，而 nbsp 在正文
  /// 字体里宽度约 0.3em，会造成"缩进半个字"的观感，这里统一替换为 2em 占位。
  void _applyReaderTypography(dom.Document document) {
    final leadingWs = RegExp(r'^[\s\u00A0\u3000]+');
    for (final p in document.querySelectorAll('p')) {
      // 目录条目（内容全部为链接）由 _normalizeTocEntries 处理缩进，
      // 不能再套用正文的 2em 首行缩进，否则各级条目缩进看起来一样
      if (_isLinkOnlyBlock(p)) continue;
      _indentParagraph(p, leadingWs);
    }
  }

  // ---- 开头页目录归一化 ----

  /// 允许作为目录条目容器的块级标签
  static const Set<String> _tocBlockTags = {
    'p', 'div', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote',
  };

  /// 允许出现在目录条目内部的纯内联标签
  static const Set<String> _inlineTags = {
    'a', 'strong', 'b', 'em', 'i', 'span', 'u', 'font', 'small', 'sup',
    'sub', 'br', 'wbr', 'nobr',
  };

  /// 开头页目录条目归一化
  ///
  /// 目录条目（可点击文字）在原始书里常被放大（如 `font-size: 1.22em`，相对正文
  /// 21px 会到 25px），且分级缩进用行首空格/`&nbsp;` 表示、会被 HTML 折叠掉。
  /// 这里只处理「内容全部是链接的块级元素」：字号缩到 16px、行高统一 1.8，
  /// 并把行首空白换算为左侧缩进（2 个空白约等于一级缩进）。版权页等非链接文字
  /// 不做任何调整。
  void _normalizeTocEntries(dom.Document document) {
    final body = document.body;
    if (body == null) return;

    for (final el in body.querySelectorAll('p, div, li, h1, h2, h3, h4, h5, h6')) {
      if (!_isLinkOnlyBlock(el)) continue;

      final indent = _consumeLeadingIndent(el);
      final styles = <String>[
        // 相对大小：随阅读字号设置缩放（0.76em ≈ 正文 21px 时的 16px）
        'font-size: 0.76em',
        'line-height: 1.8',
        if (indent > 0)
          'margin-left: ${(indent / 2).clamp(0.5, 6.0).toStringAsFixed(1)}em',
      ];
      final existing = el.attributes['style'];
      el.attributes['style'] = existing == null || existing.isEmpty
          ? styles.join('; ')
          : '$existing; ${styles.join('; ')}';
    }
  }

  /// 块级元素的内容是否全部由链接（直接或包在内联标签中）组成
  bool _isLinkOnlyBlock(dom.Element el) {
    if (!_tocBlockTags.contains(el.localName)) return false;

    var hasLink = false;
    for (final node in el.nodes) {
      if (node is dom.Text) {
        if (node.data.trim().isNotEmpty) return false;
        continue;
      }
      if (node is dom.Element) {
        if (!_inlineTags.contains(node.localName)) return false;
        if (node.localName == 'a' || node.querySelector('a') != null) {
          hasLink = true;
        } else if (node.text.trim().isNotEmpty) {
          return false;
        }
        continue;
      }
      // 注释等其他节点忽略
    }
    return hasLink;
  }

  /// 读取并移除元素开头的缩进空白，返回缩进权重
  ///
  /// 每个半角空格 / `&nbsp;` 计 1，制表符与全角空格计 2；每 2 份对应一级缩进
  /// （1em，随正文字号缩放）。
  int _consumeLeadingIndent(dom.Element el) {
    var weight = 0;
    for (final node in List<dom.Node>.of(el.nodes)) {
      if (node is! dom.Text) break;

      final data = node.data;
      var index = 0;
      while (index < data.length) {
        final unit = data.codeUnitAt(index);
        if (unit == 0x20 || unit == 0xA0) {
          weight += 1;
        } else if (unit == 0x09 || unit == 0x3000) {
          weight += 2;
        } else {
          break;
        }
        index++;
      }
      if (index > 0) node.data = data.substring(index);
      if (node.data.trim().isNotEmpty) break;
    }
    return weight;
  }

  /// 为单个段落补充首行缩进，并修正 nbsp 造成的半字缩进。
  void _indentParagraph(dom.Element p, RegExp leadingWs) {
    // 段落开头：剥离首文本节点的行首空白后插入 2em 缩进。
    final first = _firstNonEmptyText(p);
    if (first != null) {
      first.data = first.data.replaceFirst(leadingWs, '');
    }

    // 移除段落开头的纯空白文本节点（如 <p>\n  <span>正文</span> 中的换行）。
    while (p.nodes.isNotEmpty &&
        p.nodes.first is dom.Text &&
        (p.nodes.first as dom.Text).data.trim().isEmpty) {
      p.nodes.first.remove();
    }
    if (p.nodes.isNotEmpty) {
      _insertIndent(p, p.nodes.first);
    }

    // 每个 <br> 之后：若下一文本节点以空白起头（calibre 手写的行首缩进），
    // 剥离该空白并插入 2em 缩进，使引言等多行段落各行缩进一致。
    var prevIsBr = false;
    for (final node in List<dom.Node>.of(p.nodes)) {
      if (node is dom.Element && node.localName == 'br') {
        prevIsBr = true;
        continue;
      }
      if (node is dom.Text && prevIsBr) {
        final stripped = node.data.replaceFirst(leadingWs, '');
        if (stripped != node.data) {
          node.data = stripped;
          if (node.data.isNotEmpty) {
            _insertIndent(p, node);
          }
        }
      }
      prevIsBr = false;
    }
  }

  void _insertIndent(dom.Element p, dom.Node before) {
    final spacer = dom.Element.tag('span');
    spacer.attributes['style'] = 'display: inline-block';
    spacer.append(dom.Text('\u3000\u3000'));
    p.insertBefore(spacer, before);
  }

  /// 深度优先查找第一个非空文本节点（跳过仅含空白的文本节点与空元素）。
  dom.Text? _firstNonEmptyText(dom.Node node) {
    if (node is dom.Text) {
      return node.data.trim().isNotEmpty ? node : null;
    }
    if (node is dom.Element) {
      for (final child in node.nodes) {
        final found = _firstNonEmptyText(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// 去除链接文字写死的颜色声明，交由渲染器按主题取链接色。
  ///
  /// 许多 EPUB 用 `a { color: #0000CC }` 之类的深色指定链接颜色，在深色模式下
  /// 与背景对比度极低而无法辨认。这里移除 `<a>` 及其后代元素内联样式中的
  /// `color`，让 flutter_widget_from_html 使用主题链接色（浅色/深色均清晰）。
  void _normalizeLinkColors(dom.Document document) {
    for (final a in document.querySelectorAll('a')) {
      _stripColorDecl(a);
      for (final child in a.querySelectorAll('*')) {
        _stripColorDecl(child);
      }
    }
  }

  /// 从单个元素的 style 中移除 color 声明
  void _stripColorDecl(dom.Element el) {
    final style = el.attributes['style'];
    if (style == null || style.isEmpty) return;
    final decls = _parseInlineDecls(style);
    if (decls.remove('color') == null) return;
    if (decls.isEmpty) {
      el.attributes.remove('style');
    } else {
      el.attributes['style'] =
          decls.entries.map((e) => '${e.key}: ${e.value}').join('; ');
    }
  }

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

  /// 根字号（rem 换算基准，等同浏览器默认 16px）
  static const double _rootFontSize = 16;

  /// rem 单位换算为 px（仅开头页启用）。
  ///
  /// flutter_widget_from_html 只识别 px/pt/em/%，遇到 rem 会丢弃整条声明。
  /// 而不少 EPUB（Markdown/Calibre 生成）用 `padding-left: 2rem` 做目录缩进、
  /// `font-size: 1rem` 指定字号；rem 被丢弃后目录既不缩进、字号又回落到正文
  /// 21px，正是「目录字体太大、缺少分级缩进」的来源。这里按根字号换算。
  String _convertUnits(String value, bool convertRem) {
    if (!convertRem || !value.contains('rem')) return value;
    return value.replaceAllMapped(
      RegExp(r'(-?\d*\.?\d+)rem\b'),
      (m) {
        final px = double.parse(m.group(1)!) * _rootFontSize;
        final text = px == px.roundToDouble()
            ? px.round().toString()
            : px.toStringAsFixed(1);
        return '${text}px';
      },
    );
  }

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
      if (key.isEmpty || value.isEmpty) continue;
      if (_isInvalidColorValue(key, value)) continue;
      map[key] = value;
    }
    return map;
  }

  // ---- 非法 CSS 值过滤 ----

  /// 颜色相关属性：这些属性的值中可能含十六进制颜色，需要校验合法性。
  static const _colorProperties = {
    'color',
    'background',
    'background-color',
    'border',
    'border-color',
    'border-top',
    'border-right',
    'border-bottom',
    'border-left',
    'border-top-color',
    'border-right-color',
    'border-bottom-color',
    'border-left-color',
    'outline',
    'outline-color',
    'text-decoration',
    'text-decoration-color',
    'text-emphasis',
    'text-emphasis-color',
    'text-shadow',
    'box-shadow',
    'caret-color',
    'column-rule-color',
  };

  /// 检测颜色值中是否含非法十六进制颜色 token。
  ///
  /// fwfh 对十六进制颜色直接 `int.parse`，遇到非法 hex（如 #xyz、#$$codeBlockColor$$）
  /// 会抛异常导致整块渲染失败显示 ❌，故在此识别并过滤。
  bool _hasInvalidHexColor(String value) {
    // 优先匹配合法 hex（3/4/6/8 位），否则匹配 # 后跟的非法 token
    final re = RegExp(r'#[0-9a-fA-F]{3,8}|#[^\s;,()]+');
    for (final m in re.allMatches(value)) {
      final hex = m.group(0)!.substring(1);
      final isHex = RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
      final validLen = hex.length == 3 ||
          hex.length == 4 ||
          hex.length == 6 ||
          hex.length == 8;
      if (!isHex || !validLen) return true;
    }
    return false;
  }

  bool _isInvalidColorValue(String property, String value) {
    if (!_colorProperties.contains(property.toLowerCase())) return false;
    return _hasInvalidHexColor(value);
  }
}
