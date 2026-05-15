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
    _log.info('SettingsService', '开始初始化设置服务');

    try {
      if (_settingsFilePath == null) {
        final docsDir = await getApplicationDocumentsDirectory();
        final appDir = Directory(p.join(docsDir.path, 'zhidu'));
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }
        _settingsFilePath = p.join(appDir.path, 'settings.json');
      }

      await _loadSettings();
      await _migrateCurrentAiSettingsToSaved();
      _syncNotifiersWithSettings();

      _log.info('SettingsService', '设置服务初始化完成');
    } catch (e, stackTrace) {
      _log.e('SettingsService', '初始化设置服务失败', e, stackTrace);
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
      _log.d('SettingsService', '自动将当前 AI 配置 (${current.provider}) 添加到已保存列表');
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
  }

  /// 获取当前完整设置
  AppSettings get settings => _settings;

  /// 保存或更新指定提供商的AI配置
  Future<void> _saveAiConfigForProvider(String provider, AiSettings aiSettings) async {
    final updatedConfigs = Map<String, AiSettings>.from(_settings.savedAiConfigs);
    updatedConfigs[provider] = aiSettings;
    _settings = _settings.copyWith(savedAiConfigs: updatedConfigs);
    await _saveSettings();
    _log.d('SettingsService', '已保存 $provider 的AI配置');
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
    _log.info('SettingsService', 'AI设置已更新: provider=${newSettings.provider}');
  }

  /// 更新主题设置
  Future<void> _updateThemeSettings(ThemeSettings newSettings) async {
    _settings = _settings.copyWith(themeSettings: newSettings);
    themeMode.value = newSettings.mode;
    await _saveSettings();
    _log.info('SettingsService', '主题设置已更新: mode=${newSettings.mode.name}');
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
    _log.info(
        'SettingsService', '语言设置已更新: aiOutput=${newSettings.aiOutputLanguage}');
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
