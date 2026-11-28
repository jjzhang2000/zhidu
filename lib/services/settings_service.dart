import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/app_settings.dart';
import 'file_storage_service.dart';
import 'log_service.dart';
import 'storage_config.dart';

/// 设置服务 - 管理应用所有配置设置
///
/// 单例模式的设置管理服务，提供以下功能：
/// - 统一管理AI、主题、存储、语言等所有设置
/// - 使用ValueNotifiers实现响应式更新
/// - JSON文件持久化存储
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() => _instance;

  SettingsService._internal();

  /// 日志服务实例
  final _log = LogService();

  String? _settingsFilePath;

  AppSettings _settings = AppSettings();

  ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.system);
  ValueNotifier<AiSettings> _aiSettings = ValueNotifier(AiSettings());
  ValueNotifier<LanguageSettings> _languageSettings =
      ValueNotifier(LanguageSettings());
  ValueNotifier<BookSortType> _bookshelfSortType =
      ValueNotifier(BookSortType.lastRead);
  ValueNotifier<String?> _calibreLibraryPath = ValueNotifier(null);

  /// 阅读正文字号的全局覆盖值（null 表示未覆盖，回到原书排版/应用默认）
  ValueNotifier<double?> _readerFontSizeOverride = ValueNotifier(null);

  /// 阅读行高倍数的全局覆盖值（null 表示未覆盖）
  ValueNotifier<double?> _readerLineHeightOverride = ValueNotifier(null);

  /// 阅读段距系数的全局覆盖值（null 表示未覆盖）
  ValueNotifier<double?> _readerParagraphSpacingOverride = ValueNotifier(null);

  /// 主题模式ValueNotifier（用于响应式UI更新）
  ValueNotifier<ThemeMode> get themeMode => _themeMode;

  /// AI设置ValueNotifier
  ValueNotifier<AiSettings> get aiSettings => _aiSettings;

  /// 语言设置ValueNotifier
  ValueNotifier<LanguageSettings> get languageSettings => _languageSettings;

  /// 书架排序方式ValueNotifier
  ValueNotifier<BookSortType> get bookshelfSortType => _bookshelfSortType;

  /// 书库路径ValueNotifier
  ValueNotifier<String?> get calibreLibraryPath => _calibreLibraryPath;

  /// 阅读正文字号全局覆盖值（null = 未覆盖）
  ValueNotifier<double?> get readerFontSizeOverride => _readerFontSizeOverride;

  /// 阅读行高全局覆盖值（null = 未覆盖）
  ValueNotifier<double?> get readerLineHeightOverride =>
      _readerLineHeightOverride;

  /// 阅读段距全局覆盖值（null = 未覆盖）
  ValueNotifier<double?> get readerParagraphSpacingOverride =>
      _readerParagraphSpacingOverride;

  /// 测试用：重置服务状态
  @visibleForTesting
  static void resetForTest() {
    _instance._safeDispose(_instance._themeMode);
    _instance._safeDispose(_instance._aiSettings);
    _instance._safeDispose(_instance._languageSettings);
    _instance._safeDispose(_instance._bookshelfSortType);
    _instance._safeDispose(_instance._calibreLibraryPath);
    _instance._safeDispose(_instance._readerFontSizeOverride);
    _instance._safeDispose(_instance._readerLineHeightOverride);
    _instance._safeDispose(_instance._readerParagraphSpacingOverride);

    _instance._themeMode = ValueNotifier(ThemeMode.system);
    _instance._aiSettings = ValueNotifier(AiSettings());
    _instance._languageSettings = ValueNotifier(LanguageSettings());
    _instance._bookshelfSortType = ValueNotifier(BookSortType.lastRead);
    _instance._calibreLibraryPath = ValueNotifier(null);
    _instance._readerFontSizeOverride = ValueNotifier(null);
    _instance._readerLineHeightOverride = ValueNotifier(null);
    _instance._readerParagraphSpacingOverride = ValueNotifier(null);

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
    bookshelfSortType.value = _settings.bookshelfSortType;
    calibreLibraryPath.value = _settings.calibreLibraryPath;
    readerFontSizeOverride.value = _settings.readerFontSize;
    readerLineHeightOverride.value = _settings.readerLineHeight;
    readerParagraphSpacingOverride.value = _settings.readerParagraphSpacing;
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
    if (_settings.languageSettings == newSettings) return;
    _settings = _settings.copyWith(languageSettings: newSettings);
    languageSettings.value = newSettings;
    await _saveSettings();
    _log.info('SettingsService', '语言设置已更新');
  }

  /// 设置 Calibre 书库路径
  Future<void> setCalibreLibraryPath(String path) async {
    _settings = _settings.copyWith(calibreLibraryPath: path);
    calibreLibraryPath.value = path;
    await _saveSettings();
    _log.info('SettingsService', '已设置书库: $path');
  }

  /// 设置书架书籍排序方式
  Future<void> setBookshelfSortType(BookSortType type) async {
    if (_settings.bookshelfSortType == type) return;
    _settings = _settings.copyWith(bookshelfSortType: type);
    bookshelfSortType.value = type;
    await _saveSettings();
    _log.info('SettingsService', '书架排序方式已更新: ${type.name}');
  }

  /// 设置/清除阅读正文字号的全局覆盖（传 null 表示清除覆盖）
  Future<void> setReaderFontSize(double? size) async {
    if (_settings.readerFontSize == size) return;
    _settings = _settings.copyWith(readerFontSize: size);
    readerFontSizeOverride.value = size;
    await _saveSettings();
    _log.info('SettingsService', '阅读字号覆盖: ${size ?? '已清除'}');
  }

  /// 设置/清除阅读行高的全局覆盖（传 null 表示清除覆盖）
  Future<void> setReaderLineHeight(double? height) async {
    if (_settings.readerLineHeight == height) return;
    _settings = _settings.copyWith(readerLineHeight: height);
    readerLineHeightOverride.value = height;
    await _saveSettings();
    _log.info('SettingsService', '阅读行距覆盖: ${height ?? '已清除'}');
  }

  /// 设置/清除阅读段距的全局覆盖（传 null 表示清除覆盖）
  Future<void> setReaderParagraphSpacing(double? factor) async {
    if (_settings.readerParagraphSpacing == factor) return;
    _settings = _settings.copyWith(readerParagraphSpacing: factor);
    readerParagraphSpacingOverride.value = factor;
    await _saveSettings();
    _log.info('SettingsService', '阅读段距覆盖: ${factor ?? '已清除'}');
  }

  /// 释放资源
  void dispose() {
    _safeDispose(_themeMode);
    _safeDispose(_aiSettings);
    _safeDispose(_languageSettings);
    _safeDispose(_bookshelfSortType);
    _safeDispose(_calibreLibraryPath);
  }

  /// 安全地dispose ValueNotifier，忽略已dispose的错误
  void _safeDispose(ChangeNotifier notifier) {
    try {
      notifier.dispose();
    } catch (_) {
    }
  }
}
