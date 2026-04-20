import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/app_settings.dart';
import 'package:zhidu/services/settings_service.dart';

void main() {
  late SettingsService settingsService;
  late Directory testDir;
  late String settingsFilePath;

  setUp(() async {
    settingsService = SettingsService();
    SettingsService.resetForTest();

    // Create a temporary directory for testing
    testDir = Directory(
        '${Directory.systemTemp.path}/zhidu_settings_test_${DateTime.now().millisecondsSinceEpoch}');
    await testDir.create(recursive: true);

    settingsFilePath = '${testDir.path}/settings.json';
    settingsService.setTestFilePath(settingsFilePath);
  });

  tearDown(() async {
    // resetForTest() already handles disposing notifiers, no need to call dispose() again
    SettingsService.resetForTest();

    // Clean up test directory
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('SettingsService', () {
    group('singleton', () {
      test('should return same instance', () {
        final instance1 = SettingsService();
        final instance2 = SettingsService();

        expect(identical(instance1, instance2), isTrue);
      });

      test('resetForTest should reset instance state', () async {
        // Initialize and modify settings
        await settingsService.init();
        await settingsService.setThemeMode(ThemeMode.dark);

        // Reset (also delete the settings file to simulate fresh state)
        SettingsService.resetForTest();
        final file = File(settingsFilePath);
        if (await file.exists()) {
          await file.delete();
        }

        // Create new instance reference
        settingsService = SettingsService();
        settingsService.setTestFilePath(settingsFilePath);
        await settingsService.init();

        // Should have default settings after reset
        expect(settingsService.settings.themeSettings.mode, ThemeMode.system);
      });
    });

    group('initialization', () {
      test('init() creates default settings if file does not exist', () async {
        // Ensure file doesn't exist
        final file = File(settingsFilePath);
        expect(await file.exists(), isFalse);

        await settingsService.init();

        // Should have default settings
        expect(settingsService.settings, isNotNull);
        expect(settingsService.settings.aiSettings.provider, 'qwen');
        expect(settingsService.settings.themeSettings.mode, ThemeMode.system);
        expect(settingsService.settings.version, 1);

        // File is NOT created during init (only when settings are updated)
        expect(await file.exists(), isFalse);
      });

      test('init() loads existing settings from file', () async {
        // Create settings file with custom values
        final customSettings = {
          'aiSettings': {
            'provider': 'zhipu',
            'apiKey': 'test-api-key',
            'model': 'glm-4',
            'baseUrl': 'https://open.bigmodel.cn/api/paas/v4',
          },
          'themeSettings': {
            'mode': 'dark',
          },
          'storageSettings': {
            'booksDirectory': '/custom/books',
            'backupDirectory': '/custom/backup',
            'autoBackupEnabled': true,
            'autoBackupInterval': 3,
            'lastBackupTime': '2024-01-15T10:30:00.000Z',
          },
          'languageSettings': {
            'aiOutputLanguage': 'en',
            'manualLanguage': 'zh',
          },
          'version': 2,
        };

        final file = File(settingsFilePath);
        await file.writeAsString(jsonEncode(customSettings));

        await settingsService.init();

        // Verify loaded settings
        expect(settingsService.settings.aiSettings.provider, 'zhipu');
        expect(settingsService.settings.aiSettings.apiKey, 'test-api-key');
        expect(settingsService.settings.aiSettings.model, 'glm-4');
        expect(settingsService.settings.themeSettings.mode, ThemeMode.dark);
        expect(settingsService.settings.storageSettings.booksDirectory,
            '/custom/books');
        expect(
            settingsService.settings.storageSettings.autoBackupEnabled, isTrue);
        expect(settingsService.settings.storageSettings.autoBackupInterval, 3);
        expect(
            settingsService.settings.languageSettings.aiOutputLanguage, 'en');
        expect(settingsService.settings.version, 2);
      });

      test('init() handles corrupted JSON gracefully', () async {
        // Create file with invalid JSON
        final file = File(settingsFilePath);
        await file.writeAsString('not valid json {[');

        // Should not throw
        await settingsService.init();

        // Should use default settings
        expect(settingsService.settings.aiSettings.provider, 'qwen');
        expect(settingsService.settings.themeSettings.mode, ThemeMode.system);
      });

      test('init() handles empty file gracefully', () async {
        // Create empty file
        final file = File(settingsFilePath);
        await file.writeAsString('');

        // Should not throw
        await settingsService.init();

        // Should use default settings
        expect(settingsService.settings.aiSettings.provider, 'qwen');
      });

      test('init() initializes ValueNotifiers with settings values', () async {
        await settingsService.init();

        // Verify notifiers are initialized
        expect(settingsService.themeMode.value, ThemeMode.system);
        expect(settingsService.aiSettings.value.provider, 'qwen');
        expect(settingsService.languageSettings.value.aiOutputLanguage, 'zh');
        expect(
            settingsService.storageSettings.value.autoBackupEnabled, isFalse);
      });
    });

    group('AI settings updates', () {
      test('updateAiSettings() saves and notifies', () async {
        await settingsService.init();

        final newAiSettings = AiSettings(
          provider: 'zhipu',
          apiKey: 'new-api-key',
          model: 'glm-4-flash',
          baseUrl: 'https://custom.url.com',
        );

        await settingsService.updateAiSettings(newAiSettings);

        // Verify in-memory settings
        expect(settingsService.settings.aiSettings.provider, 'zhipu');
        expect(settingsService.settings.aiSettings.apiKey, 'new-api-key');
        expect(settingsService.settings.aiSettings.model, 'glm-4-flash');

        // Verify notifier updated
        expect(settingsService.aiSettings.value.provider, 'zhipu');

        // Verify persistence
        final file = File(settingsFilePath);
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        expect(json['aiSettings']['provider'], 'zhipu');
        expect(json['aiSettings']['apiKey'], 'new-api-key');
      });

      test('updateAiSettings() preserves other settings', () async {
        await settingsService.init();
        await settingsService.setThemeMode(ThemeMode.dark);

        final originalThemeMode = settingsService.settings.themeSettings.mode;

        await settingsService.updateAiSettings(AiSettings(provider: 'zhipu'));

        // Theme should be preserved
        expect(settingsService.settings.themeSettings.mode, originalThemeMode);
      });
    });

    group('theme settings updates', () {
      test('updateThemeSettings() saves and notifies', () async {
        await settingsService.init();

        final newThemeSettings = ThemeSettings(mode: ThemeMode.dark);

        await settingsService.updateThemeSettings(newThemeSettings);

        // Verify in-memory settings
        expect(settingsService.settings.themeSettings.mode, ThemeMode.dark);

        // Verify notifier updated
        expect(settingsService.themeMode.value, ThemeMode.dark);

        // Verify persistence
        final file = File(settingsFilePath);
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        expect(json['themeSettings']['mode'], 'dark');
      });

      test('setThemeMode() is a convenience method for updating theme',
          () async {
        await settingsService.init();

        await settingsService.setThemeMode(ThemeMode.light);

        expect(settingsService.settings.themeSettings.mode, ThemeMode.light);
        expect(settingsService.themeMode.value, ThemeMode.light);

        await settingsService.setThemeMode(ThemeMode.dark);

        expect(settingsService.settings.themeSettings.mode, ThemeMode.dark);
        expect(settingsService.themeMode.value, ThemeMode.dark);
      });

      test('setThemeMode() to system mode', () async {
        await settingsService.init();

        await settingsService.setThemeMode(ThemeMode.system);

        expect(settingsService.settings.themeSettings.mode, ThemeMode.system);
      });
    });

    group('storage settings updates', () {
      test('updateStorageSettings() saves and notifies', () async {
        await settingsService.init();

        final newStorageSettings = StorageSettings(
          booksDirectory: '/custom/books/path',
          backupDirectory: '/custom/backup/path',
          autoBackupEnabled: true,
          autoBackupInterval: 14,
          lastBackupTime: DateTime(2024, 6, 15),
        );

        await settingsService.updateStorageSettings(newStorageSettings);

        // Verify in-memory settings
        expect(settingsService.settings.storageSettings.booksDirectory,
            '/custom/books/path');
        expect(settingsService.settings.storageSettings.backupDirectory,
            '/custom/backup/path');
        expect(
            settingsService.settings.storageSettings.autoBackupEnabled, isTrue);
        expect(settingsService.settings.storageSettings.autoBackupInterval, 14);

        // Verify notifier updated
        expect(settingsService.storageSettings.value.autoBackupEnabled, isTrue);

        // Verify persistence
        final file = File(settingsFilePath);
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        expect(json['storageSettings']['booksDirectory'], '/custom/books/path');
        expect(json['storageSettings']['autoBackupEnabled'], isTrue);
        expect(json['storageSettings']['autoBackupInterval'], 14);
      });

      test('updateStorageSettings() with null directories', () async {
        await settingsService.init();

        final newStorageSettings = StorageSettings(
          booksDirectory: null,
          backupDirectory: null,
          autoBackupEnabled: false,
        );

        await settingsService.updateStorageSettings(newStorageSettings);

        expect(settingsService.settings.storageSettings.booksDirectory, isNull);
        expect(
            settingsService.settings.storageSettings.backupDirectory, isNull);
      });
    });

    group('language settings updates', () {
      test('updateLanguageSettings() saves and notifies', () async {
        await settingsService.init();

        final newLanguageSettings = LanguageSettings(
          aiOutputLanguage: 'en',
        );

        await settingsService.updateLanguageSettings(newLanguageSettings);

        // Verify in-memory settings
        expect(
            settingsService.settings.languageSettings.aiOutputLanguage, 'en');

        // Verify notifier updated
        expect(settingsService.languageSettings.value.aiOutputLanguage, 'en');

        // Verify persistence
        final file = File(settingsFilePath);
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        expect(json['languageSettings']['aiOutputLanguage'], 'en');
      });

      test('updateLanguageSettings() with null manualLanguage', () async {
        await settingsService.init();

        final newLanguageSettings = LanguageSettings(
          aiOutputLanguage: 'auto',
        );

        await settingsService.updateLanguageSettings(newLanguageSettings);

        expect(
            settingsService.settings.languageSettings.aiOutputLanguage, 'auto');
      });
    });

    group('notifier tests', () {
      test('themeModeNotifier emits correct initial values', () async {
        await settingsService.init();

        expect(settingsService.themeMode.value, ThemeMode.system);
      });

      test('themeModeNotifier emits updates', () async {
        await settingsService.init();

        final values = <ThemeMode>[];
        settingsService.themeMode.addListener(() {
          values.add(settingsService.themeMode.value);
        });

        await settingsService.setThemeMode(ThemeMode.dark);
        await settingsService.setThemeMode(ThemeMode.light);

        expect(values, [ThemeMode.dark, ThemeMode.light]);
      });

      test('aiSettingsNotifier emits updates', () async {
        await settingsService.init();

        final values = <AiSettings>[];
        settingsService.aiSettings.addListener(() {
          values.add(settingsService.aiSettings.value);
        });

        await settingsService.updateAiSettings(AiSettings(provider: 'zhipu'));
        await settingsService
            .updateAiSettings(AiSettings(provider: 'qwen', model: 'qwen-max'));

        expect(values.length, 2);
        expect(values[0].provider, 'zhipu');
        expect(values[1].provider, 'qwen');
        expect(values[1].model, 'qwen-max');
      });

      test('languageSettingsNotifier emits updates', () async {
        await settingsService.init();

        final values = <LanguageSettings>[];
        settingsService.languageSettings.addListener(() {
          values.add(settingsService.languageSettings.value);
        });

        await settingsService
            .updateLanguageSettings(LanguageSettings(aiOutputLanguage: 'en'));
        await settingsService
            .updateLanguageSettings(LanguageSettings(aiOutputLanguage: 'auto'));

        expect(values.length, 2);
        expect(values[0].aiOutputLanguage, 'en');
        expect(values[1].aiOutputLanguage, 'auto');
      });

      test('storageSettingsNotifier emits updates', () async {
        await settingsService.init();

        final values = <StorageSettings>[];
        settingsService.storageSettings.addListener(() {
          values.add(settingsService.storageSettings.value);
        });

        await settingsService
            .updateStorageSettings(StorageSettings(autoBackupEnabled: true));
        await settingsService
            .updateStorageSettings(StorageSettings(autoBackupInterval: 30));

        expect(values.length, 2);
        expect(values[0].autoBackupEnabled, isTrue);
        expect(values[1].autoBackupInterval, 30);
      });
    });

    group('persistence', () {
      test('settings survive app restart (simulated)', () async {
        // First session: Initialize and modify settings
        await settingsService.init();
        await settingsService.updateAiSettings(AiSettings(
          provider: 'zhipu',
          apiKey: 'persistent-key',
          model: 'glm-4',
        ));
        await settingsService.setThemeMode(ThemeMode.dark);

        // Simulate app restart: reset and re-initialize
        // Note: After resetForTest(), the original settingsService's notifiers are disposed
        SettingsService.resetForTest();

        // Update settingsService reference to the new singleton instance
        settingsService = SettingsService();
        settingsService.setTestFilePath(settingsFilePath);
        await settingsService.init();

        // Verify settings persisted
        expect(settingsService.settings.aiSettings.provider, 'zhipu');
        expect(settingsService.settings.aiSettings.apiKey, 'persistent-key');
        expect(settingsService.settings.themeSettings.mode, ThemeMode.dark);
      });

      test('settings persist to file after update', () async {
        await settingsService.init();

        await settingsService
            .updateAiSettings(AiSettings(apiKey: 'file-test-key'));

        // Read file directly
        final file = File(settingsFilePath);
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        expect(json['aiSettings']['apiKey'], 'file-test-key');
      });

      test('multiple updates result in correct final state', () async {
        await settingsService.init();

        // Make multiple updates
        await settingsService.setThemeMode(ThemeMode.dark);
        await settingsService.setThemeMode(ThemeMode.light);
        await settingsService.setThemeMode(ThemeMode.system);

        await settingsService.updateAiSettings(AiSettings(provider: 'zhipu'));
        await settingsService.updateAiSettings(AiSettings(
          provider: 'zhipu',
          model: 'custom-model',
        ));

        // Verify final state
        expect(settingsService.settings.themeSettings.mode, ThemeMode.system);
        expect(settingsService.settings.aiSettings.provider, 'zhipu');
        expect(settingsService.settings.aiSettings.model, 'custom-model');

        // Verify file state
        final file = File(settingsFilePath);
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        expect(json['themeSettings']['mode'], 'system');
        expect(json['aiSettings']['provider'], 'zhipu');
        expect(json['aiSettings']['model'], 'custom-model');
      });
    });

    group('reset to defaults', () {
      test('resetToDefaults() resets all settings', () async {
        await settingsService.init();

        // Modify settings
        await settingsService
            .updateAiSettings(AiSettings(provider: 'zhipu', apiKey: 'key'));
        await settingsService.setThemeMode(ThemeMode.dark);
        await settingsService
            .updateLanguageSettings(LanguageSettings(aiOutputLanguage: 'en'));

        // Reset
        await settingsService.resetToDefaults();

        // Verify defaults restored
        expect(settingsService.settings.aiSettings.provider, 'qwen');
        expect(settingsService.settings.aiSettings.apiKey, '');
        expect(settingsService.settings.themeSettings.mode, ThemeMode.system);
        expect(
            settingsService.settings.languageSettings.aiOutputLanguage, 'zh');

        // Verify notifiers updated
        expect(settingsService.themeMode.value, ThemeMode.system);
        expect(settingsService.aiSettings.value.provider, 'qwen');
      });

      test('resetToDefaults() persists to file', () async {
        await settingsService.init();
        await settingsService.updateAiSettings(AiSettings(provider: 'zhipu'));
        await settingsService.resetToDefaults();

        final file = File(settingsFilePath);
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        expect(json['aiSettings']['provider'], 'qwen');
      });
    });

    group('import/export', () {
      test('exportToJson() returns valid JSON string', () async {
        await settingsService.init();
        await settingsService
            .updateAiSettings(AiSettings(apiKey: 'export-test'));

        final jsonString = settingsService.exportToJson();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;

        expect(json['aiSettings']['apiKey'], 'export-test');
        expect(json['version'], 1);
      });

      test('importFromJson() loads settings from JSON', () async {
        await settingsService.init();

        const jsonString = '''
        {
          "aiSettings": {
            "provider": "zhipu",
            "apiKey": "imported-key",
            "model": "glm-4",
            "baseUrl": "https://imported.url"
          },
          "themeSettings": {
            "mode": "dark"
          },
          "storageSettings": {
            "autoBackupEnabled": true
          },
          "languageSettings": {
            "aiOutputLanguage": "en"
          },
          "version": 3
        }
        ''';

        await settingsService.importFromJson(jsonString);

        expect(settingsService.settings.aiSettings.provider, 'zhipu');
        expect(settingsService.settings.aiSettings.apiKey, 'imported-key');
        expect(settingsService.settings.themeSettings.mode, ThemeMode.dark);
        expect(
            settingsService.settings.storageSettings.autoBackupEnabled, isTrue);
        expect(
            settingsService.settings.languageSettings.aiOutputLanguage, 'en');
      });

      test('importFromJson() throws on invalid JSON', () async {
        await settingsService.init();

        expect(
          () => settingsService.importFromJson('not valid json'),
          throwsA(isA<FormatException>()),
        );
      });

      test('importFromAiConfigJson() imports from legacy format', () async {
        await settingsService.init();

        final legacyConfig = {
          'ai_provider': 'zhipu',
          'zhipu': {
            'api_key': 'legacy-key',
            'model': 'glm-4-flash',
            'base_url': 'https://legacy.url',
          },
        };

        await settingsService.importFromAiConfigJson(legacyConfig);

        expect(settingsService.settings.aiSettings.provider, 'zhipu');
        expect(settingsService.settings.aiSettings.apiKey, 'legacy-key');
        expect(settingsService.settings.aiSettings.model, 'glm-4-flash');
        expect(
            settingsService.settings.aiSettings.baseUrl, 'https://legacy.url');
      });

      test('importFromAiConfigJson() defaults to qwen provider', () async {
        await settingsService.init();

        final legacyConfig = {
          'ai_provider': null,
        };

        await settingsService.importFromAiConfigJson(legacyConfig);

        expect(settingsService.settings.aiSettings.provider, 'qwen');
      });

      test('toAiConfigJson() exports to legacy format', () async {
        await settingsService.init();
        await settingsService.updateAiSettings(AiSettings(
          provider: 'zhipu',
          apiKey: 'export-key',
          model: 'glm-4',
          baseUrl: 'https://export.url',
        ));

        final config = settingsService.toAiConfigJson();

        expect(config['ai_provider'], 'zhipu');
        expect(config['zhipu']['api_key'], 'export-key');
        expect(config['zhipu']['model'], 'glm-4');
        expect(config['zhipu']['base_url'], 'https://export.url');
      });
    });

    group('AI configuration check', () {
      test('isAiConfigured returns false for default settings', () async {
        await settingsService.init();

        expect(settingsService.isAiConfigured, isFalse);
      });

      test('isAiConfigured returns true with valid API key', () async {
        await settingsService.init();
        await settingsService
            .updateAiSettings(AiSettings(apiKey: 'valid-key-123'));

        expect(settingsService.isAiConfigured, isTrue);
      });

      test('isAiConfigured returns false for placeholder API key', () async {
        await settingsService.init();
        await settingsService
            .updateAiSettings(AiSettings(apiKey: 'YOUR_API_KEY'));

        expect(settingsService.isAiConfigured, isFalse);
      });

      test('isAiConfigured returns false for zhipu placeholder', () async {
        await settingsService.init();
        await settingsService
            .updateAiSettings(AiSettings(apiKey: 'YOUR_ZHIPU_API_KEY_HERE'));

        expect(settingsService.isAiConfigured, isFalse);
      });

      test('isAiConfigured returns false for qwen placeholder', () async {
        await settingsService.init();
        await settingsService
            .updateAiSettings(AiSettings(apiKey: 'YOUR_QWEN_API_KEY_HERE'));

        expect(settingsService.isAiConfigured, isFalse);
      });
    });

    group('settings getters', () {
      test('settings returns current AppSettings', () async {
        await settingsService.init();

        final settings = settingsService.settings;

        expect(settings, isA<AppSettings>());
        expect(settings.aiSettings, isA<AiSettings>());
        expect(settings.themeSettings, isA<ThemeSettings>());
        expect(settings.storageSettings, isA<StorageSettings>());
        expect(settings.languageSettings, isA<LanguageSettings>());
      });

      test('settingsFilePath returns the file path', () async {
        await settingsService.init();

        expect(settingsService.settingsFilePath, settingsFilePath);
      });
    });

    group('dispose', () {
      test('dispose() cleans up ValueNotifiers', () async {
        await settingsService.init();

        // Should complete without error
        settingsService.dispose();

        // Notifiers should be disposed
        expect(settingsService.themeMode.hasListeners, isFalse);
      });

      test('dispose() can be called multiple times', () async {
        await settingsService.init();

        settingsService.dispose();
        settingsService.dispose();

        // Should not throw
      });
    });

    group('settings partial loading', () {
      test('init() handles partial JSON (missing some settings)', () async {
        // Create file with only AI settings
        final partialSettings = {
          'aiSettings': {
            'provider': 'zhipu',
            'apiKey': 'partial-key',
          },
          // Missing themeSettings, storageSettings, languageSettings
        };

        final file = File(settingsFilePath);
        await file.writeAsString(jsonEncode(partialSettings));

        await settingsService.init();

        // AI settings should be loaded
        expect(settingsService.settings.aiSettings.provider, 'zhipu');

        // Other settings should have defaults
        expect(settingsService.settings.themeSettings.mode, ThemeMode.system);
        expect(settingsService.settings.storageSettings.autoBackupEnabled,
            isFalse);
      });

      test('init() handles null values in JSON', () async {
        final settingsWithNulls = {
          'aiSettings': null,
          'themeSettings': null,
          'storageSettings': null,
          'languageSettings': null,
          'version': 1,
        };

        final file = File(settingsFilePath);
        await file.writeAsString(jsonEncode(settingsWithNulls));

        await settingsService.init();

        // Should use defaults
        expect(settingsService.settings.aiSettings.provider, 'qwen');
        expect(settingsService.settings.themeSettings.mode, ThemeMode.system);
      });
    });
  });
}
