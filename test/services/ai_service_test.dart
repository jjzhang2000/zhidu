import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:zhidu/services/ai_service.dart';
import 'package:zhidu/services/settings_service.dart';
import 'package:zhidu/services/ai_prompts.dart';
import 'package:zhidu/models/app_settings.dart';

void main() {
  late AIService aiService;
  late Directory testDir;

  setUpAll(() async {
    testDir = Directory('${Directory.systemTemp.path}/zhidu_ai_service_test');
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    await testDir.create(recursive: true);
  });

  setUp(() async {
    AIService.resetForTest();
    SettingsService.resetForTest();
    aiService = AIService();
  });

  tearDown(() async {
    AIService.resetForTest();
    SettingsService.resetForTest();
  });

  tearDownAll(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('AIConfig', () {
    group('fromJson', () {
      test('should parse qwen config correctly', () {
        final json = {
          'ai_provider': 'qwen',
          'qwen': {
            'api_key': 'test_qwen_key',
            'model': 'qwen-plus',
            'base_url': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          },
        };

        final config = AIConfig.fromJson(json);

        expect(config.provider, 'qwen');
        expect(config.apiKey, 'test_qwen_key');
        expect(config.model, 'qwen-plus');
        expect(config.baseUrl,
            'https://dashscope.aliyuncs.com/compatible-mode/v1');
      });

      test('should parse zhipu config correctly', () {
        final json = {
          'ai_provider': 'zhipu',
          'zhipu': {
            'api_key': 'test_zhipu_key',
            'model': 'glm-4-flash',
            'base_url': 'https://open.bigmodel.cn/api/paas/v4',
          },
        };

        final config = AIConfig.fromJson(json);

        expect(config.provider, 'zhipu');
        expect(config.apiKey, 'test_zhipu_key');
        expect(config.model, 'glm-4-flash');
        expect(config.baseUrl, 'https://open.bigmodel.cn/api/paas/v4');
      });

      test('should default to zhipu if ai_provider not specified', () {
        final json = {
          'zhipu': {
            'api_key': 'default_key',
            'model': 'glm-4',
            'base_url': 'https://test.com',
          },
        };

        final config = AIConfig.fromJson(json);

        expect(config.provider, 'zhipu');
      });

      test('should use default values for missing fields', () {
        final json = {
          'ai_provider': 'qwen',
          'qwen': {},
        };

        final config = AIConfig.fromJson(json);

        expect(config.provider, 'qwen');
        expect(config.apiKey, '');
        expect(config.model, 'glm-4-flash');
        expect(config.baseUrl, '');
      });

      test('should handle empty provider config', () {
        final json = {
          'ai_provider': 'unknown_provider',
        };

        final config = AIConfig.fromJson(json);

        expect(config.provider, 'unknown_provider');
        expect(config.apiKey, '');
      });

      test('should handle empty json', () {
        final json = <String, dynamic>{};

        final config = AIConfig.fromJson(json);

        expect(config.provider, 'zhipu');
        expect(config.apiKey, '');
      });

      test('should handle additional fields in json', () {
        final json = {
          'ai_provider': 'qwen',
          'qwen': {
            'api_key': 'key',
            'model': 'qwen-plus',
            'base_url': 'https://url',
            'extra_field': 'ignored',
          },
          'other_field': 'also_ignored',
        };

        final config = AIConfig.fromJson(json);

        expect(config.apiKey, 'key');
        expect(config.model, 'qwen-plus');
      });
    });

    group('isValid', () {
      test('should be valid with non-empty apiKey', () {
        final config = AIConfig(
          provider: 'qwen',
          apiKey: 'valid_api_key',
          model: 'qwen-plus',
          baseUrl: 'https://url',
        );

        expect(config.isValid, isTrue);
      });

      test('should be invalid with empty apiKey', () {
        final config = AIConfig(
          provider: 'qwen',
          apiKey: '',
          model: 'qwen-plus',
          baseUrl: 'https://url',
        );

        expect(config.isValid, isFalse);
      });

      test('should be invalid with zhipu placeholder key', () {
        final config = AIConfig(
          provider: 'zhipu',
          apiKey: 'YOUR_ZHIPU_API_KEY_HERE',
          model: 'glm-4-flash',
          baseUrl: 'https://url',
        );

        expect(config.isValid, isFalse);
      });

      test('should be invalid with qwen placeholder key', () {
        final config = AIConfig(
          provider: 'qwen',
          apiKey: 'YOUR_QWEN_API_KEY_HERE',
          model: 'qwen-plus',
          baseUrl: 'https://url',
        );

        expect(config.isValid, isFalse);
      });

      test('should be valid with other placeholder-like keys', () {
        final config = AIConfig(
          provider: 'custom',
          apiKey: 'YOUR_CUSTOM_API_KEY',
          model: 'model',
          baseUrl: 'https://url',
        );

        expect(config.isValid, isTrue);
      });
    });

    group('fromAiSettings', () {
      test('should create AIConfig from AiSettings correctly', () {
        final aiSettings = AiSettings(
          provider: 'qwen',
          apiKey: 'test_key',
          model: 'qwen-plus',
          baseUrl: 'https://test.com',
        );

        final config = AIConfig.fromAiSettings(aiSettings);

        expect(config.provider, 'qwen');
        expect(config.apiKey, 'test_key');
        expect(config.model, 'qwen-plus');
        expect(config.baseUrl, 'https://test.com');
      });
    });
  });

  group('AIService', () {
    group('singleton', () {
      test('should return same instance', () {
        final instance1 = AIService();
        final instance2 = AIService();

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('init', () {
      test('should load config from SettingsService', () async {
        final settingsFile = File('${testDir.path}/settings_init.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        expect(aiService.isConfigured, isTrue);
      });

      test('should handle missing configuration', () async {
        final settingsFile = File('${testDir.path}/nonexistent.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await aiService.init();

        expect(aiService.isConfigured, isFalse);
      });

      test('should handle invalid apiKey in SettingsService', () async {
        final settingsFile = File('${testDir.path}/settings_invalid.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'YOUR_QWEN_API_KEY_HERE',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        expect(aiService.isConfigured, isFalse);
      });

      test('should handle empty apiKey in SettingsService', () async {
        final settingsFile = File('${testDir.path}/settings_empty.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: '',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        expect(aiService.isConfigured, isFalse);
      });
    });

    group('isConfigured', () {
      test('should return false before init', () {
        expect(aiService.isConfigured, isFalse);
      });

      test('should return true after init with valid config', () async {
        final settingsFile = File('${testDir.path}/settings_config.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'valid_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        expect(aiService.isConfigured, isTrue);
      });
    });

    group('generateFullChapterSummary', () {
      test('should return null when not configured', () async {
        final result = await aiService.generateFullChapterSummary(
          'chapter content',
          chapterTitle: 'Chapter 1',
        );

        expect(result, isNull);
      });

      test('should call AI API when configured', () async {
        final settingsFile = File('${testDir.path}/settings_api.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          expect(request.url.toString(), contains('/chat/completions'));
          expect(request.headers['Content-Type'], 'application/json');
          expect(request.headers['Authorization'], contains('Bearer'));

          final body = jsonDecode(request.body);
          expect(body['model'], 'qwen-plus');
          expect(body['messages'], isNotEmpty);
          expect(body['temperature'], 0.7);
          expect(body['max_tokens'], 1000);

          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Generated summary content'}
                }
              ],
            }),
            200,
          );
        }));

        final result = await aiService.generateFullChapterSummary(
          'chapter content',
          chapterTitle: 'Chapter 1',
        );

        expect(result, 'Generated summary content');
      });

      test('should handle API error response', () async {
        final settingsFile = File('${testDir.path}/settings_error.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          return http.Response('Error message', 500);
        }));

        final result = await aiService.generateFullChapterSummary(
          'chapter content',
          chapterTitle: 'Chapter 1',
        );

        expect(result, isNull);
      });

      test('should work without chapterTitle', () async {
        final settingsFile = File('${testDir.path}/settings_notitle.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Summary without title'}
                }
              ],
            }),
            200,
          );
        }));

        final result =
            await aiService.generateFullChapterSummary('chapter content');

        expect(result, 'Summary without title');
      });

      test('should handle malformed response', () async {
        final settingsFile = File('${testDir.path}/settings_malformed.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          return http.Response(
            jsonEncode({'choices': []}),
            200,
          );
        }));

        final result = await aiService.generateFullChapterSummary('content');

        expect(result, isNull);
      });
    });

    group('generateBookSummaryFromPreface', () {
      test('should return null when not configured', () async {
        final result = await aiService.generateBookSummaryFromPreface(
          title: 'Book Title',
          author: 'Author',
          prefaceContent: 'Preface content',
        );

        expect(result, isNull);
      });

      test('should call AI API with correct parameters', () async {
        final settingsFile = File('${testDir.path}/settings_preface.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          final body = jsonDecode(request.body);
          final prompt = body['messages'][0]['content'];

          expect(prompt, contains('Book Title'));
          expect(prompt, contains('Author'));
          expect(prompt, contains('Preface content'));

          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Book summary from preface'}
                }
              ],
            }),
            200,
          );
        }));

        final result = await aiService.generateBookSummaryFromPreface(
          title: 'Book Title',
          author: 'Author',
          prefaceContent: 'Preface content',
          totalChapters: 10,
        );

        expect(result, 'Book summary from preface');
      });

      test('should work without totalChapters', () async {
        final settingsFile = File('${testDir.path}/settings_preface2.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Summary'}
                }
              ],
            }),
            200,
          );
        }));

        final result = await aiService.generateBookSummaryFromPreface(
          title: 'Book',
          author: 'Author',
          prefaceContent: 'Preface',
        );

        expect(result, 'Summary');
      });

      test('should handle API error', () async {
        final settingsFile = File('${testDir.path}/settings_preface3.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          return http.Response('Error', 401);
        }));

        final result = await aiService.generateBookSummaryFromPreface(
          title: 'Book',
          author: 'Author',
          prefaceContent: 'Preface',
        );

        expect(result, isNull);
      });
    });

    group('generateBookSummary', () {
      test('should return null when not configured', () async {
        final result = await aiService.generateBookSummary(
          title: 'Book Title',
          author: 'Author',
          chapterSummaries: 'Chapter summaries',
        );

        expect(result, isNull);
      });

      test('should call AI API with correct parameters', () async {
        final settingsFile = File('${testDir.path}/settings_book.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          final body = jsonDecode(request.body);
          final prompt = body['messages'][0]['content'];

          expect(prompt, contains('Book Title'));
          expect(prompt, contains('Author'));
          expect(prompt, contains('Chapter summaries'));

          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Full book summary'}
                }
              ],
            }),
            200,
          );
        }));

        final result = await aiService.generateBookSummary(
          title: 'Book Title',
          author: 'Author',
          chapterSummaries: 'Chapter summaries',
          totalChapters: 20,
        );

        expect(result, 'Full book summary');
      });

      test('should work without totalChapters', () async {
        final settingsFile = File('${testDir.path}/settings_book2.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Summary'}
                }
              ],
            }),
            200,
          );
        }));

        final result = await aiService.generateBookSummary(
          title: 'Book',
          author: 'Author',
          chapterSummaries: 'Summaries',
        );

        expect(result, 'Summary');
      });

      test('should handle API error', () async {
        final settingsFile = File('${testDir.path}/settings_book3.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'test_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        aiService.setMockClient(http_testing.MockClient((request) async {
          return http.Response('Error', 503);
        }));

        final result = await aiService.generateBookSummary(
          title: 'Book',
          author: 'Author',
          chapterSummaries: 'Summaries',
        );

        expect(result, isNull);
      });
    });

    group('SettingsService Integration', () {
      test('reloadConfig() loads from SettingsService', () async {
        // Initialize SettingsService with test file path
        final settingsFile = File('${testDir.path}/settings.json');
        SettingsService().setTestFilePath(settingsFile.path);

        // Create valid AI settings
        final aiSettings = AiSettings(
          provider: 'qwen',
          apiKey: 'test_settings_key',
          model: 'qwen-plus',
          baseUrl: 'https://test.com',
        );

        // Initialize SettingsService and update AI settings
        await SettingsService().init();
        await SettingsService().updateAiSettings(aiSettings);

        // Reload config in AIService
        await aiService.reloadConfig();

        expect(aiService.isConfigured, isTrue);
      });

      test('reloadConfig() handles missing configuration', () async {
        // Initialize SettingsService with test file path (no settings file exists)
        final settingsFile = File('${testDir.path}/nonexistent_settings.json');
        SettingsService().setTestFilePath(settingsFile.path);

        // Initialize SettingsService (will use defaults with empty API key)
        await SettingsService().init();

        // Reload config in AIService
        await aiService.reloadConfig();

        expect(aiService.isConfigured, isFalse);
      });

      test('isConfigured reflects SettingsService state', () async {
        // Initialize SettingsService with test file path
        final settingsFile = File('${testDir.path}/settings2.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();

        // Initially should not be configured (default settings have empty API key)
        await aiService.reloadConfig();
        expect(aiService.isConfigured, isFalse);

        // Update with valid settings
        final validSettings = AiSettings(
          provider: 'qwen',
          apiKey: 'valid_key',
          model: 'qwen-plus',
          baseUrl: 'https://test.com',
        );
        await SettingsService().updateAiSettings(validSettings);
        await aiService.reloadConfig();

        expect(aiService.isConfigured, isTrue);
      });

      test('Changes in SettingsService trigger reload', () async {
        // Initialize SettingsService with test file path
        final settingsFile = File('${testDir.path}/settings3.json');
        SettingsService().setTestFilePath(settingsFile.path);

        // Initialize with valid settings
        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'initial_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        // Initialize AIService (this will also register the listener)
        await aiService.init();
        expect(aiService.isConfigured, isTrue);

        // Update settings with invalid key (should trigger reload via listener)
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: '',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        // Wait for the listener to process
        await Future.delayed(Duration(milliseconds: 100));

        expect(aiService.isConfigured, isFalse);
      });

      test('updateConfig updates configuration directly', () async {
        expect(aiService.isConfigured, isFalse);

        final settings = AiSettings(
          provider: 'qwen',
          apiKey: 'direct_key',
          model: 'qwen-plus',
          baseUrl: 'https://test.com',
        );

        aiService.updateConfig(settings);

        expect(aiService.isConfigured, isTrue);
      });
    });

    group('Language Injection', () {
      // These tests verify that language instruction can be injected through prompts.
      // The AIService methods use AiPrompts which accept languageInstruction parameter.
      // Note: Current AIService doesn't automatically inject language from SettingsService,
      // but the prompts support language instruction when provided.

      test('chapterSummary prompt includes language instruction when provided',
          () {
        final prompt = AiPrompts.chapterSummary(
          chapterTitle: 'Chapter 1',
          content: 'Test content',
          languageInstruction: 'Please respond in English.',
        );

        expect(prompt, contains('Please respond in English'));
      });

      test(
          'bookSummaryFromPreface prompt includes language instruction when provided',
          () {
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: 'Book Title',
          author: 'Author',
          prefaceContent: 'Preface content',
          languageInstruction: '请用中文输出摘要。',
        );

        expect(prompt, contains('请用中文输出摘要'));
      });

      test('bookSummary prompt includes language instruction when provided',
          () {
        final prompt = AiPrompts.bookSummary(
          title: 'Book Title',
          author: 'Author',
          chapterSummaries: 'Chapter summaries',
          languageInstruction: '摘要は日本語で出力してください。',
        );

        expect(prompt, contains('摘要は日本語で出力してください'));
      });
    });

    group('AiPrompts Language Instruction', () {
      test('Language mode auto_book adds correct instruction', () {
        final instruction = AiPrompts.getLanguageInstruction('auto_book');
        expect(instruction, contains('根据书籍内容的语言'));
      });

      test('Language mode system adds correct instruction', () {
        final instruction = AiPrompts.getLanguageInstruction('system');
        expect(instruction, contains('根据系统语言设置'));
      });

      test('Language mode manual adds correct instruction for zh', () {
        final instruction =
            AiPrompts.getLanguageInstruction('manual', manualLanguage: 'zh');
        expect(instruction, '请用中文输出摘要。');
      });

      test('Language mode manual adds correct instruction for en', () {
        final instruction =
            AiPrompts.getLanguageInstruction('manual', manualLanguage: 'en');
        expect(instruction, 'Please respond in English for the summary.');
      });

      test('Language mode manual adds correct instruction for ja', () {
        final instruction =
            AiPrompts.getLanguageInstruction('manual', manualLanguage: 'ja');
        expect(instruction, '摘要は日本語で出力してください。');
      });

      test('Invalid language mode handled gracefully', () {
        final instruction = AiPrompts.getLanguageInstruction('invalid_mode');
        expect(instruction, contains('根据系统语言设置'));
      });

      test('Invalid manual language falls back to system', () {
        final instruction =
            AiPrompts.getLanguageInstruction('manual', manualLanguage: 'fr');
        expect(instruction, contains('根据系统语言设置'));
      });

      test('chapterSummary includes language instruction when provided', () {
        final prompt = AiPrompts.chapterSummary(
          chapterTitle: 'Chapter 1',
          content: 'Test content',
          languageInstruction: '请用中文输出摘要。',
        );
        expect(prompt, contains('语言要求：请用中文输出摘要。'));
      });

      test('chapterSummary excludes language instruction when not provided',
          () {
        final prompt = AiPrompts.chapterSummary(
          chapterTitle: 'Chapter 1',
          content: 'Test content',
        );
        expect(prompt, isNot(contains('语言要求')));
      });

      test('bookSummaryFromPreface includes language instruction when provided',
          () {
        final prompt = AiPrompts.bookSummaryFromPreface(
          title: 'Book',
          author: 'Author',
          prefaceContent: 'Preface',
          languageInstruction: 'Please respond in English.',
        );
        expect(prompt, contains('语言要求：Please respond in English.'));
      });

      test('bookSummary includes language instruction when provided', () {
        final prompt = AiPrompts.bookSummary(
          title: 'Book',
          author: 'Author',
          chapterSummaries: 'Summaries',
          languageInstruction: '摘要は日本語で出力してください。',
        );
        expect(prompt, contains('语言要求：摘要は日本語で出力してください。'));
      });
    });
  });
}
