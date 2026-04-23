# main.dart 伪代码说明

## 文件概述
应用入口文件，负责初始化所有服务并启动 Flutter 应用。

---

## 函数：main()

**功能**：应用启动入口，初始化所有服务

**伪代码**：
```
FUNCTION main() ASYNC:
    // 1. 确保 Flutter 绑定已初始化
    CALL WidgetsFlutterBinding.ensureInitialized()
    
    // 2. 初始化日志服务
    AWAIT LogService().init(
        minLevel = LogLevel.verbose,  // 记录所有级别日志
        writeToFile = true            // 启用文件日志
    )
    LOG "应用启动"
    
    // 3. 初始化格式注册表（注册 EPUB 和 PDF 解析器）
    CALL _initializeFormatRegistry()
    
    // 4. 初始化设置服务（优先初始化，其他服务依赖它）
    AWAIT SettingsService().init()
    
    // 5. 初始化其他依赖设置的服务
    AWAIT BookService().init()        // 书籍管理服务
    AWAIT AIService().init()          // AI服务
    AWAIT SummaryService().init()     // 摘要服务
    LOG "所有服务初始化完成"
    
    // 6. 启动 Flutter 应用
    CALL runApp(ZhiduApp())
END FUNCTION
```

---

## 函数：_initializeFormatRegistry()

**功能**：注册所有支持的文件格式解析器

**伪代码**：
```
FUNCTION _initializeFormatRegistry():
    // 1. 注册 EPUB解析器
    CALL FormatRegistry.register('.epub', EpubParser())
    
    // 2. 注册 PDF 解析器
    CALL FormatRegistry.register('.pdf', PdfParser())
    
    // 3. 记录日志
    LOG "格式注册表初始化完成，支持：epub, pdf"
END FUNCTION
```

---

## 类：ZhiduApp

**功能**：应用根组件，管理全局主题和语言设置

### 状态：_ZhiduAppState

#### 属性
- `_settingsService`: SettingsService 实例
- `_currentLocale`: 当前语言环境（Locale?）

---

#### 方法：initState()

**功能**：初始化状态，设置监听器

**伪代码**：
```
METHOD initState():
    CALL super.initState()
    
    // 1. 获取设置服务实例
    _settingsService = SettingsService()
    
    // 2. 为主题模式添加监听器
    CALL _settingsService.themeMode.addListener(_onAppSettingsChanged)
    
    // 3. 为语言设置添加监听器
    CALL _settingsService.languageSettings.addListener(_onAppSettingsChanged)
    
    // 4. 初始化语言设置
    CALL _updateLocaleFromSettings()
END METHOD
```

---

#### 方法：dispose()

**功能**：清理资源，移除监听器

**伪代码**：
```
METHOD dispose():
    // 1. 移除主题模式监听器
    CALL _settingsService.themeMode.removeListener(_onAppSettingsChanged)
    
    // 2. 移除语言设置监听器
    CALL _settingsService.languageSettings.removeListener(_onAppSettingsChanged)
    
    CALL super.dispose()
END METHOD
```

---

#### 方法：_onAppSettingsChanged()

**功能**：设置变化时的回调，重建 UI

**伪代码**：
```
METHOD _onAppSettingsChanged():
    // 1. 触发 UI 重建
    CALL setState(() 
        // 2. 更新语言环境
        CALL _updateLocaleFromSettings()
    )
END METHOD
```

---

#### 方法：_updateLocaleFromSettings()

**功能**：根据设置更新语言环境

**伪代码**：
```
METHOD _updateLocaleFromSettings():
    // 1. 获取语言设置
    languageSettings = _settingsService.settings.languageSettings
    languageCode = 'zh'  // 默认中文
    
    // 2. 根据语言模式确定语言代码
    IF languageSettings.uiLanguageMode == 'manual' THEN
        // 手动模式：使用用户选择的语言
        languageCode = languageSettings.uiLanguage
    ELSE
        // 跟随系统模式：使用设备语言
        languageCode = WidgetsBinding.instance.window.locale.languageCode
    END IF
    
    // 3. 根据语言代码创建 Locale 对象
    SWITCH languageCode:
        CASE 'en':
            newLocale = Locale('en', 'US')
        CASE 'ja':
            newLocale = Locale('ja', 'JP')
        CASE 'zh' OR DEFAULT:
            newLocale = Locale('zh', 'CN')
    END SWITCH
    
    // 4. 如果语言发生变化，更新当前 Locale
    IF _currentLocale?.languageCode != newLocale.languageCode THEN
        _currentLocale = newLocale
    END IF
END METHOD
```

---

#### 方法：build()

**功能**：构建应用 UI

**伪代码**：
```
METHOD build(BuildContext context) -> Widget:
    // 1. 转换主题模式枚举
    flutterThemeMode = CALL _mapToFlutterThemeMode(
        _settingsService.themeMode.value
    )
    
    // 2. 创建 MaterialApp
    RETURN MaterialApp(
        title: _currentLocale != null ? 
            AppLocalizations.of(context)?.appTitle ?? '智读' : '智读',
        debugShowCheckedModeBanner = false,
        theme = AppTheme.lightTheme,          // 亮色主题
        darkTheme = AppTheme.darkTheme,       // 暗色主题
        themeMode = flutterThemeMode,         // 主题模式
        home = HomeScreen(),                  // 首页
        
        // 3. 配置国际化
        localizationsDelegates = [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales = [
            Locale('zh', 'CN'),  // 中文
            Locale('en', 'US'),  // 英文
            Locale('ja', 'JP')   // 日文
        ],
        locale = _currentLocale
    )
END METHOD
```

---

#### 方法：_mapToFlutterThemeMode()

**功能**：将自定义 ThemeMode 枚举映射到 Flutter 的 ThemeMode

**伪代码**：
```
METHOD _mapToFlutterThemeMode(AppModels.ThemeMode appThemeMode) -> ThemeMode:
    SWITCH appThemeMode:
        CASE ThemeMode.light:
            RETURN ThemeMode.light
        CASE ThemeMode.dark:
            RETURN ThemeMode.dark
        CASE ThemeMode.system OR DEFAULT:
            RETURN ThemeMode.system
    END SWITCH
END METHOD
```

---

## 数据流图

```
应用启动
    ↓
main()
    ↓
初始化服务 (LogService → SettingsService → BookService → AIService → SummaryService)
    ↓
启动 ZhiduApp
    ↓
build() 创建 MaterialApp
    ↓
监听设置变化 (主题/语言)
    ↓
用户交互
```

---

## 关键设计点

1. **服务初始化顺序**：SettingsService 优先初始化，其他服务依赖它
2. **响应式更新**：使用 ValueNotifier 监听设置变化，自动重建 UI
3. **国际化支持**：支持中文、英文、日文三种语言
4. **主题管理**：支持亮色、暗色、跟随系统三种主题模式
5. **单例模式**：所有 Service 使用单例模式，全局共享状态
