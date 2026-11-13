import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/l10n/app_localizations_zh.dart';
import 'package:zhidu/services/ai_prompts.dart';

void main() {
  group('AiPrompts', () {
    final loc = AppLocalizationsZh();

    group('bookSummary', () {

      test('should generate prompt with all parameters', () {
        final prompt = AiPrompts.bookSummary(
          loc: loc,
          title: '全书摘要测试',
          author: '作者名',
          chapterSummaries: '第一章摘要\n第二章摘要',
          totalChapters: 5,
        );

        expect(prompt, contains('全书摘要测试'));
        expect(prompt, contains('作者名'));
        expect(prompt, contains('第一章摘要\n第二章摘要'));
        expect(prompt, contains('章节数：5'));
        expect(prompt, contains('800-900字'));
      });

      test('should generate prompt without totalChapters', () {
        final prompt = AiPrompts.bookSummary(
          loc: loc,
          title: '书名',
          author: '作者',
          chapterSummaries: '摘要内容',
        );

        expect(prompt, contains('书名'));
        expect(prompt, contains('作者'));
        expect(prompt, contains('摘要内容'));
        expect(prompt, isNot(contains('章节数')));
      });

      test('should include all required sections in template', () {
        final prompt = AiPrompts.bookSummary(
          loc: loc,
          title: '书名',
          author: '作者',
          chapterSummaries: '章节摘要',
        );

        expect(prompt, contains('内容简介'));
        expect(prompt, contains('核心主题'));
        expect(prompt, contains('关键要点'));
        expect(prompt, contains('适合读者'));
      });

      test('should handle long chapter summaries', () {
        final longSummary =
            List.generate(100, (i) => '第${i + 1}章摘要内容').join('\n');
        final prompt = AiPrompts.bookSummary(
          loc: loc,
          title: '长篇书籍',
          author: '作者',
          chapterSummaries: longSummary,
        );

        expect(prompt, contains(longSummary));
        expect(prompt, contains('长篇书籍'));
      });

      test('should handle empty chapter summaries', () {
        final prompt = AiPrompts.bookSummary(
          loc: loc,
          title: '书名',
          author: '作者',
          chapterSummaries: '',
        );

        expect(prompt, contains('书名'));
      });
    });

    group('chapterSummary', () {

      test('should generate prompt with chapter title', () {
        final prompt = AiPrompts.chapterSummary(
          loc: loc,
          chapterTitle: '第1章 基础概念',
          content: '这是章节内容',
        );

        expect(prompt, contains('第1章 基础概念'));
        expect(prompt, contains('这是章节内容'));
        expect(prompt, contains('500-600字'));
        expect(prompt, contains('Markdown'));
      });

      test('should generate prompt without chapter title', () {
        final prompt = AiPrompts.chapterSummary(
          loc: loc,
          content: '无标题章节内容',
        );

        expect(prompt, contains('无标题章节内容'));
        expect(prompt, isNot(contains('原始章节标识')));
      });

      test('should include title extraction instruction', () {
        final prompt = AiPrompts.chapterSummary(
          loc: loc,
          chapterTitle: 'Chapter 1',
          content: 'Content',
        );

        expect(prompt, contains('章节标题'));
        expect(prompt, contains('真实标题'));
      });

      test('should include output format requirements', () {
        final prompt = AiPrompts.chapterSummary(
          loc: loc,
          content: '内容',
        );

        expect(prompt, contains('核心内容'));
        expect(prompt, contains('关键要点'));
        expect(prompt, contains('总结'));
      });

      test('should handle special characters in content', () {
        final prompt = AiPrompts.chapterSummary(
          loc: loc,
          chapterTitle: '测试章节<特殊>',
          content: '内容包含\n换行和"引号"及符号<>{}[]',
        );

        expect(prompt, contains('测试章节<特殊>'));
        expect(prompt, contains('内容包含\n换行和"引号"及符号<>{}[]'));
      });

      test('should handle long content', () {
        final longContent = '章节内容 ' * 10000;
        final prompt = AiPrompts.chapterSummary(
          loc: loc,
          chapterTitle: '长章节',
          content: longContent,
        );

        expect(prompt, contains(longContent));
        expect(prompt, contains('长章节'));
      });

      test('should include chapter numbering preservation instruction', () {
        final prompt = AiPrompts.chapterSummary(
          loc: loc,
          content: '内容',
        );

        expect(prompt, contains('必须保留章节编号'));
        expect(prompt, contains('第X章'));
        expect(prompt, contains('Chapter X'));
      });
    });
  });
}
