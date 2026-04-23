# Settings Screen - Pseudocode Documentation

## Overview

**File**: `lib/screens/settings_screen.dart`
**Purpose**: Main settings hub with AI, appearance, export, and about sections
**Pattern**: StatefulWidget with ListenableBuilder for reactive settings display

---

## StatefulWidget Structure

```
SettingsScreen (StatefulWidget)
└── _SettingsScreenState (State)
    ├── Services: ExportService, BookService, SummaryService, SettingsService
    ├── State: _summaryCount, _isExporting
    └── Methods: _loadSummaryCount, _exportBookSummaries, status getters
```

---

## State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_exportService` | ExportService | Markdown export service |
| `_bookService` | BookService | Book management |
| `_summaryService` | SummaryService | Summary operations |
| `_settingsService` | SettingsService | Settings management |
| `_summaryCount` | int | Total summary count |
| `_isExporting` | bool | Export operation state |

---

## Methods Pseudocode

### `initState()`

```
PROCEDURE initState():
  super.initState()
  _loadSummaryCount()
END PROCEDURE
```

### `_loadSummaryCount()`

```
ASYNC PROCEDURE _loadSummaryCount():
  summaries = AWAIT _summaryService.getAllSummaries()
  
  setState():
    _summaryCount = summaries.length
END PROCEDURE
```

### `_buildSectionHeader(title)`

```
PROCEDURE _buildSectionHeader(title):
  RETURN Padding(16, 8)
    └── Text: title
        ├── style: titleMedium
        ├── fontWeight: bold
        └── color: primary color
END PROCEDURE
```

### `_buildSection(title, icon, children)`

```
PROCEDURE _buildSection(title, icon, children):
  RETURN Card
    ├── margin: 16, 4
    ├── elevation: 2
    └── Column
        ├── Padding(16): Row
        │   ├── Icon(icon, primary color)
        │   ├── SizedBox(width: 12)
        │   └── Text: title (titleMedium, fontWeight: 600)
        └── children (ListTile list)
END PROCEDURE
```

### `_buildAiSection()`

```
PROCEDURE _buildAiSection():
  loc = AppLocalizations.of(context)
  
  RETURN _buildSection
    ├── title: loc.aiConfigTitle
    ├── icon: Icons.smart_toy
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
  loc = AppLocalizations.of(context)
  
  RETURN _buildSection
    ├── title: loc.appearanceSettingTitle
    ├── icon: Icons.palette
    └── children: [
        ListTile
        ├── leading: Icon(Icons.brightness_6)
        ├── title: Text(loc.themeSettingTitle)
        ├── subtitle: Text(_getThemeStatus())
        ├── trailing: Icon(Icons.chevron_right)
        └── onTap: Navigator.push(ThemeSettingsScreen),
        
        ListTile
        ├── leading: Icon(Icons.language)
        ├── title: Text(loc.languageSettingTitle)
        ├── subtitle: Text(_getLanguageStatus())
        ├── trailing: Icon(Icons.chevron_right)
        └── onTap: Navigator.push(LanguageSettingsScreen)
      ]
END PROCEDURE
```

### `_buildExportSection()`

```
PROCEDURE _buildExportSection():
  loc = AppLocalizations.of(context)
  
  RETURN _buildSection
    ├── title: loc.dataExportTitle
    ├── icon: Icons.upload_file
    └── children: [
        ListTile
        ├── leading: Icon(Icons.description)
        ├── title: Text(loc.exportBookSummaries)
        ├── subtitle: Text(loc.exportBookSummariesDesc)
        ├── trailing: 
        │   IF _isExporting: CircularProgressIndicator(strokeWidth: 2)
        │   ELSE: Icon(Icons.chevron_right)
        └── onTap: 
            IF _isExporting: null (disabled)
            ELSE: _exportBookSummaries()
      ]
END PROCEDURE
```

### `_buildAboutSection()`

```
PROCEDURE _buildAboutSection():
  loc = AppLocalizations.of(context)
  
  RETURN _buildSection
    ├── title: loc.aboutTitle
    ├── icon: Icons.info
    └── children: [
        ListTile
        ├── leading: Icon(Icons.apps)
        ├── title: Text(loc.appTitle)
        └── subtitle: Text("${loc.version} 0.1.0"),
        
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
  loc = AppLocalizations.of(context)
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
  loc = AppLocalizations.of(context)
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
  loc = AppLocalizations.of(context)
  settings = SettingsService().settings.languageSettings
  
  // Build AI language text
  aiLanguageText = BUILD based on settings.aiLanguageMode:
    'book' → "AI: ${loc.aiLanguageFollowBook}"
    'system' → "AI: ${loc.aiLanguageFollowSystem}"
    'manual' → "AI: ${loc.selectAiOutputLanguage} (${languageName})"
  
  // Build UI language text
  uiLanguageText = BUILD based on settings.uiLanguageMode:
    'system' → "${loc.uiDisplayLanguage}: ${loc.uiLanguageFollowSystem}"
    'manual' → "${loc.uiDisplayLanguage}: ${languageName}"
  
  RETURN "$aiLanguageText, $uiLanguageText"
END PROCEDURE
```

### `_exportBookSummaries()`

```
ASYNC PROCEDURE _exportBookSummaries():
  loc = AppLocalizations.of(context)
  books = _bookService.books
  
  IF books.isEmpty:
    _showSnackBar(loc.noBooks)
    RETURN
  
  setState(): _isExporting = true
  
  TRY:
    successCount = 0
    
    FOR each book in books:
      result = AWAIT _exportService.exportBookSummaryToMarkdown(book)
      IF result != null:
        successCount++
    
    IF successCount > 0:
      _showSnackBar("$successCount ${loc.booksCount} ${loc.success}")
    ELSE:
      _showSnackBar("${loc.exportBookSummariesDesc} - ${loc.failed}")
  FINALLY:
    setState(): _isExporting = false
END PROCEDURE
```

### `_showSnackBar(message)`

```
PROCEDURE _showSnackBar(message):
  ScaffoldMessenger.showSnackBar
    ├── content: Text(message)
    └── duration: 2 seconds
END PROCEDURE
```

---

## Widget Tree Structure

```
Scaffold
├── AppBar
│   ├── Title: "设置"
│   └── centerTitle: true
│
└── Body: ListView
    ├── _buildSectionHeader("AI配置")
    ├── _buildAiSection()
    ├── SizedBox(height: 16)
    ├── _buildSectionHeader("外观设置")
    ├── _buildAppearanceSection()
    ├── SizedBox(height: 16)
    ├── _buildSectionHeader("数据导出")
    ├── _buildExportSection()
    ├── SizedBox(height: 16)
    ├── _buildSectionHeader("关于")
    ├── _buildAboutSection()
    └── SizedBox(height: 24)
```

### AI Section Widget Tree

```
Card
├── Header Row: Icon(Icons.smart_toy) + "AI配置"
└── ListenableBuilder
    └── ListTile
        ├── leading: Icon(Icons.api)
        ├── title: "AI服务设置"
        ├── subtitle: "provider - model" OR "未配置，点击设置"
        ├── trailing: Icon(Icons.chevron_right)
        └── onTap: → AiConfigScreen
```

### Appearance Section Widget Tree

```
Card
├── Header Row: Icon(Icons.palette) + "外观设置"
├── ListTile (Theme)
│   ├── leading: Icon(Icons.brightness_6)
│   ├── title: "主题设置"
│   ├── subtitle: "跟随系统" OR "亮色" OR "暗色"
│   ├── trailing: Icon(Icons.chevron_right)
│   └── onTap: → ThemeSettingsScreen
│
└── ListTile (Language)
    ├── leading: Icon(Icons.language)
    ├── title: "语言设置"
    ├── subtitle: "AI: xxx, 界面: xxx"
    ├── trailing: Icon(Icons.chevron_right)
    └── onTap: → LanguageSettingsScreen
```

### Export Section Widget Tree

```
Card
├── Header Row: Icon(Icons.upload_file) + "数据导出"
└── ListTile
    ├── leading: Icon(Icons.description)
    ├── title: "导出书籍摘要"
    ├── subtitle: "将所有书籍摘要导出为Markdown文件"
    ├── trailing: 
    │   IF exporting: CircularProgressIndicator
    │   ELSE: Icon(Icons.chevron_right)
    └── onTap: 
        IF exporting: null (disabled)
        ELSE: _exportBookSummaries()
```

### About Section Widget Tree

```
Card
├── Header Row: Icon(Icons.info) + "关于"
├── ListTile (App Name)
│   ├── leading: Icon(Icons.apps)
│   ├── title: "智读"
│   └── subtitle: "版本 0.1.0"
│
└── ListTile (Description)
    ├── leading: Icon(Icons.code)
    ├── title: "AI分层阅读器"
    └── subtitle: "先读薄，再读厚"
```

---

## User Interaction Flows

### Flow 1: Navigate to AI Config

```
User taps "AI服务设置" ListTile
    ↓
Navigator.push(AiConfigScreen)
    ↓
AI config screen displays
    ↓
User configures provider, API key, model
    ↓
User saves configuration
    ↓
Navigator.pop()
    ↓
Return to SettingsScreen
    ↓
ListenableBuilder detects change
    ↓
AI status text updates
```

### Flow 2: Navigate to Theme Settings

```
User taps "主题设置" ListTile
    ↓
Navigator.push(ThemeSettingsScreen)
    ↓
Theme options displayed
    ↓
User selects theme mode
    ↓
Settings saved immediately
    ↓
Navigator.pop()
    ↓
Return to SettingsScreen
    ↓
Theme status text updates
```

### Flow 3: Navigate to Language Settings

```
User taps "语言设置" ListTile
    ↓
Navigator.push(LanguageSettingsScreen)
    ↓
Language options displayed
    ↓
User configures AI/UI language
    ↓
Settings saved immediately
    ↓
Navigator.pop()
    ↓
Return to SettingsScreen
    ↓
Language status text updates
```

### Flow 4: Export Book Summaries

```
User taps "导出书籍摘要" ListTile
    ↓
_exportBookSummaries() called
    ↓
Check books exist
    ↓
IF empty: Show "暂无书籍" SnackBar, RETURN
    ↓
Set _isExporting = true
    ↓
Disable button (show progress indicator)
    ↓
FOR each book:
    ├── ExportService.exportBookSummaryToMarkdown(book)
    ├── Creates Markdown file
    └── Saves to user-selected directory
    ↓
Count successful exports
    ↓
Show result SnackBar
    ↓
Set _isExporting = false
    ↓
Button re-enabled
```

---

## State Management Pattern

### ListenableBuilder for AI Settings

```
SettingsService().aiSettings (ValueNotifier)
    ↓
ListenableBuilder listens
    ↓
builder(context, _) re-executes on change
    ↓
_getAiConfigStatus() reads latest settings
    ↓
Subtitle shows current provider/model
```

### Direct Settings Read

```
_getThemeStatus():
    ↓
SettingsService().settings.themeSettings.mode
    ↓
Return localized mode name

_getLanguageStatus():
    ↓
SettingsService().settings.languageSettings
    ↓
Build combined status text
```

---

## Conditional Rendering

### Export Button State

```
_isExporting = false:
    ├── trailing: Icon(Icons.chevron_right)
    └── onTap: _exportBookSummaries (enabled)

_isExporting = true:
    ├── trailing: CircularProgressIndicator(strokeWidth: 2)
    └── onTap: null (disabled)

Purpose: Prevent duplicate export operations
```

### AI Config Status

```
settings.isValid = true:
    subtitle: "${provider} - ${model}"

settings.isValid = false:
    subtitle: "未配置，点击设置"

isValid checks:
    ├── API key not empty
    ├── API key not placeholder
    └── Model not empty
```

---

## Service Integration

### SettingsService

```
READ: SettingsService().settings
  ├── aiSettings: provider, apiKey, model, baseUrl
  ├── themeSettings: mode (system/light/dark)
  └── languageSettings: aiLanguageMode, aiOutputLanguage, uiLanguageMode, uiLanguage

LISTEN: SettingsService().aiSettings (ValueNotifier)
  - Reactive updates via ListenableBuilder
```

### ExportService

```
EXPORT: exportBookSummaryToMarkdown(book)
  ├── Get book summary
  ├── Get all chapter summaries
  ├── Combine into Markdown format
  ├── Prompt user for save location
  └── Write file to disk
  └── RETURN file path OR null (failed)
```

### BookService

```
READ: _bookService.books
  - List of all imported books
  - Used for export iteration
```

### SummaryService

```
READ: getAllSummaries()
  - Returns all chapter summaries
  - Used for count display
```

---

## Navigation Flow

```
HomeScreen (AppBar settings icon)
    ↓
Navigator.push(SettingsScreen)
    ↓
SettingsScreen displays
    ├── AI配置 → AiConfigScreen
    ├── 主题设置 → ThemeSettingsScreen
    ├── 语言设置 → LanguageSettingsScreen
    └── 导出书籍摘要 → Export operation
    ↓
Navigator.pop()
    ↓
Return to HomeScreen
```

---

## Data Export Flow

```
_exportBookSummaries():
    ↓
FOR each book in _bookService.books:
    ↓
    ExportService.exportBookSummaryToMarkdown(book)
    ↓
    SummaryService.getBookSummary(bookId)
    ↓
    SummaryService.getChapterSummaries(bookId)
    ↓
    Combine into Markdown:
    ```
    # 书名
    
    ## 全书摘要
    {book summary content}
    
    ## 章节摘要
    
    ### 第一章
    {chapter 1 summary}
    
    ### 第二章
    {chapter 2 summary}
    ...
    ```
    ↓
    file_picker.getSaveLocation()
    ↓
    Write to selected path
    ↓
    RETURN success/failure
```

---

## Internationalization

```
AppLocalizations.of(context) provides:
├── settingsTitle
├── aiConfigTitle
├── aiServiceSettings
├── notConfiguredClickToSet
├── appearanceSettingTitle
├── themeSettingTitle
├── languageSettingTitle
├── themeModeSystem/Light/Dark
├── dataExportTitle
├── exportBookSummaries
├── exportBookSummariesDesc
├── aboutTitle
├── appTitle
├── version
├── aiLayeredReader
├── readThinThick
└── ... (all UI strings)
```