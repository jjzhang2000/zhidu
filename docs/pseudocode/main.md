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

    // 2. 初始化窗口管理器（桌面版，设置窗口尺寸和位置）
    AWAIT _initWindowManager()

    // 3. 初始化日志服务
    AWAIT LogService().init(
        minLevel = LogLevel.verbose,
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

## 函数：_initWindowManager()

**功能**：初始化桌面窗口管理器，处理多显示器 DPI 适配，设置窗口尺寸和位置

**伪代码**：

```
FUNCTION _initWindowManager() ASYNC:
    // 1. 确保窗口管理器已初始化
    AWAIT windowManager.ensureInitialized()

    // 2. 等待窗口准备就绪（阻止窗口在设置好之前闪现）
    AWAIT windowManager.waitUntilReadyToShow()

    // 3. 多显示器 DPI 适配
    TRY:
        // 3a. 获取所有显示器信息（支持多显示器 + 不同 DPI）
        displays = AWAIT screenRetriever.getAllDisplays()

        // 3b. 获取窗口当前实际位置（Windows 默认放置位置）
        windowBounds = AWAIT windowManager.getBounds()

        // 3c. 计算窗口中心点
        windowCenterX = windowBounds.x + windowBounds.width / 2
        windowCenterY = windowBounds.y + windowBounds.height / 2

        // 3d. 遍历所有显示器，找到包含窗口中心点的目标显示器
        targetDisplay = displays.first  // 默认第一个
        FOR EACH display IN displays:
            displayLeft = display.visiblePosition?.dx ?? 0
            displayTop = display.visiblePosition?.dy ?? 0
            displayRight = displayLeft + display.size.width
            displayBottom = displayTop + display.size.height

            IF windowCenterX >= displayLeft
               AND windowCenterX <= displayRight
               AND windowCenterY >= displayTop
               AND windowCenterY <= displayBottom THEN
                targetDisplay = display
                BREAK
            END IF
        END FOR

        // 3e. 基于目标显示器的工作区计算窗口尺寸
        displayPos = targetDisplay.visiblePosition ?? Offset(0, 0)
        visibleSize = targetDisplay.visibleSize ?? targetDisplay.size
        screenHeight = visibleSize.height
        screenWidth = visibleSize.width

        // 3f. 计算窗口尺寸：高度=屏幕高，宽度=高度×0.75（3:4比例）
        windowHeight = screenHeight
        windowWidth = windowHeight * 0.75

        IF windowWidth > screenWidth THEN
            windowWidth = screenWidth
        END IF

        // 3g. 在目标显示器上居中
        windowLeft = displayPos.dx + (screenWidth - windowWidth) / 2
        windowTop = displayPos.dy + (screenHeight - windowHeight) / 2

        AWAIT windowManager.setBounds(Rect.fromLTWH(
            windowLeft, windowTop, windowWidth, windowHeight
        ))

    CATCH (e):
        // 3h. 获取屏幕信息失败时使用默认尺寸
        LOG WARNING "获取屏幕尺寸失败，使用默认窗口大小: {e}"
        AWAIT windowManager.setSize(Size(960, 720))
        AWAIT windowManager.center()
    END TRY

    // 4. 设置窗口最小尺寸
    AWAIT windowManager.setMinimumSize(Size(600, 400))

    // 5. 显示窗口（所有设置完成后才显示，避免闪烁）
    AWAIT windowManager.show()
END FUNCTION
```

**关键设计点**：

- **多显示器支持**: 使用 `getAllDisplays()` 而非 `getPrimaryDisplay()`，支持多显示器不同 DPI 的环境
- **窗口中心点匹配**: 通过窗口中心坐标找到窗口实际所在的显示器（而非假设在主显示器）
- **visiblePosition**: 工作区在虚拟桌面上的坐标位置，用于精确计算窗口在目标显示器上的位置
- **visibleSize vs size**: `visibleSize` 排除任务栏，`size` 是完整屏幕尺寸
- **waitUntilReadyToShow**: 阻止窗口在设置好之前闪现，避免用户看到窗口从默认位置跳到目标位置
- **异常回退**: 如果 `screen_retriever` 获取失败（如非桌面平台），使用默认 960×720
- **show() 最后调用**: 确保所有尺寸和位置设置完成后再显示窗口

**窗口尺寸策略**：

- 高度 = 目标显示器工作区高度（全屏高，不含任务栏）
- 宽度 = 高度 × 0.75（3:4 宽高比）
- 如果计算宽度超过屏幕宽度，则宽度回退为屏幕宽度
- 窗口在目标显示器上居中显示

**screen_retriever Display 字段**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `visiblePosition` | `Offset?` | 工作区在虚拟桌面上的位置 (逻辑像素) |
| `visibleSize` | `Size?` | 工作区尺寸 (逻辑像素，排除任务栏) |
| `size` | `Size` | 显示器总分辨率 (逻辑像素) |
| `scaleFactor` | `num?` | DPI 缩放因子 |

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
初始化窗口管理器 (_initWindowManager)
    ├─ windowManager.ensureInitialized()
    ├─ windowManager.waitUntilReadyToShow()
    ├─ screenRetriever.getAllDisplays() → 获取所有显示器
    ├─ windowManager.getBounds() → 窗口中心点匹配目标显示器
    ├─ 基于目标显示器计算窗口尺寸和居中位置
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

1. **窗口初始化优先**: `_initWindowManager()` 在所有服务初始化之前执行，确保窗口尺寸和位置在应用启动时就正确设置
2. **双层窗口管理**: C++ 原生层（main.cpp）负责创建默认窗口，Dart 层（window_manager）负责精确尺寸和位置调整
3. **多显示器 DPI 适配**: Dart 层通过 `getAllDisplays()` + 窗口中心点匹配，自动适配多显示器不同 DPI 环境
4. **防闪烁**: `waitUntilReadyToShow()` + `show()` 确保窗口在所有设置完成后再显示
5. **服务初始化顺序**：SettingsService 优先初始化，其他服务依赖它
6. **响应式更新**：使用 ValueNotifier 监听设置变化，自动重建 UI
7. **国际化支持**：支持中文、英文、日文三种语言
8. **主题管理**：支持亮色、暗色、跟随系统三种主题模式
9. **单例模式**：所有 Service 使用单例模式，全局共享状态
