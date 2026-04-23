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
    ├── Services: SettingsService, AIService
    ├── Form: GlobalKey<FormState>
    ├── Controllers: TextEditingController (apiKey, baseUrl, model)
    └── State Variables: provider, model, obscure, loading flags
```

---

## State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_settingsService` | SettingsService | Singleton for settings management |
| `_aiService` | AIService | Singleton for AI operations |
| `_formKey` | GlobalKey<FormState> | Form validation |
| `_selectedProvider` | String | Current AI provider (zhipu/qwen/ollama) |
| `_selectedModel` | String | Current model name |
| `_apiKeyController` | TextEditingController | API Key input |
| `_baseUrlController` | TextEditingController | Base URL input |
| `_modelController` | TextEditingController | Model name input |
| `_isApiKeyObscured` | bool | API Key visibility toggle |
| `_isSaving` | bool | Save operation in progress |
| `_isTesting` | bool | Test connection in progress |
| `_testResultMessage` | String? | Test result message |
| `_testResultSuccess` | bool? | Test success status |

---

## Constants

```
PROVIDERS = [
  ('zhipu', '智谱'),
  ('qwen', '通义千问'),
  ('ollama', 'Ollama（本地）')
]

MODELS_BY_PROVIDER = {
  'zhipu': ['glm-4-flash', 'glm-4', 'glm-4-plus'],
  'qwen': ['qwen-turbo', 'qwen-plus', 'qwen-max']
}

DEFAULT_BASE_URLS = {
  'zhipu': 'https://open.bigmodel.cn/api/paas/v4',
  'qwen': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  'ollama': 'http://localhost:11434/v1'
}
```

---

## Methods Pseudocode

### `_loadCurrentSettings()`

```
PROCEDURE _loadCurrentSettings():
  aiSettings = _settingsService.settings.aiSettings
  
  _selectedProvider = aiSettings.provider
  IF _selectedProvider NOT in valid providers:
    _selectedProvider = first provider
  
  _selectedModel = aiSettings.model
  _apiKeyController.text = aiSettings.apiKey
  _modelController.text = aiSettings.model
  _baseUrlController.text = aiSettings.baseUrl OR defaultBaseUrl[_selectedProvider]
END PROCEDURE
```

### `_onProviderChanged(newProvider)`

```
PROCEDURE _onProviderChanged(newProvider):
  IF newProvider == null OR newProvider == _selectedProvider:
    RETURN
  
  setState():
    _selectedProvider = newProvider
    _baseUrlController.text = DEFAULT_BASE_URLS[newProvider]
    _testResultMessage = null  // Clear previous test result
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

---

## Widget Tree Structure

```
Scaffold
├── AppBar
│   └── Title: "AI配置"
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
            └── _buildActionButtons()
```

### Provider Section Widget Tree

```
Column
├── Text: "AI提供商" (titleMedium, bold)
├── SizedBox(height: 8)
└── DropdownButtonFormField<String>
    ├── value: _selectedProvider
    ├── items: provider options
    ├── onChanged: _onProviderChanged
    └── validator: NOT empty
```

### API Key Section Widget Tree

```
Column
├── Text: "API Key" (titleMedium, bold)
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
├── Text: "模型" (titleMedium, bold)
├── SizedBox(height: 8)
└── TextFormField
    ├── controller: _modelController
    ├── suffixIcon: PopupMenuButton (recommended models)
    ├── validator: NOT empty
    └── onChanged: _onModelChanged
```

### Base URL Section Widget Tree

```
Column
├── Text: "Base URL" (titleMedium, bold)
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
│   ├── label: "测试连接" OR "测试中..."
│   └── onTap: _testConnection
│
├── SizedBox(width: 16)
│
└── Expanded(flex: 3): ElevatedButton.icon
    ├── onPressed: disabled if testing/saving
    ├── icon: CircularProgressIndicator OR save
    ├── label: "保存" OR "保存中..."
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
Display current configuration
```

### Flow 2: Change Provider

```
User selects new provider from dropdown
    ↓
_onProviderChanged(newProvider)
    ↓
Update _selectedProvider
    ↓
Update Base URL to default for new provider
    ↓
Clear previous test result
    ↓
setState() triggers rebuild
```

### Flow 3: Test Connection

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

### Flow 4: Save Configuration

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
| API Key | Must not be null or empty |
| Model | Must not be null or empty |
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
    ↓ (save successful)
Navigator.pop()
    ↓
Return to SettingsScreen
    ↓
ListenableBuilder updates AI status display
```