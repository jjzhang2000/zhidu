import 'package:flutter/material.dart' hide ThemeMode;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zhidu/l10n/app_localizations.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';
import 'ai_config_screen.dart';
import 'theme_settings_screen.dart';
import 'language_settings_screen.dart';

/// 设置页面 - 应用各项配置入口
///
/// 功能模块：
/// 1. AI配置：AI服务提供商、API密钥、模型等参数设置
/// 2. 外观设置：主题模式、界面语言等
/// 3. 关于：应用信息、版本等
///
/// 设计特点：
/// - 使用卡片面板组织不同设置类别
/// - 实时显示设置状态（如AI配置状态、主题模式等）
/// - 响应式UI更新（设置变更后自动刷新显示）
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settingsTitle),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildSectionHeader(loc.aiConfigTitle),
          _buildAiSection(),
          const SizedBox(height: 16),
          _buildSectionHeader(loc.appearanceSettingTitle),
          _buildAppearanceSection(),
          const SizedBox(height: 16),
          _buildSectionHeader(loc.aboutTitle),
          _buildAboutSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 构建区域标题
  ///
  /// 统一的区域标题样式：
  /// - 左粗字体
  /// - 适当间距
  /// - 与内容形成视觉分组
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  /// 构建区域容器
  ///
  /// 为设置区域提供统一样式：
  /// - 圆角边框
  /// - 阴影效果
  /// - 内边距
  /// - 适配主题色彩
  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children,
        ],
      ),
    );
  }

  /// 构建AI配置区块
  ///
  /// 提供AI服务配置入口：
  /// - 点击跳转到AI配置页面
  /// - 显示当前配置状态（provider/model 或 未配置）
  Widget _buildAiSection() {
    final loc = AppLocalizations.of(context)!;
    return _buildSection(
      title: loc.aiConfigTitle,
      icon: Icons.smart_toy,
      children: [
        ListenableBuilder(
          listenable: SettingsService().aiSettings,
          builder: (context, _) {
            return ListTile(
              leading: const Icon(Icons.api),
              title: Text(loc.aiServiceSettings),
              subtitle: Text(_getAiConfigStatus()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AiConfigScreen(),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// 构建外观设置区块
  ///
  /// 提供主题和语言设置入口
  Widget _buildAppearanceSection() {
    final loc = AppLocalizations.of(context)!;
    return _buildSection(
      title: loc.appearanceSettingTitle,
      icon: Icons.palette,
      children: [
        ListenableBuilder(
          listenable: SettingsService().themeMode,
          builder: (context, _) {
            return ListTile(
              leading: const Icon(Icons.brightness_6),
              title: Text(loc.themeSettingTitle),
              subtitle: Text(_getThemeStatus()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ThemeSettingsScreen(),
                  ),
                );
              },
            );
          },
        ),
        ListenableBuilder(
          listenable: SettingsService().languageSettings,
          builder: (context, _) {
            return ListTile(
              leading: const Icon(Icons.language),
              title: Text(loc.languageSettingTitle),
              subtitle: Text(_getLanguageStatus()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LanguageSettingsScreen(),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// 构建关于区块
  ///
  /// 显示应用信息：
  /// - 应用名称：智读
  /// - 版本号：0.1.0
  /// - 副标题：AI 分层阅读器 - 先读薄，再读厚
  Widget _buildAboutSection() {
    final loc = AppLocalizations.of(context)!;
    return _buildSection(
      title: loc.aboutTitle,
      icon: Icons.info,
      children: [
        ListTile(
          leading: const Icon(Icons.apps),
          title: Text(loc.appTitle),
          subtitle: Text('${loc.version} $_version'),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text(loc.aiLayeredReader),
          subtitle: Text(loc.readThinThick),
        ),
      ],
    );
  }

  /// 获取AI配置状态显示文本
  ///
  /// 根据当前AI设置返回描述性文本：
  /// - 有效配置：显示provider和model
  /// - 无效配置：提示用户检查设置
  String _getAiConfigStatus() {
    final loc = AppLocalizations.of(context)!;
    final settings = SettingsService().settings.aiSettings;
    if (settings.isValid) {
      return '${settings.provider} - ${settings.model}';
    } else {
      return loc.notConfiguredClickToSet;
    }
  }

  /// 获取主题状态显示文本
  String _getThemeStatus() {
    final loc = AppLocalizations.of(context)!;
    final mode = SettingsService().settings.themeSettings.mode;
    switch (mode) {
      case ThemeMode.system:
        return loc.themeModeSystem;
      case ThemeMode.light:
        return loc.themeModeLight;
      case ThemeMode.dark:
        return loc.themeModeDark;
    }
  }

  /// 获取语言状态显示文本
  String _getLanguageStatus() {
    final loc = AppLocalizations.of(context)!;
    final settings = SettingsService().settings.languageSettings;

    // 构建AI语言设置显示文本
    String aiLanguageText;
    switch (settings.aiLanguageMode) {
      case 'book':
        aiLanguageText = 'AI: ${loc.aiLanguageFollowBook}';
        break;
      case 'system':
        aiLanguageText = 'AI: ${loc.aiLanguageFollowSystem}';
        break;
      case 'manual':
        final lang = settings.aiOutputLanguage;
        switch (lang) {
          case 'zh':
            aiLanguageText = 'AI: ${loc.chineseLanguage}';
            break;
          case 'en':
            aiLanguageText = 'AI: ${loc.englishLanguage}';
            break;
          case 'ja':
            aiLanguageText = 'AI: ${loc.japaneseLanguage}';
            break;
          default:
            aiLanguageText = 'AI: ${loc.chineseLanguage}';
            break;
        }
        break;
      default:
        aiLanguageText = 'AI: ${loc.aiLanguageFollowSystem}';
        break;
    }

    // 构建界面语言设置显示文本
    String uiLanguageText;
    switch (settings.uiLanguageMode) {
      case 'system':
        uiLanguageText = '${loc.uiDisplayLanguage}: ${loc.uiLanguageFollowSystem}';
        break;
      case 'manual':
        final lang = settings.uiLanguage;
        switch (lang) {
          case 'zh':
            uiLanguageText = '${loc.uiDisplayLanguage}: ${loc.chineseLanguage}';
            break;
          case 'en':
            uiLanguageText = '${loc.uiDisplayLanguage}: ${loc.englishLanguage}';
            break;
          case 'ja':
            uiLanguageText = '${loc.uiDisplayLanguage}: ${loc.japaneseLanguage}';
            break;
          default:
            uiLanguageText = '${loc.uiDisplayLanguage}: ${loc.chineseLanguage}';
            break;
        }
        break;
      default:
        uiLanguageText = '${loc.uiDisplayLanguage}: ${loc.uiLanguageFollowSystem}';
        break;
    }

    // 返回AI和界面语言设置的组合文本
    return '$aiLanguageText, $uiLanguageText';
  }

}