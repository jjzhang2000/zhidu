import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/book_service.dart';
import 'services/ai_service.dart';
import 'services/summary_service.dart';
import 'services/log_service.dart';
import 'services/parsers/format_registry.dart';
import 'services/parsers/epub_parser.dart';
import 'services/parsers/pdf_parser.dart';
import 'utils/app_theme.dart';
import 'services/settings_service.dart';
import '../models/app_settings.dart' as AppModels;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志服务（可选：启用文件日志）
  await LogService().init(
    minLevel: LogLevel.verbose, // 记录所有级别日志
    writeToFile: true, // 同时写入文件
  );

  LogService().info('Main', '应用启动');

  // 初始化格式注册表
  _initializeFormatRegistry();

  await BookService().init();
  await AIService().init();
  await SummaryService().init();
  await SettingsService().init(); // 初始化设置服务

  LogService().info('Main', '所有服务初始化完成');

  runApp(
    const ZhiduApp(),
  );
}

/// 初始化格式注册表，注册所有支持的解析器
void _initializeFormatRegistry() {
  FormatRegistry.register('.epub', EpubParser());
  FormatRegistry.register('.pdf', PdfParser());
  LogService().info('Main', '格式注册表初始化完成，支持: epub, pdf');
}

class ZhiduApp extends StatefulWidget {
  const ZhiduApp({super.key});

  @override
  State<ZhiduApp> createState() => _ZhiduAppState();
}

class _ZhiduAppState extends State<ZhiduApp> {
  late final SettingsService _settingsService;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService();
    // 添加监听器，当主题模式改变时重建UI
    _settingsService.themeMode.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    _settingsService.themeMode.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  void _onThemeModeChanged() {
    // 当主题模式发生变化时，重建UI以应用新主题
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 将自定义的ThemeMode枚举转换为Flutter的ThemeMode
    ThemeMode flutterThemeMode =
        _mapToFlutterThemeMode(_settingsService.themeMode.value);

    return MaterialApp(
      title: '智读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: flutterThemeMode, // 使用转换后的Flutter主题模式
      home: const HomeScreen(),
    );
  }

  /// 将自定义的ThemeMode枚举映射到Flutter的ThemeMode
  ThemeMode _mapToFlutterThemeMode(AppModels.ThemeMode appThemeMode) {
    switch (appThemeMode) {
      case AppModels.ThemeMode.light:
        return ThemeMode.light;
      case AppModels.ThemeMode.dark:
        return ThemeMode.dark;
      case AppModels.ThemeMode.system:
      default:
        return ThemeMode.system;
    }
  }
}
