import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/screens/chapter_screen.dart';
import 'package:zhidu/models/book.dart';
import 'package:zhidu/models/chapter.dart';
import 'package:zhidu/models/reader_typography.dart';
import 'package:zhidu/services/settings_service.dart';

Book _createTestBook({
  String id = 'test-book-1',
  String title = 'Test Book',
  BookFormat format = BookFormat.epub,
}) {
  return Book(
    id: id,
    title: title,
    author: 'Test Author',
    filePath: '/test/path/book.epub',
    format: format,
    totalChapters: 3,
    addedAt: DateTime(2024, 1, 1),
  );
}

Chapter _createTestChapter({
  int index = 0,
  String title = 'Test Chapter',
  int level = 0,
  String? href,
  int? startPage,
  int? endPage,
}) {
  return Chapter(
    bookId: 'test-book-1',
    index: index,
    title: title,
    location: ChapterLocation(
      href: href ?? 'chapter$index.xhtml',
      startPage: startPage,
      endPage: endPage,
    ),
    level: level,
  );
}

List<Chapter> _createTestChapters(int count) {
  return List.generate(
      count, (i) => _createTestChapter(index: i, title: '第${i + 1}章'));
}

void main() {
  group('ChapterScreen Widget Tests', () {
    group('rendering tests', () {
      testWidgets('renders AppBar with chapter title',
          (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = _createTestChapters(3);

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              chapterContent: '<p>测试内容</p>',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        await tester.pump();

        expect(find.text('第一章'), findsOneWidget);
      });

      testWidgets('renders Scaffold with body', (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = _createTestChapters(3);

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              chapterContent: '<p>测试内容</p>',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        expect(find.byType(Scaffold), findsOneWidget);
      });

    });

    group('chapter navigation tests', () {
      testWidgets('EPUB 原文不再显示底部大翻页按钮（改用左右 1/3 点击/滚轮）',
          (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = _createTestChapters(5);

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 1,
              chapterTitle: '第二章',
              chapterContent: '<p>测试内容</p>',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        await tester.pump();

        expect(find.byIcon(Icons.keyboard_arrow_left), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
      });

      testWidgets('does not show navigation buttons for single chapter',
          (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = [_createTestChapter()];

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              chapterContent: '<p>测试内容</p>',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        await tester.pump();

        expect(find.byIcon(Icons.keyboard_arrow_left), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
      });

      testWidgets('shows original chapter title when no AI title exists',
          (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = _createTestChapters(3);

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '原始标题',
              chapterContent: '<p>测试内容</p>',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        await tester.pump();

        expect(find.text('原始标题'), findsOneWidget);
      });
    });

    group('error handling tests', () {
      testWidgets('shows error view when no content and no file path',
          (WidgetTester tester) async {
        final book = _createTestBook();

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              book: book,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('出错了'), findsOneWidget);
      });
    });

    group('vertical tab tests', () {
      testWidgets('shows vertical tabs for switching views',
          (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = _createTestChapters(3);

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              chapterContent: '<p>测试内容足够</p>',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        await tester.pump();
        
        // Expect to find both vertical tabs (summary and original text)
        expect(find.byIcon(Icons.auto_awesome), findsOneWidget); // Summary tab
        expect(find.byIcon(Icons.menu_book), findsOneWidget);    // Original text tab
      });
    });

    group('PDF specific tests', () {
      testWidgets('shows PDF format screen structure',
          (WidgetTester tester) async {
        final book = _createTestBook(format: BookFormat.pdf);
        final chapters = [
          _createTestChapter(index: 0, startPage: 1, endPage: 5),
          _createTestChapter(index: 1, startPage: 6, endPage: 10),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              filePath: '/test/book.pdf',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('filters chapters by level 0 for navigation',
          (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = [
          _createTestChapter(index: 0, level: 0, title: '第一章'),
          _createTestChapter(index: 1, level: 1, title: '第一节'),
          _createTestChapter(index: 2, level: 0, title: '第二章'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              chapterContent: '<p>测试内容</p>',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        await tester.pump();

        // 子章节被过滤掉，仅剩两个顶层章节，故不再有底部按钮（EPUB 无翻页按钮）
        expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
      });
    });

    group('content display structure tests', () {
      testWidgets('shows padded layout for content display',
          (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = _createTestChapters(3);

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              chapterContent: '<p>测试内容</p>',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(Padding), findsWidgets);
      });

      testWidgets('shows centered layout for loading/error states',
          (WidgetTester tester) async {
        final book = _createTestBook();

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              book: book,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(Center), findsWidgets);
      });
    });

    group('content too short handling tests', () {
      testWidgets('displays content even when short',
          (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = _createTestChapters(3);

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              chapterContent: '<p>短内容</p>',
              chapters: chapters,
              book: book,
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });
    });

    group('resume position tests', () {
      testWidgets('initialPagedPage 打开后定位到指定页（续读）',
          (WidgetTester tester) async {
        final book = _createTestBook();
        final chapters = _createTestChapters(3);
        final html = List.generate(
          120,
          (i) => '<p>段落$i：这是用于分页测试的一段文本内容。</p>',
        ).join();

        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              openingContent: html,
              chapters: chapters,
              book: book,
              initialPagedPage: 3,
            ),
          ),
        );

        // 分页依赖 120ms 定时重测，需显式推进时间
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        await tester.pump();

        // 已定位到第 4 页：首页段落不应再出现在构建范围内
        expect(
          find.textContaining('段落0：', findRichText: true),
          findsNothing,
        );
      });
    });
    group('typography menu tests', () {
      testWidgets('format_size 菜单展示三组选项并即时调整字号',
          (WidgetTester tester) async {
        SettingsService.resetForTest();
        addTearDown(SettingsService.resetForTest);

        final book = _createTestBook();
        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              chapterContent: '<p>测试内容</p>',
              chapters: _createTestChapters(3),
              book: book,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.format_size));
        await tester.pumpAndSettle();

        expect(find.text('文字'), findsOneWidget);
        expect(find.text('行距'), findsOneWidget);
        expect(find.text('段距'), findsOneWidget);
        expect(find.byTooltip('文字 重置'), findsOneWidget);

        // 未覆盖时应为默认字号 21
        expect(SettingsService().readerFontSizeOverride.value, isNull);
        await tester.tap(find.byTooltip('文字 +'));
        await tester.pumpAndSettle();
        expect(SettingsService().readerFontSizeOverride.value, 23);
      });
      testWidgets('重置恢复原书排版，书籍未定义时用应用默认值',
          (WidgetTester tester) async {
        SettingsService.resetForTest();
        addTearDown(SettingsService.resetForTest);

        final book = _createTestBook();
        await tester.pumpWidget(
          MaterialApp(
            home: ChapterScreen(
              bookId: book.id,
              chapterIndex: 0,
              chapterTitle: '第一章',
              chapterContent: '<p>测试内容</p>',
              chapters: _createTestChapters(3),
              book: book,
              bookTypography: const ReaderTypography(
                fontSize: 17,
                lineHeight: 1.4,
                paragraphSpacing: 0.4,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.format_size));
        await tester.pumpAndSettle();

        // 无全局覆盖 → 起步值采用原书字号 17；+ 后为 19 并写入全局覆盖
        expect(SettingsService().readerFontSizeOverride.value, isNull);
        await tester.tap(find.byTooltip('文字 +'));
        await tester.pumpAndSettle();
        expect(SettingsService().readerFontSizeOverride.value, 19);

        // 重置 = 清除字号覆盖，回到原书字号 17
        await tester.tap(find.byTooltip('文字 重置'));
        await tester.pumpAndSettle();
        expect(SettingsService().readerFontSizeOverride.value, isNull);

        // 段距重置 = 清除段距覆盖（行距覆盖不受影响）
        await tester.tap(find.byTooltip('段距 重置'));
        await tester.pumpAndSettle();
        expect(SettingsService().readerParagraphSpacingOverride.value, isNull);
      });
    });
  });
}
