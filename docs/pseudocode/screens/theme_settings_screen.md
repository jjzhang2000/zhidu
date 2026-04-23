# Theme Settings Screen - Pseudocode Documentation

## Overview

**File**: `lib/screens/theme_settings_screen.dart`
**Purpose**: Application theme mode configuration
**Pattern**: Simple StatefulWidget with ListenableBuilder for reactive updates

---

## StatefulWidget Structure

```
ThemeSettingsScreen (StatefulWidget)
└── _ThemeSettingsScreenState (State)
    ├── Service: SettingsService
    ├── State: None (uses ListenableBuilder)
    └── Methods: _buildThemeOption()
```

---

## State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_settingsService` | SettingsService | Settings management singleton |

---

## Theme Mode Options

```
ThemeMode enum (from app_settings.dart):
├── ThemeMode.system - Follow system setting
├── ThemeMode.light - Force light theme
└── ThemeMode.dark - Force dark theme
```

---

## Methods Pseudocode

### `build(context)`

```
PROCEDURE build(context):
  localizations = AppLocalizations.of(context)
  
  RETURN Scaffold
    ├── AppBar
    │   ├── Title: Text(localizations.themeSettingsScreenTitle)
    │   └── centerTitle: true
    │
    └── Body: ListView
        ├── _buildThemeOption(system)
        ├── Divider()
        ├── _buildThemeOption(light)
        ├── Divider()
        └── _buildThemeOption(dark)
END PROCEDURE
```

### `_buildThemeOption(mode, title, subtitle, icon)`

```
PROCEDURE _buildThemeOption(mode, title, subtitle, icon):
  RETURN ListenableBuilder
    ├── listenable: _settingsService.themeMode
    └── builder: (context, _)
        └── RadioListTile<ThemeMode>
            ├── value: mode
            ├── groupValue: _settingsService.themeMode.value
            ├── onChanged: (selectedMode)
            │   └── IF selectedMode != null:
            │        _settingsService.setThemeMode(selectedMode)
            ├── title: Text(title)
            ├── subtitle: Text(subtitle)
            ├── secondary: Icon(icon)
            └── activeColor: Theme.of(context).colorScheme.primary
END PROCEDURE
```

---

## Widget Tree Structure

```
Scaffold
├── AppBar
│   ├── Title: "主题设置"
│   └── centerTitle: true
│
└── Body: ListView
    ├── _buildThemeOption(system)
    │   └── ListenableBuilder
    │       └── RadioListTile
    │           ├── value: ThemeMode.system
    │           ├── groupValue: current mode
    │           ├── title: "跟随系统"
    │           ├── subtitle: "自动跟随系统主题设置"
    │           ├── secondary: Icon(Icons.brightness_auto)
    │           └── onChanged: setThemeMode
    │
    ├── Divider()
    │
    ├── _buildThemeOption(light)
    │   └── ListenableBuilder
    │       └── RadioListTile
    │           ├── value: ThemeMode.light
    │           ├── groupValue: current mode
    │           ├── title: "亮色模式"
    │           ├── subtitle: "强制使用浅色主题"
    │           ├── secondary: Icon(Icons.light_mode)
    │           └── onChanged: setThemeMode
    │
    ├── Divider()
    │
    └── _buildThemeOption(dark)
    │   └── ListenableBuilder
    │       └── RadioListTile
    │           ├── value: ThemeMode.dark
    │           ├── groupValue: current mode
    │           ├── title: "暗色模式"
    │           ├── subtitle: "强制使用深色主题"
    │           ├── secondary: Icon(Icons.dark_mode)
    │           └── onChanged: setThemeMode
```

---

## User Interaction Flows

### Flow 1: Select Theme Mode

```
User opens Theme Settings Screen
    ↓
ListenableBuilder reads current themeMode
    ↓
RadioListTile shows current selection
    ↓
User taps different radio option
    ↓
RadioListTile.onChanged triggered
    ↓
_settingsService.setThemeMode(selectedMode)
    ↓
Settings saved to settings.json
    ↓
ValueNotifier.value updated
    ↓
ListenableBuilder rebuilds
    ↓
New selection shown immediately
    ↓
App theme changes globally
```

### Flow 2: Theme Change Propagation

```
SettingsService.setThemeMode(mode)
    ↓
Update ThemeSettings.mode
    ↓
Save to settings.json
    ↓
ValueNotifier.themeMode notifies listeners
    ↓
main.dart MaterialApp.themeMode listener
    ↓
App rebuilds with new theme
    ↓
All screens reflect new theme
```

---

## State Management Pattern

### ListenableBuilder Pattern

```
SettingsService.themeMode (ValueNotifier<ThemeMode>)
    ↓
ListenableBuilder listens to changes
    ↓
builder(context, _) re-executes on change
    ↓
RadioListTile.groupValue = _settingsService.themeMode.value
    ↓
Selection updates automatically

Benefits:
├── No manual setState() needed
├── Automatic UI sync with settings
├── Immediate theme change propagation
└── Clean reactive pattern
```

### Settings Update Flow

```
User selects new theme mode
    ↓
RadioListTile.onChanged callback
    ↓
_settingsService.setThemeMode(mode)
    ├── Validate mode
    ├── Update ThemeSettings
    ├── Save to settings.json
    └── Update ValueNotifier.value
    ↓
ValueNotifier notifies listeners
    ↓
All ListenableBuilders rebuild
    ↓
UI shows new selection
    ↓
App theme changes
```

---

## Theme Mode Descriptions

### System Mode

```
Title: "跟随系统"
Subtitle: "自动跟随系统主题设置"
Icon: Icons.brightness_auto

Behavior:
├── Windows: Follows Windows light/dark setting
├── macOS: Follows macOS appearance setting
├── Android: Follows system dark mode
├── iOS: Follows system appearance
└── Auto-switches when system changes
```

### Light Mode

```
Title: "亮色模式"
Subtitle: "强制使用浅色主题"
Icon: Icons.light_mode

Behavior:
├── Always shows light theme
├── Ignores system setting
├── White/light backgrounds
├── Dark text on light surfaces
└── Suitable for daytime reading
```

### Dark Mode

```
Title: "暗色模式"
Subtitle: "强制使用深色主题"
Icon: Icons.dark_mode

Behavior:
├── Always shows dark theme
├── Ignores system setting
├── Dark/black backgrounds
├── Light text on dark surfaces
└── Suitable for nighttime reading
```

---

## Service Integration

### SettingsService

```
READ: _settingsService.themeMode.value
  - Returns current ThemeMode
  - ValueNotifier pattern

WRITE: _settingsService.setThemeMode(mode)
  - Validates mode
  - Updates ThemeSettings
  - Saves to settings.json
  - Notifies listeners
```

---

## Navigation Flow

```
SettingsScreen
    ↓ (tap "主题设置" ListTile)
Navigator.push(ThemeSettingsScreen)
    ↓
Theme options displayed
    ↓ (user selects mode)
Theme changes immediately
    ↓ (tap back)
Navigator.pop()
    ↓
Return to SettingsScreen
    ↓
Theme status text updated
```

---

## Global Theme Propagation

```
main.dart MaterialApp
├── theme: AppTheme.lightTheme
├── darkTheme: AppTheme.darkTheme
└── themeMode: SettingsService().themeMode.value
    ↓
ListenableBuilder in main.dart
    ↓
When themeMode changes:
    ↓
MaterialApp.themeMode updates
    ↓
Entire app rebuilds
    ↓
All widgets use new theme colors
```

---

## Internationalization

```
AppLocalizations.of(context) provides:
├── themeSettingsScreenTitle
├── themeModeSystem
├── themeModeSystemSubtitle
├── themeModeLight
├── themeModeLightSubtitle
├── themeModeDark
└── themeModeDarkSubtitle

Language files:
├── lib/l10n/app_zh.arb (Chinese)
├── lib/l10n/app_en.arb (English)
└── lib/l10n/app_ja.arb (Japanese)
```

---

## Data Persistence

```
settings.json structure:
{
  "themeSettings": {
    "mode": "system" | "light" | "dark"
  },
  ... (other settings)
}

Location: Documents/zhidu/settings.json
```

---

## ThemeSettings Model

```
ThemeSettings:
└── mode: ThemeMode
    ├── ThemeMode.system (default)
    ├── ThemeMode.light
    └── ThemeMode.dark

Methods:
├── copyWith(mode: ThemeMode) → ThemeSettings
└── toJson() → Map
└── fromJson(Map) → ThemeSettings
```

---

## AppTheme Configuration

```
AppTheme (lib/utils/app_theme.dart):
├── lightTheme: ThemeData
│   ├── brightness: Brightness.light
│   ├── primaryColor: Colors.blue
│   ├── scaffoldBackgroundColor: Colors.white
│   └── ... (typography, components)
│
└── darkTheme: ThemeData
    ├── brightness: Brightness.dark
    ├── primaryColor: Colors.blue
    ├── scaffoldBackgroundColor: Colors.grey[900]
    └── ... (typography, components)
```

---

## Conditional Rendering

### Radio Selection State

```
RadioListTile.groupValue = _settingsService.themeMode.value

IF value == groupValue:
    Radio button shows selected state
ELSE:
    Radio button shows unselected state

Visual:
├── Selected: filled circle, primary color
└── Unselected: empty circle outline
```

---

## Error Handling

```
SettingsService handles:
├── Invalid mode values → Default to system
├── File read errors → Use default settings
├── File write errors → Log error, keep current
└── Corrupted JSON → Parse fallback
```

---

## Performance Considerations

```
ListenableBuilder benefits:
├── Only rebuilds when themeMode changes
├── Efficient listener pattern
├── No unnecessary rebuilds
└── Minimal memory overhead

Theme change impact:
├── Entire app rebuilds (MaterialApp)
├── All widgets get new theme data
├── Smooth transition (no animation)
└── Immediate visual feedback
```