import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/models/app_settings.dart';

void main() {
  group('ThemeMode', () {
    test('should have system, light, and dark values', () {
      expect(ThemeMode.values.length, 3);
      expect(ThemeMode.values, contains(ThemeMode.system));
      expect(ThemeMode.values, contains(ThemeMode.light));
      expect(ThemeMode.values, contains(ThemeMode.dark));
    });

    test('should have correct name property', () {
      expect(ThemeMode.system.name, 'system');
      expect(ThemeMode.light.name, 'light');
      expect(ThemeMode.dark.name, 'dark');
    });

    group('fromString', () {
      test('should parse "light" to ThemeMode.light', () {
        expect(ThemeMode.fromString('light'), ThemeMode.light);
      });

      test('should parse "dark" to ThemeMode.dark', () {
        expect(ThemeMode.fromString('dark'), ThemeMode.dark);
      });

      test('should parse "system" to ThemeMode.system', () {
        expect(ThemeMode.fromString('system'), ThemeMode.system);
      });

      test('should return system for null value', () {
        expect(ThemeMode.fromString(null), ThemeMode.system);
      });

      test('should return system for unknown value', () {
        expect(ThemeMode.fromString('unknown'), ThemeMode.system);
        expect(ThemeMode.fromString(''), ThemeMode.system);
      });
    });
  });

  group('AiSettings', () {
    group('constructor', () {
      test('should create AiSettings with default values', () {
        final settings = AiSettings();

        expect(settings.provider, 'qwen');
        expect(settings.apiKey, '');
        expect(settings.model, 'qwen-plus');
        expect(settings.baseUrl,
            'https://dashscope.aliyuncs.com/compatible-mode/v1');
      });

      test('should create AiSettings with custom values', () {
        final settings = AiSettings(
          provider: 'zhipu',
          apiKey: 'test-api-key',
          model: 'glm-4',
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        );

        expect(settings.provider, 'zhipu');
        expect(settings.apiKey, 'test-api-key');
        expect(settings.model, 'glm-4');
        expect(settings.baseUrl, 'https://open.bigmodel.cn/api/paas/v4');
      });
    });

    group('isValid', () {
      test('should return false for empty apiKey', () {
        final settings = AiSettings(apiKey: '');
        expect(settings.isValid, false);
      });

      test('should return true for valid apiKey', () {
        final settings = AiSettings(apiKey: 'sk-test123456789');
        expect(settings.isValid, true);
      });

      test('should return false for YOUR_API_KEY placeholder', () {
        final settings = AiSettings(apiKey: 'YOUR_API_KEY');
        expect(settings.isValid, false);
      });

      test('should return false for YOUR_ZHIPU_API_KEY_HERE placeholder', () {
        final settings = AiSettings(apiKey: 'YOUR_ZHIPU_API_KEY_HERE');
        expect(settings.isValid, false);
      });

      test('should return false for YOUR_QWEN_API_KEY_HERE placeholder', () {
        final settings = AiSettings(apiKey: 'YOUR_QWEN_API_KEY_HERE');
        expect(settings.isValid, false);
      });

      test('should return true for apiKey with spaces', () {
        final settings = AiSettings(apiKey: '  sk-test123  ');
        expect(settings.isValid, true);
      });
    });

    group('copyWith', () {
      late AiSettings original;

      setUp(() {
        original = AiSettings(
          provider: 'qwen',
          apiKey: 'original-key',
          model: 'qwen-plus',
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        );
      });

      test('should create copy with no changes', () {
        final copy = original.copyWith();

        expect(copy.provider, original.provider);
        expect(copy.apiKey, original.apiKey);
        expect(copy.model, original.model);
        expect(copy.baseUrl, original.baseUrl);
      });

      test('should create copy with updated provider', () {
        final copy = original.copyWith(provider: 'zhipu');
        expect(copy.provider, 'zhipu');
        expect(copy.apiKey, original.apiKey);
        expect(copy.model, original.model);
        expect(copy.baseUrl, original.baseUrl);
      });

      test('should create copy with updated apiKey', () {
        final copy = original.copyWith(apiKey: 'new-key');
        expect(copy.provider, original.provider);
        expect(copy.apiKey, 'new-key');
        expect(copy.model, original.model);
        expect(copy.baseUrl, original.baseUrl);
      });

      test('should create copy with updated model', () {
        final copy = original.copyWith(model: 'qwen-max');
        expect(copy.provider, original.provider);
        expect(copy.apiKey, original.apiKey);
        expect(copy.model, 'qwen-max');
        expect(copy.baseUrl, original.baseUrl);
      });

      test('should create copy with updated baseUrl', () {
        final copy = original.copyWith(baseUrl: 'https://custom.api.com/v1');
        expect(copy.provider, original.provider);
        expect(copy.apiKey, original.apiKey);
        expect(copy.model, original.model);
        expect(copy.baseUrl, 'https://custom.api.com/v1');
      });

      test('should allow setting apiKey to empty string', () {
        final copy = original.copyWith(apiKey: '');
        expect(copy.apiKey, '');
        expect(copy.isValid, false);
      });
    });

    group('toJson', () {
      test('should serialize all fields correctly', () {
        final settings = AiSettings(
          provider: 'zhipu',
          apiKey: 'test-key',
          model: 'glm-4',
          baseUrl: 'https://custom.api.com',
        );

        final json = settings.toJson();

        expect(json['provider'], 'zhipu');
        expect(json['apiKey'], 'test-key');
        expect(json['model'], 'glm-4');
        expect(json['baseUrl'], 'https://custom.api.com');
      });

      test('should serialize default values correctly', () {
        final settings = AiSettings();

        final json = settings.toJson();

        expect(json['provider'], 'qwen');
        expect(json['apiKey'], '');
        expect(json['model'], 'qwen-plus');
        expect(json['baseUrl'],
            'https://dashscope.aliyuncs.com/compatible-mode/v1');
      });
    });

    group('fromJson', () {
      test('should deserialize all fields correctly', () {
        final json = {
          'provider': 'zhipu',
          'apiKey': 'test-key',
          'model': 'glm-4',
          'baseUrl': 'https://custom.api.com',
        };

        final settings = AiSettings.fromJson(json);

        expect(settings.provider, 'zhipu');
        expect(settings.apiKey, 'test-key');
        expect(settings.model, 'glm-4');
        expect(settings.baseUrl, 'https://custom.api.com');
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};

        final settings = AiSettings.fromJson(json);

        expect(settings.provider, 'qwen');
        expect(settings.apiKey, '');
        expect(settings.model, 'qwen-plus');
        expect(settings.baseUrl,
            'https://dashscope.aliyuncs.com/compatible-mode/v1');
      });

      test('should use defaults for null values', () {
        final json = {
          'provider': null,
          'apiKey': null,
          'model': null,
          'baseUrl': null,
        };

        final settings = AiSettings.fromJson(json);

        expect(settings.provider, 'qwen');
        expect(settings.apiKey, '');
        expect(settings.model, 'qwen-plus');
        expect(settings.baseUrl,
            'https://dashscope.aliyuncs.com/compatible-mode/v1');
      });

      test('should handle partial json with some missing fields', () {
        final json = {
          'provider': 'zhipu',
          'apiKey': 'partial-key',
        };

        final settings = AiSettings.fromJson(json);

        expect(settings.provider, 'zhipu');
        expect(settings.apiKey, 'partial-key');
        expect(settings.model, 'qwen-plus');
        expect(settings.baseUrl,
            'https://dashscope.aliyuncs.com/compatible-mode/v1');
      });
    });

    group('toJson and fromJson round trip', () {
      test('should maintain data integrity through serialization cycle', () {
        final original = AiSettings(
          provider: 'zhipu',
          apiKey: 'test-key',
          model: 'glm-4',
          baseUrl: 'https://custom.api.com',
        );

        final json = original.toJson();
        final restored = AiSettings.fromJson(json);

        expect(restored.provider, original.provider);
        expect(restored.apiKey, original.apiKey);
        expect(restored.model, original.model);
        expect(restored.baseUrl, original.baseUrl);
        expect(restored.isValid, original.isValid);
      });
    });
  });

  group('ThemeSettings', () {
    group('constructor', () {
      test('should create ThemeSettings with default mode', () {
        final settings = ThemeSettings();
        expect(settings.mode, ThemeMode.system);
      });

      test('should create ThemeSettings with custom mode', () {
        final settings = ThemeSettings(mode: ThemeMode.dark);
        expect(settings.mode, ThemeMode.dark);
      });
    });

    group('copyWith', () {
      late ThemeSettings original;

      setUp(() {
        original = ThemeSettings(mode: ThemeMode.light);
      });

      test('should create copy with no changes', () {
        final copy = original.copyWith();
        expect(copy.mode, original.mode);
      });

      test('should create copy with updated mode', () {
        final copy = original.copyWith(mode: ThemeMode.dark);
        expect(copy.mode, ThemeMode.dark);
      });

      test('should keep original mode when not specified', () {
        final copy = original.copyWith();
        expect(copy.mode, ThemeMode.light);
      });
    });

    group('toJson', () {
      test('should serialize mode as string name', () {
        final settings = ThemeSettings(mode: ThemeMode.dark);
        final json = settings.toJson();
        expect(json['mode'], 'dark');
      });

      test('should serialize system mode correctly', () {
        final settings = ThemeSettings(mode: ThemeMode.system);
        final json = settings.toJson();
        expect(json['mode'], 'system');
      });
    });

    group('fromJson', () {
      test('should deserialize from string name', () {
        final json = {'mode': 'dark'};
        final settings = ThemeSettings.fromJson(json);
        expect(settings.mode, ThemeMode.dark);
      });

      test('should default to system for missing mode', () {
        final json = <String, dynamic>{};
        final settings = ThemeSettings.fromJson(json);
        expect(settings.mode, ThemeMode.system);
      });

      test('should default to system for null mode', () {
        final json = {'mode': null};
        final settings = ThemeSettings.fromJson(json);
        expect(settings.mode, ThemeMode.system);
      });

      test('should default to system for unknown mode string', () {
        final json = {'mode': 'unknown'};
        final settings = ThemeSettings.fromJson(json);
        expect(settings.mode, ThemeMode.system);
      });
    });

    group('toJson and fromJson round trip', () {
      test('should maintain data integrity through serialization cycle', () {
        final original = ThemeSettings(mode: ThemeMode.dark);
        final json = original.toJson();
        final restored = ThemeSettings.fromJson(json);
        expect(restored.mode, original.mode);
      });
    });
  });

  group('StorageSettings', () {
    late DateTime testDateTime;

    setUp(() {
      testDateTime = DateTime(2024, 6, 15, 10, 30, 0);
    });

    group('constructor', () {
      test('should create StorageSettings with default values', () {
        final settings = StorageSettings();

        expect(settings.booksDirectory, isNull);
        expect(settings.backupDirectory, isNull);
        expect(settings.autoBackupEnabled, false);
        expect(settings.autoBackupInterval, 7);
        expect(settings.lastBackupTime, isNull);
      });

      test('should create StorageSettings with custom values', () {
        final settings = StorageSettings(
          booksDirectory: '/custom/books',
          backupDirectory: '/custom/backup',
          autoBackupEnabled: true,
          autoBackupInterval: 3,
          lastBackupTime: testDateTime,
        );

        expect(settings.booksDirectory, '/custom/books');
        expect(settings.backupDirectory, '/custom/backup');
        expect(settings.autoBackupEnabled, true);
        expect(settings.autoBackupInterval, 3);
        expect(settings.lastBackupTime, testDateTime);
      });
    });

    group('copyWith', () {
      late StorageSettings original;

      setUp(() {
        original = StorageSettings(
          booksDirectory: '/original/books',
          backupDirectory: '/original/backup',
          autoBackupEnabled: false,
          autoBackupInterval: 7,
          lastBackupTime: null,
        );
      });

      test('should create copy with no changes', () {
        final copy = original.copyWith();

        expect(copy.booksDirectory, original.booksDirectory);
        expect(copy.backupDirectory, original.backupDirectory);
        expect(copy.autoBackupEnabled, original.autoBackupEnabled);
        expect(copy.autoBackupInterval, original.autoBackupInterval);
        expect(copy.lastBackupTime, original.lastBackupTime);
      });

      test('should create copy with updated booksDirectory', () {
        final copy = original.copyWith(booksDirectory: '/new/books');
        expect(copy.booksDirectory, '/new/books');
        expect(copy.backupDirectory, original.backupDirectory);
      });

      test('should create copy with updated backupDirectory', () {
        final copy = original.copyWith(backupDirectory: '/new/backup');
        expect(copy.backupDirectory, '/new/backup');
        expect(copy.booksDirectory, original.booksDirectory);
      });

      test('should create copy with updated autoBackupEnabled', () {
        final copy = original.copyWith(autoBackupEnabled: true);
        expect(copy.autoBackupEnabled, true);
        expect(copy.autoBackupInterval, original.autoBackupInterval);
      });

      test('should create copy with updated autoBackupInterval', () {
        final copy = original.copyWith(autoBackupInterval: 1);
        expect(copy.autoBackupInterval, 1);
      });

      test('should create copy with updated lastBackupTime', () {
        final newTime = DateTime(2024, 7, 1);
        final copy = original.copyWith(lastBackupTime: newTime);
        expect(copy.lastBackupTime, newTime);
      });

      test('should keep original lastBackupTime when null passed to copyWith',
          () {
        // Note: copyWith uses ?? operator, so null means "keep original"
        final settingsWithTime = StorageSettings(lastBackupTime: testDateTime);
        final copy = settingsWithTime.copyWith(lastBackupTime: null);
        expect(copy.lastBackupTime, testDateTime);
      });
    });

    group('toJson', () {
      test('should serialize all fields correctly', () {
        final settings = StorageSettings(
          booksDirectory: '/books',
          backupDirectory: '/backup',
          autoBackupEnabled: true,
          autoBackupInterval: 3,
          lastBackupTime: testDateTime,
        );

        final json = settings.toJson();

        expect(json['booksDirectory'], '/books');
        expect(json['backupDirectory'], '/backup');
        expect(json['autoBackupEnabled'], true);
        expect(json['autoBackupInterval'], 3);
        expect(json['lastBackupTime'], testDateTime.toIso8601String());
      });

      test('should serialize null fields correctly', () {
        final settings = StorageSettings();

        final json = settings.toJson();

        expect(json['booksDirectory'], isNull);
        expect(json['backupDirectory'], isNull);
        expect(json['autoBackupEnabled'], false);
        expect(json['autoBackupInterval'], 7);
        expect(json['lastBackupTime'], isNull);
      });
    });

    group('fromJson', () {
      test('should deserialize all fields correctly', () {
        final json = {
          'booksDirectory': '/books',
          'backupDirectory': '/backup',
          'autoBackupEnabled': true,
          'autoBackupInterval': 3,
          'lastBackupTime': testDateTime.toIso8601String(),
        };

        final settings = StorageSettings.fromJson(json);

        expect(settings.booksDirectory, '/books');
        expect(settings.backupDirectory, '/backup');
        expect(settings.autoBackupEnabled, true);
        expect(settings.autoBackupInterval, 3);
        expect(settings.lastBackupTime, testDateTime);
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};

        final settings = StorageSettings.fromJson(json);

        expect(settings.booksDirectory, isNull);
        expect(settings.backupDirectory, isNull);
        expect(settings.autoBackupEnabled, false);
        expect(settings.autoBackupInterval, 7);
        expect(settings.lastBackupTime, isNull);
      });

      test('should use defaults for null values', () {
        final json = {
          'booksDirectory': null,
          'backupDirectory': null,
          'autoBackupEnabled': null,
          'autoBackupInterval': null,
          'lastBackupTime': null,
        };

        final settings = StorageSettings.fromJson(json);

        expect(settings.booksDirectory, isNull);
        expect(settings.backupDirectory, isNull);
        expect(settings.autoBackupEnabled, false);
        expect(settings.autoBackupInterval, 7);
        expect(settings.lastBackupTime, isNull);
      });

      test('should handle partial json', () {
        final json = {
          'booksDirectory': '/custom/books',
          'autoBackupEnabled': true,
        };

        final settings = StorageSettings.fromJson(json);

        expect(settings.booksDirectory, '/custom/books');
        expect(settings.backupDirectory, isNull);
        expect(settings.autoBackupEnabled, true);
        expect(settings.autoBackupInterval, 7);
        expect(settings.lastBackupTime, isNull);
      });
    });

    group('toJson and fromJson round trip', () {
      test('should maintain data integrity through serialization cycle', () {
        final original = StorageSettings(
          booksDirectory: '/books',
          backupDirectory: '/backup',
          autoBackupEnabled: true,
          autoBackupInterval: 3,
          lastBackupTime: testDateTime,
        );

        final json = original.toJson();
        final restored = StorageSettings.fromJson(json);

        expect(restored.booksDirectory, original.booksDirectory);
        expect(restored.backupDirectory, original.backupDirectory);
        expect(restored.autoBackupEnabled, original.autoBackupEnabled);
        expect(restored.autoBackupInterval, original.autoBackupInterval);
        expect(restored.lastBackupTime, original.lastBackupTime);
      });

      test('should handle null lastBackupTime in round trip', () {
        final original = StorageSettings();

        final json = original.toJson();
        final restored = StorageSettings.fromJson(json);

        expect(restored.lastBackupTime, isNull);
      });
    });
  });

  group('LanguageSettings', () {
    group('constructor', () {
      test('should create LanguageSettings with default values', () {
        final settings = LanguageSettings();

        expect(settings.aiOutputLanguage, 'zh');
        expect(settings.manualLanguage, isNull);
      });

      test('should create LanguageSettings with custom values', () {
        final settings = LanguageSettings(
          aiOutputLanguage: 'en',
          manualLanguage: 'zh',
        );

        expect(settings.aiOutputLanguage, 'en');
        expect(settings.manualLanguage, 'zh');
      });
    });

    group('copyWith', () {
      late LanguageSettings original;

      setUp(() {
        original = LanguageSettings(
          aiOutputLanguage: 'zh',
          manualLanguage: null,
        );
      });

      test('should create copy with no changes', () {
        final copy = original.copyWith();

        expect(copy.aiOutputLanguage, original.aiOutputLanguage);
        expect(copy.manualLanguage, original.manualLanguage);
      });

      test('should create copy with updated aiOutputLanguage', () {
        final copy = original.copyWith(aiOutputLanguage: 'en');
        expect(copy.aiOutputLanguage, 'en');
        expect(copy.manualLanguage, original.manualLanguage);
      });

      test('should create copy with updated manualLanguage', () {
        final copy = original.copyWith(manualLanguage: 'en');
        expect(copy.manualLanguage, 'en');
        expect(copy.aiOutputLanguage, original.aiOutputLanguage);
      });

      test('should keep original manualLanguage when null passed to copyWith',
          () {
        // Note: copyWith uses ?? operator, so null means "keep original"
        final settingsWithLanguage = LanguageSettings(manualLanguage: 'zh');
        final copy = settingsWithLanguage.copyWith(manualLanguage: null);
        expect(copy.manualLanguage, 'zh');
      });
    });

    group('toJson', () {
      test('should serialize all fields correctly', () {
        final settings = LanguageSettings(
          aiOutputLanguage: 'en',
          manualLanguage: 'zh',
        );

        final json = settings.toJson();

        expect(json['aiOutputLanguage'], 'en');
        expect(json['manualLanguage'], 'zh');
      });

      test('should serialize null manualLanguage correctly', () {
        final settings = LanguageSettings();

        final json = settings.toJson();

        expect(json['aiOutputLanguage'], 'zh');
        expect(json['manualLanguage'], isNull);
      });
    });

    group('fromJson', () {
      test('should deserialize all fields correctly', () {
        final json = {
          'aiOutputLanguage': 'en',
          'manualLanguage': 'zh',
        };

        final settings = LanguageSettings.fromJson(json);

        expect(settings.aiOutputLanguage, 'en');
        expect(settings.manualLanguage, 'zh');
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};

        final settings = LanguageSettings.fromJson(json);

        expect(settings.aiOutputLanguage, 'zh');
        expect(settings.manualLanguage, isNull);
      });

      test('should use defaults for null values', () {
        final json = {
          'aiOutputLanguage': null,
          'manualLanguage': null,
        };

        final settings = LanguageSettings.fromJson(json);

        expect(settings.aiOutputLanguage, 'zh');
        expect(settings.manualLanguage, isNull);
      });

      test('should handle partial json', () {
        final json = {
          'aiOutputLanguage': 'en',
        };

        final settings = LanguageSettings.fromJson(json);

        expect(settings.aiOutputLanguage, 'en');
        expect(settings.manualLanguage, isNull);
      });
    });

    group('toJson and fromJson round trip', () {
      test('should maintain data integrity through serialization cycle', () {
        final original = LanguageSettings(
          aiOutputLanguage: 'en',
          manualLanguage: 'zh',
        );

        final json = original.toJson();
        final restored = LanguageSettings.fromJson(json);

        expect(restored.aiOutputLanguage, original.aiOutputLanguage);
        expect(restored.manualLanguage, original.manualLanguage);
      });

      test('should handle null manualLanguage in round trip', () {
        final original = LanguageSettings();

        final json = original.toJson();
        final restored = LanguageSettings.fromJson(json);

        expect(restored.manualLanguage, isNull);
      });
    });
  });

  group('AppSettings', () {
    late DateTime testDateTime;

    setUp(() {
      testDateTime = DateTime(2024, 6, 15, 10, 30, 0);
    });

    group('constructor', () {
      test('should create AppSettings with default values', () {
        final settings = AppSettings();

        expect(settings.aiSettings, isA<AiSettings>());
        expect(settings.themeSettings, isA<ThemeSettings>());
        expect(settings.storageSettings, isA<StorageSettings>());
        expect(settings.languageSettings, isA<LanguageSettings>());
        expect(settings.version, 1);
      });

      test('should create AppSettings with custom nested settings', () {
        final aiSettings = AiSettings(provider: 'zhipu', apiKey: 'test-key');
        final themeSettings = ThemeSettings(mode: ThemeMode.dark);
        final storageSettings = StorageSettings(autoBackupEnabled: true);
        final languageSettings = LanguageSettings(aiOutputLanguage: 'en');

        final settings = AppSettings(
          aiSettings: aiSettings,
          themeSettings: themeSettings,
          storageSettings: storageSettings,
          languageSettings: languageSettings,
          version: 2,
        );

        expect(settings.aiSettings.provider, 'zhipu');
        expect(settings.themeSettings.mode, ThemeMode.dark);
        expect(settings.storageSettings.autoBackupEnabled, true);
        expect(settings.languageSettings.aiOutputLanguage, 'en');
        expect(settings.version, 2);
      });

      test('should create default nested settings when null passed', () {
        final settings = AppSettings(
          aiSettings: null,
          themeSettings: null,
          storageSettings: null,
          languageSettings: null,
        );

        expect(settings.aiSettings, isA<AiSettings>());
        expect(settings.themeSettings, isA<ThemeSettings>());
        expect(settings.storageSettings, isA<StorageSettings>());
        expect(settings.languageSettings, isA<LanguageSettings>());
      });
    });

    group('copyWith', () {
      late AppSettings original;

      setUp(() {
        original = AppSettings(
          aiSettings: AiSettings(provider: 'qwen'),
          themeSettings: ThemeSettings(mode: ThemeMode.light),
          storageSettings: StorageSettings(autoBackupEnabled: false),
          languageSettings: LanguageSettings(aiOutputLanguage: 'zh'),
          version: 1,
        );
      });

      test('should create copy with no changes', () {
        final copy = original.copyWith();

        expect(copy.aiSettings.provider, original.aiSettings.provider);
        expect(copy.themeSettings.mode, original.themeSettings.mode);
        expect(copy.storageSettings.autoBackupEnabled,
            original.storageSettings.autoBackupEnabled);
        expect(copy.languageSettings.aiOutputLanguage,
            original.languageSettings.aiOutputLanguage);
        expect(copy.version, original.version);
      });

      test('should create copy with updated aiSettings', () {
        final newAiSettings = AiSettings(provider: 'zhipu');
        final copy = original.copyWith(aiSettings: newAiSettings);

        expect(copy.aiSettings.provider, 'zhipu');
        expect(copy.themeSettings.mode, original.themeSettings.mode);
      });

      test('should create copy with updated themeSettings', () {
        final newThemeSettings = ThemeSettings(mode: ThemeMode.dark);
        final copy = original.copyWith(themeSettings: newThemeSettings);

        expect(copy.themeSettings.mode, ThemeMode.dark);
        expect(copy.aiSettings.provider, original.aiSettings.provider);
      });

      test('should create copy with updated storageSettings', () {
        final newStorageSettings = StorageSettings(autoBackupEnabled: true);
        final copy = original.copyWith(storageSettings: newStorageSettings);

        expect(copy.storageSettings.autoBackupEnabled, true);
      });

      test('should create copy with updated languageSettings', () {
        final newLanguageSettings = LanguageSettings(aiOutputLanguage: 'en');
        final copy = original.copyWith(languageSettings: newLanguageSettings);

        expect(copy.languageSettings.aiOutputLanguage, 'en');
      });

      test('should create copy with updated version', () {
        final copy = original.copyWith(version: 2);
        expect(copy.version, 2);
      });
    });

    group('toJson', () {
      test('should serialize all nested settings correctly', () {
        final settings = AppSettings(
          aiSettings: AiSettings(provider: 'zhipu', apiKey: 'test-key'),
          themeSettings: ThemeSettings(mode: ThemeMode.dark),
          storageSettings: StorageSettings(
            autoBackupEnabled: true,
            lastBackupTime: testDateTime,
          ),
          languageSettings:
              LanguageSettings(aiOutputLanguage: 'en', manualLanguage: 'zh'),
          version: 2,
        );

        final json = settings.toJson();

        expect(json['aiSettings'], isA<Map<String, dynamic>>());
        expect(json['aiSettings']['provider'], 'zhipu');
        expect(json['aiSettings']['apiKey'], 'test-key');

        expect(json['themeSettings'], isA<Map<String, dynamic>>());
        expect(json['themeSettings']['mode'], 'dark');

        expect(json['storageSettings'], isA<Map<String, dynamic>>());
        expect(json['storageSettings']['autoBackupEnabled'], true);
        expect(json['storageSettings']['lastBackupTime'],
            testDateTime.toIso8601String());

        expect(json['languageSettings'], isA<Map<String, dynamic>>());
        expect(json['languageSettings']['aiOutputLanguage'], 'en');
        expect(json['languageSettings']['manualLanguage'], 'zh');

        expect(json['version'], 2);
      });

      test('should serialize default settings correctly', () {
        final settings = AppSettings();

        final json = settings.toJson();

        expect(json['aiSettings']['provider'], 'qwen');
        expect(json['themeSettings']['mode'], 'system');
        expect(json['storageSettings']['autoBackupEnabled'], false);
        expect(json['languageSettings']['aiOutputLanguage'], 'zh');
        expect(json['version'], 1);
      });
    });

    group('fromJson', () {
      test('should deserialize all nested settings correctly', () {
        final json = {
          'aiSettings': {
            'provider': 'zhipu',
            'apiKey': 'test-key',
            'model': 'glm-4',
            'baseUrl': 'https://custom.api.com',
          },
          'themeSettings': {
            'mode': 'dark',
          },
          'storageSettings': {
            'booksDirectory': '/books',
            'autoBackupEnabled': true,
            'autoBackupInterval': 3,
            'lastBackupTime': testDateTime.toIso8601String(),
          },
          'languageSettings': {
            'aiOutputLanguage': 'en',
            'manualLanguage': 'zh',
          },
          'version': 2,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.aiSettings.provider, 'zhipu');
        expect(settings.aiSettings.apiKey, 'test-key');
        expect(settings.themeSettings.mode, ThemeMode.dark);
        expect(settings.storageSettings.autoBackupEnabled, true);
        expect(settings.storageSettings.autoBackupInterval, 3);
        expect(settings.languageSettings.aiOutputLanguage, 'en');
        expect(settings.languageSettings.manualLanguage, 'zh');
        expect(settings.version, 2);
      });

      test('should create default nested settings when fields are null', () {
        final json = {
          'aiSettings': null,
          'themeSettings': null,
          'storageSettings': null,
          'languageSettings': null,
          'version': 1,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.aiSettings, isA<AiSettings>());
        expect(settings.themeSettings, isA<ThemeSettings>());
        expect(settings.storageSettings, isA<StorageSettings>());
        expect(settings.languageSettings, isA<LanguageSettings>());
        expect(settings.aiSettings.provider, 'qwen');
        expect(settings.themeSettings.mode, ThemeMode.system);
      });

      test('should create default nested settings when fields are missing', () {
        final json = <String, dynamic>{};

        final settings = AppSettings.fromJson(json);

        expect(settings.aiSettings, isA<AiSettings>());
        expect(settings.themeSettings, isA<ThemeSettings>());
        expect(settings.storageSettings, isA<StorageSettings>());
        expect(settings.languageSettings, isA<LanguageSettings>());
        expect(settings.version, 1);
      });

      test('should handle partial json with some missing nested settings', () {
        final json = {
          'aiSettings': {
            'provider': 'zhipu',
            'apiKey': 'partial-key',
          },
          'version': 3,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.aiSettings.provider, 'zhipu');
        expect(settings.aiSettings.apiKey, 'partial-key');
        expect(settings.themeSettings.mode, ThemeMode.system);
        expect(settings.storageSettings.autoBackupEnabled, false);
        expect(settings.languageSettings.aiOutputLanguage, 'zh');
        expect(settings.version, 3);
      });
    });

    group('toJson and fromJson round trip', () {
      test('should maintain data integrity through serialization cycle', () {
        final original = AppSettings(
          aiSettings: AiSettings(provider: 'zhipu', apiKey: 'test-key'),
          themeSettings: ThemeSettings(mode: ThemeMode.dark),
          storageSettings: StorageSettings(
            autoBackupEnabled: true,
            lastBackupTime: testDateTime,
          ),
          languageSettings: LanguageSettings(aiOutputLanguage: 'en'),
          version: 2,
        );

        final json = original.toJson();
        final restored = AppSettings.fromJson(json);

        expect(restored.aiSettings.provider, original.aiSettings.provider);
        expect(restored.aiSettings.apiKey, original.aiSettings.apiKey);
        expect(restored.themeSettings.mode, original.themeSettings.mode);
        expect(restored.storageSettings.autoBackupEnabled,
            original.storageSettings.autoBackupEnabled);
        expect(restored.storageSettings.lastBackupTime,
            original.storageSettings.lastBackupTime);
        expect(restored.languageSettings.aiOutputLanguage,
            original.languageSettings.aiOutputLanguage);
        expect(restored.version, original.version);
      });

      test('should handle null values in round trip', () {
        final original = AppSettings();

        final json = original.toJson();
        final restored = AppSettings.fromJson(json);

        expect(restored.storageSettings.lastBackupTime, isNull);
        expect(restored.languageSettings.manualLanguage, isNull);
      });
    });

    group('nested settings access', () {
      test('should access aiSettings.isValid correctly', () {
        final settingsWithValidKey = AppSettings(
          aiSettings: AiSettings(apiKey: 'valid-key'),
        );
        expect(settingsWithValidKey.aiSettings.isValid, true);

        final settingsWithInvalidKey = AppSettings(
          aiSettings: AiSettings(apiKey: 'YOUR_API_KEY'),
        );
        expect(settingsWithInvalidKey.aiSettings.isValid, false);
      });

      test('should access themeSettings.mode correctly', () {
        final settings = AppSettings(
          themeSettings: ThemeSettings(mode: ThemeMode.dark),
        );
        expect(settings.themeSettings.mode, ThemeMode.dark);
        expect(settings.themeSettings.mode.name, 'dark');
      });

      test('should access storageSettings auto backup properties', () {
        final settings = AppSettings(
          storageSettings: StorageSettings(
            autoBackupEnabled: true,
            autoBackupInterval: 5,
          ),
        );
        expect(settings.storageSettings.autoBackupEnabled, true);
        expect(settings.storageSettings.autoBackupInterval, 5);
      });

      test('should access languageSettings properties', () {
        final settings = AppSettings(
          languageSettings: LanguageSettings(
            aiOutputLanguage: 'en',
            manualLanguage: 'zh',
          ),
        );
        expect(settings.languageSettings.aiOutputLanguage, 'en');
        expect(settings.languageSettings.manualLanguage, 'zh');
      });
    });
  });
}
