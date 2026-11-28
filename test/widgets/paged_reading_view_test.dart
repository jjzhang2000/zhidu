import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:zhidu/widgets/paged_reader_controller.dart';
import 'package:zhidu/widgets/paged_reading_view.dart';

const _textStyle = TextStyle(fontSize: 16, height: 1.8);

/// 判断包含指定文字的渲染块是否落在 320x480 的可视区域内
/// （离屏测量列位于 x=-100000，滑出屏幕的旧页也会整体平移，均判定为不可见）
bool _hasTextOnScreen(String text) {
  for (final element
      in find.textContaining(text, findRichText: true).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final origin = box.localToGlobal(Offset.zero);
    if (origin.dx > -1 &&
        origin.dx < 320 &&
        origin.dy > -1 &&
        origin.dy < 480) {
      return true;
    }
  }
  return false;
}

PagedReaderController _newController({PagedBoundaryCallback? onBoundary}) {
  return PagedReaderController(
    vsync: const TestVSync(),
    textStyle: _textStyle,
    onBoundary: onBoundary,
  );
}

Widget _wrap(PagedReaderController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 320,
        height: 480,
        child: PagedReadingView(controller: controller),
      ),
    ),
  );
}

/// 分页依赖 120ms 定时重测，pumpAndSettle 不会推进定时器，需显式推进时间
Future<void> _settlePaging(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  await tester.pumpAndSettle();
}

String _chapterHtml(String tag, {int paragraphs = 60}) {
  return List.generate(
    paragraphs,
    (i) => '<p>$tag段落$i：这是用于分页测试的一段文本内容。</p>',
  ).join();
}

void main() {
  testWidgets('长文本被切分为多页并显示页码指示', (tester) async {
    final longHtml = List.generate(
      120,
      (i) => '<p>段落$i：这是用于分页测试的一段文本内容。</p>',
    ).join();
    final controller = _newController();
    controller.open(longHtml);

    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    // 应渲染出 PageView，且页码指示不为「1 / 1」（即确实发生了分页）
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1 / 1'), findsNothing);

    controller.dispose();
  });

  testWidgets('切章时保留旧页快照再滑出（跨章滑动过渡）', (tester) async {
    final controller = _newController();
    controller.open(_chapterHtml('旧章'));

    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('旧章段落0：', findRichText: true),
      findsWidgets,
    );

    // 切到新章：新章分页尚未完成时，应继续显示旧页快照而非空白
    controller.open(_chapterHtml('新章'));
    await tester.pump();
    expect(
      find.textContaining('旧章段落0：', findRichText: true),
      findsWidgets,
    );

    // 分页稳定后播放滑动过渡，结束后旧页移出、新页显示
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('旧章段落0：', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('新章段落0：', findRichText: true),
      findsWidgets,
    );

    controller.dispose();
  });

  testWidgets('连续切章时旧页快照仍显示在屏幕内（过渡进度已复位）', (tester) async {
    final chapters = [
      _chapterHtml('甲章'),
      _chapterHtml('乙章'),
      _chapterHtml('丙章'),
    ];
    var index = 0;
    late final PagedReaderController controller;
    controller = _newController(
      onBoundary: (delta) {
        index += delta;
        controller.open(chapters[index]);
      },
    );
    controller.open(chapters[0]);

    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    // 第一次切章并让过渡完整播完（此 controller 过渡值会停在终点）
    controller.pageController.jumpToPage(9);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(300, 240));
    await _settlePaging(tester);
    expect(index, 1);
    expect(controller.currentPage, 0);

    // 第二次切章：翻到末页后点击右侧跨章，新章测量期间必须仍在屏幕内
    // 显示上一章（乙章）的那一页
    controller.pageController.jumpToPage(9);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(300, 240));
    await tester.pump();
    expect(index, 2);
    expect(_hasTextOnScreen('乙章段落'), isTrue,
        reason: '过渡进度未复位时旧页快照会被平移到屏幕外，表现为白屏后突然弹回');

    await _settlePaging(tester);
    expect(controller.currentPage, 0);
    controller.dispose();
  });

  testWidgets('切章定位完成前点击右侧不触发跨章（防跳过整章）', (tester) async {
    final chapters = [
      _chapterHtml('甲章'),
      _chapterHtml('乙章'),
      _chapterHtml('丙章'),
    ];
    var index = 0;
    var boundaryCalls = 0;
    late final PagedReaderController controller;
    controller = _newController(
      onBoundary: (delta) {
        boundaryCalls++;
        index += delta;
        controller.open(chapters[index]);
      },
    );
    controller.open(chapters[0]);

    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    // 翻到末页后点击右侧 1/3 跨章
    controller.pageController.jumpToPage(controller.totalPages - 1);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(300, 240));
    await tester.pump();
    await tester.pump(); // 首轮测量完成，新章 PageView 已存在但仍处于定位中（隐藏）
    expect(index, 1);
    expect(boundaryCalls, 1);

    // 定位完成前再点右侧：应被忽略，不能基于上一章页码再跨一章
    await tester.tapAt(const Offset(300, 240));
    await tester.pump();
    expect(index, 1);
    expect(boundaryCalls, 1);

    // 分页稳定后应定位到新章首页
    await _settlePaging(tester);
    expect(controller.currentPage, 0);
    controller.dispose();
  });

  testWidgets('章首页向前翻触发边界并定位到上一章末页', (tester) async {
    final chapters = [
      _chapterHtml('上一章', paragraphs: 80),
      _chapterHtml('当前章'),
    ];
    var index = 1;
    late final PagedReaderController controller;
    controller = _newController(
      onBoundary: (delta) {
        index += delta;
        controller.open(
          chapters[index],
          target: delta < 0 ? PagedOpenTarget.last : PagedOpenTarget.first,
        );
      },
    );
    controller.open(chapters[1]);

    await tester.pumpWidget(_wrap(controller));
    await _settlePaging(tester);
    expect(controller.currentPage, 0);

    // 首页继续向前翻：应切到上一章并落在其末页
    controller.turnPage(-1);
    await tester.pump();
    expect(index, 0);
    await _settlePaging(tester);
    expect(controller.currentPage, controller.totalPages - 1);
    expect(controller.currentPage, greaterThan(0));
    // 过渡结束后 PageView 的实际页码必须与控制器一致：
    // 旧实现会在过渡层出现/消失时重建 PageView，使其回到第 0 页，
    // 于是「翻到上一章末页」实际显示的是上一章首页
    expect(controller.pageController.page!.round(), controller.currentPage);

    controller.dispose();
  });

  testWidgets('跨章过渡结束后仍停在目标页（过渡层增减不重建 PageView）',
      (tester) async {
    final chapters = [
      _chapterHtml('上一章', paragraphs: 80),
      _chapterHtml('当前章'),
    ];
    late final PagedReaderController controller;
    controller = _newController(
      onBoundary: (delta) =>
          controller.open(chapters[0], target: PagedOpenTarget.last),
    );
    controller.open(chapters[1]);

    await tester.pumpWidget(_wrap(controller));
    await _settlePaging(tester);
    expect(controller.pageController.page!.round(), 0);

    controller.turnPage(-1);
    await _settlePaging(tester);

    final target = controller.totalPages - 1;
    expect(controller.currentPage, target);
    expect(controller.pageController.page!.round(), target,
        reason: '过渡层移除时 PageView 若被重建会回到第 0 页，导致定位错误');

    controller.dispose();
  });

  testWidgets('跨章到新章首页后继续向后翻页可正常前进', (tester) async {
    final chapters = [
      _chapterHtml('甲章', paragraphs: 80),
      _chapterHtml('乙章', paragraphs: 80),
    ];
    var index = 0;
    var boundaryCalls = 0;
    late final PagedReaderController controller;
    controller = _newController(
      onBoundary: (delta) {
        boundaryCalls++;
        index += delta;
        controller.open(
          chapters[index],
          target: delta < 0 ? PagedOpenTarget.last : PagedOpenTarget.first,
        );
      },
    );
    controller.open(chapters[0]);

    await tester.pumpWidget(_wrap(controller));
    await _settlePaging(tester);

    // 从甲章末页向后翻：跨到乙章首页
    controller.pageController.jumpToPage(controller.totalPages - 1);
    await tester.pumpAndSettle();
    controller.turnPage(1);
    await _settlePaging(tester);
    expect(index, 1);
    expect(controller.currentPage, 0);
    expect(controller.pageController.page!.round(), 0);

    // 新章首页继续向后翻：应在本章内翻到第 2 页，而不是再次跨章
    final callsBefore = boundaryCalls;
    controller.turnPage(1);
    await tester.pumpAndSettle();
    expect(boundaryCalls, callsBefore, reason: '新章首页应能正常翻到下一页');
    expect(controller.currentPage, 1);
    expect(controller.pageController.page!.round(), 1);

    controller.dispose();
  });

  testWidgets('越界拖动时页面不位移（Clamping 物理，避免切章时跳回）', (tester) async {
    // 不设 onBoundary：越界不会切章，便于观察越界期间页面是否被拖动
    final controller = _newController();
    controller.open(_chapterHtml('当前章', paragraphs: 120));

    await tester.pumpWidget(_wrap(controller));
    await _settlePaging(tester);
    expect(controller.currentPage, 0);

    /// 页面上可见的正文原点（离屏测量列不算）
    Offset visibleOrigin() {
      for (final element in find
          .textContaining('当前章段落0：', findRichText: true)
          .evaluate()) {
        final box = element.renderObject;
        if (box is! RenderBox || !box.hasSize) continue;
        final origin = box.localToGlobal(Offset.zero);
        if (origin.dx > -1 && origin.dx < 320) return origin;
      }
      return Offset.zero;
    }

    final before = visibleOrigin();
    expect(before, isNot(Offset.zero));

    // 首页继续向右拖动（越过开头）。若允许位移（BouncingScrollPhysics），
    // 页面会被拖开，随后切章瞬间旧页快照回到原位，视觉上就是「首页跳动一次」。
    await tester.drag(find.byType(PageView), const Offset(60, 0));
    await tester.pump();
    expect((visibleOrigin() - before).distance, lessThan(0.5),
        reason: '越界拖动不应使页面位移');

    controller.dispose();
  });

  testWidgets('章节首页向左拖动越过边界翻到上一章末页', (tester) async {
    final chapters = [
      _chapterHtml('上一章', paragraphs: 80),
      _chapterHtml('当前章'),
    ];
    var index = 1;
    final deltas = <int>[];
    late final PagedReaderController controller;
    controller = _newController(
      onBoundary: (delta) {
        deltas.add(delta);
        index += delta;
        controller.open(
          chapters[index],
          target: delta < 0 ? PagedOpenTarget.last : PagedOpenTarget.first,
        );
      },
    );
    controller.open(chapters[1]);

    await tester.pumpWidget(_wrap(controller));
    await _settlePaging(tester);
    expect(controller.currentPage, 0);

    // 首页向右拖动（越过开头）：ClampingScrollPhysics 下页面不位移，
    // 越界量累计超过阈值即判定「向前翻章」
    await tester.drag(find.byType(PageView), const Offset(220, 0));
    await tester.pump();
    expect(deltas, [-1]);

    await _settlePaging(tester);
    expect(index, 0);
    expect(controller.currentPage, controller.totalPages - 1);
    expect(controller.pageController.page!.round(), controller.currentPage);

    controller.dispose();
  });

  testWidgets('旧页过渡层不铺不透明底色（避免白页闪过）', (tester) async {
    final controller = _newController();
    controller.open(_chapterHtml('旧章'));

    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    controller.open(_chapterHtml('新章'));
    await tester.pump();
    // 过渡期间旧页层不应带 ColoredBox 之类的纯色底：它与阅读区背景不同，
    // 滑动时会出现一片白/异色区域
    expect(
      find.descendant(
        of: find.byType(PagedReadingView),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    controller.dispose();
  });

  testWidgets('点击左右区域 / 方向键 / 滚轮统一走 turnPage 翻页', (tester) async {
    final controller = _newController();
    controller.open(_chapterHtml('统一入口', paragraphs: 120));

    await tester.pumpWidget(_wrap(controller));
    await _settlePaging(tester);
    expect(controller.currentPage, 0);

    // 点击右侧 1/3
    await tester.tapAt(const Offset(300, 240));
    await tester.pumpAndSettle();
    expect(controller.currentPage, 1);

    // 键盘右方向键
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.currentPage, 2);

    // 键盘左方向键
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(controller.currentPage, 1);

    // 鼠标滚轮向下
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(160, 240),
        scrollDelta: Offset(0, 100),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.currentPage, 2);

    controller.dispose();
  });

  testWidgets('点击链接触发 onLinkTap 且不翻页（链接优先于点击翻页）', (tester) async {
    final tapped = <String>[];
    final controller = _newController();
    // 首块是右对齐链接（落在右侧 1/3），后接足量段落形成第二页，
    // 以此区分「点链接跳转」与「点右侧翻页」
    final html = '<p style="text-align: right"><a href="next.html">跳转链接</a></p>' +
        List.generate(
          120,
          (i) => '<p>段落$i：这是用于分页测试的一段文本内容。</p>',
        ).join();
    controller.open(html);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: PagedReadingView(
              controller: controller,
              onLinkTap: tapped.add,
            ),
          ),
        ),
      ),
    );
    await _settlePaging(tester);
    expect(controller.currentPage, 0);

    // 找到屏幕内可见的链接 RichText，点击其右端（确保落在右侧 1/3 的文字上）
    Offset? linkPoint;
    for (final element
        in find.textContaining('跳转链接', findRichText: true).evaluate()) {
      final box = element.renderObject;
      if (box is! RenderBox || !box.hasSize) continue;
      final origin = box.localToGlobal(Offset.zero);
      if (origin.dx > -1 && origin.dx < 320) {
        linkPoint = origin +
            Offset(box.size.width - 12, box.size.height / 2);
        break;
      }
    }
    expect(linkPoint, isNotNull);
    expect(linkPoint!.dx, greaterThan(320 * 2 / 3),
        reason: '点击点应落在右侧 1/3，否则无法证明「链接优先于翻页」');

    await tester.tapAt(linkPoint);
    await tester.pumpAndSettle();

    expect(tapped, ['next.html']);
    expect(controller.currentPage, 0, reason: '点中链接应跳转而非翻页');

    controller.dispose();
  });

  testWidgets('短文本只占一页', (tester) async {
    final controller = _newController();
    controller.open('<p>短文本</p>');

    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('div 包裹的多个段落被展开为独立块并分页', (tester) async {
    final longHtml = '<div>${List.generate(
      120,
      (i) => '<p>段落$i：这是用于分页测试的一段文本内容。</p>',
    ).join()}</div>';
    final controller = _newController();
    controller.open(longHtml);

    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    // 若整个 div 被当作单块，则只有一个超高块、页码为 1/1；展开为段落块后应分多页
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1 / 1'), findsNothing);

    controller.dispose();
  });

  testWidgets('切换文本时复位页码且不抛 setState-during-build 异常', (tester) async {
    final controller = _newController();
    var page = 0;
    controller.addListener(() => page = controller.currentPage);

    final longA = List.generate(
      120,
      (i) => '<p>段落A$i：测试内容。</p>',
    ).join();
    final longB = List.generate(
      120,
      (i) => '<p>段落B$i：另一段测试内容。</p>',
    ).join();

    controller.open(longA);
    await tester.pumpWidget(_wrap(controller));
    await _settlePaging(tester);

    // 翻到最后一页，使当前页偏离 0，再切换内容
    controller.pageController.jumpToPage(controller.totalPages - 1);
    await tester.pumpAndSettle();
    expect(controller.currentPage, greaterThan(0));

    controller.open(longB);
    await _settlePaging(tester);

    expect(tester.takeException(), isNull);
    expect(page, 0);
    controller.dispose();
  });

  testWidgets('带锚点打开时直接定位到该标题所在页', (tester) async {
    final controller = _newController();
    var page = 0;
    controller.addListener(() => page = controller.currentPage);
    final html = [
      for (var i = 0; i < 80; i++)
        '<p>前置段落$i：这是用于分页测试的一段文本内容。</p>',
      '<p>目标小节标题</p>',
      for (var i = 0; i < 80; i++)
        '<p>后续段落$i：这是用于分页测试的一段文本内容。</p>',
    ].join();

    // 标题带空白也应能匹配（比对时忽略空白）
    controller.open(html, target: const PagedOpenTarget.atAnchor('目标 小节标题'));

    await tester.pumpWidget(_wrap(controller));
    await _settlePaging(tester);

    // 不应停留在首页，而是定位到标题所在的后续页
    expect(page, greaterThan(0));

    controller.dispose();
  });

  testWidgets('同章内重新定位（retarget）跳到锚点所在页', (tester) async {
    final controller = _newController();
    final html = [
      for (var i = 0; i < 80; i++)
        '<p>前置段落$i：这是用于分页测试的一段文本内容。</p>',
      '<p>目标小节标题</p>',
      for (var i = 0; i < 80; i++)
        '<p>后续段落$i：这是用于分页测试的一段文本内容。</p>',
    ].join();

    controller.open(html);
    await tester.pumpWidget(_wrap(controller));
    await _settlePaging(tester);
    expect(controller.currentPage, 0);

    controller.retarget(const PagedOpenTarget.atAnchor('目标小节标题'));
    await tester.pumpAndSettle();
    expect(controller.currentPage, greaterThan(0));

    // 点击当前顶层章节（无锚点）回到首页
    controller.retarget(PagedOpenTarget.first);
    await tester.pumpAndSettle();
    expect(controller.currentPage, 0);

    controller.dispose();
  });

  testWidgets('HTML 格式被保留（加粗内容经 HtmlWidget 渲染）', (tester) async {
    final controller = _newController();
    controller.open('<p>普通<b>加粗</b>文字</p>');

    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    // 分页渲染走 HtmlWidget（而非纯 Text），说明 HTML 结构未被丢弃
    expect(find.byType(HtmlWidget), findsWidgets);
    expect(find.textContaining('加粗', findRichText: true), findsWidgets);

    controller.dispose();
  });

  testWidgets('SVG 图片经 flutter_svg 渲染，不再显示红叉占位', (tester) async {
    final controller = _newController();
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">'
        '<rect width="24" height="24" fill="#000"/></svg>';
    final dataUri = 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
    controller.open('<p><img src="$dataUri" alt="矢量图"/></p>');

    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    // fwfh 图片解码失败的默认占位是 ❌，SVG 交由 flutter_svg 渲染后不应出现
    expect(find.text('❌'), findsNothing);

    controller.dispose();
  });
}
