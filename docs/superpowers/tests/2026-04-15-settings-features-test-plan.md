# Settings Page Features Test Plan

## Overview

This document outlines the test coverage needed for the settings page features implementation. All new components require unit tests and widget tests to ensure correctness and maintainability.

## Test Files to Create

### 1. Model Tests

#### test/models/app_settings_test.dart

**Purpose:** Test AppSettings and its nested model classes

**Test Cases:**

**AiSettings Tests:**
- `AiSettings.defaults()` returns valid default values
- `AiSettings.isValid` returns true when apiKey is valid
- `AiSettings.isValid` returns false when apiKey is empty
- `AiSettings.isValid` returns false when apiKey is placeholder
- `AiSettings.copyWith()` creates modified copy
- `AiSettings.toJson()` produces correct JSON
- `AiSettings.fromJson()` parses valid JSON correctly
- `AiSettings.fromJson()` handles missing fields with defaults

**ThemeSettings Tests:**
- `ThemeSettings.defaults()` returns mode='system'
- `ThemeSettings.fromJson()` parses mode correctly
- `ThemeSettings.toJson()` produces correct JSON
- `ThemeSettings.copyWith()` creates modified copy

**StorageSettings Tests:**
- `StorageSettings.defaults()` returns correct default paths
- `StorageSettings.fromJson()` parses all fields
- `StorageSettings.toJson()` produces correct JSON
- `StorageSettings.copyWith()` creates modified copy
- Handles null lastBackupTime correctly

**LanguageSettings Tests:**
- `LanguageSettings.defaults()` returns auto_book mode
- `LanguageSettings.fromJson()` parses correctly
- `LanguageSettings.toJson()` produces correct JSON
- `LanguageSettings.copyWith()` creates modified copy

**AppSettings Tests:**
- `AppSettings.defaults()` returns complete default settings
- `AppSettings.toJson()` serializes all nested settings
- `AppSettings.fromJson()` deserializes correctly
- `AppSettings.fromJson()` handles version compatibility
- `AppSettings.copyWith()` creates modified copy
- Handles migration from legacy ai_config.json format

---

### 2. Service Tests

#### test/services/settings_service_test.dart

**Purpose:** Test SettingsService singleton behavior and persistence

**Test Cases:**

**Initialization Tests:**
- `init()` creates default settings if file doesn't exist
- `init()` loads existing settings from file
- `init()` handles corrupted JSON gracefully
- `init()` creates settings directory if needed

**Configuration Update Tests:**
- `updateAiSettings()` saves AI configuration
- `updateThemeMode()` saves theme mode and notifies listeners
- `updateStorageSettings()` saves storage configuration
- `updateLanguageSettings()` saves language configuration
- All update methods trigger ValueNotifier updates
- Settings persist to file after update

**Notifier Tests:**
- `themeModeNotifier` emits correct ThemeMode values
- `aiSettingsNotifier` emits AiSettings updates
- `languageSettingsNotifier` emits LanguageSettings updates
- Multiple listeners receive notifications

**Persistence Tests:**
- Settings survive app restart
- Concurrent updates handled correctly
- File permissions handled gracefully

**Import/Export Tests:**
- `exportToJson()` produces valid JSON
- `importFromJson()` restores all settings
- `importFromJson()` handles invalid JSON gracefully
- `resetToDefaults()` clears all custom settings

---

#### test/services/storage_path_service_test.dart

**Purpose:** Test StoragePathService directory management

**Test Cases:**

**Directory Access Tests:**
- `booksDirectory` returns custom path when set
- `booksDirectory` returns default path when not set
- `backupDirectory` returns custom path when set
- `backupDirectory` returns default path when not set

**Directory Selection Tests:**
- `pickBooksDirectory()` returns selected path
- `pickBooksDirectory()` validates directory is writable
- `pickBackupDirectory()` returns selected path
- `pickBackupDirectory()` validates directory is writable
- Cancellation returns null without error

**Path Management Tests:**
- `setBooksDirectory()` updates SettingsService
- `setBackupDirectory()` updates SettingsService
- `resetBooksDirectory()` reverts to default
- `resetBackupDirectory()` reverts to default
- Path changes notify listeners

**Edge Case Tests:**
- Handles non-existent directories
- Handles read-only directories
- Handles permission errors gracefully
- Creates directories if they don't exist

---

#### test/services/ai_service_test.dart (Update)

**Purpose:** Update existing tests for SettingsService integration

**Test Cases to Add:**

**Configuration Loading Tests:**
- `reloadConfig()` loads from SettingsService
- `reloadConfig()` handles missing configuration
- `reloadConfig()` handles invalid configuration
- `isConfigured` reflects SettingsService state
- Changes in SettingsService trigger reload

**Language Injection Tests:**
- `generateFullChapterSummary()` injects language instruction
- `generateBookSummaryFromPreface()` injects language instruction
- `generateBookSummary()` injects language instruction
- Language mode 'auto_book' adds correct instruction
- Language mode 'system' adds correct instruction
- Language mode 'manual' adds correct instruction
- Invalid language mode handled gracefully

**Compatibility Tests:**
- Legacy ai_config.json migration
- Backward compatibility with existing code

---

#### test/services/ai_prompts_test.dart (Update)

**Purpose:** Update existing tests for language instruction support

**Test Cases to Add:**

**Language Instruction Tests:**
- `getLanguageInstruction('auto_book', '')` returns correct Chinese text
- `getLanguageInstruction('system', '')` returns correct Chinese text
- `getLanguageInstruction('manual', 'zh')` returns correct Chinese text
- `getLanguageInstruction('manual', 'en')` returns correct English text
- `getLanguageInstruction('manual', 'ja')` returns correct Japanese text
- Invalid language code handled gracefully

**Prompt Injection Tests:**
- `chapterSummary()` appends language instruction to prompt
- `bookSummaryFromPreface()` appends language instruction to prompt
- `bookSummary()` appends language instruction to prompt
- Empty language instruction doesn't break prompt

---

#### test/services/export_service_test.dart (Update)

**Purpose:** Update existing tests for settings backup/restore

**Test Cases to Add:**

**Settings Backup Tests:**
- `exportAllDataToJson()` includes settings in backup
- Backup contains complete settings JSON
- Backup structure is valid

**Settings Restore Tests:**
- `importFromJson()` restores settings
- `importFromJson()` calls SettingsService.updateAllSettings()
- `importFromJson()` calls AIService.reloadConfig()
- Missing settings in backup handled gracefully
- Corrupted settings in backup handled gracefully

**Auto Backup Tests:**
- Auto backup creates file at correct location
- Auto backup overwrites existing file
- Auto backup includes all data

---

### 3. Screen/Widget Tests

#### test/screens/ai_config_screen_test.dart

**Purpose:** Test AI configuration UI

**Test Cases:**

**Rendering Tests:**
- Screen displays all form fields
- Provider dropdown shows options
- API Key field is obscured by default
- Model dropdown updates based on provider
- Base URL auto-populates for selected provider

**Interaction Tests:**
- Tapping provider updates model options
- Tapping model selection works
- API Key show/hide toggle works
- Test connection button triggers API call
- Save button persists settings
- Navigation back after save

**Validation Tests:**
- Empty API Key shows validation error
- Invalid API Key shows error after test
- Invalid provider handled gracefully

**State Tests:**
- Form loads with existing settings
- Form handles no existing settings
- Loading state during test connection
- Error state on test failure
- Success state on test success

---

#### test/screens/theme_settings_screen_test.dart

**Purpose:** Test theme settings UI

**Test Cases:**

**Rendering Tests:**
- Three radio options displayed
- Current selection is checked
- Labels are correct (跟随系统, 亮色模式, 暗色模式)

**Interaction Tests:**
- Selecting option updates SettingsService
- Selection immediately updates theme
- Theme persists after app restart
- Back navigation works

---

#### test/screens/language_settings_screen_test.dart

**Purpose:** Test language settings UI

**Test Cases:**

**Rendering Tests:**
- Three radio options displayed
- Current selection is checked
- Language dropdown hidden when not manual
- Language dropdown visible when manual selected
- Dropdown contains correct options

**Interaction Tests:**
- Selecting mode updates SettingsService
- Selecting language updates SettingsService
- Manual mode shows dropdown
- Other modes hide dropdown
- Settings persist

---

#### test/screens/backup_settings_screen_test.dart

**Purpose:** Test backup settings UI

**Test Cases:**

**Rendering Tests:**
- Current backup directory displayed
- Last backup time displayed
- Auto backup toggle visible
- Frequency dropdown visible when enabled
- Frequency dropdown hidden when disabled

**Interaction Tests:**
- Directory picker opens on tap
- Directory updates after selection
- Toggle enables/disables auto backup
- Frequency selection updates settings
- Manual backup button triggers backup
- Restore button opens file picker
- Confirmation dialog shown before restore

**State Tests:**
- Loading state during backup
- Success message after backup
- Error message on failure
- Progress indication

---

#### test/screens/storage_settings_screen_test.dart

**Purpose:** Test storage settings UI

**Test Cases:**

**Rendering Tests:**
- Current books directory displayed
- Warning message visible
- Pick directory button visible

**Interaction Tests:**
- Directory picker opens on tap
- Directory updates after selection
- Warning about manual migration shown

---

#### test/screens/settings_screen_test.dart (Update)

**Purpose:** Update existing tests for new sections

**Test Cases to Add:**

**Section Rendering Tests:**
- AI配置 section displayed
- AI配置 shows correct status (configured/not configured)
- 外观设置 section displayed
- 外观设置 shows theme and language status
- 数据管理 section displayed
- 数据管理 shows storage and backup options
- Navigation to each sub-screen works

**Status Display Tests:**
- AI status shows provider/model when configured
- AI status shows "未配置" when not configured
- Theme status shows correct mode
- Language status shows correct language

---

### 4. Integration Tests

#### test/integration/settings_flow_test.dart

**Purpose:** Test complete user flows

**Test Cases:**

**AI Configuration Flow:**
- Navigate to AI config
- Enter valid credentials
- Test connection succeeds
- Save configuration
- Verify AIService updated
- Verify settings persisted

**Theme Change Flow:**
- Navigate to theme settings
- Select dark mode
- Verify theme changes immediately
- Restart app
- Verify theme persists

**Language Change Flow:**
- Navigate to language settings
- Select manual English
- Generate summary
- Verify English output

**Backup/Restore Flow:**
- Add test data
- Navigate to backup settings
- Perform manual backup
- Clear data
- Restore from backup
- Verify all data restored
- Verify settings restored

**Auto Backup Flow:**
- Enable auto backup with daily interval
- Simulate time passage
- Verify auto backup triggered
- Verify backup file updated

---

## Test Implementation Priority

1. **High Priority** - Core functionality
   - app_settings_test.dart
   - settings_service_test.dart
   - storage_path_service_test.dart

2. **Medium Priority** - Service integration
   - ai_service_test.dart updates
   - ai_prompts_test.dart updates
   - export_service_test.dart updates

3. **Lower Priority** - UI testing
   - All screen tests
   - Integration tests

## Testing Notes

- Use `flutter_test` and `mockito` for mocking
- Mock SettingsService for service tests
- Mock FilePicker for directory selection tests
- Mock http.Client for AI API tests
- Use temporary directories for file operations
- Clean up test files after tests
- Follow existing test patterns in the codebase