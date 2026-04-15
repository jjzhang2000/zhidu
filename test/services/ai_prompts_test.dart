import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/services/ai_prompts.dart';

void main() {
  group('AiPrompts', () {
    group('getLanguageInstruction', () {
      test('should return correct Chinese text for auto_book mode', () {
        final instruction = AiPrompts.getLanguageInstruction('auto_book');

        expect(instruction, contains('根据书籍内容'));
        expect(instruction, contains('相同语言'));
        expect(instruction, contains('摘要'));
      });

      test('should return correct Chinese text for system mode', () {
        final instruction = AiPrompts.getLanguageInstruction('system');

        expect(instruction, contains('系统语言设置'));
        expect(instruction, contains('对应语言'));
        expect(instruction, contains('摘要'));
      });

      test('should return correct Chinese text for manual zh', () {
        final instruction = AiPrompts.getLanguageInstruction(
          'manual',
          manualLanguage: 'zh',
        );

        expect(instruction, contains('中文'));
        expect(instruction, contains('输出摘要'));
      });

      test('should return correct English text for manual en', () {
        final instruction = AiPrompts.getLanguageInstruction(
          'manual',
          manualLanguage: 'en',
        );

        expect(instruction, contains('English'));
        expect(instruction, contains('respond'));
        expect(instruction, contains('summary'));
      });

      test('should return correct Japanese text for manual ja', () {
        final instruction = AiPrompts.getLanguageInstruction(
          'manual',
          manualLanguage: 'ja',
        );

        expect(instruction, contains('日本語'));
        expect(instruction, contains('出力'));
      });

      test('should handle invalid language code gracefully', () {
        final instruction = AiPrompts.getLanguageInstruction(
          'manual',
          manualLanguage: 'invalid_code',
        );

        expect(instruction, contains('系统语言设置'));
        expect(instruction, isNotEmpty);
      });

      test('should handle invalid mode gracefully', () {
        final instruction = AiPrompts.getLanguageInstruction('invalid_mode');

        expect(instruction, contains('系统语言设置'));
        expect(instruction, isNotEmpty);
      });

      test('should handle null manualLanguage in manual mode', () {
        final instruction = AiPrompts.getLanguageInstruction('manual');

        expect(instruction, contains('系统语言设置'));
        expect(instruction, isNotEmpty);
      });
    });

    group('Language Instruction Injection', () {
      test('chapterSummary should append language instruction to prompt', () {
        final prompt = AiPrompts.chapterSummary(
          chapterTitle: '第1章 测试',
          content: '这是章节内容',
          languageInstruction: '请用中文输出摘要。',
        );

        expect(prompt, contains('语言要求'));
        expect(prompt, contains('请用中文输出摘要。'));
        expect(
          prompt.indexOf('语言要求：请用中文输出摘要。'),
          lessThan(prompt.indexOf('要求：') + prompt.indexOf('1. ')),
        );
      });

      test(
          'bookSummaryFromPreface should append language instruction to prompt',
          () {
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: '测试书籍',
          author: '测试作者',
          prefaceContent: '这是前言内容',
          totalChapters: 10,
          languageInstruction: 'Please respond in English for the summary.',
        );

        expect(prompt, contains('语言要求'));
        expect(prompt, contains('Please respond in English for the summary.'));
        expect(prompt.indexOf('语言要求'), greaterThan(prompt.indexOf('作者')));
      });

      test('bookSummary should append language instruction to prompt', () {
        final prompt = AiPrompts.bookSummary(
          title: '全书摘要测试',
          author: '作者名',
          chapterSummaries: '第一章摘要\n第二章摘要',
          totalChapters: 5,
          languageInstruction: '摘要は日本語で出力してください。',
        );

        expect(prompt, contains('语言要求'));
        expect(prompt, contains('摘要は日本語で出力してください。'));
        expect(prompt.indexOf('语言要求'), greaterThan(prompt.indexOf('作者')));
      });

      test(
          'chapterSummary with empty language instruction should not break prompt',
          () {
        final prompt = AiPrompts.chapterSummary(
          chapterTitle: '第1章 测试',
          content: '这是章节内容',
          languageInstruction: '',
        );

        // Empty string still produces '语言要求：' in the prompt, just without content after
        expect(prompt, contains('语言要求：'));
        expect(prompt, contains('这是章节内容'));
        expect(prompt, contains('第1章 测试'));
      });

      test(
          'bookSummaryFromPreface with null language instruction should not break prompt',
          () {
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: '测试书籍',
          author: '测试作者',
          prefaceContent: '这是前言内容',
        );

        expect(prompt, isNot(contains('语言要求')));
        expect(prompt, contains('测试书籍'));
        expect(prompt, contains('测试作者'));
      });

      test('bookSummary with null language instruction should not break prompt',
          () {
        final prompt = AiPrompts.bookSummary(
          title: '全书摘要测试',
          author: '作者名',
          chapterSummaries: '第一章摘要',
        );

        expect(prompt, isNot(contains('语言要求')));
        expect(prompt, contains('全书摘要测试'));
        expect(prompt, contains('作者名'));
      });

      test(
          'language instruction should appear in correct location in chapterSummary',
          () {
        final languageInstruction = '请用中文输出摘要。';
        final prompt = AiPrompts.chapterSummary(
          chapterTitle: '第1章',
          content: '章节内容',
          languageInstruction: languageInstruction,
        );

        final contentIndex = prompt.indexOf('章节内容');
        final langIndex = prompt.indexOf('语言要求：$languageInstruction');
        final requirementIndex = prompt.indexOf('要求：');

        expect(langIndex, greaterThan(contentIndex));
        expect(langIndex, lessThan(requirementIndex));
      });

      test(
          'language instruction should appear in correct location in bookSummaryFromPreface',
          () {
        final languageInstruction = 'Please respond in English.';
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: '书名',
          author: '作者',
          prefaceContent: '前言内容',
          totalChapters: 10,
          languageInstruction: languageInstruction,
        );

        final authorLineIndex = prompt.indexOf('- 作者：作者');
        final langIndex = prompt.indexOf('语言要求：$languageInstruction');
        final prefaceHeaderIndex = prompt.indexOf('前言/序言内容：');

        // Language instruction should be in the book info section, after author line but before preface content
        expect(langIndex, greaterThan(authorLineIndex));
        expect(langIndex, lessThan(prefaceHeaderIndex));
      });

      test(
          'language instruction should appear in correct location in bookSummary',
          () {
        final languageInstruction = '日本語で出力してください。';
        final prompt = AiPrompts.bookSummary(
          title: '书名',
          author: '作者',
          chapterSummaries: '摘要',
          totalChapters: 5,
          languageInstruction: languageInstruction,
        );

        final authorLineIndex = prompt.indexOf('- 作者：作者');
        final langIndex = prompt.indexOf('语言要求：$languageInstruction');
        final summaryHeaderIndex = prompt.indexOf('各章节摘要：');

        // Language instruction should be in the book info section, after author line but before chapter summaries
        expect(langIndex, greaterThan(authorLineIndex));
        expect(langIndex, lessThan(summaryHeaderIndex));
      });
    });

    group('bookSummaryFromPreface', () {
      test('should generate prompt with all parameters', () {
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: '测试书籍',
          author: '测试作者',
          prefaceContent: '这是前言内容',
          totalChapters: 10,
        );

        expect(prompt, contains('测试书籍'));
        expect(prompt, contains('测试作者'));
        expect(prompt, contains('这是前言内容'));
        expect(prompt, contains('章节数：10'));
        expect(prompt, contains('800-900字'));
        expect(prompt, contains('Markdown'));
      });

      test('should generate prompt without totalChapters', () {
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: '无章节书籍',
          author: '匿名作者',
          prefaceContent: '简短前言',
        );

        expect(prompt, contains('无章节书籍'));
        expect(prompt, contains('匿名作者'));
        expect(prompt, contains('简短前言'));
        expect(prompt, isNot(contains('章节数')));
      });

      test('should include all required sections in template', () {
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: '书名',
          author: '作者',
          prefaceContent: '前言',
        );

        expect(prompt, contains('内容简介'));
        expect(prompt, contains('核心主题'));
        expect(prompt, contains('适合读者'));
      });

      test('should handle empty preface content', () {
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: '书名',
          author: '作者',
          prefaceContent: '',
        );

        expect(prompt, contains('书名'));
        expect(prompt, contains('作者'));
      });

      test('should handle special characters in parameters', () {
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: '《测试》书籍：第二版',
          author: '作者<测试>',
          prefaceContent: '前言\n包含换行和"引号"',
        );

        expect(prompt, contains('《测试》书籍：第二版'));
        expect(prompt, contains('作者<测试>'));
        expect(prompt, contains('前言\n包含换行和"引号"'));
      });
    });

    group('bookSummary', () {
      test('should generate prompt with all parameters', () {
        final prompt = AiPrompts.bookSummary(
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
          title: '长篇书籍',
          author: '作者',
          chapterSummaries: longSummary,
        );

        expect(prompt, contains(longSummary));
        expect(prompt, contains('长篇书籍'));
      });

      test('should handle empty chapter summaries', () {
        final prompt = AiPrompts.bookSummary(
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
          content: '无标题章节内容',
        );

        expect(prompt, contains('无标题章节内容'));
        expect(prompt, isNot(contains('原始章节标识')));
      });

      test('should include title extraction instruction', () {
        final prompt = AiPrompts.chapterSummary(
          chapterTitle: 'Chapter 1',
          content: 'Content',
        );

        expect(prompt, contains('章节标题'));
        expect(prompt, contains('真实标题'));
      });

      test('should include output format requirements', () {
        final prompt = AiPrompts.chapterSummary(
          content: '内容',
        );

        expect(prompt, contains('核心内容'));
        expect(prompt, contains('关键要点'));
        expect(prompt, contains('总结'));
      });

      test('should handle special characters in content', () {
        final prompt = AiPrompts.chapterSummary(
          chapterTitle: '测试章节<特殊>',
          content: '内容包含\n换行和"引号"及符号<>{}[]',
        );

        expect(prompt, contains('测试章节<特殊>'));
        expect(prompt, contains('内容包含\n换行和"引号"及符号<>{}[]'));
      });

      test('should handle long content', () {
        final longContent = '章节内容 ' * 10000;
        final prompt = AiPrompts.chapterSummary(
          chapterTitle: '长章节',
          content: longContent,
        );

        expect(prompt, contains(longContent));
        expect(prompt, contains('长章节'));
      });

      test('should include chapter numbering preservation instruction', () {
        final prompt = AiPrompts.chapterSummary(
          content: '内容',
        );

        expect(prompt, contains('必须保留章节编号'));
        expect(prompt, contains('第X章'));
        expect(prompt, contains('Chapter X'));
      });
    });
  });
}
