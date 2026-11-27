// 真实阅读路径回归测试
//
// 用真实 EPUB（第一章约 174KB HTML）与真实 1280x800 布局驱动完整的 ChapterScreen，
// 逐项核对「每个输入落到哪一页」：
//   初始首页 → 右点下一页 → 左点上一页 → 首页再左点跨到上一章末页 → 右点跨回下一章首页。
//
// 页码指示现在是全书页码（本章起始页 + 页内偏移 / 全书总页数），因此断言以
// 「相邻页页码 +1 / -1」与「跨章后跨回落在原页」表达，不依赖具体章节页数。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/screens/chapter_screen.dart';
import 'package:zhidu/services/parsers/book_format_parser.dart';
import 'package:zhidu/services/parsers/epub_parser.dart';
import 'package:zhidu/widgets/paged_reading_view.dart';

const _epubPath = 'test/Vibe Coding AI Bian Cheng Wan Q - Tan Xing Xing.epub';

/// 读取页码指示「n / total」，不存在时返回 null
String? _indicator(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data;
    if (data != null && RegExp(r'^\d+ / \d+$').hasMatch(data)) return data;
  }
  return null;
}

/// 页码指示中的当前页（全书页码）
int? _pageNo(WidgetTester tester) {
  final indicator = _indicator(tester);
  if (indicator == null) return null;
  return int.tryParse(indicator.split(' / ').first);
}

/// PageView 实际停在第几页（章节内，0 起）
int? _renderedPage(WidgetTester tester) {
  final pageViews = find.descendant(
    of: find.byType(PagedReadingView),
    matching: find.byType(PageView),
  );
  if (pageViews.evaluate().isEmpty) return null;
  final widget = tester.widget<PageView>(pageViews.first);
  final controller = widget.controller;
  if (controller == null || !controller.hasClients) return null;
  return controller.page?.round();
}

/// 真实 IO（EPUB 解析）与分页测量都在 widget 测试的假时钟下进行，
/// 需要 runAsync 给真实事件循环让出时间，再 pump 推进测量定时器。
Future<bool> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxRounds = 300,
}) async {
  for (var i = 0; i < maxRounds; i++) {
    if (condition()) return true;
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  return condition();
}

/// 等分页测量稳定（换章定位期间会忽略输入，需等定位完成后再操作）
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 等页码指示切换为「全书页码」：前缀章（开头页及之前的章节）分页完成后，
/// 当前章首页的全书页码才会大于 1（本章首页的章节内页码恒为 1）。
///
/// 页码前缀一旦就绪就不会再变，因此后续断言只需比较页码，不必等全书分页完成。
Future<bool> _waitForBookNumbering(WidgetTester tester) {
  return _waitUntil(
    tester,
    () => (_renderedPage(tester) ?? 0) == 0 && (_pageNo(tester) ?? 0) > 1,
    maxRounds: 600,
  );
}

/// 反复点击同一侧直到页码满足条件。
///
/// 每次点击后必须等这一页真正翻过去再点下一次：连续点击会不断重启 PageView
/// 翻页动画，导致页码始终不前进（实际阅读时用户也不会这样连点）。
Future<void> _tapUntil(
  WidgetTester tester,
  Offset position,
  bool Function() done, {
  int maxTaps = 40,
}) async {
  for (var i = 0; i < maxTaps && !done(); i++) {
    final before = _indicator(tester);
    await tester.tapAt(position);
    await _waitUntil(
      tester,
      () => _indicator(tester) != before,
      maxRounds: 60,
    );
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// 只保留前 [count] 个顶层章节（含其子章节），让后台全书分页尽快完成，
/// 避免测试为了等整本书分页而长时间空转。
List<Chapter> _limitTopChapters(List<Chapter> all, int count) {
  var seen = 0;
  for (var i = 0; i < all.length; i++) {
    if (all[i].level != 0) continue;
    seen++;
    if (seen == count) {
      var end = all.length;
      for (var j = i + 1; j < all.length; j++) {
        if (all[j].level == 0) {
          end = j;
          break;
        }
      }
      return all.sublist(0, end);
    }
  }
  return all;
}

Future<List<Chapter>> _loadChapters(WidgetTester tester) async {
  FormatRegistry.clear();
  FormatRegistry.register('.epub', EpubParser());
  final chapters =
      await tester.runAsync(() => EpubParser().getChapters(_epubPath)) ??
          const <Chapter>[];
  return _limitTopChapters(chapters, 3);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实 EPUB：逐项核对翻页落点与跨章落点', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chapters = await _loadChapters(tester);
    final top = chapters.where((c) => c.level == 0).toList();
    expect(top.length, 3, reason: '需要至少三章才能测跨章');

    // 使用第 2 章（第一章正文），其 HTML 约 174KB，可稳定分出多页
    const startIndex = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: ChapterScreen(
          bookId: 'reader_flow',
          chapterIndex: startIndex,
          chapterTitle: top[startIndex].title,
          filePath: _epubPath,
          chapters: chapters,
        ),
      ),
    );

    // 初始：内容解析 + 分页测量 + 后台全书分页（等页码前缀就绪后取全书页码）
    expect(await _waitForBookNumbering(tester), isTrue,
        reason: '章节内容或页码前缀未完成');
    final start = _pageNo(tester)!;
    expect(_renderedPage(tester), 0);

    // 右点：下一页（全书页码 +1）
    await tester.tapAt(const Offset(1100, 400));
    expect(await _waitUntil(tester, () => _pageNo(tester) == start + 1), isTrue);
    await _settle(tester);
    expect(_renderedPage(tester), 1);

    // 左点：上一页（回到起始页）
    await tester.tapAt(const Offset(200, 400));
    expect(await _waitUntil(tester, () => _pageNo(tester) == start), isTrue);
    await _settle(tester);
    expect(_renderedPage(tester), 0);

    // 首页再左点：跨到上一章，应落在其末页（全书页码正好是起始页 - 1）
    await tester.tapAt(const Offset(200, 400));
    expect(await _waitUntil(tester, () => _pageNo(tester) == start - 1), isTrue,
        reason: '首页向前翻应跨到上一章末页');
    await _settle(tester);
    final prevLocal = _renderedPage(tester)!;
    expect(prevLocal, greaterThan(0), reason: '应落在上一章的非首页');

    // 末页再右点：跨回下一章首页（全书页码回到起始页，PageView 回到第 0 页）
    await tester.tapAt(const Offset(1100, 400));
    expect(await _waitUntil(tester, () => _pageNo(tester) == start), isTrue,
        reason: '上一章末页向后翻应回到下一章首页');
    await _settle(tester);
    expect(_renderedPage(tester), 0);

    expect(tester.takeException(), isNull);
  });

  testWidgets('真实 EPUB：第一章首页向前翻回到开头页（目录/版权页）末页', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chapters = await _loadChapters(tester);
    final top = chapters.where((c) => c.level == 0).toList();
    expect(top, isNotEmpty);

    // 从第一个顶层章节（第一章）开始，其首页继续向前翻应回到开头页末页
    await tester.pumpWidget(
      MaterialApp(
        home: ChapterScreen(
          bookId: 'reader_flow_opening',
          chapterIndex: 0,
          chapterTitle: top[0].title,
          filePath: _epubPath,
          chapters: chapters,
        ),
      ),
    );

    expect(await _waitForBookNumbering(tester), isTrue,
        reason: '章节内容或页码前缀未完成');
    final start = _pageNo(tester)!;
    // 开头页排在最前，第一章首页的全书页码必须大于 1
    expect(start, greaterThan(1), reason: '开头页应占用前面的页码');

    // 首页左点：回到开头页（目录/版权等未列入章节的前置页）并落在其末页
    await tester.tapAt(const Offset(200, 400));
    final entered = await _waitUntil(
      tester,
      () => _pageNo(tester) == start - 1,
      maxRounds: 600,
    );
    expect(entered, isTrue, reason: '第一章首页向前翻应进入开头页末页');
    await _settle(tester);
    expect(_renderedPage(tester), greaterThan(0),
        reason: '进入开头页必须落在其末页（非首页）');

    // 开头页末页右点：回到第一章首页
    await tester.tapAt(const Offset(1100, 400));
    final backToFirst =
        await _waitUntil(tester, () => _pageNo(tester) == start, maxRounds: 600);
    expect(backToFirst, isTrue, reason: '开头页末页向后翻应回到第一章首页');
    await _settle(tester);
    expect(_renderedPage(tester), 0);

    expect(tester.takeException(), isNull);
  });

  testWidgets('真实 EPUB：开头页首页继续向前翻无变化', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chapters = await _loadChapters(tester);
    final top = chapters.where((c) => c.level == 0).toList();

    await tester.pumpWidget(
      MaterialApp(
        home: ChapterScreen(
          bookId: 'reader_flow_opening_guard',
          chapterIndex: 0,
          chapterTitle: top.first.title,
          filePath: _epubPath,
          chapters: chapters,
        ),
      ),
    );

    expect(await _waitForBookNumbering(tester), isTrue,
        reason: '章节内容或页码前缀未完成');
    final start = _pageNo(tester)!;
    expect(start, greaterThan(1));

    // 进入开头页末页后，一路向前翻到开头页首页
    await tester.tapAt(const Offset(200, 400));
    expect(await _waitUntil(tester, () => _pageNo(tester) == start - 1,
            maxRounds: 600),
        isTrue);
    await _settle(tester);
    await _tapUntil(tester, const Offset(200, 400), () => _pageNo(tester) == 1);
    await _settle(tester);
    expect(_pageNo(tester), 1, reason: '应回到开头页首页（全书第 1 页）');

    // 开头页首页之前没有内容：继续向前翻页码不应变化
    await tester.tapAt(const Offset(200, 400));
    await _settle(tester);
    expect(_pageNo(tester), 1, reason: '开头页首页向前翻应无变化');

    // 一路向后翻：应进入第一章首页（不能跳过第一章）
    await _tapUntil(tester, const Offset(1100, 400), () => _pageNo(tester) == start);
    await _settle(tester);
    expect(_pageNo(tester), start,
        reason: '开头页向后翻应逐页进入第一章首页（$start），实际 ${_indicator(tester)}');
    expect(_renderedPage(tester), 0);

    expect(tester.takeException(), isNull);
  });
}
