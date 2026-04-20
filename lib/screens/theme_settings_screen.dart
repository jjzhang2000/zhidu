/// 主题设置页面
///
/// 提供应用主题模式切换功能：
/// - 跟随系统：自动跟随系统主题设置
/// - 亮色模式：强制使用浅色主题
/// - 暗色模式：强制使用深色主题
///
/// 主题切换即时生效，通过 SettingsService.themeMode 通知监听者
/// 设置自动保存到本地文件

import 'package:flutter/material.dart' hide ThemeMode;
import 'package:zhidu/l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

/// 主题设置页面组件
///
/// 使用 StatefulWidget 监听主题变化并更新 UI
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

/// 主题设置页面状态管理
class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  /// 设置服务实例
  final _settingsService = SettingsService();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.themeSettingsScreenTitle),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildThemeOption(
            mode: ThemeMode.system,
            title: localizations.themeModeSystem,
            subtitle: localizations.themeModeSystemSubtitle,
            icon: Icons.brightness_auto,
          ),
          const Divider(),
          _buildThemeOption(
            mode: ThemeMode.light,
            title: localizations.themeModeLight,
            subtitle: localizations.themeModeLightSubtitle,
            icon: Icons.light_mode,
          ),
          const Divider(),
          _buildThemeOption(
            mode: ThemeMode.dark,
            title: localizations.themeModeDark,
            subtitle: localizations.themeModeDarkSubtitle,
            icon: Icons.dark_mode,
          ),
        ],
      ),
    );
  }

  /// 构建主题选项
  ///
  /// 参数：
  /// - mode: 主题模式
  /// - title: 选项标题
  /// - subtitle: 选项描述
  /// - icon: 图标
  Widget _buildThemeOption({
    required ThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListenableBuilder(
      listenable: _settingsService.themeMode,
      builder: (context, _) {
        return RadioListTile<ThemeMode>(
          value: mode,
          groupValue: _settingsService.themeMode.value,
          onChanged: (selectedMode) {
            if (selectedMode != null) {
              _settingsService.setThemeMode(selectedMode);
            }
          },
          title: Text(title),
          subtitle: Text(subtitle),
          secondary: Icon(icon),
          activeColor: Theme.of(context).colorScheme.primary,
        );
      },
    );
  }
}
