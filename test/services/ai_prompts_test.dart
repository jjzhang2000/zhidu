import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/l10n/app_localizations_zh.dart';
import 'package:zhidu/services/ai_prompts.dart';

void main() {
  group('AiPrompts', () {
    final loc = AppLocalizationsZh();

    group('translateHtml', () {
      test('should generate prompt with chapter title', () {
        final prompt = AiPrompts.translateHtml(
          loc: loc,
          content: '<p>这是正文</p>',
          chapterTitle: '第1章 基础概念',
        );

        expect(prompt, '<p>这是正文</p>|第1章 基础概念');
      });

      test('should generate prompt without chapter title', () {
        final prompt = AiPrompts.translateHtml(
          loc: loc,
          content: '<p>无标题正文</p>',
        );

        expect(prompt, '<p>无标题正文</p>|');
      });
    });
  });
}
