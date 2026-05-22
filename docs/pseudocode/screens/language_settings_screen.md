# Language Settings Screen - Pseudocode Documentation

## Overview

**File**: `lib/screens/language_settings_screen.dart`
**Purpose**: Configure AI output language and UI display language
**Pattern**: StatefulWidget with ListenableBuilder for reactive updates

---

## StatefulWidget Structure

```
LanguageSettingsScreen (StatefulWidget)
└── _LanguageSettingsScreenState (State)
    ├── Service: SettingsService
    ├── State: None (uses ListenableBuilder)
    └── Methods: _updateAiLanguageMode, _updateAiOutputLanguage, 
                 _updateUiLanguageMode, _updateUiLanguage
```

---

## State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_settingsService` | SettingsService | Settings management singleton |

---

## Language Mode Options

### AI Language Modes

```
AI_LANGUAGE_MODES = [
  ('book', '跟随书籍', '根据书籍内容语言自动选择'),
  ('system', '跟随系统', '根据系统语言设置自动选择'),
  ('manual', '手动选择', '用户指定AI输出语言')
]
```

### UI Language Modes

```
UI_LANGUAGE_MODES = [
  ('system', '跟随系统', '根据系统语言设置自动选择'),
  ('manual', '手动选择', '用户指定界面显示语言')
]
```

### Available Languages

```
LANGUAGES = [
  ('zh', '简体中文'),
  ('en', 'English'),
  ('ja', '日本語')
]
```

---

## Methods Pseudocode

### `_getAiLanguageModes(localizations)`

```
PROCEDURE _getAiLanguageModes(localizations):
  RETURN [
    ('book', localizations.aiLanguageFollowBook, localizations.aiLanguageModeBookSubtitle),
    ('system', localizations.aiLanguageFollowSystem, localizations.aiLanguageModeSystemSubtitle),
    ('manual', localizations.aiLanguageManualSelect, localizations.aiLanguageModeManualSubtitle)
  ]
END PROCEDURE
```

### `_getUiLanguageModes(localizations)`

```
PROCEDURE _getUiLanguageModes(localizations):
  RETURN [
    ('system', localizations.uiLanguageFollowSystem, localizations.uiLanguageModeSystemSubtitle),
    ('manual', localizations.uiLanguageManualSelect, localizations.uiLanguageModeManualSubtitle)
  ]
END PROCEDURE
```

### `_getLanguages(localizations)`

```
PROCEDURE _getLanguages(localizations):
  RETURN [
    ('zh', localizations.chineseLanguage),
    ('en', localizations.englishLanguage),
    ('ja', localizations.japaneseLanguage)
  ]
END PROCEDURE
```

### `_buildSection(title, subtitle, children)`

```
PROCEDURE _buildSection(title, subtitle, children):
  RETURN Column
    ├── Padding(16, 16, 16, 8): Column
    │   ├── Text: title (titleMedium, bold)
    │   └── Text: subtitle (bodySmall, grey)
    └── children (RadioListTile list)
END PROCEDURE
```

### `_buildLanguageSelector(localizations, title, value, onChanged)`

```
PROCEDURE _buildLanguageSelector(localizations, title, value, onChanged):
  languages = _getLanguages(localizations)  // 提取为局部变量，避免重复调用
  RETURN Padding(16, 8)
    └── Card
        └── Padding(16)
            └── Column
                ├── Text: title (titleSmall)
                ├── SizedBox(height: 8)
                └── DropdownButtonFormField<String>
                    ├── value: languages.contains(value) ? value : 'zh'
                    ├── decoration: OutlineInputBorder
                    ├── items: languages
                    └── onChanged: onChanged callback
END PROCEDURE
```

### `_updateAiLanguageMode(mode)`

```
ASYNC PROCEDURE _updateAiLanguageMode(mode):
  IF mode not in ['book', 'system', 'manual']: RETURN
  currentSettings = _settingsService.languageSettings.value
  IF currentSettings.aiLanguageMode == mode: RETURN
  
  newSettings = currentSettings.copyWith(aiLanguageMode: mode)
  AWAIT _settingsService.updateLanguageSettings(newSettings)
END PROCEDURE
```

### `_updateAiOutputLanguage(language)`

```
ASYNC PROCEDURE _updateAiOutputLanguage(language):
  currentSettings = _settingsService.languageSettings.value
  IF currentSettings.aiOutputLanguage == language: RETURN
  
  newSettings = currentSettings.copyWith(aiOutputLanguage: language)
  AWAIT _settingsService.updateLanguageSettings(newSettings)
END PROCEDURE
```

### `_updateUiLanguageMode(mode)`

```
ASYNC PROCEDURE _updateUiLanguageMode(mode):
  IF mode not in ['system', 'manual']: RETURN
  currentSettings = _settingsService.languageSettings.value
  IF currentSettings.uiLanguageMode == mode: RETURN
  
  newSettings = currentSettings.copyWith(uiLanguageMode: mode)
  AWAIT _settingsService.updateLanguageSettings(newSettings)
END PROCEDURE
```

### `_updateUiLanguage(language)`

```
ASYNC PROCEDURE _updateUiLanguage(language):
  currentSettings = _settingsService.languageSettings.value
  IF currentSettings.uiLanguage == language: RETURN
  
  newSettings = currentSettings.copyWith(uiLanguage: language)
  AWAIT _settingsService.updateLanguageSettings(newSettings)
END PROCEDURE
```

---

## Widget Tree Structure

```
Scaffold
├── AppBar
│   ├── Title: "语言设置"
│   └── centerTitle: true
│
└── Body: ListenableBuilder
    ├── listenable: _settingsService.languageSettings
    └── builder: (context, _)
        └── ListView
            ├── _buildSection: AI语言设置
            │   ├── Title: "AI语言设置"
            │   ├── Subtitle: "控制AI生成内容的语言"
            │   └── Children: RadioListTile for each mode
            │       ├── value: mode key
            │       ├── groupValue: currentSettings.aiLanguageMode
            │       ├── title: mode name
            │       ├── subtitle: mode description
            │       └── onChanged: _updateAiLanguageMode
            │
            ├── IF aiLanguageMode == 'manual':
            │   _buildLanguageSelector
            │   ├── title: "选择AI输出语言"
            │   ├── value: currentSettings.aiOutputLanguage
            │   └── onChanged: _updateAiOutputLanguage
            │
            ├── Divider(height: 32)
            │
            ├── _buildSection: 界面语言设置
            │   ├── Title: "界面语言设置"
            │   ├── Subtitle: "控制应用界面显示语言"
            │   └── Children: RadioListTile for each mode
            │       ├── value: mode key
            │       ├── groupValue: currentSettings.uiLanguageMode
            │       ├── title: mode name
            │       ├── subtitle: mode description
            │       └── onChanged: _updateUiLanguageMode
            │
            └── IF uiLanguageMode == 'manual':
                _buildLanguageSelector
                ├── title: "选择界面语言"
                ├── value: currentSettings.uiLanguage
                └── onChanged: _updateUiLanguage
```

---

## User Interaction Flows

### Flow 1: Change AI Language Mode

```
User selects radio option (book/system/manual)
    ↓
RadioListTile.onChanged triggered
    ↓
_updateAiLanguageMode(mode)
    ↓
Get current settings
    ↓
Create new LanguageSettings with copyWith
    ↓
Call SettingsService.updateLanguageSettings()
    ↓
Settings saved to settings.json
    ↓
ValueNotifier updates
    ↓
ListenableBuilder rebuilds
    ↓
IF mode == 'manual':
  Language selector dropdown appears
```

### Flow 2: Select AI Output Language

```
AI language mode is 'manual'
    ↓
Language selector visible
    ↓
User selects language from dropdown
    ↓
DropdownButtonFormField.onChanged
    ↓
_updateAiOutputLanguage(language)
    ↓
Create new settings with selected language
    ↓
Save to SettingsService
    ↓
AI will use this language for summaries
```

### Flow 3: Change UI Language Mode

```
User selects radio option (system/manual)
    ↓
RadioListTile.onChanged triggered
    ↓
_updateUiLanguageMode(mode)
    ↓
Get current settings
    ↓
Create new LanguageSettings
    ↓
Save to SettingsService
    ↓
IF mode == 'manual':
  Language selector appears
    ↓
User selects language
    ↓
_updateUiLanguage(language)
    ↓
App locale changes
    ↓
UI text updates to selected language
```

---

## Conditional Rendering Logic

### AI Language Selector Visibility

```
IF currentSettings.aiLanguageMode == 'manual':
  SHOW language selector dropdown
ELSE:
  HIDE language selector

Reason: Only show selector when user chooses manual mode
```

### UI Language Selector Visibility

```
IF currentSettings.uiLanguageMode == 'manual':
  SHOW language selector dropdown
ELSE:
  HIDE language selector

Reason: Only show selector when user chooses manual mode
```

---

## State Management Pattern

### ListenableBuilder Pattern

```
SettingsService.languageSettings (ValueNotifier<LanguageSettings>)
    ↓
ListenableBuilder listens to changes
    ↓
builder(context, _) re-executes on change
    ↓
UI reflects new settings immediately

Benefits:
├── No manual setState() needed
├── Automatic UI sync with settings
└── Clean separation of concerns
```

### Settings Update Flow

```
User action (radio/dropdown change)
    ↓
_updateXxx method called
    ↓
Create new LanguageSettings via copyWith
    ↓
SettingsService.updateLanguageSettings(newSettings)
    ├── Save to settings.json
    └── Update ValueNotifier.value
    ↓
ValueNotifier notifies listeners
    ↓
ListenableBuilder rebuilds
    ↓
UI shows new selection
```

---

## LanguageSettings Model Structure

```
LanguageSettings:
├── aiLanguageMode: String
│   ├── 'book' - Follow book content language
│   ├── 'system' - Follow system locale
│   └── 'manual' - User specified
│
├── aiOutputLanguage: String
│   ├── 'zh' - Chinese
│   ├── 'en' - English
│   └── 'ja' - Japanese
│
├── uiLanguageMode: String
│   ├── 'system' - Follow system locale
│   └── 'manual' - User specified
│
└── uiLanguage: String
    ├── 'zh' - Chinese
    ├── 'en' - English
    └── 'ja' - Japanese
```

---

## Service Integration

### SettingsService

```
READ: _settingsService.languageSettings.value
  - Returns current LanguageSettings
  - ValueNotifier pattern

WRITE: _settingsService.updateLanguageSettings(newSettings)
  - Validates settings
  - Saves to settings.json
  - Updates ValueNotifier
  - Triggers listener notifications
```

---

## Navigation Flow

```
SettingsScreen
    ↓ (tap 语言设置 ListTile)
Navigator.push(LanguageSettingsScreen)
    ↓
Language settings displayed
    ↓ (user changes settings)
Settings saved immediately
    ↓ (tap back)
Navigator.pop()
    ↓
Return to SettingsScreen
    ↓
Language status text updated
```

---

## Internationalization Support

```
AppLocalizations.of(context)
    ↓
Provides localized strings:
├── aiLanguageFollowBook
├── aiLanguageFollowSystem
├── aiLanguageManualSelect
├── uiLanguageFollowSystem
├── uiLanguageManualSelect
├── chineseLanguage
├── englishLanguage
├── japaneseLanguage
└── ... (all UI text)

Language files:
├── lib/l10n/app_zh.arb (Chinese)
├── lib/l10n/app_en.arb (English)
├── lib/l10n/app_ja.arb (Japanese)
```

---

## Data Persistence

```
settings.json structure:
{
  "languageSettings": {
    "aiLanguageMode": "manual",
    "aiOutputLanguage": "zh",
    "uiLanguageMode": "system",
    "uiLanguage": "zh"
  },
  ... (other settings)
}

Location: Documents/zhidu/settings.json
```