import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zhidu/l10n/app_localizations.dart';
import '../services/settings_service.dart';
import '../services/library_import_service.dart';
import '../services/book_service.dart';
import '../models/app_settings.dart';
import 'ai_config_screen.dart';

/// 设置页面 - 应用各项配置入口
///
/// 区块顺序：AI、主题、语言、书库、关于。
/// 设置项直接内联，修改后即时生效并自动保存。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  final _libraryPathController = TextEditingController();

  AppLocalizations get loc => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _libraryPathController.text =
        SettingsService().calibreLibraryPath.value ?? '';
    SettingsService().calibreLibraryPath.addListener(_onLibraryPathChanged);
  }

  @override
  void dispose() {
    SettingsService().calibreLibraryPath.removeListener(_onLibraryPathChanged);
    _libraryPathController.dispose();
    super.dispose();
  }

  /// 书库路径变更时同步输入框显示
  void _onLibraryPathChanged() {
    _libraryPathController.text =
        SettingsService().calibreLibraryPath.value ?? '';
    if (mounted) setState(() {});
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
          _buildSectionHeader(loc.themeSettingTitle),
          _buildThemeSection(),
          const SizedBox(height: 16),
          _buildSectionHeader(loc.languageSettingTitle),
          _buildLanguageSection(),
          const SizedBox(height: 16),
          _buildSectionHeader(loc.librarySettingsTitle),
          _buildLibrarySection(),
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
  /// 统一样式：粗体标题 + 主题色 + 适当间距
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

  Widget _buildSection({required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// 构建AI配置区块
  ///
  /// 提供AI服务配置入口：
  /// - 点击跳转到AI配置页面
  /// - 显示当前配置状态（provider/model 或 未配置）
  Widget _buildAiSection() {
    return _buildSection(children: [
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

  /// 构建主题设置区块
  ///
  /// 直接内联三种主题模式单选，即时生效并自动保存
  Widget _buildThemeSection() {
    return _buildSection(children: [
        ListenableBuilder(
          listenable: SettingsService().themeMode,
          builder: (context, _) {
            return RadioGroup<ThemeMode>(
              groupValue: SettingsService().themeMode.value,
              onChanged: (mode) {
                if (mode != null) {
                  SettingsService().setThemeMode(mode);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildThemeOption(
                    mode: ThemeMode.system,
                    title: loc.themeModeSystem,
                    subtitle: loc.themeModeSystemSubtitle,
                  ),
                  _buildThemeOption(
                    mode: ThemeMode.light,
                    title: loc.themeModeLight,
                    subtitle: loc.themeModeLightSubtitle,
                  ),
                  _buildThemeOption(
                    mode: ThemeMode.dark,
                    title: loc.themeModeDark,
                    subtitle: loc.themeModeDarkSubtitle,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// 构建语言设置区块
  ///
  /// 直接内联统一语言设置（AI 摘要/翻译与界面显示共用），即时生效并自动保存
  Widget _buildLanguageSection() {
    return _buildSection(children: [
        ListenableBuilder(
          listenable: SettingsService().languageSettings,
          builder: (context, _) {
            final settings = SettingsService().languageSettings.value;
            return RadioGroup<String>(
              groupValue: settings.languageMode,
              onChanged: (value) {
                if (value != null) _updateLanguageMode(value);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<String>(
                    value: 'system',
                    title: Text(loc.languageModeFollowSystem),
                    subtitle: Text(loc.languageModeSystemSubtitle),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  RadioListTile<String>(
                    value: 'manual',
                    title: Text(loc.languageModeManualSelect),
                    subtitle: Text(loc.languageModeManualSubtitle),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  if (settings.languageMode == 'manual')
                    _buildLanguageSelector(
                      title: loc.selectLanguage,
                      value: settings.language,
                      onChanged: (value) {
                        if (value != null) _updateLanguage(value);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// 手动语言选项
  List<(String, String)> _getLanguages() {
    return [
      ('zh', loc.chineseLanguage),
      ('en', loc.englishLanguage),
      ('ja', loc.japaneseLanguage),
    ];
  }

  /// 构建语言选择下拉框
  Widget _buildLanguageSelector({
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    final languages = _getLanguages();
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
                initialValue: languages.any((l) => l.$1 == value) ? value : 'zh',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                ),
                items: languages.map((lang) {
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

  /// 更新语言模式
  Future<void> _updateLanguageMode(String mode) async {
    if (mode != 'system' && mode != 'manual') return;
    final settings = SettingsService().languageSettings.value;
    if (settings.languageMode == mode) return;
    await SettingsService().updateLanguageSettings(
      settings.copyWith(languageMode: mode),
    );
  }

  /// 更新语言
  Future<void> _updateLanguage(String language) async {
    final settings = SettingsService().languageSettings.value;
    if (settings.language == language) return;
    await SettingsService().updateLanguageSettings(
      settings.copyWith(language: language),
    );
  }

  /// 构建主题选项（单选）
  Widget _buildThemeOption({
    required ThemeMode mode,
    required String title,
    required String subtitle,
  }) {
    return RadioListTile<ThemeMode>(
      value: mode,
      title: Text(title),
      subtitle: Text(subtitle),
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  /// 构建书库设置区块
  ///
  /// 一行内展示：标题 + 文件夹路径输入框（只读）+ 浏览按钮。
  Widget _buildLibrarySection() {
    final hasLibrary =
        (SettingsService().calibreLibraryPath.value?.isNotEmpty ?? false);
    return _buildSection(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(loc.calibreLibraryLocation),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _libraryPathController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: loc.noLibraries,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _browseCalibreLibrary,
                  child: Text(loc.browse),
                ),
                IconButton(
                  onPressed: hasLibrary ? _refreshCalibreLibrary : null,
                  icon: const Icon(Icons.refresh),
                  tooltip: loc.refresh,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _confirmClearBookshelf,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(loc.clearBookshelf),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  /// 浏览并选择 Calibre 书库文件夹（导入在后台进行，不显示进度）
  Future<void> _browseCalibreLibrary() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: loc.calibreLibraryLocation,
    );
    if (path == null || !mounted) return;

    // 路径未变化时不重复导入
    if (path == SettingsService().calibreLibraryPath.value) return;

    await SettingsService().setCalibreLibraryPath(path);
    if (!mounted) return;

    _libraryPathController.text = path;
    LibraryImportService().startImport(path);
  }

  /// 重新扫描 Calibre 书库，导入书架外的新增书籍
  void _refreshCalibreLibrary() {
    final path = SettingsService().calibreLibraryPath.value;
    if (path == null || path.isEmpty) return;
    LibraryImportService().startImport(path);
  }

  /// 确认并清空书架
  Future<void> _confirmClearBookshelf() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.clearBookshelf),
        content: Text(loc.clearBookshelfConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await BookService().clearAllBooks();
    if (!mounted) return;

    // 触发首页刷新（书架已空）
    LibraryImportService().refreshSignal.value++;
    _showSnackBar(loc.clearBookshelfDone);
  }

  /// 显示 SnackBar 提示
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 构建关于区块
  ///
  /// 显示应用名称、版本号、副标题等信息
  Widget _buildAboutSection() {
    return _buildSection(children: [
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
    final settings = SettingsService().settings.aiSettings;
    if (settings.isValid) {
      return '${settings.provider} / ${settings.model}';
    } else {
      return loc.notConfiguredClickToSet;
    }
  }

}