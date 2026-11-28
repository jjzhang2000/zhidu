// 全书后台分页器单元测试
//
// 验证：优先处理当前章（进入阅读页/尺寸变化时不长时间等待）、页码前缀就绪判断、
// 采用控制器测量结果（adopt）避免重复测量、尺寸变化后整体重排。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/services/parsers/rendered_content.dart';
import 'package:zhidu/widgets/book_paginator.dart';

const _textStyle = TextStyle(fontSize: 16, height: 1.8);
const _width = 320.0;
const _height = 400.0;

String _chapterHtml(String tag, {int paragraphs = 30}) {
  return List.generate(
    paragraphs,
    (i) => '<p>$tag第$i段：这是用于后台分页测试的一段较长文本内容。</p>',
  ).join();
}

Widget _wrap(BookPaginator paginator) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: -10000,
            top: 0,
            child: BookPaginatorHost(paginator: paginator),
          ),
        ],
      ),
    ),
  );
}

/// 推进假时钟直到条件成立（测量用 120ms 定时器重测，需多次 pump）
Future<bool> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxRounds = 80,
}) async {
  for (var i = 0; i < maxRounds; i++) {
    if (condition()) return true;
    await tester.pump(const Duration(milliseconds: 150));
  }
  return condition();
}

void main() {
  testWidgets('优先分页当前章，页码前缀就绪后才给出起始页', (tester) async {
    final loaded = <int>[];
    final paginator = BookPaginator(
      textStyle: _textStyle,
      chapterCount: 5,
      hasOpening: false,
      loader: (index) async {
        loaded.add(index);
        return RenderedContent(_chapterHtml('章$index'));
      },
      registerFonts: (_) {},
    );
    addTearDown(paginator.dispose);

    paginator.setPriority(3);
    paginator.configure(_width, _height);
    await tester.pumpWidget(_wrap(paginator));

    // 优先级 3 应最先完成分页
    expect(await _pumpUntil(tester, () => paginator.pagesFor(3) != null), isTrue);
    expect(loaded.first, 3, reason: '当前章应被优先加载/分页');
    // 前缀章（0..2）尚未完成，起始页未知
    expect(paginator.startPageFor(3), isNull);

    // 全书完成后起始页 = 前面所有章节页数之和
    expect(await _pumpUntil(tester, () => paginator.isComplete), isTrue);
    var expected = 0;
    for (var i = 0; i < 3; i++) {
      expected += paginator.pagesFor(i)!.pageCount;
    }
    expect(paginator.startPageFor(3), expected);
    expect(paginator.startPageFor(0), 0);
    expect(paginator.totalPages, greaterThan(expected));
    expect(tester.takeException(), isNull);
  });

  testWidgets('图片独立页固定占 1 页（与图片像素尺寸无关）', (tester) async {
    final paginator = BookPaginator(
      textStyle: _textStyle,
      chapterCount: 3,
      hasOpening: false,
      loader: (index) async {
        if (index == 1) {
          // 超大尺寸图片页：仍应固定为 1 页，不按像素尺寸计算
          return RenderedContent(
            '<html><body>'
            '<div data-zhidu-image-page="1" style="text-align: center">'
            '<img src="data:image/jpeg;base64,AAAA" width="4000" height="6000" />'
            '</div></body></html>',
          );
        }
        return RenderedContent(_chapterHtml('章$index'));
      },
      registerFonts: (_) {},
    );
    addTearDown(paginator.dispose);

    paginator.configure(_width, _height);
    await tester.pumpWidget(_wrap(paginator));
    expect(await _pumpUntil(tester, () => paginator.isComplete), isTrue,
        reason: '全书分页未完成');

    expect(paginator.pagesFor(1)!.pageCount, 1, reason: '图片条目应恒为 1 页');
    expect(paginator.startPageFor(2),
        1 + paginator.pagesFor(0)!.pageCount);
    expect(tester.takeException(), isNull);
  });

  testWidgets('采用控制器测量结果后不再重复测量，尺寸变化整体重排', (tester) async {
    final loaded = <int>[];
    final paginator = BookPaginator(
      textStyle: _textStyle,
      chapterCount: 4,
      hasOpening: false,
      loader: (index) async {
        loaded.add(index);
        return RenderedContent(_chapterHtml('章$index'));
      },
      registerFonts: (_) {},
    );
    addTearDown(paginator.dispose);

    paginator.configure(_width, _height);
    await tester.pumpWidget(_wrap(paginator));
    expect(await _pumpUntil(tester, () => paginator.isComplete), isTrue);
    final firstSizePages = paginator.pagesFor(0)!.pageCount;
    expect(loaded.where((i) => i == 0).length, 1);

    // 回填控制器测量结果：同尺寸下不应再重复测量
    paginator.adopt(
      0,
      paginator.pagesFor(0)!,
    );
    expect(loaded.where((i) => i == 0).length, 1);

    // 尺寸变化：整体失效并按新宽度重排（复用已解析内容，不再解析 EPUB）
    paginator.configure(_width / 2, _height);
    expect(await _pumpUntil(tester, () => paginator.isComplete), isTrue);
    expect(loaded.where((i) => i == 0).length, 1,
        reason: '尺寸变化应复用已解析内容，只重新测量');
    expect(paginator.pagesFor(0)!.pageCount,
        greaterThanOrEqualTo(firstSizePages));
    expect(tester.takeException(), isNull);
  });
}
