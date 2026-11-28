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

/// 书架书籍排序方式
enum BookSortType {
  lastRead,
  addedAsc,
  addedDesc,
  titleAsc,
  titleDesc,
  authorAsc,
  authorDesc;

  /// 从字符串解析排序方式，无法匹配时返回 [lastRead]
  static BookSortType fromString(String? value) {
    switch (value) {
      case 'addedAsc':
        return BookSortType.addedAsc;
      case 'addedDesc':
        return BookSortType.addedDesc;
      case 'titleAsc':
        return BookSortType.titleAsc;
      case 'titleDesc':
        return BookSortType.titleDesc;
      case 'authorAsc':
        return BookSortType.authorAsc;
      case 'authorDesc':
        return BookSortType.authorDesc;
      default:
        return BookSortType.lastRead;
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

/// 语言设置，统一控制 AI 输出语言与界面显示语言
class LanguageSettings {
  /// 语言模式：'system'（跟随系统）、'manual'（用户自选）
  final String languageMode;

  /// 语言，仅当 [languageMode] 为 'manual' 时生效，如 'zh'、'en'、'ja'
  final String language;

  LanguageSettings({
    this.languageMode = 'system',
    this.language = 'zh',
  });

  LanguageSettings copyWith({
    String? languageMode,
    String? language,
  }) {
    return LanguageSettings(
      languageMode: languageMode ?? this.languageMode,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageSettings &&
        other.languageMode == languageMode &&
        other.language == language;
  }

  @override
  int get hashCode {
    return Object.hash(languageMode, language);
  }

  Map<String, dynamic> toJson() {
    return {
      'languageMode': languageMode,
      'language': language,
    };
  }

  factory LanguageSettings.fromJson(Map<String, dynamic> json) {
    // 新版字段优先
    if (json.containsKey('languageMode')) {
      return LanguageSettings(
        languageMode: json['languageMode'] ?? 'system',
        language: json['language'] ?? 'zh',
      );
    }
    // 迁移旧版字段：优先沿用界面语言手动选择，其次 AI 输出语言手动选择
    if (json['uiLanguageMode'] == 'manual') {
      return LanguageSettings(
        languageMode: 'manual',
        language: json['uiLanguage'] ?? 'zh',
      );
    }
    if (json['aiLanguageMode'] == 'manual') {
      return LanguageSettings(
        languageMode: 'manual',
        language: json['aiOutputLanguage'] ?? 'zh',
      );
    }
    return LanguageSettings();
  }
}

/// copyWith 的哨兵值：用于区分「未传参」与「显式传 null（清除覆盖）」
const Object _unsetReaderValue = Object();

/// 应用完整设置：聚合 AI、主题、语言、书架排序、阅读排版等配置，作为 SettingsService 的数据载体
class AppSettings {
  /// AI 设置
  final AiSettings aiSettings;

  /// 已保存的 AI 配置映射，key 为 provider，value 为对应完整配置
  final Map<String, AiSettings> savedAiConfigs;

  /// 主题设置
  final ThemeSettings themeSettings;

  /// 语言设置
  final LanguageSettings languageSettings;

  /// 书架书籍排序方式
  final BookSortType bookshelfSortType;

  /// Calibre 书库文件夹路径（未设置时为 null）
  final String? calibreLibraryPath;

  /// 阅读正文字号的全局覆盖值（null 表示未覆盖，由原书排版或应用默认值决定）
  final double? readerFontSize;

  /// 阅读行高倍数的全局覆盖值（null 表示未覆盖）
  final double? readerLineHeight;

  /// 阅读段距系数的全局覆盖值（null 表示未覆盖）
  final double? readerParagraphSpacing;

  /// 设置版本号，用于未来数据迁移
  final int version;

  AppSettings({
    AiSettings? aiSettings,
    Map<String, AiSettings>? savedAiConfigs,
    ThemeSettings? themeSettings,
    LanguageSettings? languageSettings,
    this.bookshelfSortType = BookSortType.lastRead,
    this.calibreLibraryPath,
    this.readerFontSize,
    this.readerLineHeight,
    this.readerParagraphSpacing,
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
    BookSortType? bookshelfSortType,
    String? calibreLibraryPath,
    Object? readerFontSize = _unsetReaderValue,
    Object? readerLineHeight = _unsetReaderValue,
    Object? readerParagraphSpacing = _unsetReaderValue,
    int? version,
  }) {
    return AppSettings(
      aiSettings: aiSettings ?? this.aiSettings,
      savedAiConfigs: savedAiConfigs ?? this.savedAiConfigs,
      themeSettings: themeSettings ?? this.themeSettings,
      languageSettings: languageSettings ?? this.languageSettings,
      bookshelfSortType: bookshelfSortType ?? this.bookshelfSortType,
      calibreLibraryPath: calibreLibraryPath ?? this.calibreLibraryPath,
      readerFontSize: identical(readerFontSize, _unsetReaderValue)
          ? this.readerFontSize
          : readerFontSize as double?,
      readerLineHeight: identical(readerLineHeight, _unsetReaderValue)
          ? this.readerLineHeight
          : readerLineHeight as double?,
      readerParagraphSpacing:
          identical(readerParagraphSpacing, _unsetReaderValue)
              ? this.readerParagraphSpacing
              : readerParagraphSpacing as double?,
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
      'bookshelfSortType': bookshelfSortType.name,
      'calibreLibraryPath': calibreLibraryPath,
      'readerFontSize': readerFontSize,
      'readerLineHeight': readerLineHeight,
      'readerParagraphSpacing': readerParagraphSpacing,
      'version': version,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final savedAiConfigs = <String, AiSettings>{};
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
      bookshelfSortType:
          BookSortType.fromString(json['bookshelfSortType'] as String?),
      calibreLibraryPath: json['calibreLibraryPath'] as String?,
      readerFontSize: _legacyOverride(json['readerFontSize'], 21.0),
      readerLineHeight: _legacyOverride(json['readerLineHeight'], 1.6),
      readerParagraphSpacing:
          _legacyOverride(json['readerParagraphSpacing'], 0.8),
      version: json['version'] ?? 1,
    );
  }

  /// 兼容旧配置：旧版本会把默认值也写入文件，视同「未覆盖」，以便回到原书排版
  static double? _legacyOverride(Object? raw, double legacyDefault) {
    final value = (raw as num?)?.toDouble();
    return value == legacyDefault ? null : value;
  }
}
