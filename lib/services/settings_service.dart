import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/app_settings.dart';
import 'log_service.dart';

/// 设置服务 - 管理应用所有配置设置
///
/// 单例模式的设置管理服务，提供以下功能：
/// - 统一管理AI、主题、存储、语言等所有设置
/// - 使用ValueNotifiers实现响应式更新
/// - JSON文件持久化存储
/// - 与现有AIService兼容的配置格式
///
/// 使用示例：
/// ```dart
/// // 初始化（在main.dart中）
/// await SettingsService().init();
///
/// // 监听主题变化
/// SettingsService().themeMode.addListener(() {
///   print('主题已切换: ${SettingsService().themeMode.value}');
/// });
///
/// // 更新AI设置
/// await SettingsService().updateAiSettings(
///   SettingsService().aiSettings.value.copyWith(apiKey: 'new-key'),
/// );
///
/// // 切换主题
/// await SettingsService().setThemeMode(ThemeMode.dark);
/// ```
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  /// 获取设置服务单例实例
  factory SettingsService() => _instance;

  /// 私有构造函数
  SettingsService._internal();

  /// 日志服务实例
  final _log = LogService();

  /// 设置文件路径
  String? _settingsFilePath;

  /// 当前设置对象
  AppSettings _settings = AppSettings();

  // Private ValueNotifier fields
  ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.system);
  ValueNotifier<AiSettings> _aiSettings = ValueNotifier(AiSettings());
  ValueNotifier<LanguageSettings> _languageSettings =
      ValueNotifier(LanguageSettings());
  ValueNotifier<StorageSettings> _storageSettings =
      ValueNotifier(StorageSettings());

  /// 主题模式ValueNotifier（用于响应式UI更新）
  ValueNotifier<ThemeMode> get themeMode => _themeMode;

  /// AI设置ValueNotifier
  ValueNotifier<AiSettings> get aiSettings => _aiSettings;

  /// 语言设置ValueNotifier
  ValueNotifier<LanguageSettings> get languageSettings => _languageSettings;

  /// 存储设置ValueNotifier
  ValueNotifier<StorageSettings> get storageSettings => _storageSettings;

  /// 测试用：重置服务状态
  @visibleForTesting
  static void resetForTest() {
    // Dispose old notifiers if they exist (safely)
    _instance._safeDispose(_instance._themeMode);
    _instance._safeDispose(_instance._aiSettings);
    _instance._safeDispose(_instance._languageSettings);
    _instance._safeDispose(_instance._storageSettings);

    // Create new notifiers
    _instance._themeMode = ValueNotifier(ThemeMode.system);
    _instance._aiSettings = ValueNotifier(AiSettings());
    _instance._languageSettings = ValueNotifier(LanguageSettings());
    _instance._storageSettings = ValueNotifier(StorageSettings());

    _instance._settings = AppSettings();
    _instance._settingsFilePath = null;
  }

  /// 测试用：设置测试文件路径
  @visibleForTesting
  void setTestFilePath(String path) {
    _settingsFilePath = path;
  }

  /// 初始化设置服务
  ///
  /// 加载保存的设置，如果不存在则使用默认值。
  /// 同时初始化ValueNotifiers的值。
  ///
  /// 调用时机：
  /// - 在main.dart中应用启动时调用
  Future<void> init() async {
    _log.info('SettingsService', '开始初始化设置服务');

    try {
      // 获取设置文件路径
      if (_settingsFilePath == null) {
        final docsDir = await getApplicationDocumentsDirectory();
        final appDir = Directory(p.join(docsDir.path, 'zhidu'));
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }
        _settingsFilePath = p.join(appDir.path, 'settings.json');
      }

      // 加载设置
      await _loadSettings();

      // 初始化ValueNotifiers
      _syncNotifiersWithSettings();

      _log.info('SettingsService', '设置服务初始化完成');
    } catch (e, stackTrace) {
      _log.e('SettingsService', '初始化设置服务失败', e, stackTrace);
      // 使用默认设置继续
      _settings = AppSettings();
      _syncNotifiersWithSettings();
    }
  }

  /// 从文件加载设置
  Future<void> _loadSettings() async {
    if (_settingsFilePath == null) return;

    final file = File(_settingsFilePath!);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(json);
        _log.info('SettingsService', '已加载设置文件: $_settingsFilePath');
      } catch (e) {
        _log.e('SettingsService', '解析设置文件失败，使用默认设置', e);
        _settings = AppSettings();
      }
    } else {
      _log.info('SettingsService', '设置文件不存在，使用默认设置');
      _settings = AppSettings();
    }
  }

  /// 保存设置到文件
  Future<void> _saveSettings() async {
    if (_settingsFilePath == null) return;

    try {
      final file = File(_settingsFilePath!);
      final content = jsonEncode(_settings.toJson());
      await file.writeAsString(content);
      _log.d('SettingsService', '设置已保存到: $_settingsFilePath');
    } catch (e, stackTrace) {
      _log.e('SettingsService', '保存设置失败', e, stackTrace);
      rethrow;
    }
  }

  /// 同步ValueNotifiers与当前设置
  void _syncNotifiersWithSettings() {
    themeMode.value = _settings.themeSettings.mode;
    aiSettings.value = _settings.aiSettings;
    languageSettings.value = _settings.languageSettings;
    storageSettings.value = _settings.storageSettings;
  }

  /// 获取当前完整设置
  AppSettings get settings => _settings;

  /// 更新AI设置
  ///
  /// [newSettings] 新的AI设置
  ///
  /// 更新后会：
  /// - 保存到文件
  /// - 更新aiSettings ValueNotifier
  Future<void> updateAiSettings(AiSettings newSettings) async {
    _settings = _settings.copyWith(aiSettings: newSettings);
    aiSettings.value = newSettings;
    await _saveSettings();
    _log.info('SettingsService', 'AI设置已更新: provider=${newSettings.provider}');
  }

  /// 更新主题设置
  ///
  /// [newSettings] 新的主题设置
  Future<void> updateThemeSettings(ThemeSettings newSettings) async {
    _settings = _settings.copyWith(themeSettings: newSettings);
    themeMode.value = newSettings.mode;
    await _saveSettings();
    _log.info('SettingsService', '主题设置已更新: mode=${newSettings.mode.name}');
  }

  /// 设置主题模式（便捷方法）
  ///
  /// [mode] 目标主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    await updateThemeSettings(_settings.themeSettings.copyWith(mode: mode));
  }

  /// 更新存储设置
  ///
  /// [newSettings] 新的存储设置
  Future<void> updateStorageSettings(StorageSettings newSettings) async {
    _settings = _settings.copyWith(storageSettings: newSettings);
    storageSettings.value = newSettings;
    await _saveSettings();
    _log.info('SettingsService', '存储设置已更新');
  }

  /// 更新语言设置
  ///
  /// [newSettings] 新的语言设置
  Future<void> updateLanguageSettings(LanguageSettings newSettings) async {
    _settings = _settings.copyWith(languageSettings: newSettings);
    languageSettings.value = newSettings;
    await _saveSettings();
    _log.info(
        'SettingsService', '语言设置已更新: aiOutput=${newSettings.aiOutputLanguage}');
  }

  /// 重置所有设置为默认值
  Future<void> resetToDefaults() async {
    _settings = AppSettings();
    _syncNotifiersWithSettings();
    await _saveSettings();
    _log.info('SettingsService', '设置已重置为默认值');
  }

  /// 获取设置文件路径
  String? get settingsFilePath => _settingsFilePath;

  /// 导出设置为JSON字符串
  String exportToJson() {
    return jsonEncode(_settings.toJson());
  }

  /// 从JSON字符串导入设置
  ///
  /// [jsonString] JSON格式的设置字符串
  Future<void> importFromJson(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _settings = AppSettings.fromJson(json);
      _syncNotifiersWithSettings();
      await _saveSettings();
      _log.info('SettingsService', '设置已从JSON导入');
    } catch (e, stackTrace) {
      _log.e('SettingsService', '导入设置失败', e, stackTrace);
      rethrow;
    }
  }

  /// 将设置转换为与旧版ai_config.json兼容的格式
  ///
  /// 用于AIService读取配置
  Map<String, dynamic> toAiConfigJson() {
    return {
      'ai_provider': _settings.aiSettings.provider,
      _settings.aiSettings.provider: {
        'api_key': _settings.aiSettings.apiKey,
        'model': _settings.aiSettings.model,
        'base_url': _settings.aiSettings.baseUrl,
      },
    };
  }

  /// 从旧版ai_config.json格式导入AI设置
  ///
  /// [json] 旧版格式的JSON对象
  Future<void> importFromAiConfigJson(Map<String, dynamic> json) async {
    final provider = json['ai_provider'] as String? ?? 'qwen';
    final providerConfig = json[provider] as Map<String, dynamic>? ?? {};

    final newAiSettings = AiSettings(
      provider: provider,
      apiKey: providerConfig['api_key'] ?? '',
      model: providerConfig['model'] ?? 'qwen-plus',
      baseUrl: providerConfig['base_url'] ??
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
    );

    await updateAiSettings(newAiSettings);
  }

  /// 检查AI配置是否有效
  bool get isAiConfigured => _settings.aiSettings.isValid;

  /// 更新所有设置
  ///
  /// 一次性更新所有设置类别，用于从备份恢复设置。
  ///
  /// 参数：
  /// - [settings] 新的完整设置对象
  ///
  /// 使用场景：
  /// - 从JSON备份导入设置时调用
  /// - 设置迁移或重置时调用
  Future<void> updateAllSettings(AppSettings settings) async {
    _settings = settings;
    _syncNotifiersWithSettings();
    await _saveSettings();
    _log.info('SettingsService', '所有设置已更新');
  }

  /// 释放资源
  ///
  /// 在应用退出前调用，清理ValueNotifiers
  void dispose() {
    _safeDispose(_themeMode);
    _safeDispose(_aiSettings);
    _safeDispose(_languageSettings);
    _safeDispose(_storageSettings);
  }

  /// 安全地dispose ValueNotifier，忽略已dispose的错误
  void _safeDispose(ChangeNotifier notifier) {
    try {
      notifier.dispose();
    } catch (_) {
      // Already disposed, ignore
    }
  }
}
