/// 主题模式枚举，支持系统/浅色/深色三种模式
enum ThemeMode {
  system,
  light,
  dark;

  /// 从字符串解析主题模式，无法匹配时返回 [system]
  static ThemeMode fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// AI 服务配置，存储提供商、密钥、模型及接口地址
class AiSettings {
  /// AI 提供商标识，如 'qwen'、'zhipu'、'deepseek'、'ollama' 等
  final String provider;

  /// API 密钥，本地部署提供商可为空
  final String apiKey;

  /// 模型名称，如 'qwen-plus'、'glm-4' 等
  final String model;

  /// API 接口地址
  final String baseUrl;

  /// 是否需要 API Key（本地部署提供商不需要）
  bool get requiresApiKey {
    const localProviders = {'ollama', 'lmstudio'};
    return !localProviders.contains(provider);
  }

  AiSettings({
    this.provider = 'qwen',
    this.apiKey = '',
    this.model = 'qwen-plus',
    this.baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  });

  AiSettings copyWith({
    String? provider,
    String? apiKey,
    String? model,
    String? baseUrl,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'apiKey': apiKey,
      'model': model,
      'baseUrl': baseUrl,
    };
  }

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      provider: json['provider'] ?? 'qwen',
      apiKey: json['apiKey'] ?? '',
      model: json['model'] ?? 'qwen-plus',
      baseUrl: json['baseUrl'] ??
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
    );
  }

  /// 配置是否有效：云服务需要非空且非占位符的 API Key，本地服务需要非空 baseUrl
  bool get isValid {
    if (requiresApiKey) {
      return apiKey.isNotEmpty && !_isPlaceholderApiKey(apiKey);
    } else {
      return baseUrl.isNotEmpty;
    }
  }

  /// 判断是否为占位符 API Key（如 YOUR_KEY_HERE）
  bool _isPlaceholderApiKey(String key) {
    return key.startsWith('YOUR_') && key.endsWith('_HERE');
  }
}

/// 主题设置，存储主题模式偏好
class ThemeSettings {
  /// 主题模式
  final ThemeMode mode;

  ThemeSettings({
    this.mode = ThemeMode.system,
  });

  ThemeSettings copyWith({
    ThemeMode? mode,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
    };
  }

  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    return ThemeSettings(
      mode: ThemeMode.fromString(json['mode']),
    );
  }
}

/// 语言设置，配置 AI 输出语言和界面语言的偏好模式
class LanguageSettings {
  /// AI 输出语言模式：'book'（跟随书籍）、'system'（跟随系统）、'manual'（用户自选）
  final String aiLanguageMode;

  /// AI 输出语言，仅当 [aiLanguageMode] 为 'manual' 时生效，如 'zh'、'en'、'ja'
  final String aiOutputLanguage;

  /// 界面语言模式：'system'（跟随系统）、'manual'（用户自选）
  final String uiLanguageMode;

  /// 界面语言，仅当 [uiLanguageMode] 为 'manual' 时生效，如 'zh'、'en'、'ja'
  final String uiLanguage;

  LanguageSettings({
    this.aiLanguageMode = 'book',
    this.aiOutputLanguage = 'zh',
    this.uiLanguageMode = 'system',
    this.uiLanguage = 'zh',
  });

  LanguageSettings copyWith({
    String? aiLanguageMode,
    String? aiOutputLanguage,
    String? uiLanguageMode,
    String? uiLanguage,
  }) {
    return LanguageSettings(
      aiLanguageMode: aiLanguageMode ?? this.aiLanguageMode,
      aiOutputLanguage: aiOutputLanguage ?? this.aiOutputLanguage,
      uiLanguageMode: uiLanguageMode ?? this.uiLanguageMode,
      uiLanguage: uiLanguage ?? this.uiLanguage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageSettings &&
        other.aiLanguageMode == aiLanguageMode &&
        other.aiOutputLanguage == aiOutputLanguage &&
        other.uiLanguageMode == uiLanguageMode &&
        other.uiLanguage == uiLanguage;
  }

  @override
  int get hashCode {
    return Object.hash(
      aiLanguageMode,
      aiOutputLanguage,
      uiLanguageMode,
      uiLanguage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aiLanguageMode': aiLanguageMode,
      'aiOutputLanguage': aiOutputLanguage,
      'uiLanguageMode': uiLanguageMode,
      'uiLanguage': uiLanguage,
    };
  }

  factory LanguageSettings.fromJson(Map<String, dynamic> json) {
    return LanguageSettings(
      aiLanguageMode: json['aiLanguageMode'] ?? 'book',
      aiOutputLanguage: json['aiOutputLanguage'] ?? 'zh',
      uiLanguageMode: json['uiLanguageMode'] ?? 'system',
      uiLanguage: json['uiLanguage'] ?? 'zh',
    );
  }
}

/// 应用完整设置，聚合 AI、主题、语言三类配置，作为 SettingsService 的数据载体
class AppSettings {
  /// AI 设置
  final AiSettings aiSettings;

  /// 已保存的 AI 配置映射，key 为 provider，value 为对应完整配置
  final Map<String, AiSettings> savedAiConfigs;

  /// 主题设置
  final ThemeSettings themeSettings;

  /// 语言设置
  final LanguageSettings languageSettings;

  /// 设置版本号，用于未来数据迁移
  final int version;

  AppSettings({
    AiSettings? aiSettings,
    Map<String, AiSettings>? savedAiConfigs,
    ThemeSettings? themeSettings,
    LanguageSettings? languageSettings,
    this.version = 1,
  })  : aiSettings = aiSettings ?? AiSettings(),
        savedAiConfigs = savedAiConfigs ?? {},
        themeSettings = themeSettings ?? ThemeSettings(),
        languageSettings = languageSettings ?? LanguageSettings();

  AppSettings copyWith({
    AiSettings? aiSettings,
    Map<String, AiSettings>? savedAiConfigs,
    ThemeSettings? themeSettings,
    LanguageSettings? languageSettings,
    int? version,
  }) {
    return AppSettings(
      aiSettings: aiSettings ?? this.aiSettings,
      savedAiConfigs: savedAiConfigs ?? this.savedAiConfigs,
      themeSettings: themeSettings ?? this.themeSettings,
      languageSettings: languageSettings ?? this.languageSettings,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aiSettings': aiSettings.toJson(),
      'savedAiConfigs': savedAiConfigs.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'themeSettings': themeSettings.toJson(),
      'languageSettings': languageSettings.toJson(),
      'version': version,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    Map<String, AiSettings> savedAiConfigs = {};
    if (json['savedAiConfigs'] != null) {
      final configsMap = json['savedAiConfigs'] as Map<String, dynamic>;
      configsMap.forEach((key, value) {
        savedAiConfigs[key] =
            AiSettings.fromJson(value as Map<String, dynamic>);
      });
    }

    return AppSettings(
      aiSettings: json['aiSettings'] != null
          ? AiSettings.fromJson(json['aiSettings'])
          : null,
      savedAiConfigs: savedAiConfigs,
      themeSettings: json['themeSettings'] != null
          ? ThemeSettings.fromJson(json['themeSettings'])
          : null,
      languageSettings: json['languageSettings'] != null
          ? LanguageSettings.fromJson(json['languageSettings'])
          : null,
      version: json['version'] ?? 1,
    );
  }
}
