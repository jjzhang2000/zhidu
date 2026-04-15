/// 语言设置页面
///
/// 提供AI输出语言偏好设置功能：
/// - 书籍语言（自动判断）：根据书籍内容自动判断语言
/// - 跟随系统：使用系统语言设置
/// - 手动选择：手动指定语言
///
/// 当选择"手动选择"时，显示语言下拉菜单
/// 设置即时保存到本地文件

import 'package:flutter/material.dart';
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

  /// 语言选项定义
  static const _languageOptions = [
    ('auto_book', '书籍语言（自动判断）', '根据书籍内容自动判断语言'),
    ('system', '跟随系统', '使用系统语言设置'),
    ('manual', '手动选择', '手动指定AI输出语言'),
  ];

  /// 手动语言选项定义
  static const _manualLanguages = [
    ('zh', '简体中文'),
    ('en', 'English'),
    ('ja', '日本語'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语言设置'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _settingsService.languageSettings,
        builder: (context, _) {
          final currentSettings = _settingsService.languageSettings.value;
          final currentMode = _getCurrentMode(currentSettings);

          return ListView(
            children: [
              // 语言模式选项
              ..._languageOptions.map((option) {
                return RadioListTile<String>(
                  value: option.$1,
                  groupValue: currentMode,
                  onChanged: (value) {
                    if (value != null) {
                      _updateLanguageMode(value);
                    }
                  },
                  title: Text(option.$2),
                  subtitle: Text(option.$3),
                  activeColor: Theme.of(context).colorScheme.primary,
                );
              }),

              // 手动选择时的语言下拉菜单
              if (currentMode == 'manual')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildManualLanguageDropdown(currentSettings),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 获取当前语言模式
  ///
  /// 根据设置中的 aiOutputLanguage 和 manualLanguage 推断当前模式
  String _getCurrentMode(LanguageSettings settings) {
    final aiLang = settings.aiOutputLanguage;
    final manualLang = settings.manualLanguage;

    if (aiLang == 'auto_book') {
      return 'auto_book';
    } else if (manualLang == null) {
      return 'system';
    } else {
      return 'manual';
    }
  }

  /// 更新语言模式
  ///
  /// 参数：
  /// - mode: 目标模式 ('auto_book' | 'system' | 'manual')
  Future<void> _updateLanguageMode(String mode) async {
    LanguageSettings newSettings;

    switch (mode) {
      case 'auto_book':
        newSettings = _settingsService.languageSettings.value.copyWith(
          aiOutputLanguage: 'auto_book',
          manualLanguage: null,
        );
        break;
      case 'system':
        newSettings = _settingsService.languageSettings.value.copyWith(
          aiOutputLanguage: 'zh',
          manualLanguage: null,
        );
        break;
      case 'manual':
        // 默认选择简体中文
        final currentManual =
            _settingsService.languageSettings.value.manualLanguage;
        newSettings = _settingsService.languageSettings.value.copyWith(
          aiOutputLanguage: currentManual ?? 'zh',
          manualLanguage: currentManual ?? 'zh',
        );
        break;
      default:
        return;
    }

    await _settingsService.updateLanguageSettings(newSettings);
  }

  /// 构建手动语言选择下拉菜单
  Widget _buildManualLanguageDropdown(LanguageSettings settings) {
    final currentManualLang = settings.manualLanguage ?? 'zh';

    return Card(
      margin: const EdgeInsets.only(top: 8.0, bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择语言',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8.0),
            DropdownButtonFormField<String>(
              value: currentManualLang,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              ),
              items: _manualLanguages.map((lang) {
                return DropdownMenuItem<String>(
                  value: lang.$1,
                  child: Text(lang.$2),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _updateManualLanguage(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 更新手动选择的语言
  ///
  /// 参数：
  /// - language: 目标语言 ('zh' | 'en' | 'ja')
  Future<void> _updateManualLanguage(String language) async {
    final newSettings = _settingsService.languageSettings.value.copyWith(
      aiOutputLanguage: language,
      manualLanguage: language,
    );
    await _settingsService.updateLanguageSettings(newSettings);
  }
}
