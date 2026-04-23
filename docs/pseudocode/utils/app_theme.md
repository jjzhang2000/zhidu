# app_theme.dart 伪代码说明

## 文件概述
应用主题配置类，定义全局主题样式和组件主题。

---

## 类：AppTheme

**功能**：定义应用的主题配置，包括颜色方案和组件样式

### 静态常量属性

```
CONST primaryColor = Color(0xFF2C3E50)     // 主色调 - 深蓝灰色
CONST accentColor = Color(0xFFE67E22)      // 强调色 - 橙色
CONST backgroundColor = Color(0xFFF8F9FA)  // 背景色 - 浅灰白色
CONST cardColor = Colors.white              // 卡片背景色 - 白色
```

---

### 方法：lightTheme (getter)

**功能**：获取亮色主题配置

**伪代码**：
```
GETTER lightTheme() -> ThemeData:
    RETURN ThemeData(
        // 1. 启用 Material 3 设计规范
        useMaterial3 = true,
        
        // 2. 从主色调生成完整颜色方案
        colorScheme = ColorScheme.fromSeed(
            seedColor = primaryColor,
            brightness = Brightness.light
        ),
        
        // 3. 设置页面背景色
        scaffoldBackgroundColor = backgroundColor,
        
        // 4. 配置 AppBar 主题
        appBarTheme = AppBarTheme(
            centerTitle = true,              // 标题居中
            elevation = 0,                   // 无阴影，扁平化
            backgroundColor = primaryColor,  // 背景使用主色调
            foregroundColor = Colors.white   // 前景色（标题、图标）为白色
        ),
        
        // 5. 配置卡片主题
        cardTheme = CardThemeData(
            elevation = 2,  // 轻微阴影
            shape = RoundedRectangleBorder(
                borderRadius = BorderRadius.all(Radius.circular(12))  // 圆角 12px
            )
        ),
        
        // 6. 配置浮动操作按钮主题
        floatingActionButtonTheme = FloatingActionButtonThemeData(
            backgroundColor = accentColor,  // 背景使用强调色
            foregroundColor = Colors.white, // 图标为白色
            shape = CircleBorder()          // 圆形
        ),
        
        // 7. 配置底部导航栏主题
        bottomNavigationBarTheme = BottomNavigationBarThemeData(
            selectedItemColor = primaryColor,    // 选中项使用主色调
            unselectedItemColor = Colors.grey    // 未选中项为灰色
        ),
        
        // 8. 配置文本主题
        textTheme = TextTheme(
            // 大标题 - 页面主标题
            headlineLarge = TextStyle(
                fontSize = 28,
                fontWeight = FontWeight.bold,
                color = primaryColor
            ),
            
            // 中标题 - 卡片标题、章节标题
            headlineMedium = TextStyle(
                fontSize = 24,
                fontWeight = FontWeight.bold,
                color = primaryColor
            ),
            
            // 小标题 - 列表项标题
            headlineSmall = TextStyle(
                fontSize = 20,
                fontWeight = FontWeight.w600,
                color = primaryColor
            ),
            
            // 大正文 - 主要内容
            bodyLarge = TextStyle(
                fontSize = 16,
                color = Colors.black87
            ),
            
            // 中正文 - 次要内容
            bodyMedium = TextStyle(
                fontSize = 14,
                color = Colors.black87
            )
        )
    )
END GETTER
```

---

### 方法：darkTheme (getter)

**功能**：获取暗色主题配置

**伪代码**：
```
GETTER darkTheme() -> ThemeData:
    RETURN ThemeData(
        // 1. 启用 Material 3 设计规范
        useMaterial3 = true,
        
        // 2. 从主色调生成暗色颜色方案
        colorScheme = ColorScheme.fromSeed(
            seedColor = primaryColor,
            brightness = Brightness.dark
        ),
        
        // 3. 设置深色背景（纯黑带轻微灰度）
        scaffoldBackgroundColor = Color(0xFF121212),
        
        // 4. 配置 AppBar 主题（保持与亮色主题一致）
        appBarTheme = AppBarTheme(
            centerTitle = true,              // 标题居中
            elevation = 0,                   // 无阴影
            backgroundColor = primaryColor,  // 背景使用主色调
            foregroundColor = Colors.white   // 白色前景
        ),
        
        // 5. 配置卡片主题
        cardTheme = CardThemeData(
            elevation = 2,  // 轻微阴影
            shape = RoundedRectangleBorder(
                borderRadius = BorderRadius.all(Radius.circular(12))  // 圆角 12px
            )
        ),
        
        // 6. 配置浮动操作按钮主题
        floatingActionButtonTheme = FloatingActionButtonThemeData(
            backgroundColor = accentColor,  // 强调色背景
            foregroundColor = Colors.white, // 白色图标
            shape = CircleBorder()          // 圆形
        )
        
        // 注意：暗色主题未配置 bottomNavigationBarTheme 和 textTheme
        // Flutter 会根据 brightness: Brightness.dark 自动调整
    )
END GETTER
```

---

## 主题配置对比

| 组件/属性 | 亮色主题 | 暗色主题 |
|-----------|---------|---------|
| scaffoldBackgroundColor | #F8F9FA (浅灰白) | #121212 (深黑) |
| colorScheme.brightness | Brightness.light | Brightness.dark |
| appBarTheme | 配置完整 | 配置完整 |
| cardTheme | 配置完整 | 配置完整 |
| floatingActionButtonTheme | 配置完整 | 配置完整 |
| bottomNavigationBarTheme | 配置完整 | 使用默认 |
| textTheme | 配置完整 | 使用默认 |

---

## 颜色使用场景

### primaryColor (#2C3E50 - 深蓝灰色)
- AppBar 背景
- 底部导航栏选中项
- 标题文字
- 强调文本

### accentColor (#E67E22 - 橙色)
- 浮动操作按钮 (FAB) 背景
- 重要按钮
- 高亮元素
- 引导用户注意力的元素

### backgroundColor (#F8F9FA - 浅灰白色)
- 页面背景
- 阅读底色
- 大面积背景区域

### cardColor (白色)
- 卡片容器背景
- 对话框背景
- 与 backgroundColor 形成层次感

---

## 设计原则

1. **Material 3 规范**：遵循最新的 Material Design 3 设计语言
2. **色彩对比**：主色调与强调色形成对比，引导视觉焦点
3. **层次感**：通过阴影和颜色深浅创建 UI 层次
4. **一致性**：亮色和暗色主题保持相同的设计语言
5. **可读性**：文本颜色与背景保持足够对比度
6. **圆角设计**：统一使用 12px 圆角，视觉柔和

---

## 使用示例

```dart
// 在 MaterialApp 中使用
MaterialApp(
  title: '智读',
  theme: AppTheme.lightTheme,      // 亮色主题
  darkTheme: AppTheme.darkTheme,   // 暗色主题
  themeMode: ThemeMode.system,     // 跟随系统
  home: HomeScreen()
)

// 在组件中使用主题颜色
Container(
  color: AppTheme.primaryColor,    // 主色调背景
  child: Text(
    '标题',
    style: Theme.of(context).textTheme.headlineMedium  // 使用主题文本样式
  )
)
```
