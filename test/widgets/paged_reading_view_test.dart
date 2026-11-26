import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:zhidu/widgets/paged_reading_view.dart';

void main() {
  testWidgets('长文本被切分为多页并显示页码指示', (tester) async {
    final longHtml = List.generate(
      120,
      (i) => '<p>段落$i：这是用于分页测试的一段文本内容。</p>',
    ).join('');
    final controller = PageController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: PagedReadingView(
              html: longHtml,
              textStyle: const TextStyle(fontSize: 16, height: 1.8),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 应渲染出 PageView，且页码指示不为「1 / 1」（即确实发生了分页）
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1 / 1'), findsNothing);

    controller.dispose();
  });

  testWidgets('短文本只占一页', (tester) async {
    final controller = PageController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: PagedReadingView(
              html: '<p>短文本</p>',
              textStyle: const TextStyle(fontSize: 16, height: 1.8),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('div 包裹的多个段落被展开为独立块并分页', (tester) async {
    final longHtml = '<div>${List.generate(
      120,
      (i) => '<p>段落$i：这是用于分页测试的一段文本内容。</p>',
    ).join()}</div>';
    final controller = PageController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: PagedReadingView(
              html: longHtml,
              textStyle: const TextStyle(fontSize: 16, height: 1.8),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 若整个 div 被当作单块，则只有一个超高块、页码为 1/1；展开为段落块后应分多页
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1 / 1'), findsNothing);

    controller.dispose();
  });

  testWidgets('切换文本时复位页码且不抛 setState-during-build 异常', (tester) async {
    final controller = PageController();
    var page = 0;
    var total = 1;

    Widget buildView(String html) => MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 320,
                height: 480,
                child: PagedReadingView(
                  html: html,
                  textStyle: const TextStyle(fontSize: 16, height: 1.8),
                  controller: controller,
                  onPageChanged: (p, t) => setState(() {
                    page = p;
                    total = t;
                  }),
                ),
              ),
            ),
          ),
        );

    final longA = List.generate(
      120,
      (i) => '<p>段落A$i：测试内容。</p>',
    ).join('');
    final longB = List.generate(
      120,
      (i) => '<p>段落B$i：另一段测试内容。</p>',
    ).join('');

    await tester.pumpWidget(buildView(longA));
    await tester.pumpAndSettle();

    // 翻到最后一页，使控制器位置偏离 0，再切换文本触发 didUpdateWidget
    controller.jumpToPage(total - 1);
    await tester.pumpAndSettle();

    await tester.pumpWidget(buildView(longB));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(page, 0);
    controller.dispose();
  });

  testWidgets('带 initialAnchor 时直接定位到该标题所在页', (tester) async {
    final controller = PageController();
    var page = 0;
    final html = [
      for (var i = 0; i < 80; i++)
        '<p>前置段落$i：这是用于分页测试的一段文本内容。</p>',
      '<p>目标小节标题</p>',
      for (var i = 0; i < 80; i++)
        '<p>后续段落$i：这是用于分页测试的一段文本内容。</p>',
    ].join();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: PagedReadingView(
              html: html,
              textStyle: const TextStyle(fontSize: 16, height: 1.8),
              controller: controller,
              // 标题带空白也应能匹配（比对时忽略空白）
              initialAnchor: '目标 小节标题',
              onPageChanged: (p, t) => page = p,
            ),
          ),
        ),
      ),
    );
    // 分页依赖 120ms 定时重测，pumpAndSettle 不会推进定时器，需显式推进时间
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump();

    // 不应停留在首页，而是定位到标题所在的后续页
    expect(page, greaterThan(0));

    controller.dispose();
  });

  testWidgets('HTML 格式被保留（加粗内容经 HtmlWidget 渲染）', (tester) async {
    final controller = PageController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: PagedReadingView(
              html: '<p>普通<b>加粗</b>文字</p>',
              textStyle: const TextStyle(fontSize: 16),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 分页渲染走 HtmlWidget（而非纯 Text），说明 HTML 结构未被丢弃
    expect(find.byType(HtmlWidget), findsWidgets);
    expect(find.textContaining('加粗', findRichText: true), findsWidgets);

    controller.dispose();
  });

  testWidgets('SVG 图片经 flutter_svg 渲染，不再显示红叉占位', (tester) async {
    final controller = PageController();
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">'
        '<rect width="24" height="24" fill="#000"/></svg>';
    final dataUri = 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: PagedReadingView(
              html: '<p><img src="$dataUri" alt="矢量图"/></p>',
              textStyle: const TextStyle(fontSize: 16),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // fwfh 图片解码失败的默认占位是 ❌，SVG 交由 flutter_svg 渲染后不应出现
    expect(find.text('❌'), findsNothing);

    controller.dispose();
  });
}
