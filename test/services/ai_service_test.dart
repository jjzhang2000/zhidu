import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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
    SettingsService.resetForTest();
    aiService = AIService();
  });

  group('AIService', () {
    group('singleton', () {
      test('should return same instance', () {
        final service1 = AIService();
        final service2 = AIService();
        expect(identical(service1, service2), isTrue);
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
            apiKey: 'valid_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        expect(aiService.isConfigured, isTrue);
      });

      test('should handle missing configuration', () async {
        final settingsFile = File('${testDir.path}/settings_missing.json');
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
            apiKey: '',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();

        expect(aiService.isConfigured, isFalse);
      });

      test('should handle empty apiKey in SettingsService', () async {
        final settingsFile = File('${testDir.path}/settings_empty_key.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'YOUR_API_KEY_HERE',
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
        final settingsFile = File('${testDir.path}/settings_configured.json');
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

    group('SettingsService Integration', () {
      test('reloadConfig() loads from SettingsService', () async {
        final settingsFile = File('${testDir.path}/settings.json');
        SettingsService().setTestFilePath(settingsFile.path);

        final aiSettings = AiSettings(
          provider: 'qwen',
          apiKey: 'test_settings_key',
          model: 'qwen-plus',
          baseUrl: 'https://test.com',
        );

        await SettingsService().init();
        await SettingsService().updateAiSettings(aiSettings);

        await aiService.reloadConfig();

        expect(aiService.isConfigured, isTrue);
      });

      test('reloadConfig() handles missing configuration', () async {
        final settingsFile = File('${testDir.path}/nonexistent_settings.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();

        await aiService.reloadConfig();

        expect(aiService.isConfigured, isFalse);
      });

      test('isConfigured reflects SettingsService state', () async {
        final settingsFile = File('${testDir.path}/settings2.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();

        await aiService.reloadConfig();
        expect(aiService.isConfigured, isFalse);

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
        final settingsFile = File('${testDir.path}/settings3.json');
        SettingsService().setTestFilePath(settingsFile.path);

        await SettingsService().init();
        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: 'initial_key',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

        await aiService.init();
        expect(aiService.isConfigured, isTrue);

        await SettingsService().updateAiSettings(
          AiSettings(
            provider: 'qwen',
            apiKey: '',
            model: 'qwen-plus',
            baseUrl: 'https://test.com',
          ),
        );

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
