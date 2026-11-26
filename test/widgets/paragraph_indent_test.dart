import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:zhidu/services/parsers/epub_css_engine.dart';

void main() {
  testWidgets('text-align: justify 下首行缩进不被剥离', (tester) async {
    const body = '小时候最崇拜的就是三国英雄，历数其中名将谋臣如数家珍。'
        '当时我深深地相信，智的最高境界是诸葛亮。';
    // 模拟真实正文章节：text-align: justify + 首行缩进
    final html =
        EpubCssEngine(Archive()).render('<p style="text-align: justify">$body</p>').html;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: HtmlWidget(html, textStyle: const TextStyle(fontSize: 21)),
          ),
        ),
      ),
    );
    await tester.pump();

    final rp = tester.renderObjectList<RenderParagraph>(find.byType(RichText)).first;
    final full = rp.text.toPlainText();
    final idx = full.indexOf('小');
    final boxes = rp.getBoxesForSelection(
      TextSelection(baseOffset: idx, extentOffset: idx + 1),
    );
    expect(boxes, isNotEmpty);

    // 首字符应缩进约 2em（fontSize 21 时约 42px），而非贴在左边界（≈0）
    final left = boxes.first.left;
    expect(left, greaterThan(30));
    expect(left, lessThan(55));
  });
}
