/// 语言设置页面
///
/// 提供 AI 输出语言和界面语言的独立设置功能：
/// - AI 语言：跟随书籍、跟随系统、用户自选
/// - 界面语言：跟随系统、用户自选
///
/// 设置即时保存到本地文件

import 'package:flutter/material.dart';
import 'package:zhidu/l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

/// 语言设置页面组件
///
/// 使用 StatefulWidget 管理语言设置状态
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

/// 语言设置页面状态管理
class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  /// 设置服务实例
  final _settingsService = SettingsService();

  /// AI 语言模式选项
  List<(String, String, String)> _getAiLanguageModes(AppLocalizations localizations) {
    return [
      ('book', localizations.aiLanguageFollowBook, localizations.aiLanguageModeBookSubtitle),
      ('system', localizations.aiLanguageFollowSystem, localizations.aiLanguageModeSystemSubtitle),
      ('manual', localizations.aiLanguageManualSelect, localizations.aiLanguageModeManualSubtitle),
    ];
  }

  /// 界面语言模式选项
  List<(String, String, String)> _getUiLanguageModes(AppLocalizations localizations) {
    return [
      ('system', localizations.uiLanguageFollowSystem, localizations.uiLanguageModeSystemSubtitle),
      ('manual', localizations.uiLanguageManualSelect, localizations.uiLanguageModeManualSubtitle),
    ];
  }

  /// 手动语言选项
  List<(String, String)> _getLanguages(AppLocalizations localizations) {
    return [
      ('zh', localizations.chineseLanguage ?? '简体中文'),
      ('en', localizations.englishLanguage ?? 'English'),
      ('ja', localizations.japaneseLanguage ?? '日本語'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.languageSettingsScreenTitle),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _settingsService.languageSettings,
        builder: (context, _) {
          final currentSettings = _settingsService.languageSettings.value;

          return ListView(
            children: [
              // AI 语言设置部分
              _buildSection(
                title: localizations.aiLanguageSetting,
                subtitle: localizations.aiLanguageControl,
                children: [
                  ..._getAiLanguageModes(localizations).map((mode) {
                    return RadioListTile<String>(
                      value: mode.$1,
                      groupValue: currentSettings.aiLanguageMode,
                      onChanged: (value) {
                        if (value != null) {
                          _updateAiLanguageMode(value);
                        }
                      },
                      title: Text(mode.$2),
                      subtitle: Text(mode.$3),
                      activeColor: Theme.of(context).colorScheme.primary,
                    );
                  }),
                ],
              ),

              // AI 语言手动选择时的语言下拉菜单
              if (currentSettings.aiLanguageMode == 'manual')
                _buildLanguageSelector(
                  localizations,
                  title: localizations.selectAiOutputLanguage,
                  value: currentSettings.aiOutputLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      _updateAiOutputLanguage(value);
                    }
                  },
                ),

              const Divider(height: 32),

              // 界面语言设置部分
              _buildSection(
                title: localizations.uiLanguageSetting,
                subtitle: localizations.uiLanguageControl,
                children: [
                  ..._getUiLanguageModes(localizations).map((mode) {
                    return RadioListTile<String>(
                      value: mode.$1,
                      groupValue: currentSettings.uiLanguageMode,
                      onChanged: (value) {
                        if (value != null) {
                          _updateUiLanguageMode(value);
                        }
                      },
                      title: Text(mode.$2),
                      subtitle: Text(mode.$3),
                      activeColor: Theme.of(context).colorScheme.primary,
                    );
                  }),
                ],
              ),

              // 界面语言手动选择时的语言下拉菜单
              if (currentSettings.uiLanguageMode == 'manual')
                _buildLanguageSelector(
                  localizations,
                  title: localizations.selectUiLanguage,
                  value: currentSettings.uiLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      _updateUiLanguage(value);
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  /// 构建设置分组
  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }

  /// 构建语言选择器
  Widget _buildLanguageSelector(
    AppLocalizations localizations, {
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8.0),
              DropdownButtonFormField<String>(
                value: _getLanguages(localizations).any((l) => l.$1 == value) ? value : 'zh',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                ),
                items: _getLanguages(localizations).map((lang) {
                  return DropdownMenuItem<String>(
                    value: lang.$1,
                    child: Text(lang.$2),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 更新 AI 语言模式
  Future<void> _updateAiLanguageMode(String mode) async {
    LanguageSettings newSettings;

    switch (mode) {
      case 'book':
        newSettings = _settingsService.languageSettings.value.copyWith(
          aiLanguageMode: 'book',
        );
        break;
      case 'system':
        newSettings = _settingsService.languageSettings.value.copyWith(
          aiLanguageMode: 'system',
        );
        break;
      case 'manual':
        newSettings = _settingsService.languageSettings.value.copyWith(
          aiLanguageMode: 'manual',
          aiOutputLanguage:
              _settingsService.languageSettings.value.aiOutputLanguage,
        );
        break;
      default:
        return;
    }

    await _settingsService.updateLanguageSettings(newSettings);
  }

  /// 更新 AI 输出语言
  Future<void> _updateAiOutputLanguage(String language) async {
    final newSettings = _settingsService.languageSettings.value.copyWith(
      aiOutputLanguage: language,
    );
    await _settingsService.updateLanguageSettings(newSettings);
  }

  /// 更新界面语言模式
  Future<void> _updateUiLanguageMode(String mode) async {
    LanguageSettings newSettings;

    switch (mode) {
      case 'system':
        newSettings = _settingsService.languageSettings.value.copyWith(
          uiLanguageMode: 'system',
        );
        break;
      case 'manual':
        newSettings = _settingsService.languageSettings.value.copyWith(
          uiLanguageMode: 'manual',
          uiLanguage: _settingsService.languageSettings.value.uiLanguage,
        );
        break;
      default:
        return;
    }

    await _settingsService.updateLanguageSettings(newSettings);
  }

  /// 更新界面语言
  Future<void> _updateUiLanguage(String language) async {
    final newSettings = _settingsService.languageSettings.value.copyWith(
      uiLanguage: language,
    );
    await _settingsService.updateLanguageSettings(newSettings);
  }
}
