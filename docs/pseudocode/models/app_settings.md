# app_settings.dart - Pseudocode Documentation

## Overview

This file defines the application settings data models, including AI settings, theme settings, language settings, and the aggregated app settings container.

---

## Enum: ThemeMode

Defines the three supported theme modes for the application.

### Values

| Value | Description |
|-------|-------------|
| `system` | Follow system theme settings |
| `light` | Force light theme |
| `dark` | Force dark theme |

### Methods

#### `fromString(String? value) -> ThemeMode`

**Purpose**: Parse theme mode from string value.

**Pseudocode**:
```
FUNCTION fromString(value):
    SWITCH value:
        CASE 'light':
            RETURN ThemeMode.light
        CASE 'dark':
            RETURN ThemeMode.dark
        DEFAULT:
            RETURN ThemeMode.system
    END SWITCH
END FUNCTION
```

---

## Class: AiSettings

AI service configuration data model for storing provider settings, API keys, and connection parameters.

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `provider` | `String` | `'qwen'` | AI provider identifier ('zhipu', 'qwen', 'ollama') |
| `apiKey` | `String` | `''` | API authentication key |
| `model` | `String` | `'qwen-plus'` | Model name to use |
| `baseUrl` | `String` | `'https://dashscope.aliyuncs.com/compatible-mode/v1'` | API base URL |

### Constructor

```
CONSTRUCTOR AiSettings(provider, apiKey, model, baseUrl):
    SET provider = provider OR 'qwen'
    SET apiKey = apiKey OR ''
    SET model = model OR 'qwen-plus'
    SET baseUrl = baseUrl OR 'https://dashscope.aliyuncs.com/compatible-mode/v1'
END CONSTRUCTOR
```

### Methods

#### `copyWith(...) -> AiSettings`

**Purpose**: Create a copy with optionally modified fields.

**Pseudocode**:
```
FUNCTION copyWith(provider, apiKey, model, baseUrl):
    RETURN NEW AiSettings(
        provider = provider OR this.provider,
        apiKey = apiKey OR this.apiKey,
        model = model OR this.model,
        baseUrl = baseUrl OR this.baseUrl
    )
END FUNCTION
```

#### `toJson() -> Map<String, dynamic>`

**Purpose**: Serialize AiSettings to JSON format.

**Pseudocode**:
```
FUNCTION toJson():
    RETURN {
        'provider': this.provider,
        'apiKey': this.apiKey,
        'model': this.model,
        'baseUrl': this.baseUrl
    }
END FUNCTION
```

#### `fromJson(Map<String, dynamic> json) -> AiSettings` (Factory)

**Purpose**: Deserialize JSON to AiSettings instance.

**Pseudocode**:
```
FUNCTION fromJson(json):
    RETURN NEW AiSettings(
        provider = json['provider'] OR 'qwen',
        apiKey = json['apiKey'] OR '',
        model = json['model'] OR 'qwen-plus',
        baseUrl = json['baseUrl'] OR 'https://dashscope.aliyuncs.com/compatible-mode/v1'
    )
END FUNCTION
```

#### `isValid -> bool` (Getter)

**Purpose**: Validate AI configuration.

**Pseudocode**:
```
GETTER isValid():
    IF provider == 'ollama':
        // Ollama local model only needs valid base URL
        RETURN baseUrl.isNotEmpty
    ELSE:
        // Other providers need valid API key
        RETURN apiKey.isNotEmpty 
            AND apiKey != 'YOUR_API_KEY'
            AND apiKey != 'YOUR_ZHIPU_API_KEY_HERE'
            AND apiKey != 'YOUR_QWEN_API_KEY_HERE'
    END IF
END GETTER
```

---

## Class: ThemeSettings

Theme preference settings data model.

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `mode` | `ThemeMode` | `ThemeMode.system` | Current theme mode |

### Constructor

```
CONSTRUCTOR ThemeSettings(mode):
    SET mode = mode OR ThemeMode.system
END CONSTRUCTOR
```

### Methods

#### `copyWith(ThemeMode? mode) -> ThemeSettings`

**Pseudocode**:
```
FUNCTION copyWith(mode):
    RETURN NEW ThemeSettings(mode = mode OR this.mode)
END FUNCTION
```

#### `toJson() -> Map<String, dynamic>`

**Pseudocode**:
```
FUNCTION toJson():
    RETURN { 'mode': this.mode.name }
END FUNCTION
```

#### `fromJson(Map<String, dynamic> json) -> ThemeSettings` (Factory)

**Pseudocode**:
```
FUNCTION fromJson(json):
    RETURN NEW ThemeSettings(
        mode = ThemeMode.fromString(json['mode'])
    )
END FUNCTION
```

---

## Class: LanguageSettings

Language preference settings for AI output and UI.

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `aiLanguageMode` | `String` | `'book'` | AI output language mode ('book', 'system', 'manual') |
| `aiOutputLanguage` | `String` | `'zh'` | AI output language when mode is 'manual' |
| `uiLanguageMode` | `String` | `'system'` | UI language mode ('system', 'manual') |
| `uiLanguage` | `String` | `'zh'` | UI language when mode is 'manual' |

### Constructor

```
CONSTRUCTOR LanguageSettings(aiLanguageMode, aiOutputLanguage, uiLanguageMode, uiLanguage):
    SET aiLanguageMode = aiLanguageMode OR 'book'
    SET aiOutputLanguage = aiOutputLanguage OR 'zh'
    SET uiLanguageMode = uiLanguageMode OR 'system'
    SET uiLanguage = uiLanguage OR 'zh'
END CONSTRUCTOR
```

### Methods

#### `copyWith(...) -> LanguageSettings`

**Pseudocode**:
```
FUNCTION copyWith(aiLanguageMode, aiOutputLanguage, uiLanguageMode, uiLanguage):
    RETURN NEW LanguageSettings(
        aiLanguageMode = aiLanguageMode OR this.aiLanguageMode,
        aiOutputLanguage = aiOutputLanguage OR this.aiOutputLanguage,
        uiLanguageMode = uiLanguageMode OR this.uiLanguageMode,
        uiLanguage = uiLanguage OR this.uiLanguage
    )
END FUNCTION
```

#### `toJson() -> Map<String, dynamic>`

**Pseudocode**:
```
FUNCTION toJson():
    RETURN {
        'aiLanguageMode': this.aiLanguageMode,
        'aiOutputLanguage': this.aiOutputLanguage,
        'uiLanguageMode': this.uiLanguageMode,
        'uiLanguage': this.uiLanguage
    }
END FUNCTION
```

#### `fromJson(Map<String, dynamic> json) -> LanguageSettings` (Factory)

**Pseudocode**:
```
FUNCTION fromJson(json):
    RETURN NEW LanguageSettings(
        aiLanguageMode = json['aiLanguageMode'] OR 'book',
        aiOutputLanguage = json['aiOutputLanguage'] OR 'zh',
        uiLanguageMode = json['uiLanguageMode'] OR 'system',
        uiLanguage = json['uiLanguage'] OR 'zh'
    )
END FUNCTION
```

---

## Class: AppSettings

Aggregated application settings container combining all setting categories.

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `aiSettings` | `AiSettings` | `AiSettings()` | AI service configuration |
| `themeSettings` | `ThemeSettings` | `ThemeSettings()` | Theme preferences |
| `languageSettings` | `LanguageSettings` | `LanguageSettings()` | Language preferences |
| `version` | `int` | `1` | Settings version for future migrations |

### Constructor

```
CONSTRUCTOR AppSettings(aiSettings, themeSettings, languageSettings, version):
    SET aiSettings = aiSettings OR NEW AiSettings()
    SET themeSettings = themeSettings OR NEW ThemeSettings()
    SET languageSettings = languageSettings OR NEW LanguageSettings()
    SET version = version OR 1
END CONSTRUCTOR
```

### Methods

#### `copyWith(...) -> AppSettings`

**Pseudocode**:
```
FUNCTION copyWith(aiSettings, themeSettings, languageSettings, version):
    RETURN NEW AppSettings(
        aiSettings = aiSettings OR this.aiSettings,
        themeSettings = themeSettings OR this.themeSettings,
        languageSettings = languageSettings OR this.languageSettings,
        version = version OR this.version
    )
END FUNCTION
```

#### `toJson() -> Map<String, dynamic>`

**Pseudocode**:
```
FUNCTION toJson():
    RETURN {
        'aiSettings': this.aiSettings.toJson(),
        'themeSettings': this.themeSettings.toJson(),
        'languageSettings': this.languageSettings.toJson(),
        'version': this.version
    }
END FUNCTION
```

#### `fromJson(Map<String, dynamic> json) -> AppSettings` (Factory)

**Pseudocode**:
```
FUNCTION fromJson(json):
    RETURN NEW AppSettings(
        aiSettings = IF json['aiSettings'] EXISTS 
                     THEN AiSettings.fromJson(json['aiSettings']) 
                     ELSE NULL,
        themeSettings = IF json['themeSettings'] EXISTS 
                        THEN ThemeSettings.fromJson(json['themeSettings']) 
                        ELSE NULL,
        languageSettings = IF json['languageSettings'] EXISTS 
                          THEN LanguageSettings.fromJson(json['languageSettings']) 
                          ELSE NULL,
        version = json['version'] OR 1
    )
END FUNCTION
```

---

## Data Relationships

```
AppSettings (Root Container)
├── aiSettings: AiSettings
│   ├── provider: String
│   ├── apiKey: String
│   ├── model: String
│   └── baseUrl: String
├── themeSettings: ThemeSettings
│   └── mode: ThemeMode (enum)
├── languageSettings: LanguageSettings
│   ├── aiLanguageMode: String
│   ├── aiOutputLanguage: String
│   ├── uiLanguageMode: String
│   └── uiLanguage: String
└── version: int
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    SettingsService                          │
│  (Manages singleton instance of AppSettings)                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     AppSettings                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  AiSettings  │  │ThemeSettings │  │ LanguageSettings │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   settings.json                            │
│  (Persistent storage in Documents/zhidu/)                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Usage Examples

### Creating Settings

```
// Create default settings
settings = NEW AppSettings()

// Create with custom AI settings
settings = NEW AppSettings(
    aiSettings = NEW AiSettings(
        provider = 'zhipu',
        apiKey = 'your-api-key',
        model = 'glm-4-flash'
    )
)
```

### Validating AI Configuration

```
aiSettings = NEW AiSettings(provider='ollama', baseUrl='http://localhost:11434')
IF aiSettings.isValid:
    // Proceed with AI operations
ELSE:
    // Show configuration error
```

### Updating Settings

```
// Update theme mode
newSettings = settings.copyWith(
    themeSettings = settings.themeSettings.copyWith(mode = ThemeMode.dark)
)

// Update AI provider
newSettings = settings.copyWith(
    aiSettings = settings.aiSettings.copyWith(provider = 'zhipu')
)
```