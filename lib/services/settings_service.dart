import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';
import 'log_helper.dart';

import '../models/app_settings.dart';
import 'file_storage_service.dart';
import 'storage_config.dart';

/// 设置服务 - 管理应用所有配置设置
///
/// 单例模式的设置管理服务，提供以下功能：
/// - 统一管理AI、主题、存储、语言等所有设置
/// - 使用ValueNotifiers实现响应式更新
/// - JSON文件持久化存储
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  /// 获取设置服务单例实例
  factory SettingsService() => _instance;

  /// 私有构造函数
  SettingsService._internal();

  /// 日志服务实例
  final _log = Logger(output: LogHelper.output);

  /// 设置文件路径
  String? _settingsFilePath;

  /// 当前设置对象
  AppSettings _settings = AppSettings();

  ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.system);
  ValueNotifier<AiSettings> _aiSettings = ValueNotifier(AiSettings());
  ValueNotifier<LanguageSettings> _languageSettings =
      ValueNotifier(LanguageSettings());

  /// 主题模式ValueNotifier（用于响应式UI更新）
  ValueNotifier<ThemeMode> get themeMode => _themeMode;

  /// AI设置ValueNotifier
  ValueNotifier<AiSettings> get aiSettings => _aiSettings;

  /// 语言设置ValueNotifier
  ValueNotifier<LanguageSettings> get languageSettings => _languageSettings;

  /// 测试用：重置服务状态
  @visibleForTesting
  static void resetForTest() {
    _instance._safeDispose(_instance._themeMode);
    _instance._safeDispose(_instance._aiSettings);
    _instance._safeDispose(_instance._languageSettings);

    _instance._themeMode = ValueNotifier(ThemeMode.system);
    _instance._aiSettings = ValueNotifier(AiSettings());
    _instance._languageSettings = ValueNotifier(LanguageSettings());

    _instance._settings = AppSettings();
    _instance._settingsFilePath = null;
  }

  /// 测试用：设置测试文件路径
  @visibleForTesting
  void setTestFilePath(String path) {
    _settingsFilePath = path;
  }

  /// 初始化设置服务
  Future<void> init() async {
    try {
      if (_settingsFilePath == null) {
        final appDir = await StorageConfig.getAppDirectory();
        _settingsFilePath = p.join(appDir.path, 'settings.json');
      }

      await _loadSettings();
      await _migrateCurrentAiSettingsToSaved();
      _syncNotifiersWithSettings();
    } catch (e, stackTrace) {
      _log.e('初始化设置服务失败', error: e, stackTrace: stackTrace);
      _settings = AppSettings();
      _syncNotifiersWithSettings();
    }
  }

  /// 迁移当前AI设置到已保存配置列表
  Future<void> _migrateCurrentAiSettingsToSaved() async {
    final current = _settings.aiSettings;
    if (current.isValid && !_settings.savedAiConfigs.containsKey(current.provider)) {
      final updatedConfigs = Map<String, AiSettings>.from(_settings.savedAiConfigs);
      updatedConfigs[current.provider] = current;
      _settings = _settings.copyWith(savedAiConfigs: updatedConfigs);
      await _saveSettings();
      _log.d('自动将当前 AI 配置 (${current.provider}) 添加到已保存列表');
    }
  }

  /// 从文件加载设置
  Future<void> _loadSettings() async {
    if (_settingsFilePath == null) return;
    final json = await FileStorageService().readJson(_settingsFilePath!);
    if (json != null) {
      _settings = AppSettings.fromJson(json);
    } else {
      _settings = AppSettings();
    }
  }

  /// 保存设置到文件
  Future<void> _saveSettings() async {
    if (_settingsFilePath == null) return;
    await FileStorageService().writeJson(_settingsFilePath!, _settings.toJson());
  }

  /// 同步ValueNotifiers与当前设置
  void _syncNotifiersWithSettings() {
    themeMode.value = _settings.themeSettings.mode;
    aiSettings.value = _settings.aiSettings;
    languageSettings.value = _settings.languageSettings;
  }

  /// 获取当前完整设置
  AppSettings get settings => _settings;

  /// 保存或更新指定提供商的AI配置
  Future<void> _saveAiConfigForProvider(String provider, AiSettings aiSettings) async {
    final updatedConfigs = Map<String, AiSettings>.from(_settings.savedAiConfigs);
    updatedConfigs[provider] = aiSettings;
    _settings = _settings.copyWith(savedAiConfigs: updatedConfigs);
    await _saveSettings();
  }

  /// 获取指定提供商的已保存配置
  AiSettings? getSavedAiConfigForProvider(String provider) {
    return _settings.savedAiConfigs[provider];
  }

  /// 检查指定提供商是否有已保存的配置
  bool hasSavedAiConfigForProvider(String provider) {
    return _settings.savedAiConfigs.containsKey(provider);
  }

  /// 更新AI设置
  Future<void> updateAiSettings(AiSettings newSettings) async {
    _settings = _settings.copyWith(aiSettings: newSettings);
    aiSettings.value = newSettings;
    await _saveAiConfigForProvider(newSettings.provider, newSettings);
    _log.i('AI设置已更新: provider=${newSettings.provider}');
  }

  /// 更新主题设置
  Future<void> _updateThemeSettings(ThemeSettings newSettings) async {
    _settings = _settings.copyWith(themeSettings: newSettings);
    themeMode.value = newSettings.mode;
    await _saveSettings();
    _log.i('主题设置已更新: mode=${newSettings.mode.name}');
  }

  /// 设置主题模式（便捷方法）
  Future<void> setThemeMode(ThemeMode mode) async {
    await _updateThemeSettings(_settings.themeSettings.copyWith(mode: mode));
  }

  /// 更新语言设置
  Future<void> updateLanguageSettings(LanguageSettings newSettings) async {
    _settings = _settings.copyWith(languageSettings: newSettings);
    languageSettings.value = newSettings;
    await _saveSettings();
    _log.i('语言设置已更新: aiOutput=${newSettings.aiOutputLanguage}');
  }

  /// 释放资源
  void dispose() {
    _safeDispose(_themeMode);
    _safeDispose(_aiSettings);
    _safeDispose(_languageSettings);
  }

  /// 安全地dispose ValueNotifier，忽略已dispose的错误
  void _safeDispose(ChangeNotifier notifier) {
    try {
      notifier.dispose();
    } catch (_) {
    }
  }
}
