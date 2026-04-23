# SettingsService - 设置服务伪代码文档

## 概述

SettingsService 是一个单例模式的设置管理服务，统一管理 AI、主题、语言、存储等所有应用设置，使用 ValueNotifier 实现响应式更新，JSON 文件持久化存储。

---

## 单例模式实现

```pseudocode
CLASS SettingsService:
    // 单例实例 - 静态私有变量
    PRIVATE STATIC _instance: SettingsService = SettingsService._internal()
    
    // 工厂构造函数 - 返回单例实例
    PUBLIC STATIC FACTORY SettingsService():
        RETURN _instance
    
    // 私有命名构造函数 - 防止外部实例化
    PRIVATE CONSTRUCTOR _internal():
        // 初始化默认设置
        _settings = AppSettings()
        _settingsFilePath = null
        
        // 初始化 ValueNotifiers
        _themeMode = ValueNotifier(ThemeMode.system)
        _aiSettings = ValueNotifier(AiSettings())
        _languageSettings = ValueNotifier(LanguageSettings())
```

---

## 数据结构

### 私有属性

```pseudocode
PRIVATE PROPERTIES:
    _log: LogService                  // 日志服务实例
    _settingsFilePath: String?        // 设置文件路径
    _settings: AppSettings            // 当前设置对象
    
    // ValueNotifier 字段（响应式更新）
    _themeMode: ValueNotifier<ThemeMode>
    _aiSettings: ValueNotifier<AiSettings>
    _languageSettings: ValueNotifier<LanguageSettings>
```

### 公共属性（ValueNotifier 访问器）

```pseudocode
PUBLIC PROPERTIES:
    // 主题模式 ValueNotifier - 用于 UI 响应式更新
    themeMode: ValueNotifier<ThemeMode> -> _themeMode
    
    // AI 设置 ValueNotifier
    aiSettings: ValueNotifier<AiSettings> -> _aiSettings
    
    // 语言设置 ValueNotifier
    languageSettings: ValueNotifier<LanguageSettings> -> _languageSettings
    
    // 获取当前完整设置
    settings: AppSettings -> _settings
    
    // 获取设置文件路径
    settingsFilePath: String? -> _settingsFilePath
```

---

## 方法伪代码

### init() - 初始化设置服务

```pseudocode
ASYNC METHOD init():
    _log.info('SettingsService', '开始初始化设置服务')
    
    TRY:
        // 获取设置文件路径
        IF _settingsFilePath == null:
            // 获取应用文档目录
            docsDir = await getApplicationDocumentsDirectory()
            
            // 构建应用目录路径
            appDir = Directory(join(docsDir.path, 'zhidu'))
            
            // 创建目录（如果不存在）
            IF NOT await appDir.exists():
                await appDir.create(recursive: true)
            
            // 设置文件路径
            _settingsFilePath = join(appDir.path, 'settings.json')
        
        // 加载设置文件
        await _loadSettings()
        
        // 同步 ValueNotifiers 与设置对象
        _syncNotifiersWithSettings()
        
        _log.info('SettingsService', '设置服务初始化完成')
    
    CATCH e, stackTrace:
        _log.e('SettingsService', '初始化设置服务失败', e, stackTrace)
        
        // 使用默认设置继续
        _settings = AppSettings()
        _syncNotifiersWithSettings()
```

**初始化流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│                     init() 初始化流程                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  获取应用文档目录                                            │
│      ↓                                                      │
│  构建路径: Documents/zhidu/settings.json                    │
│      ↓                                                      │
│  检查目录是否存在                                            │
│      ├─ 不存在 → 创建目录                                    │
│      ↓                                                      │
│  加载设置文件 (_loadSettings)                                │
│      ├─ 文件存在 → 解析 JSON                                 │
│      ├─ 文件不存在 → 使用默认设置                            │
│      ├─ 解析失败 → 使用默认设置                              │
│      ↓                                                      │
│  同步 ValueNotifiers (_syncNotifiersWithSettings)           │
│      ├─ themeMode.value = settings.themeSettings.mode       │
│      ├─ aiSettings.value = settings.aiSettings              │
│      └─ languageSettings.value = settings.languageSettings  │
│      ↓                                                      │
│  初始化完成                                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### _loadSettings() - 从文件加载设置

```pseudocode
PRIVATE ASYNC METHOD _loadSettings():
    // 检查路径是否设置
    IF _settingsFilePath == null:
        RETURN
    
    file = File(_settingsFilePath)
    
    // 检查文件是否存在
    IF await file.exists():
        TRY:
            // 读取文件内容
            content = await file.readAsString()
            
            // 解析 JSON
            json = jsonDecode(content) as Map<String, dynamic>
            
            // 创建设置对象
            _settings = AppSettings.fromJson(json)
            
            _log.info('SettingsService', '已加载设置文件: {_settingsFilePath}')
        
        CATCH e:
            _log.e('SettingsService', '解析设置文件失败，使用默认设置', e)
            _settings = AppSettings()
    
    ELSE:
        _log.info('SettingsService', '设置文件不存在，使用默认设置')
        _settings = AppSettings()
```

---

### _saveSettings() - 保存设置到文件

```pseudocode
PRIVATE ASYNC METHOD _saveSettings():
    // 检查路径是否设置
    IF _settingsFilePath == null:
        RETURN
    
    TRY:
        file = File(_settingsFilePath)
        
        // 序列化设置对象为 JSON
        content = jsonEncode(_settings.toJson())
        
        // 写入文件
        await file.writeAsString(content)
        
        _log.d('SettingsService', '设置已保存到: {_settingsFilePath}')
    
    CATCH e, stackTrace:
        _log.e('SettingsService', '保存设置失败', e, stackTrace)
        
        // 重新抛出异常，让调用方处理
        THROW e
```

---

### _syncNotifiersWithSettings() - 同步 ValueNotifiers

```pseudocode
PRIVATE METHOD _syncNotifiersWithSettings():
    // 同步主题模式
    themeMode.value = _settings.themeSettings.mode
    
    // 同步 AI 设置
    aiSettings.value = _settings.aiSettings
    
    // 同步语言设置
    languageSettings.value = _settings.languageSettings
```

---

### updateAiSettings() - 更新 AI 设置

```pseudocode
PUBLIC ASYNC METHOD updateAiSettings(newSettings: AiSettings):
    // 更新设置对象（使用 copyWith 保持其他设置不变）
    _settings = _settings.copyWith(aiSettings: newSettings)
    
    // 更新 ValueNotifier（触发 UI 更新）
    aiSettings.value = newSettings
    
    // 保存到文件
    await _saveSettings()
    
    _log.info('SettingsService', 'AI设置已更新: provider={newSettings.provider}')
```

**更新流程:**

```
┌─────────────────────────────────────────────────────────────┐
│              updateAiSettings() 更新流程                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  输入: newSettings (AiSettings 对象)                        │
│      ↓                                                      │
│  _settings.copyWith(aiSettings: newSettings)                │
│      ↓                                                      │
│  aiSettings.value = newSettings                             │
│      ↓                                                      │
│  await _saveSettings()                                      │
│      ↓                                                      │
│  触发 AIService 监听器（自动重新加载配置）                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### updateThemeSettings() - 更新主题设置

```pseudocode
PUBLIC ASYNC METHOD updateThemeSettings(newSettings: ThemeSettings):
    // 更新设置对象
    _settings = _settings.copyWith(themeSettings: newSettings)
    
    // 更新 ValueNotifier
    themeMode.value = newSettings.mode
    
    // 保存到文件
    await _saveSettings()
    
    _log.info('SettingsService', '主题设置已更新: mode={newSettings.mode.name}')
```

---

### setThemeMode() - 设置主题模式（便捷方法）

```pseudocode
PUBLIC ASYNC METHOD setThemeMode(mode: ThemeMode):
    // 使用当前主题设置，仅更新模式
    newSettings = _settings.themeSettings.copyWith(mode: mode)
    
    // 调用完整更新方法
    await updateThemeSettings(newSettings)
```

---

### updateLanguageSettings() - 更新语言设置

```pseudocode
PUBLIC ASYNC METHOD updateLanguageSettings(newSettings: LanguageSettings):
    // 更新设置对象
    _settings = _settings.copyWith(languageSettings: newSettings)
    
    // 更新 ValueNotifier
    languageSettings.value = newSettings
    
    // 保存到文件
    await _saveSettings()
    
    _log.info('SettingsService', '语言设置已更新: aiOutput={newSettings.aiOutputLanguage}')
```

---

### resetToDefaults() - 重置所有设置

```pseudocode
PUBLIC ASYNC METHOD resetToDefaults():
    // 创建默认设置对象
    _settings = AppSettings()
    
    // 同步 ValueNotifiers
    _syncNotifiersWithSettings()
    
    // 保存到文件
    await _saveSettings()
    
    _log.info('SettingsService', '设置已重置为默认值')
```

---

### exportToJson() - 导出设置为 JSON

```pseudocode
PUBLIC METHOD exportToJson() -> String:
    // 序列化设置对象
    RETURN jsonEncode(_settings.toJson())
```

---

### importFromJson() - 从 JSON 导入设置

```pseudocode
PUBLIC ASYNC METHOD importFromJson(jsonString: String):
    TRY:
        // 解析 JSON
        json = jsonDecode(jsonString) as Map<String, dynamic>
        
        // 创建设置对象
        _settings = AppSettings.fromJson(json)
        
        // 同步 ValueNotifiers
        _syncNotifiersWithSettings()
        
        // 保存到文件
        await _saveSettings()
        
        _log.info('SettingsService', '设置已从JSON导入')
    
    CATCH e, stackTrace:
        _log.e('SettingsService', '导入设置失败', e, stackTrace)
        
        // 重新抛出异常
        THROW e
```

---

### toAiConfigJson() - 转换为旧版 AI 配置格式

```pseudocode
PUBLIC METHOD toAiConfigJson() -> Map<String, dynamic>:
    // 构建兼容旧版 ai_config.json 的格式
    RETURN {
        'ai_provider': _settings.aiSettings.provider,
        _settings.aiSettings.provider: {
            'api_key': _settings.aiSettings.apiKey,
            'model': _settings.aiSettings.model,
            'base_url': _settings.aiSettings.baseUrl,
        }
    }
```

**输出格式示例:**

```json
{
  "ai_provider": "qwen",
  "qwen": {
    "api_key": "sk-xxx",
    "model": "qwen-plus",
    "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1"
  }
}
```

---

### importFromAiConfigJson() - 从旧版格式导入

```pseudocode
PUBLIC ASYNC METHOD importFromAiConfigJson(json: Map<String, dynamic>):
    // 提取提供商标识
    provider = json['ai_provider'] as String? ?? 'qwen'
    
    // 提取提供商配置块
    providerConfig = json[provider] as Map<String, dynamic>? ?? {}
    
    // 创建新的 AI 设置
    newAiSettings = AiSettings(
        provider: provider,
        apiKey: providerConfig['api_key'] ?? '',
        model: providerConfig['model'] ?? 'qwen-plus',
        baseUrl: providerConfig['base_url'] ?? 'https://dashscope.aliyuncs.com/compatible-mode/v1'
    )
    
    // 更新 AI 设置
    await updateAiSettings(newAiSettings)
```

---

### isAiConfigured - 检查 AI 配置有效性

```pseudocode
PUBLIC PROPERTY isAiConfigured -> Boolean:
    RETURN _settings.aiSettings.isValid
```

---

### updateAllSettings() - 更新所有设置

```pseudocode
PUBLIC ASYNC METHOD updateAllSettings(settings: AppSettings):
    // 替换设置对象
    _settings = settings
    
    // 同步 ValueNotifiers
    _syncNotifiersWithSettings()
    
    // 保存到文件
    await _saveSettings()
    
    _log.info('SettingsService', '所有设置已更新')
```

---

### dispose() - 释放资源

```pseudocode
PUBLIC METHOD dispose():
    // 安全释放 ValueNotifiers
    _safeDispose(_themeMode)
    _safeDispose(_aiSettings)
    _safeDispose(_languageSettings)
```

---

### _safeDispose() - 安全释放 ChangeNotifier

```pseudocode
PRIVATE METHOD _safeDispose(notifier: ChangeNotifier):
    TRY:
        notifier.dispose()
    CATCH _:
        // 已释放，忽略错误
```

---

## 测试支持方法

### resetForTest() - 重置服务状态（测试用）

```pseudocode
PUBLIC STATIC METHOD resetForTest():
    // 安全释放旧 ValueNotifiers
    _instance._safeDispose(_instance._themeMode)
    _instance._safeDispose(_instance._aiSettings)
    _instance._safeDispose(_instance._languageSettings)
    
    // 创建新 ValueNotifiers
    _instance._themeMode = ValueNotifier(ThemeMode.system)
    _instance._aiSettings = ValueNotifier(AiSettings())
    _instance._languageSettings = ValueNotifier(LanguageSettings())
    
    // 重置设置对象
    _instance._settings = AppSettings()
    _instance._settingsFilePath = null
```

### setTestFilePath() - 设置测试文件路径

```pseudocode
PUBLIC METHOD setTestFilePath(path: String):
    _settingsFilePath = path
```

---

## 响应式更新机制

### ValueNotifier 工作原理

```pseudocode
// ValueNotifier 是 Flutter 的响应式数据容器
CLASS ValueNotifier<T>:
    value: T                      // 当前值
    listeners: List<VoidCallback> // 监听器列表
    
    METHOD addListener(listener):
        listeners.add(listener)
    
    METHOD removeListener(listener):
        listeners.remove(listener)
    
    METHOD setValue(newValue):
        IF value != newValue:
            value = newValue
            // 通知所有监听器
            FOR listener IN listeners:
                listener()
```

### UI 监听示例

```pseudocode
// 在 Widget 中监听设置变化
CLASS ThemeSettingsWidget EXTENDS StatefulWidget:
    METHOD initState():
        // 添加监听器
        SettingsService().themeMode.addListener(_onThemeChanged)
    
    METHOD _onThemeChanged():
        // 主题变化时更新 UI
        setState(() {})
    
    METHOD dispose():
        // 移除监听器
        SettingsService().themeMode.removeListener(_onThemeChanged)
```

---

## 数据持久化策略

### 文件存储

```
存储位置: Documents/zhidu/settings.json
格式: JSON
写入时机: 每次设置更新后立即写入
读取时机: 服务初始化时
```

### JSON 结构

```json
{
  "aiSettings": {
    "provider": "qwen",
    "apiKey": "sk-xxx",
    "model": "qwen-plus",
    "baseUrl": "https://dashscope.aliyuncs.com/compatible-mode/v1"
  },
  "themeSettings": {
    "mode": "system"
  },
  "languageSettings": {
    "aiLanguageMode": "book",
    "aiOutputLanguage": "zh"
  }
}
```

---

## 与 AIService 的集成

### 配置同步机制

```pseudocode
// AIService 监听 SettingsService 的 AI 设置变化
METHOD AIService.init():
    // 添加监听器
    SettingsService().aiSettings.addListener(_onAiSettingsChanged)

METHOD AIService._onAiSettingsChanged():
    // AI 设置变化时重新加载配置
    _log.d('AIService', 'AI设置发生变化，重新加载配置')
    reloadConfig()
```

**同步流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│           SettingsService → AIService 同步流程               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  用户修改 AI 设置                                            │
│      ↓                                                      │
│  SettingsService.updateAiSettings()                         │
│      ├─ 更新 _settings                                      │
│      ├─ 更新 aiSettings.value                               │
│      └─ 保存到文件                                           │
│      ↓                                                      │
│  ValueNotifier 触发监听器                                    │
│      ↓                                                      │
│  AIService._onAiSettingsChanged()                           │
│      ↓                                                      │
│  AIService.reloadConfig()                                   │
│      ├─ 从 SettingsService 获取新配置                       │
│      └─ 更新 _config                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 错误处理

### 文件读取失败

```pseudocode
CATCH e:
    _log.e('SettingsService', '解析设置文件失败，使用默认设置', e)
    _settings = AppSettings()  // 使用默认设置继续
```

### 文件写入失败

```pseudocode
CATCH e, stackTrace:
    _log.e('SettingsService', '保存设置失败', e, stackTrace)
    THROW e  // 重新抛出，让调用方处理
```

---

## 并发控制

SettingsService 不使用并发控制，原因:

1. 设置更新通常是用户操作，频率低
2. 文件写入是异步操作，不会阻塞
3. ValueNotifier 内部有监听器管理机制

**注意事项:**

- 快速连续更新可能导致多次文件写入
- ValueNotifier 监听器在主线程执行
- dispose() 后不应再访问服务