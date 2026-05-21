import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:zhidu/services/ai_service.dart';
import 'package:zhidu/services/settings_service.dart';
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

    group('generateFullChapterSummaryStream', () {
      test('should return empty stream when not configured', () async {
        final stream = aiService.generateFullChapterSummaryStream(
          'chapter content',
          chapterTitle: 'Chapter 1',
        );

        final results = await stream.toList();
        expect(results, isEmpty);
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

        final stream = aiService.generateFullChapterSummaryStream(
          'chapter content',
          chapterTitle: 'Chapter 1',
        );

        final results = await stream.toList();
        final combined = results.join();
        expect(combined, contains('Generated summary content'));
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

        final stream = aiService.generateFullChapterSummaryStream(
          'chapter content',
          chapterTitle: 'Chapter 1',
        );

        final results = await stream.toList();
        expect(results, isEmpty);
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

        final stream =
            aiService.generateFullChapterSummaryStream('chapter content');

        final results = await stream.toList();
        final combined = results.join();
        expect(combined, contains('Summary without title'));
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

        final stream = aiService.generateFullChapterSummaryStream('content');

        final results = await stream.toList();
        expect(results, isEmpty);
      });
    });

    group('generateBookSummaryFromPrefaceStream', () {
      test('should return empty stream when not configured', () async {
        final stream = aiService.generateBookSummaryFromPrefaceStream(
          title: 'Book Title',
          author: 'Author',
          prefaceContent: 'Preface content',
        );

        final results = await stream.toList();
        expect(results, isEmpty);
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

        final stream = aiService.generateBookSummaryFromPrefaceStream(
          title: 'Book Title',
          author: 'Author',
          prefaceContent: 'Preface content',
          totalChapters: 10,
        );

        final results = await stream.toList();
        final combined = results.join();
        expect(combined, contains('Book summary from preface'));
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

        final stream = aiService.generateBookSummaryFromPrefaceStream(
          title: 'Book',
          author: 'Author',
          prefaceContent: 'Preface',
        );

        final results = await stream.toList();
        final combined = results.join();
        expect(combined, contains('Summary'));
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

        final stream = aiService.generateBookSummaryFromPrefaceStream(
          title: 'Book',
          author: 'Author',
          prefaceContent: 'Preface',
        );

        final results = await stream.toList();
        expect(results, isEmpty);
      });
    });

    group('generateBookSummaryStream', () {
      test('should return empty stream when not configured', () async {
        final stream = aiService.generateBookSummaryStream(
          title: 'Book Title',
          author: 'Author',
          chapterSummaries: 'Chapter summaries',
        );

        final results = await stream.toList();
        expect(results, isEmpty);
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

        final stream = aiService.generateBookSummaryStream(
          title: 'Book Title',
          author: 'Author',
          chapterSummaries: 'Chapter summaries',
          totalChapters: 20,
        );

        final results = await stream.toList();
        final combined = results.join();
        expect(combined, contains('Full book summary'));
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

        final stream = aiService.generateBookSummaryStream(
          title: 'Book',
          author: 'Author',
          chapterSummaries: 'Summaries',
        );

        final results = await stream.toList();
        final combined = results.join();
        expect(combined, contains('Summary'));
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

        final stream = aiService.generateBookSummaryStream(
          title: 'Book',
          author: 'Author',
          chapterSummaries: 'Summaries',
        );

        final results = await stream.toList();
        expect(results, isEmpty);
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
  });
}
