# window_utils.dart 伪代码文档

## 概述

**文件**: `lib/utils/window_utils.dart`
**用途**: 桌面平台窗口初始化和配置，设置窗口大小、位置、标题、最小尺寸
**依赖**: `window_manager`, `screen_retriever`

---

## 函数

### isDesktopPlatform() — 平台检测

```
FUNCTION isDesktopPlatform() -> bool:
    IF kIsWeb:
        RETURN false
    RETURN Platform.isWindows OR Platform.isMacOS OR Platform.isLinux
END FUNCTION
```

---

### initDesktopWindow() — 初始化桌面窗口

```
ASYNC FUNCTION initDesktopWindow() -> void:
    IF NOT isDesktopPlatform():
        RETURN

    await windowManager.ensureInitialized()

    // 窗口选项：标题、标题栏样式、按钮可见性
    await windowManager.waitUntilReadyToShow(
        WindowOptions(
            title: '智读',
            titleBarStyle: TitleBarStyle.normal,
            windowButtonVisibility: true,
        ),
    )

    TRY:
        // 获取主显示器可见区域
        display = await screenRetriever.getPrimaryDisplay()
        displayPos = display.visiblePosition ?? Offset(0, 0)
        visibleSize = display.visibleSize ?? display.size
        screenHeight = visibleSize.height
        screenWidth = visibleSize.width

        // 窗口尺寸：高度 = 屏幕高度，宽度 = 高度 * 0.75（4:3 比例）
        windowHeight = screenHeight
        windowWidth = windowHeight * 0.75

        // 宽度不超过屏幕
        IF windowWidth > screenWidth:
            windowWidth = screenWidth

        // 窗口居中
        windowLeft = displayPos.dx + (screenWidth - windowWidth) / 2
        windowTop = displayPos.dy + (screenHeight - windowHeight) / 2

        await windowManager.setBounds(
            Rect.fromLTWH(windowLeft, windowTop, windowWidth, windowHeight),
        )

    CATCH e:
        // 回退方案：固定尺寸 + 居中
        await windowManager.setSize(Size(960, 720))
        await windowManager.center()

    await windowManager.setMinimumSize(Size(600, 400))
    await windowManager.show()
END FUNCTION
```

---

## 窗口配置

| 属性 | 值 |
|------|------|
| 标题 | 智读 |
| 默认比例 | 4:3（宽 = 高 × 0.75） |
| 最大高度 | 显示器可见高度 |
| 最小尺寸 | 600 × 400 |
| 标题栏样式 | normal（系统原生） |

---

## 调用关系

| 调用方 | 被调用方法 |
|--------|-----------|
| `main.dart` | `initDesktopWindow()` |
