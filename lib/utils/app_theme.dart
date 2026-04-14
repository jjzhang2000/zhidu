import 'package:flutter/material.dart';

/// 应用主题配置类
///
/// 定义应用的全局主题样式，包括颜色方案、文本样式、组件主题等。
/// 提供亮色主题（lightTheme）和暗色主题（darkTheme）两种配置。
///
/// 使用方式：
/// ```dart
/// MaterialApp(
///   theme: AppTheme.lightTheme,
///   darkTheme: AppTheme.darkTheme,
/// )
/// ```
class AppTheme {
  /// 主色调 - 深蓝灰色
  ///
  /// 用于AppBar背景、底部导航选中状态、标题文字等核心UI元素。
  /// 色值：#2C3E50（深蓝灰）
  static const Color primaryColor = Color(0xFF2C3E50);

  /// 强调色 - 橙色
  ///
  /// 用于浮动操作按钮(FAB)、重要按钮、高亮元素等。
  /// 与主色调形成对比，引导用户注意力。
  /// 色值：#E67E22（暖橙色）
  static const Color accentColor = Color(0xFFE67E22);

  /// 背景色 - 浅灰白色
  ///
  /// 用于页面背景，提供舒适的阅读底色。
  /// 色值：#F8F9FA（接近白色的浅灰）
  static const Color backgroundColor = Color(0xFFF8F9FA);

  /// 卡片背景色 - 白色
  ///
  /// 用于卡片、对话框等容器组件的背景。
  /// 与背景色形成层次感。
  static const Color cardColor = Colors.white;

  /// 亮色主题配置
  ///
  /// 返回适用于日间模式的主题数据，包含完整的颜色方案和组件样式。
  /// 主要特点：
  /// - 使用Material 3设计规范
  /// - 基于主色调生成完整色彩方案
  /// - 配置AppBar、卡片、浮动按钮等组件主题
  /// - 定义标题和正文文本样式
  ///
  /// 应用场景：普通日间使用，适合长时间阅读。
  static ThemeData get lightTheme {
    return ThemeData(
      // 启用Material 3设计系统
      useMaterial3: true,
      // 从主色调生成完整的颜色方案
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      // 页面背景色
      scaffoldBackgroundColor: backgroundColor,
      // AppBar主题配置
      appBarTheme: const AppBarTheme(
        centerTitle: true, // 标题居中
        elevation: 0, // 无阴影，扁平化设计
        backgroundColor: primaryColor, // 背景色使用主色调
        foregroundColor: Colors.white, // 前景色（标题、图标）为白色
      ),
      // 卡片主题配置
      cardTheme: const CardThemeData(
        elevation: 2, // 轻微阴影，增加层次感
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)), // 圆角12px
        ),
      ),
      // 浮动操作按钮主题
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor, // 背景使用强调色
        foregroundColor: Colors.white, // 图标为白色
        shape: CircleBorder(), // 圆形
      ),
      // 底部导航栏主题
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryColor, // 选中项使用主色调
        unselectedItemColor: Colors.grey, // 未选中项为灰色
      ),
      // 文本主题配置
      textTheme: const TextTheme(
        // 大标题样式 - 用于页面主标题
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        // 中标题样式 - 用于卡片标题、章节标题等
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        // 小标题样式 - 用于列表项标题、小节标题等
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
        // 大正文样式 - 用于主要内容文本
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        // 中正文样式 - 用于次要内容、描述文本等
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// 暗色主题配置
  ///
  /// 返回适用于夜间模式的主题数据，保护用户视力。
  /// 主要特点：
  /// - 深色背景减少屏幕光线
  /// - 保持与亮色主题一致的设计语言
  /// - 优化夜间阅读体验
  ///
  /// 应用场景：夜间阅读、暗光环境使用。
  static ThemeData get darkTheme {
    return ThemeData(
      // 启用Material 3设计系统
      useMaterial3: true,
      // 从主色调生成暗色方案
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      // 深色背景 - 纯黑带轻微灰度
      scaffoldBackgroundColor: const Color(0xFF121212),
      // AppBar主题配置
      appBarTheme: const AppBarTheme(
        centerTitle: true, // 标题居中
        elevation: 0, // 无阴影
        backgroundColor: primaryColor, // 保持与亮色主题一致的背景色
        foregroundColor: Colors.white, // 白色前景
      ),
      // 卡片主题配置
      cardTheme: const CardThemeData(
        elevation: 2, // 轻微阴影
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)), // 圆角12px
        ),
      ),
      // 浮动操作按钮主题
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor, // 强调色背景
        foregroundColor: Colors.white, // 白色图标
        shape: CircleBorder(), // 圆形
      ),
    );
  }
}
