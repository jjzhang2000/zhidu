# Settings Screen - 伪代码文档

## 概述

**文件**: `lib/screens/settings_screen.dart`
**用途**: 设置主入口页面，聚合 AI、外观、关于三个区块
**模式**: StatefulWidget + loc getter + ListenableBuilder 响应式显示

---

## StatefulWidget 结构

```
SettingsScreen (StatefulWidget)
└── _SettingsScreenState (State)
    ├── Service: SettingsService
    ├── Getter: loc → AppLocalizations.of(context)!
    ├── State: _version
    └── Methods: _loadVersion, _buildXxxSection, _getXxxStatus
```

---

## 状态变量

| 变量 | 类型 | 用途 |
|------|------|------|
| `_version` | String | 应用版本号 |
| `loc` | AppLocalizations | 国际化 getter（一次定义，全局复用） |

---

## 方法伪代码

### `initState()`

```
PROCEDURE initState():
  super.initState()
  _loadVersion()
END PROCEDURE
```

### `_loadVersion()`

```
ASYNC PROCEDURE _loadVersion():
  info = AWAIT PackageInfo.fromPlatform()
  IF mounted:
    setState():
      _version = info.version
END PROCEDURE
```

### `_buildSectionHeader(title)`

```
PROCEDURE _buildSectionHeader(title):
  RETURN Padding(horizontal: 16, vertical: 8)
    └── Text: title
        ├── style: titleMedium
        ├── fontWeight: bold
        └── color: primary
END PROCEDURE
```

### `_buildSection(children)`

```
PROCEDURE _buildSection(children):
  RETURN Card
    ├── margin: horizontal 16, vertical 4
    ├── elevation: 2
    └── Column
        └── children: children
END PROCEDURE
```

### `_buildAiSection()`

```
PROCEDURE _buildAiSection():
  RETURN _buildSection
    └── children: [
        ListenableBuilder
        ├── listenable: SettingsService().aiSettings
        └── builder: ListTile
            ├── leading: Icon(Icons.api)
            ├── title: Text(loc.aiServiceSettings)
            ├── subtitle: Text(_getAiConfigStatus())
            ├── trailing: Icon(Icons.chevron_right)
            └── onTap: Navigator.push(AiConfigScreen)
      ]
END PROCEDURE
```

### `_buildAppearanceSection()`

```
PROCEDURE _buildAppearanceSection():
  RETURN _buildSection
    └── children: [
        ListenableBuilder
        ├── listenable: SettingsService().themeMode
        └── builder: ListTile
            ├── leading: Icon(Icons.brightness_6)
            ├── title: Text(loc.themeSettingTitle)
            ├── subtitle: Text(_getThemeStatus())
            ├── trailing: Icon(Icons.chevron_right)
            └── onTap: Navigator.push(ThemeSettingsScreen),

        ListenableBuilder
        ├── listenable: SettingsService().languageSettings
        └── builder: ListTile
            ├── leading: Icon(Icons.language)
            ├── title: Text(loc.languageSettingTitle)
            ├── subtitle: Text(_getLanguageStatus())
            ├── trailing: Icon(Icons.chevron_right)
            └── onTap: Navigator.push(LanguageSettingsScreen)
      ]
END PROCEDURE
```

### `_buildAboutSection()`

```
PROCEDURE _buildAboutSection():
  RETURN _buildSection
    └── children: [
        ListTile
        ├── leading: Icon(Icons.apps)
        ├── title: Text(loc.appTitle)
        └── subtitle: Text("${loc.version} $_version"),

        ListTile
        ├── leading: Icon(Icons.code)
        ├── title: Text(loc.aiLayeredReader)
        └── subtitle: Text(loc.readThinThick)
      ]
END PROCEDURE
```

### `_getAiConfigStatus()`

```
PROCEDURE _getAiConfigStatus():
  settings = SettingsService().settings.aiSettings

  IF settings.isValid:
    RETURN "${settings.provider} - ${settings.model}"
  ELSE:
    RETURN loc.notConfiguredClickToSet
END PROCEDURE
```

### `_getThemeStatus()`

```
PROCEDURE _getThemeStatus():
  mode = SettingsService().settings.themeSettings.mode

  SWITCH mode:
    CASE ThemeMode.system:
      RETURN loc.themeModeSystem
    CASE ThemeMode.light:
      RETURN loc.themeModeLight
    CASE ThemeMode.dark:
      RETURN loc.themeModeDark
END PROCEDURE
```

### `_getLanguageStatus()`

```
PROCEDURE _getLanguageStatus():
  settings = SettingsService().settings.languageSettings

  aiLanguageText = BUILD based on settings.aiLanguageMode:
    'book' → "AI: ${loc.aiLanguageFollowBook}"
    'system' → "AI: ${loc.aiLanguageFollowSystem}"
    'manual' → "AI: ${languageName}"

  uiLanguageText = BUILD based on settings.uiLanguageMode:
    'system' → "${loc.uiDisplayLanguage}: ${loc.uiLanguageFollowSystem}"
    'manual' → "${loc.uiDisplayLanguage}: ${languageName}"

  RETURN "$aiLanguageText, $uiLanguageText"
END PROCEDURE
```

---

## Widget 树结构

```
Scaffold
├── AppBar
│   ├── Title: loc.settingsTitle
│   └── centerTitle: true
│
└── Body: ListView
    ├── _buildSectionHeader(loc.aiConfigTitle)
    ├── _buildAiSection()
    ├── SizedBox(height: 16)
    ├── _buildSectionHeader(loc.appearanceSettingTitle)
    ├── _buildAppearanceSection()
    ├── SizedBox(height: 16)
    ├── _buildSectionHeader(loc.aboutTitle)
    ├── _buildAboutSection()
    └── SizedBox(height: 24)
```

### AI 区块

```
Card
└── ListenableBuilder
    └── ListTile
        ├── leading: Icon(Icons.api)
        ├── title: loc.aiServiceSettings
        ├── subtitle: "provider - model" OR loc.notConfiguredClickToSet
        ├── trailing: Icon(Icons.chevron_right)
        └── onTap: → AiConfigScreen
```

### 外观区块

```
Card
├── ListenableBuilder (themeMode)
│   └── ListTile
│       ├── leading: Icon(Icons.brightness_6)
│       ├── title: loc.themeSettingTitle
│       ├── subtitle: loc.themeModeSystem/Light/Dark
│       ├── trailing: Icon(Icons.chevron_right)
│       └── onTap: → ThemeSettingsScreen
│
└── ListenableBuilder (languageSettings)
    └── ListTile
        ├── leading: Icon(Icons.language)
        ├── title: loc.languageSettingTitle
        ├── subtitle: "AI: xxx, ${loc.uiDisplayLanguage}: xxx"
        ├── trailing: Icon(Icons.chevron_right)
        └── onTap: → LanguageSettingsScreen
```

### 关于区块

```
Card
├── ListTile (应用名称)
│   ├── leading: Icon(Icons.apps)
│   ├── title: loc.appTitle
│   └── subtitle: "${loc.version} $_version"
│
└── ListTile (描述)
    ├── leading: Icon(Icons.code)
    ├── title: loc.aiLayeredReader
    └── subtitle: loc.readThinThick
```

---

## 用户交互流程

### AI 配置

```
用户点击 "AI服务设置" ListTile
    ↓
Navigator.push(AiConfigScreen)
    ↓
用户配置 provider/apiKey/model
    ↓
返回 SettingsScreen
    ↓
ListenableBuilder 检测变化 → 状态文本自动更新
```

### 主题设置

```
用户点击 "主题设置" ListTile
    ↓
Navigator.push(ThemeSettingsScreen)
    ↓
用户选择模式 → 即时保存
    ↓
返回 SettingsScreen → 主题状态文本更新
```

### 语言设置

```
用户点击 "语言设置" ListTile
    ↓
Navigator.push(LanguageSettingsScreen)
    ↓
用户配置 AI/UI 语言 → 即时保存
    ↓
返回 SettingsScreen → 语言状态文本更新
```

---

## 状态管理模式

### loc Getter

```
AppLocalizations get loc => AppLocalizations.of(context)!

一次定义，所有方法共享：
├── 避免 7 处重复 final loc = AppLocalizations.of(context)!
├── 每次 build 时自动获取最新 locale
└── 语言切换时随 widget 重建自动更新
```

### ListenableBuilder 响应式

```
SettingsService().aiSettings (ValueNotifier)
    ↓
ListenableBuilder 监听变化
    ↓
_getAiConfigStatus() 读取最新设置
    ↓
Subtitle 实时显示当前 provider/model
```

---

## Service 集成

```
SettingsService
├── READ: settings.aiSettings / themeSettings / languageSettings
├── LISTEN: aiSettings / themeMode / languageSettings (ValueNotifier)
└── 导航目标: AiConfigScreen / ThemeSettingsScreen / LanguageSettingsScreen
```

---

## 导航流程

```
HomeScreen (AppBar 设置图标)
    ↓
Navigator.push(SettingsScreen)
    ↓
├── AI配置 → AiConfigScreen
├── 主题设置 → ThemeSettingsScreen
├── 语言设置 → LanguageSettingsScreen
└── 关于 (信息展示)
    ↓
Navigator.pop()
    ↓
返回 HomeScreen
```

---

## 国际化

```
loc (AppLocalizations) 提供:
├── settingsTitle
├── aiConfigTitle / aiServiceSettings / notConfiguredClickToSet
├── appearanceSettingTitle / themeSettingTitle / languageSettingTitle
├── themeModeSystem/Light/Dark
├── aboutTitle / appTitle / version
├── aiLayeredReader / readThinThick
├── aiLanguageFollowBook/System / chineseLanguage/englishLanguage/japaneseLanguage
└── uiDisplayLanguage / uiLanguageFollowSystem
```
