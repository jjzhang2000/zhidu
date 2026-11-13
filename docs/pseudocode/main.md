# main.dart 伪代码说明

## 文件概述

应用入口文件，负责初始化窗口管理器、所有服务并启动 Flutter 应用。

---

## 函数：main()

**功能**：应用启动入口，初始化窗口管理器和服务

**伪代码**：

```
FUNCTION main() ASYNC:
    // 1. 确保 Flutter 绑定已初始化
    CALL WidgetsFlutterBinding.ensureInitialized()

    // 2. 初始化桌面窗口（标题、尺寸、位置、最小尺寸）
    AWAIT initDesktopWindow()

    // 3. 初始化日志服务（logging 官方库 + 文件持久化）
    AWAIT LogHelper.init(
        minLevel = Level.ALL,
        writeToFile = true
    )
    LOG "应用启动"

    // 4. 初始化格式注册表（注册 EPUB 和 PDF 解析器）
    CALL _initializeFormatRegistry()

    // 5. 初始化设置服务（优先初始化，其他服务依赖它）
    AWAIT SettingsService().init()

    // 6. 初始化其他依赖设置的服务
    AWAIT BookService().init()
    AWAIT AIService().init()
    AWAIT SummaryService().init()
    LOG "所有服务初始化完成"

    // 7. 启动 Flutter 应用
    CALL runApp(ZhiduApp())
END FUNCTION
```

---

## 函数：initDesktopWindow()

窗口初始化函数，位于 main.dart 中（原 window_utils.dart 已合并入 main.dart）。

核心流程：
- 平台检测（Windows/macOS/Linux），非桌面平台自动跳过
- `windowManager.ensureInitialized()` 初始化窗口管理器
- `windowManager.waitUntilReadyToShow(WindowOptions(title: '智读'))` 设置窗口标题
- 获取主显示器可见区域，计算 4:3 比例窗口尺寸并居中
- 设置最小尺寸 600×400，最后调用 `show()` 显示窗口

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
初始化桌面窗口 (initDesktopWindow)
    ├─ windowManager.ensureInitialized()
    ├─ windowManager.waitUntilReadyToShow(WindowOptions(title: '智读'))
    ├─ screenRetriever.getPrimaryDisplay() → 获取显示器信息
    ├─ 计算窗口尺寸和居中位置
    ├─ windowManager.setBounds() → 精确设置位置和尺寸
    ├─ windowManager.setMinimumSize(600, 400)
    └─ windowManager.show()
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

1. **窗口初始化优先**: `initDesktopWindow()` 在所有服务初始化之前执行，通过 `WindowOptions(title: '智读')` 显式设置窗口标题，确保中文正确显示
2. **窗口初始化封装**: 窗口逻辑封装在 `initDesktopWindow()` 中（位于 main.dart），支持桌面平台检测（Windows/macOS/Linux），非桌面平台自动跳过
3. **防闪烁**: `waitUntilReadyToShow()` + `show()` 确保窗口在所有设置完成后再显示
4. **服务初始化顺序**：SettingsService 优先初始化，其他服务依赖它
5. **响应式更新**：使用 ValueNotifier 监听设置变化，自动重建 UI
6. **国际化支持**：支持中文、英文、日文三种语言
7. **主题管理**：支持亮色、暗色、跟随系统三种主题模式
8. **单例模式**：所有 Service 使用单例模式，全局共享状态
