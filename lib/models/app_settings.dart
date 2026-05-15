/// ============================================================================
/// 文件名：app_settings.dart
/// 功能：应用设置数据模型定义
/// ============================================================================

/// 枚举：主题模式
///
/// 定义应用支持的三种主题模式：
/// - [system]: 跟随系统设置
/// - [light]: 强制使用浅色主题
/// - [dark]: 强制使用深色主题
enum ThemeMode {
  system,
  light,
  dark;

  /// 从字符串解析主题模式
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

/// 类名：AiSettings
/// 功能：AI服务设置数据模型
///
/// 主要用途：
/// - 存储AI服务提供商配置（智谱/通义千问等）
/// - 管理API Key、模型、Base URL等参数
/// - 提供配置有效性验证
class AiSettings {
  /// AI服务提供商标识
  /// 有效值：'zhipu'（智谱）、'qwen'（通义千问）或 'ollama'（本地Ollama）
  final String provider;

  /// API密钥
  final String apiKey;

  /// 使用的模型名称
  final String model;

  /// API基础URL
  final String baseUrl;

  /// 该提供商是否需要 API Key
  /// 用于 isValid 验证逻辑
  bool get requiresApiKey {
    const localProviders = {'ollama', 'lmstudio'};
    return !localProviders.contains(provider);
  }

  /// 构造函数
  AiSettings({
    this.provider = 'qwen',
    this.apiKey = '',
    this.model = 'qwen-plus',
    this.baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  });

  /// 创建副本，可选择性地修改部分字段
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

  /// 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'apiKey': apiKey,
      'model': model,
      'baseUrl': baseUrl,
    };
  }

  /// 从JSON反序列化
  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      provider: json['provider'] ?? 'qwen',
      apiKey: json['apiKey'] ?? '',
      model: json['model'] ?? 'qwen-plus',
      baseUrl: json['baseUrl'] ??
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
    );
  }

  /// 检查配置是否有效
  ///
  /// 验证规则：
  /// - 需要 API Key 的提供商：apiKey 不能为空且不能为占位符字符串
  /// - 不需要 API Key 的提供商（如 Ollama）：baseUrl 不能为空
  bool get isValid {
    if (requiresApiKey) {
      return apiKey.isNotEmpty && !_isPlaceholderApiKey(apiKey);
    } else {
      return baseUrl.isNotEmpty;
    }
  }

  /// 检查 API Key 是否为占位符字符串
  bool _isPlaceholderApiKey(String key) {
    return key.startsWith('YOUR_') && key.endsWith('_HERE');
  }
}

/// 类名：ThemeSettings
/// 功能：主题设置数据模型
///
/// 主要用途：
/// - 存储主题模式偏好（系统/浅色/深色）
class ThemeSettings {
  /// 主题模式
  final ThemeMode mode;

  /// 构造函数
  ThemeSettings({
    this.mode = ThemeMode.system,
  });

  /// 创建副本
  ThemeSettings copyWith({
    ThemeMode? mode,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
    );
  }

  /// 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
    };
  }

  /// 从JSON反序列化
  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    return ThemeSettings(
      mode: ThemeMode.fromString(json['mode']),
    );
  }
}

/// 类名：LanguageSettings
/// 功能：语言设置数据模型
///
/// 主要用途：
/// - 配置 AI 输出语言偏好（跟随书籍/跟随系统/用户自选）
/// - 配置界面语言偏好（跟随系统/用户自选）
class LanguageSettings {
  /// AI 输出语言模式
  /// 可选值：'book'（跟随书籍）、'system'（跟随系统）、'manual'（用户自选）
  final String aiLanguageMode;

  /// AI 输出语言（当 aiLanguageMode 为'manual'时使用）
  /// 可选值：'zh'（中文）、'en'（英文）、'ja'（日文）等
  final String aiOutputLanguage;

  /// 界面语言模式
  /// 可选值：'system'（跟随系统）、'manual'（用户自选）
  final String uiLanguageMode;

  /// 界面语言（当 uiLanguageMode 为'manual'时使用）
  /// 可选值：'zh'（中文）、'en'（英文）、'ja'（日文）等
  final String uiLanguage;

  /// 构造函数
  LanguageSettings({
    this.aiLanguageMode = 'book',
    this.aiOutputLanguage = 'zh',
    this.uiLanguageMode = 'system',
    this.uiLanguage = 'zh',
  });

  /// 创建副本
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

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'aiLanguageMode': aiLanguageMode,
      'aiOutputLanguage': aiOutputLanguage,
      'uiLanguageMode': uiLanguageMode,
      'uiLanguage': uiLanguage,
    };
  }

  /// 从 JSON 反序列化
  factory LanguageSettings.fromJson(Map<String, dynamic> json) {
    return LanguageSettings(
      aiLanguageMode: json['aiLanguageMode'] ?? 'book',
      aiOutputLanguage: json['aiOutputLanguage'] ?? 'zh',
      uiLanguageMode: json['uiLanguageMode'] ?? 'system',
      uiLanguage: json['uiLanguage'] ?? 'zh',
    );
  }
}

/// 类名：AppSettings
/// 功能：应用完整设置数据模型
///
/// 主要用途：
/// - 聚合所有设置类别（AI、主题、语言）
/// - 提供统一的序列化/反序列化接口
/// - 作为SettingsService的数据载体
class AppSettings {
  /// AI设置
  final AiSettings aiSettings;

  /// 已保存的AI配置列表
  /// 用于保存用户曾经配置过的所有AI提供商配置，方便下次直接使用
  /// key 为 provider，value 为该提供商的完整AiSettings配置
  final Map<String, AiSettings> savedAiConfigs;

  /// 主题设置
  final ThemeSettings themeSettings;

  /// 语言设置
  final LanguageSettings languageSettings;

  /// 设置版本号（用于未来迁移）
  final int version;

  /// 构造函数
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

  /// 创建副本
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

  /// 序列化为JSON
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

  /// 从JSON反序列化
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    Map<String, AiSettings> savedAiConfigs = {};
    if (json['savedAiConfigs'] != null) {
      final configsMap = json['savedAiConfigs'] as Map<String, dynamic>;
      configsMap.forEach((key, value) {
        savedAiConfigs[key] = AiSettings.fromJson(value as Map<String, dynamic>);
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