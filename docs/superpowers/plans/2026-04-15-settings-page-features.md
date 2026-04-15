# Settings Page Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement four settings features: AI configuration, theme switching, backup/recovery, and language settings.

**Architecture:** Create SettingsService (singleton) to manage all config items with ValueNotifier for global listening. Each feature has its own settings screen. Config stored in Documents/zhidu/settings.json.

**Tech Stack:** Flutter, SharedPreferences (optional), FilePicker, existing AIService/ExportService/BookService

---

## Task 1: Create SettingsService and AppSettings Model

**Files:**
- Create: `lib/models/app_settings.dart`
- Create: `lib/services/settings_service.dart`

- [ ] **Step 1: Create AppSettings model**

```dart
// lib/models/app_settings.dart
class AppSettings {
  final AiSettings ai;
  final ThemeSettings theme;
  final StorageSettings storage;
  final LanguageSettings language;

  AppSettings({
    required this.ai,
    required this.theme,
    required this.storage,
    required this.language,
  });

  factory AppSettings.defaults() => AppSettings(
    ai: AiSettings.defaults(),
    theme: ThemeSettings.defaults(),
    storage: StorageSettings.defaults(),
    language: LanguageSettings.defaults(),
  );

  Map<String, dynamic> toJson();
  factory AppSettings.fromJson(Map<String, dynamic> json);
}

class AiSettings {
  final String provider;
  final String apiKey;
  final String model;
  final String baseUrl;

  AiSettings({...});
  factory AiSettings.defaults() => AiSettings(
    provider: 'qwen',
    apiKey: '',
    model: 'qwen-plus',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  );
  bool get isValid => apiKey.isNotEmpty && apiKey != 'YOUR_*_API_KEY_HERE';
}

class ThemeSettings {
  final String mode; // 'system' | 'light' | 'dark'
  ThemeSettings({required this.mode});
  factory ThemeSettings.defaults() => ThemeSettings(mode: 'system');
}

class StorageSettings {
  final String booksDirectory;
  final String backupDirectory;
  final bool autoBackupEnabled;
  final String autoBackupInterval; // 'daily' | 'weekly'
  final DateTime? lastBackupTime;
  StorageSettings({...});
  factory StorageSettings.defaults();
}

class LanguageSettings {
  final String aiOutputLanguage; // 'auto_book' | 'system' | 'manual'
  final String manualLanguage; // 'zh' | 'en' | 'ja'
  LanguageSettings({...});
  factory LanguageSettings.defaults() => LanguageSettings(
    aiOutputLanguage: 'auto_book',
    manualLanguage: 'zh',
  );
}
```

- [ ] **Step 2: Create SettingsService**

```dart
// lib/services/settings_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import 'log_service.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _log = LogService();
  AppSettings _settings = AppSettings.defaults();
  
  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);
  final ValueNotifier<AiSettings> aiSettingsNotifier = ValueNotifier(AiSettings.defaults());
  final ValueNotifier<LanguageSettings> languageSettingsNotifier = ValueNotifier(LanguageSettings.defaults());

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/zhidu/settings.json');
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      _settings = AppSettings.fromJson(json);
    } else {
      await _saveSettings();
    }
    _updateNotifiers();
  }

  Future<void> _saveSettings() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/zhidu/settings.json');
    await file.writeAsString(jsonEncode(_settings.toJson()));
  }

  void _updateNotifiers() {
    final modeMap = {'system': ThemeMode.system, 'light': ThemeMode.light, 'dark': ThemeMode.dark};
    themeModeNotifier.value = modeMap[_settings.theme.mode] ?? ThemeMode.system;
    aiSettingsNotifier.value = _settings.ai;
    languageSettingsNotifier.value = _settings.language;
  }

  Future<void> updateAiSettings(AiSettings ai) async {
    _settings = AppSettings(
      ai: ai,
      theme: _settings.theme,
      storage: _settings.storage,
      language: _settings.language,
    );
    await _saveSettings();
    aiSettingsNotifier.value = ai;
  }

  Future<void> updateThemeMode(String mode) async {
    _settings = AppSettings(
      ai: _settings.ai,
      theme: ThemeSettings(mode: mode),
      storage: _settings.storage,
      language: _settings.language,
    );
    await _saveSettings();
    final modeMap = {'system': ThemeMode.system, 'light': ThemeMode.light, 'dark': ThemeMode.dark};
    themeModeNotifier.value = modeMap[mode] ?? ThemeMode.system;
  }

  Future<void> updateLanguageSettings(LanguageSettings language) async {
    _settings = AppSettings(
      ai: _settings.ai,
      theme: _settings.theme,
      storage: _settings.storage,
      language: language,
    );
    await _saveSettings();
    languageSettingsNotifier.value = language;
  }

  AppSettings get settings => _settings;
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/models/app_settings.dart lib/services/settings_service.dart
git commit -m "feat: add SettingsService and AppSettings model"
```

---

## Task 2: Create StoragePathService

**Files:**
- Create: `lib/services/storage_path_service.dart`

- [ ] **Step 1: Create StoragePathService**

```dart
// lib/services/storage_path_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import 'settings_service.dart';
import 'log_service.dart';

class StoragePathService {
  static final StoragePathService _instance = StoragePathService._internal();
  factory StoragePathService() => _instance;
  StoragePathService._internal();

  final _log = LogService();
  final _settingsService = SettingsService();

  Future<String> get booksDirectory async {
    final settings = _settingsService.settings.storage;
    if (settings.booksDirectory.isNotEmpty) {
      return settings.booksDirectory;
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/zhidu/books';
  }

  Future<String> get backupDirectory async {
    final settings = _settingsService.settings.storage;
    if (settings.backupDirectory.isNotEmpty) {
      return settings.backupDirectory;
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/zhidu/backups';
  }

  Future<String?> pickBooksDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择书籍存放目录');
    if (result != null) {
      await _updateBooksDirectory(result);
      return result;
    }
    return null;
  }

  Future<String?> pickBackupDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择备份目录');
    if (result != null) {
      await _updateBackupDirectory(result);
      return result;
    }
    return null;
  }

  Future<void> _updateBooksDirectory(String path) async {
    final settings = _settingsService.settings;
    final newStorage = StorageSettings(
      booksDirectory: path,
      backupDirectory: settings.storage.backupDirectory,
      autoBackupEnabled: settings.storage.autoBackupEnabled,
      autoBackupInterval: settings.storage.autoBackupInterval,
      lastBackupTime: settings.storage.lastBackupTime,
    );
    // Update settings...
  }

  Future<void> _updateBackupDirectory(String path) async {
    // Similar implementation
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/storage_path_service.dart
git commit -m "feat: add StoragePathService for directory management"
```

---

## Task 3: Modify AIService to use SettingsService

**Files:**
- Modify: `lib/services/ai_service.dart`

- [ ] **Step 1: Add reloadConfig method**

```dart
// In ai_service.dart, modify init() and add reloadConfig()

Future<void> init() async {
  await reloadConfig();
}

Future<void> reloadConfig() async {
  final settingsService = SettingsService();
  final aiSettings = settingsService.settings.ai;
  if (aiSettings.isValid) {
    _config = AIConfig(
      provider: aiSettings.provider,
      apiKey: aiSettings.apiKey,
      model: aiSettings.model,
      baseUrl: aiSettings.baseUrl,
    );
    _log.d('AIService', 'AI配置加载成功: ${_config?.provider}, model: ${_config?.model}');
  } else {
    _log.w('AIService', 'AI服务未配置或API Key无效');
    _config = null;
  }
}
```

- [ ] **Step 2: Remove old ai_config.json reading logic**

Delete the old init() method that reads from File('ai_config.json')

- [ ] **Step 3: Commit**

```bash
git add lib/services/ai_service.dart
git commit -m "refactor: AIService uses SettingsService for config"
```

---

## Task 4: Create AI Config Screen

**Files:**
- Create: `lib/screens/ai_config_screen.dart`

- [ ] **Step 1: Create AiConfigScreen**

```dart
// lib/screens/ai_config_screen.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/ai_service.dart';
import '../models/app_settings.dart';

class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({super.key});
  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<AiConfigScreen> {
  final _settingsService = SettingsService();
  final _aiService = AIService();
  
  String _provider = 'qwen';
  String _apiKey = '';
  String _model = 'qwen-plus';
  String _baseUrl = '';
  bool _obscureApiKey = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final ai = _settingsService.settings.ai;
    _provider = ai.provider;
    _apiKey = ai.apiKey;
    _model = ai.model;
    _baseUrl = ai.baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI配置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider dropdown
          // API Key input with obscure toggle
          // Model dropdown (dynamic based on provider)
          // Base URL input
          // Test connection button
          // Save button
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    // Test API call
    setState(() => _isTesting = false);
  }

  Future<void> _saveConfig() async {
    final aiSettings = AiSettings(
      provider: _provider,
      apiKey: _apiKey,
      model: _model,
      baseUrl: _baseUrl,
    );
    await _settingsService.updateAiSettings(aiSettings);
    await _aiService.reloadConfig();
    Navigator.pop(context);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/ai_config_screen.dart
git commit -m "feat: add AiConfigScreen for in-app AI configuration"
```

---

## Task 5: Create Theme Settings Screen

**Files:**
- Create: `lib/screens/theme_settings_screen.dart`

- [ ] **Step 1: Create ThemeSettingsScreen**

```dart
// lib/screens/theme_settings_screen.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});
  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final _settingsService = SettingsService();
  String _mode = 'system';

  @override
  void initState() {
    super.initState();
    _mode = _settingsService.settings.theme.mode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('主题设置')),
      body: ListView(
        children: [
          RadioListTile<String>(
            title: const Text('跟随系统'),
            value: 'system',
            groupValue: _mode,
            onChanged: (v) => _updateMode(v!),
          ),
          RadioListTile<String>(
            title: const Text('亮色模式'),
            value: 'light',
            groupValue: _mode,
            onChanged: (v) => _updateMode(v!),
          ),
          RadioListTile<String>(
            title: const Text('暗色模式'),
            value: 'dark',
            groupValue: _mode,
            onChanged: (v) => _updateMode(v!),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMode(String mode) async {
    setState(() => _mode = mode);
    await _settingsService.updateThemeMode(mode);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/theme_settings_screen.dart
git commit -m "feat: add ThemeSettingsScreen"
```

---

## Task 6: Modify ZhiduApp to listen theme changes

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add SettingsService init in main()**

```dart
// In main.dart main() function, add:
await SettingsService().init();
```

- [ ] **Step 2: Modify ZhiduApp to StatefulWidget**

```dart
class ZhiduApp extends StatefulWidget {
  const ZhiduApp({super.key});
  @override
  State<ZhiduApp> createState() => _ZhiduAppState();
}

class _ZhiduAppState extends State<ZhiduApp> {
  final _settingsService = SettingsService();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _settingsService.themeModeNotifier,
      builder: (context, mode, child) {
        return MaterialApp(
          title: '智读',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "refactor: ZhiduApp listens to theme mode changes"
```

---

## Task 7: Create Language Settings Screen

**Files:**
- Create: `lib/screens/language_settings_screen.dart`

- [ ] **Step 1: Create LanguageSettingsScreen**

```dart
// lib/screens/language_settings_screen.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});
  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final _settingsService = SettingsService();
  String _mode = 'auto_book';
  String _manualLanguage = 'zh';

  @override
  void initState() {
    super.initState();
    final lang = _settingsService.settings.language;
    _mode = lang.aiOutputLanguage;
    _manualLanguage = lang.manualLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('语言设置')),
      body: ListView(
        children: [
          RadioListTile<String>(
            title: const Text('书籍语言（自动判断）'),
            subtitle: const Text('AI根据书籍内容自动识别语言'),
            value: 'auto_book',
            groupValue: _mode,
            onChanged: (v) => _updateMode(v!),
          ),
          RadioListTile<String>(
            title: const Text('跟随系统'),
            value: 'system',
            groupValue: _mode,
            onChanged: (v) => _updateMode(v!),
          ),
          RadioListTile<String>(
            title: const Text('手动选择'),
            value: 'manual',
            groupValue: _mode,
            onChanged: (v) => _updateMode(v!),
          ),
          if (_mode == 'manual')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                value: _manualLanguage,
                items: [
                  DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ja', child: Text('日本語')),
                ],
                onChanged: (v) => _updateManualLanguage(v!),
                decoration: const InputDecoration(labelText: '选择语言'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateMode(String mode) async {
    setState(() => _mode = mode);
    await _saveSettings();
  }

  Future<void> _updateManualLanguage(String lang) async {
    setState(() => _manualLanguage = lang);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    final langSettings = LanguageSettings(
      aiOutputLanguage: _mode,
      manualLanguage: _manualLanguage,
    );
    await _settingsService.updateLanguageSettings(langSettings);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/language_settings_screen.dart
git commit -m "feat: add LanguageSettingsScreen"
```

---

## Task 8: Modify AiPrompts to inject language instruction

**Files:**
- Modify: `lib/services/ai_prompts.dart`

- [ ] **Step 1: Add language parameter to prompts**

```dart
// In ai_prompts.dart, modify all prompt methods to accept language parameter

static String chapterSummary({
  String? chapterTitle,
  required String content,
  String languageInstruction = '', // Add this parameter
}) {
  final langInstruction = languageInstruction.isEmpty 
    ? '' 
    : '\n\n$languageInstruction';
  
  return '''...existing prompt...
$langInstruction''';
}

static String getLanguageInstruction(String mode, String manualLanguage) {
  switch (mode) {
    case 'auto_book':
      return '根据书籍内容的语言，使用相同语言输出摘要。';
    case 'system':
      return '根据系统语言设置，使用对应语言输出摘要。';
    case 'manual':
      switch (manualLanguage) {
        case 'zh': return '请用中文输出摘要。';
        case 'en': return 'Please respond in English for the summary.';
        case 'ja': return '摘要は日本語で出力してください。';
        default: return '';
      }
    default:
      return '';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/ai_prompts.dart
git commit -m "refactor: AiPrompts supports language instruction injection"
```

---

## Task 9: Modify AIService to inject language instruction

**Files:**
- Modify: `lib/services/ai_service.dart`

- [ ] **Step 1: Get language setting before generating summary**

```dart
// In ai_service.dart, modify generateFullChapterSummary()

Future<String?> generateFullChapterSummary(
  String content, {
  String? chapterTitle,
}) async {
  // ...existing validation...
  
  final settingsService = SettingsService();
  final langSettings = settingsService.settings.language;
  final langInstruction = AiPrompts.getLanguageInstruction(
    langSettings.aiOutputLanguage,
    langSettings.manualLanguage,
  );

  final prompt = AiPrompts.chapterSummary(
    chapterTitle: chapterTitle,
    content: content,
    languageInstruction: langInstruction,
  );

  return await _callAI(prompt);
}
```

- [ ] **Step 2: Apply same pattern to other generate methods**

Apply similar changes to generateBookSummaryFromPreface and generateBookSummary

- [ ] **Step 3: Commit**

```bash
git add lib/services/ai_service.dart
git commit -m "refactor: AIService injects language instruction from settings"
```

---

## Task 10: Modify ExportService for full backup

**Files:**
- Modify: `lib/services/export_service.dart`

- [ ] **Step 1: Add settings backup**

```dart
// In export_service.dart, modify exportAllDataToJson()

Future<String?> exportAllDataToJson() async {
  final summaries = await _summaryService.getAllSummaries();
  final settingsService = SettingsService();
  final storagePathService = StoragePathService();
  
  final data = {
    'exportTime': DateTime.now().toIso8601String(),
    'version': '1.1',
    'books': _bookService.books.map((b) => b.toJson()).toList(),
    'summaries': summaries.map((s) => s.toJson()).toList(),
    'settings': settingsService.settings.toJson(), // Add settings
  };
  
  final backupDir = await storagePathService.backupDirectory;
  final fileName = 'zhidu_backup_${DateTime.now().millisecondsSinceEpoch}.json';
  final filePath = '$backupDir/$fileName';
  
  final file = File(filePath);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  
  return filePath;
}
```

- [ ] **Step 2: Modify importFromJson to restore settings**

```dart
// Add settings restoration in importFromJson()

Future<bool> importFromJson(String filePath) async {
  // ...existing parsing logic...
  
  // Restore settings
  if (data['settings'] != null) {
    final settings = AppSettings.fromJson(data['settings']);
    final settingsService = SettingsService();
    await settingsService.updateAllSettings(settings);
    await AIService().reloadConfig();
  }
  
  return true;
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/export_service.dart
git commit -m "refactor: ExportService includes settings in backup"
```

---

## Task 11: Implement auto backup check

**Files:**
- Modify: `lib/services/settings_service.dart`

- [ ] **Step 1: Add checkAutoBackup method**

```dart
// In settings_service.dart

Future<void> checkAutoBackup() async {
  final storage = _settings.storage;
  if (!storage.autoBackupEnabled) return;
  
  final lastBackup = storage.lastBackupTime;
  if (lastBackup == null) {
    await _performAutoBackup();
    return;
  }
  
  final now = DateTime.now();
  final diff = now.difference(lastBackup);
  final threshold = storage.autoBackupInterval == 'daily' 
    ? const Duration(hours: 24)
    : const Duration(days: 7);
  
  if (diff >= threshold) {
    await _performAutoBackup();
  }
}

Future<void> _performAutoBackup() async {
  final exportService = ExportService();
  final storagePathService = StoragePathService();
  
  final backupDir = await storagePathService.backupDirectory;
  final summaries = await SummaryService().getAllSummaries();
  
  final data = {
    'exportTime': DateTime.now().toIso8601String(),
    'version': '1.1',
    'books': BookService().books.map((b) => b.toJson()).toList(),
    'summaries': summaries.map((s) => s.toJson()).toList(),
    'settings': _settings.toJson(),
  };
  
  final file = File('$backupDir/auto_backup.json');
  await file.writeAsString(jsonEncode(data));
  
  // Update lastBackupTime
  _settings = AppSettings(
    ai: _settings.ai,
    theme: _settings.theme,
    storage: StorageSettings(
      booksDirectory: _settings.storage.booksDirectory,
      backupDirectory: _settings.storage.backupDirectory,
      autoBackupEnabled: _settings.storage.autoBackupEnabled,
      autoBackupInterval: _settings.storage.autoBackupInterval,
      lastBackupTime: DateTime.now(),
    ),
    language: _settings.language,
  );
  await _saveSettings();
}
```

- [ ] **Step 2: Call checkAutoBackup in main()**

```dart
// In main.dart main() function, after all services init:

await SettingsService().checkAutoBackup();
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/settings_service.dart lib/main.dart
git commit -m "feat: implement auto backup check on startup"
```

---

## Task 12: Create Backup Settings Screen

**Files:**
- Create: `lib/screens/backup_settings_screen.dart`

- [ ] **Step 1: Create BackupSettingsScreen**

```dart
// lib/screens/backup_settings_screen.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/export_service.dart';
import '../services/storage_path_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});
  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _settingsService = SettingsService();
  final _exportService = ExportService();
  final _storagePathService = StoragePathService();
  
  bool _autoBackupEnabled = false;
  String _autoBackupInterval = 'daily';
  String _backupDirectory = '';
  DateTime? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    final storage = _settingsService.settings.storage;
    _autoBackupEnabled = storage.autoBackupEnabled;
    _autoBackupInterval = storage.autoBackupInterval;
    _lastBackupTime = storage.lastBackupTime;
    _loadBackupDirectory();
  }

  Future<void> _loadBackupDirectory() async {
    final dir = await _storagePathService.backupDirectory;
    setState(() => _backupDirectory = dir);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('备份目录'),
            subtitle: Text(_backupDirectory),
            trailing: const Icon(Icons.folder),
            onTap: _pickBackupDirectory,
          ),
          ListTile(
            title: const Text('上次备份时间'),
            subtitle: Text(_lastBackupTime?.toString() ?? '从未备份'),
          ),
          SwitchListTile(
            title: const Text('自动备份'),
            value: _autoBackupEnabled,
            onChanged: _toggleAutoBackup,
          ),
          if (_autoBackupEnabled)
            DropdownButtonFormField<String>(
              value: _autoBackupInterval,
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('每天')),
                DropdownMenuItem(value: 'weekly', child: Text('每周')),
              ],
              onChanged: _updateInterval,
              decoration: const InputDecoration(labelText: '备份频率'),
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.backup),
            label: const Text('备份数据'),
            onPressed: _backupNow,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('恢复数据'),
            onPressed: _restoreData,
          ),
        ],
      ),
    );
  }

  Future<void> _pickBackupDirectory() async {
    final dir = await _storagePathService.pickBackupDirectory();
    if (dir != null) setState(() => _backupDirectory = dir);
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    setState(() => _autoBackupEnabled = enabled);
    // Save to settings
  }

  Future<void> _updateInterval(String interval) async {
    setState(() => _autoBackupInterval = interval);
    // Save to settings
  }

  Future<void> _backupNow() async {
    // Call ExportService
  }

  Future<void> _restoreData() async {
    // Show confirmation dialog, then call ExportService.pickAndImportBackup()
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/backup_settings_screen.dart
git commit -m "feat: add BackupSettingsScreen with auto backup options"
```

---

## Task 13: Create Storage Settings Screen

**Files:**
- Create: `lib/screens/storage_settings_screen.dart`

- [ ] **Step 1: Create StorageSettingsScreen**

```dart
// lib/screens/storage_settings_screen.dart
import 'package:flutter/material.dart';
import '../services/storage_path_service.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});
  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final _storagePathService = StoragePathService();
  String _booksDirectory = '';

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    final dir = await _storagePathService.booksDirectory;
    setState(() => _booksDirectory = dir);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('存储路径设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('书籍存放目录'),
            subtitle: Text(_booksDirectory),
            trailing: const Icon(Icons.folder),
            onTap: _pickDirectory,
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('注意：更改目录后，需要手动迁移现有数据。', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDirectory() async {
    final dir = await _storagePathService.pickBooksDirectory();
    if (dir != null) setState(() => _booksDirectory = dir);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/storage_settings_screen.dart
git commit -m "feat: add StorageSettingsScreen"
```

---

## Task 14: Refactor Settings Screen

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Refactor SettingsScreen to show all settings groups**

```dart
// lib/screens/settings_screen.dart - Add new sections

Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: ListView(
      children: [
        _buildSection(title: 'AI配置', icon: Icons.smart_toy, children: [
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('AI服务配置'),
            subtitle: Text(_getAiConfigStatus()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiConfigScreen())),
          ),
        ]),
        const Divider(),
        _buildSection(title: '外观设置', icon: Icons.palette, children: [
          ListTile(
            leading: const Icon(Icons brightness_6),
            title: const Text('主题设置'),
            subtitle: Text(_getThemeStatus()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言设置'),
            subtitle: Text(_getLanguageStatus()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageSettingsScreen())),
          ),
        ]),
        const Divider(),
        _buildSection(title: '数据管理', icon: Icons.storage, children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('存储路径设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageSettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('备份设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupSettingsScreen())),
          ),
        ]),
        const Divider(),
        _buildDataSection(bookCount, summaryCount),
        const Divider(),
        _buildAboutSection(),
      ],
    ),
  );
}
```

- [ ] **Step 2: Add status helper methods**

```dart
String _getAiConfigStatus() {
  final ai = SettingsService().settings.ai;
  return ai.isValid ? '${ai.provider} - ${ai.model}' : '未配置';
}

String _getThemeStatus() {
  final mode = SettingsService().settings.theme.mode;
  const map = {'system': '跟随系统', 'light': '亮色', 'dark': '暗色'};
  return map[mode] ?? '';
}

String _getLanguageStatus() {
  final lang = SettingsService().settings.language;
  const map = {'auto_book': '书籍语言', 'system': '跟随系统', 'manual': '手动选择'};
  return map[lang.aiOutputLanguage] ?? '';
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "refactor: SettingsScreen shows all settings groups"
```

---

## Task 15: Add imports and verify compilation

**Files:**
- Verify: All modified files have correct imports

- [ ] **Step 1: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

- [ ] **Step 2: Fix any import issues**

Add missing imports if flutter analyze shows errors

- [ ] **Step 3: Run flutter test**

```bash
flutter test
```

Expected: All tests pass

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete settings page features implementation"
```

---

## Summary

This plan implements all four settings features in priority order:
1. AI configuration (Tasks 1-4, 8-9)
2. Theme settings (Tasks 5-6)
3. Backup/recovery (Tasks 10-13)
4. Language settings (Tasks 7, 14)

Total: 15 tasks, approximately 75 steps.