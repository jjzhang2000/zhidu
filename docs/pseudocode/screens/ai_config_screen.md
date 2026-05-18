# AI Configuration Screen - Pseudocode Documentation

## Overview

**File**: `lib/screens/ai_config_screen.dart`
**Purpose**: AI service provider configuration interface
**Pattern**: StatefulWidget with form validation and service integration

---

## StatefulWidget Structure

```
AiConfigScreen (StatefulWidget)
└── _AiConfigScreenState (State)
    ├── Services: SettingsService, AIService, LogService
    ├── Form: GlobalKey<FormState>
    ├── Keys: _modelBoxKey (GlobalKey, model dropdown anchor)
    ├── Controllers: TextEditingController (apiKey, baseUrl, model)
    └── State Variables: provider, obscure, loading flags, availableModels
```

---

## State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_settingsService` | SettingsService | Singleton for settings management |
| `_aiService` | AIService | Singleton for AI operations |
| `_log` | LogService | Log service instance |
| `_formKey` | GlobalKey<FormState> | Form validation |
| `_modelBoxKey` | GlobalKey | Anchor key for model dropdown positioning |
| `_selectedProvider` | String | Current AI provider (zhipu/qwen/deepseek/minimax/ollama/lmstudio) |
| `_apiKeyController` | TextEditingController | API Key input |
| `_baseUrlController` | TextEditingController | Base URL input |
| `_modelController` | TextEditingController | Model name (selected from dropdown) |
| `_isApiKeyObscured` | bool | API Key visibility toggle |
| `_isSaving` | bool | Save operation in progress |
| `_isTesting` | bool | Test connection in progress |
| `_testResultMessage` | String? | Test result message |
| `_testResultSuccess` | bool? | Test success status |
| `_availableModels` | List\<String\> | Dynamically fetched model list from provider |
| `_requiresApiKey` | bool (getter) | Whether current provider requires API Key |

---

## Constants

```
PROVIDERS = [
  ('zhipu', '智谱'),
  ('qwen', '通义千问'),
  ('deepseek', 'DeepSeek'),
  ('minimax', 'MiniMax'),
  ('ollama', 'Ollama（本地）'),
  ('lmstudio', 'LM Studio（本地）')
]

DEFAULT_BASE_URLS = {
  'zhipu': 'https://open.bigmodel.cn/api/paas/v4',
  'qwen': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  'deepseek': 'https://api.deepseek.com/v1',
  'minimax': 'https://api.minimaxi.com/v1',
  'ollama': 'http://localhost:11434/v1',
  'lmstudio': 'http://localhost:1234/v1'
}
```

Note: Models are fetched dynamically via `AIService.fetchAvailableModels()` and displayed in a `showMenu` dropdown sorted alphabetically. No hardcoded model lists.

---

## Methods Pseudocode

### `_getCurrentProviders()`

```
PROCEDURE _getCurrentProviders():
  localizations = AppLocalizations.of(context)
  IF localizations != null:
    RETURN provider list using localized names (zhipu → localizations.zhipuProvider, ...)
  RETURN default _providers list
END PROCEDURE
```

### `_loadCurrentSettings()`

```
PROCEDURE _loadCurrentSettings():
  aiSettings = _settingsService.settings.aiSettings

  _selectedProvider = aiSettings.provider
  IF _selectedProvider NOT in valid providers:
    _selectedProvider = first provider

  needsApiKey = _requiresApiKey
  _apiKeyController.text = needsApiKey ? aiSettings.apiKey : ''
  _modelController.text = aiSettings.model
  _baseUrlController.text = aiSettings.baseUrl OR _defaultBaseUrls[_selectedProvider]
END PROCEDURE
```

### `_onProviderChanged(newProvider)`

```
PROCEDURE _onProviderChanged(newProvider):
  IF newProvider == null OR newProvider == _selectedProvider:
    RETURN

  setState():
    _selectedProvider = newProvider
    _testResultMessage = null

    savedConfig = _settingsService.getSavedAiConfigForProvider(newProvider)
    currentAiSettings = _settingsService.settings.aiSettings
    isCurrentConfig = (newProvider == currentAiSettings.provider AND currentAiSettings.isValid)

    IF savedConfig != null:
      fill form from savedConfig
    ELSE IF isCurrentConfig:
      fill form from currentAiSettings
    ELSE:
      _baseUrlController.text = _defaultBaseUrls[newProvider]
      _apiKeyController.clear()
      _modelController.clear()
      _availableModels.clear()

  _fetchModelsForCurrentProvider()  // async fetch after setState
END PROCEDURE
```

### `_fetchModelsForCurrentProvider()`

```
ASYNC PROCEDURE _fetchModelsForCurrentProvider():
  provider = _selectedProvider
  IF provider.isEmpty: RETURN

  baseUrl = _baseUrlController.text.trim()

  setState(): _availableModels.clear()

  TRY:
    models = AWAIT _aiService.fetchAvailableModels(
      baseUrl: baseUrl,
      apiKey: _apiKeyController.text.trim()
    )
    IF models.isNotEmpty AND mounted:
      setState(): _availableModels = models
  CATCH e:
    _log.w('AiConfigScreen', '获取模型列表失败: $e')
END PROCEDURE
```

### `_saveConfig()`

```
ASYNC PROCEDURE _saveConfig():
  IF NOT _formKey.currentState.validate():
    RETURN

  setState(): _isSaving = true

  TRY:
    newSettings = AiSettings(
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      baseUrl: _baseUrlController.text.trim()
    )

    AWAIT _settingsService.updateAiSettings(newSettings)
    _aiService.reloadConfig()

    _showSnackBar('AI配置已保存')

    IF mounted:
      Navigator.pop(context)  // Return to previous screen
  CATCH e:
    _showSnackBar('保存失败: $e')
  FINALLY:
    IF mounted:
      setState(): _isSaving = false
END PROCEDURE
```

### `_testConnection()`

```
ASYNC PROCEDURE _testConnection():
  IF NOT _formKey.currentState.validate():
    RETURN

  setState():
    _isTesting = true
    _testResultMessage = null
    _testResultSuccess = null

  TRY:
    tempSettings = AiSettings(
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      baseUrl: _baseUrlController.text.trim()
    )

    _aiService.updateConfig(tempSettings)
    isValid = AWAIT _aiService.testConnection()

    setState():
      _testResultSuccess = isValid
      _testResultMessage = isValid ? '连接成功！' : '连接失败，请检查配置'
  CATCH e:
    setState():
      _testResultSuccess = false
      _testResultMessage = '连接失败: $e'
  FINALLY:
    IF mounted:
      setState(): _isTesting = false
END PROCEDURE
```

### `_getMenuPosition()`

```
ASYNC PROCEDURE _getMenuPosition():
  renderBox = _modelBoxKey.currentContext.findRenderObject() as RenderBox
  IF renderBox == null:
    RETURN RelativeRect.fromLTRB(0, 0, 0, 0)

  position = renderBox.localToGlobal(Offset.zero)
  size = renderBox.size
  screenHeight = MediaQuery.of(context).size.height

  RETURN RelativeRect.fromLTRB(
    position.dx,
    position.dy + size.height,
    position.dx + size.width,
    screenHeight - position.dy
  )
END PROCEDURE
```

### `_showModelMenu()`

```
ASYNC PROCEDURE _showModelMenu():
  position = AWAIT _getMenuPosition()
  width = _modelBoxKey renderBox width OR 200

  selected = AWAIT showMenu<String>(
    context: context,
    position: position,
    constraints: BoxConstraints(minWidth: width, maxWidth: width),
    items: _availableModels (sorted alphabetically).map(model → PopupMenuItem)
  )

  IF selected != null:
    _modelController.text = selected
    setState(() {})
END PROCEDURE
```

### `_tryFetchModels()`

```
ASYNC PROCEDURE _tryFetchModels():
  apiKey = _apiKeyController.text.trim()
  IF apiKey.isNotEmpty:
    AWAIT _fetchModelsForCurrentProvider()
    IF mounted AND _availableModels.isNotEmpty:
      AWAIT _showModelMenu()
END PROCEDURE
```

---

## Widget Tree Structure

```
Scaffold
├── AppBar
│   └── Title: localizations.aiConfigScreenTitle
│
└── Body: SingleChildScrollView
    └── Form (key: _formKey)
        └── Column
            ├── _buildProviderSection()
            ├── SizedBox(height: 24)
            ├── _buildApiKeySection()
            ├── SizedBox(height: 24)
            ├── _buildModelSection()
            ├── SizedBox(height: 24)
            ├── _buildBaseUrlSection()
            ├── SizedBox(height: 32)
            ├── IF _testResultMessage != null: _buildTestResult()
            ├── SizedBox(height: 16)
            └── _buildActionButtons(localizations)
```

### Provider Section Widget Tree

```
Column
├── Text: localized provider label (titleMedium, bold)
├── SizedBox(height: 8)
└── DropdownButtonFormField<String>
    ├── value: _selectedProvider
    ├── items: _getCurrentProviders() mapped with ✓ for saved configs
    ├── onChanged: _onProviderChanged
    └── validator: NOT empty
```

### API Key Section Widget Tree

```
IF _requiresApiKey == false (local model: Ollama/LM Studio):
  Column
  ├── Text: localized API Key label
  ├── Container (grey background, info icon + "本地模型不需要 API Key")

ELSE (cloud provider):
  Column
  ├── Text: localized API Key label (titleMedium, bold)
  ├── SizedBox(height: 8)
  └── TextFormField
      ├── controller: _apiKeyController
      ├── obscureText: _isApiKeyObscured
      ├── suffixIcon: IconButton (visibility toggle)
      └── validator: NOT empty
```

### Model Section Widget Tree

```
Column
├── Text: localized model label (titleMedium, bold)
├── SizedBox(height: 8)
└── InkWell (onTap: _showModelMenu or _tryFetchModels)
    └── Container (key: _modelBoxKey)
        └── Row
            ├── Expanded: Text (selected model name or "请选择模型")
            └── Icon: arrow_drop_down
```

### Base URL Section Widget Tree

```
Column
├── Text: localized Base URL label (titleMedium, bold)
├── SizedBox(height: 8)
└── TextFormField
    ├── controller: _baseUrlController
    ├── hintText: "https://..."
    └── validator:
        ├── NOT empty
        └── starts with http:// or https://
```

### Test Result Widget Tree

```
Container
├── decoration:
│   ├── color: green/red (based on success)
│   ├── borderRadius: 8
│   └── border: green/red
└── Row
    ├── Icon: check_circle/error
    ├── SizedBox(width: 8)
    └── Text: _testResultMessage
```

### Action Buttons Widget Tree

```
Row
├── Expanded(flex: 2): ElevatedButton.icon
│   ├── onPressed: disabled if testing/saving
│   ├── icon: CircularProgressIndicator OR network_check
│   ├── label: "测试中..." / "测试连接"
│   └── onTap: _testConnection
│
├── SizedBox(width: 16)
│
└── Expanded(flex: 3): ElevatedButton.icon
    ├── onPressed: disabled if testing/saving
    ├── icon: CircularProgressIndicator OR save
    ├── label: "保存中..." / "保存"
    ├── style: primary color
    └── onTap: _saveConfig
```

---

## User Interaction Flows

### Flow 1: Load Existing Configuration

```
User opens AI Config Screen
    ↓
initState() called
    ↓
_loadCurrentSettings()
    ↓
Read from SettingsService.settings.aiSettings
    ↓
Populate form fields with existing values
    ↓
addPostFrameCallback → _fetchModelsForCurrentProvider()
    ↓
Display current configuration with available models
```

### Flow 2: Change Provider

```
User selects new provider from dropdown
    ↓
_onProviderChanged(newProvider)
    ↓
Update _selectedProvider
    ↓
Load saved config for provider OR current config OR defaults
    ↓
Update Base URL / API Key / Model accordingly
    ↓
Clear previous test result
    ↓
setState() triggers rebuild
    ↓
_fetchModelsForCurrentProvider() → fetch model list for new provider
```

### Flow 3: Select Model

```
User taps model selection box
    ↓
IF _availableModels is empty:
    _tryFetchModels() → fetch model list → if got models: _showModelMenu()
ELSE:
    _showModelMenu()
    ↓
    _getMenuPosition() → calculate dropdown position
    ↓
    showMenu (alphabetically sorted model list)
    ↓
    User selects model → _modelController.text = selected
```

### Flow 4: Test Connection

```
User clicks "测试连接" button
    ↓
Validate form
    ↓
IF invalid: RETURN
    ↓
Set _isTesting = true
    ↓
Create temporary AiSettings
    ↓
Update AIService config temporarily
    ↓
Call AIService.testConnection()
    ↓
Display result (success/failure)
    ↓
Set _isTesting = false
```

### Flow 5: Save Configuration

```
User clicks "保存" button
    ↓
Validate form
    ↓
IF invalid: RETURN
    ↓
Set _isSaving = true
    ↓
Create new AiSettings object
    ↓
Call SettingsService.updateAiSettings()
    ↓
Call AIService.reloadConfig()
    ↓
Show success SnackBar
    ↓
Navigate back to Settings Screen
```

---

## Form Validation Rules

| Field | Validation |
|-------|------------|
| Provider | Must not be null or empty |
| API Key | Required for cloud providers only; not applicable for Ollama/LM Studio |
| Model | No validation (selected from dynamic dropdown) |
| Base URL | Must not be empty, must start with http:// or https:// |

---

## Service Integration

### SettingsService Integration

```
READ: _settingsService.settings.aiSettings
  - provider: String
  - apiKey: String
  - model: String
  - baseUrl: String

READ: _settingsService.getSavedAiConfigForProvider(provider)
  - Returns saved AiSettings for a specific provider

READ: _settingsService.hasSavedAiConfigForProvider(provider)
  - Returns bool, used for ✓ indicator in dropdown

WRITE: _settingsService.updateAiSettings(AiSettings)
  - Saves to settings.json
  - Updates ValueNotifier
  - Triggers UI rebuild in listeners
```

### AIService Integration

```
RELOAD: _aiService.reloadConfig()
  - Reads latest settings from SettingsService
  - Updates internal configuration
  - Ready for new API calls

TEST: _aiService.testConnection()
  - Sends test request to AI provider
  - Returns bool (success/failure)

TEMP UPDATE: _aiService.updateConfig(tempSettings)
  - Temporary config for testing
  - Does not persist

FETCH MODELS: _aiService.fetchAvailableModels(baseUrl, apiKey)
  - Dynamically fetches available model list from provider API
  - Returns List<String> sorted alphabetically
```

---

## State Management Pattern

```
ValueNotifier Pattern:
┌─────────────────────────────────────────┐
│ SettingsService.aiSettings (ValueNotifier)│
└─────────────────────────────────────────┘
                    ↓
         ListenableBuilder in SettingsScreen
                    ↓
              UI auto-updates

Direct setState():
┌─────────────────────────────────────────┐
│ _AiConfigScreenState                    │
│ - _selectedProvider                     │
│ - _isApiKeyObscured                     │
│ - _isSaving / _isTesting                │
│ - _availableModels                      │
│ - _testResultMessage / _testResultSuccess│
└─────────────────────────────────────────┘
                    ↓
              setState() triggers rebuild
```

---

## Navigation Flow

```
SettingsScreen
    ↓ (tap AI配置 ListTile)
Navigator.push(AiConfigScreen)
    ↓
AiConfigScreen displays
    ↓
initState → _loadCurrentSettings → _fetchModelsForCurrentProvider
    ↓ (save successful)
Navigator.pop()
    ↓
Return to SettingsScreen
    ↓
ListenableBuilder updates AI status display
```

---

## Version History

- **2026-05-18**: Comment standardization and dead code cleanup
  - Removed `_recommendedModels` getter (redundant wrapper)
  - Inlined `_getLocalizedProviders` into `_getCurrentProviders`
  - Fixed outdated `_buildModelSection` comments (no manual input)
  - Standardized all method doc comments (fields, logic, build methods)
  - Updated pseudocode: added new methods, removed MODELS_BY_PROVIDER

- **2026-05-17**: Model selection improvement
  - Changed to dropdown-only selection (no manual input)
  - Models fetched dynamically via `AIService.fetchAvailableModels()`
  - Model names sorted alphabetically
  - Removed `cachedModels` caching mechanism
