import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';

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

  // 初始化窗口管理器（仅桌面版）
  await _initWindowManager();

  // 初始化日志服务（可选：启用文件日志）
  await LogService().init(
    minLevel: LogLevel.verbose, // 记录所有级别日志
    writeToFile: true, // 同时写入文件
  );

  LogService().info('Main', '应用启动');

  // 初始化格式注册表
  _initializeFormatRegistry();

  // 重要：首先初始化设置服务以确保自定义路径被加载
  await SettingsService().init(); // 初始化设置服务
  // 然后初始化其他依赖设置的服务
  await BookService().init();
  await AIService().init();
  await SummaryService().init();

  LogService().info('Main', '所有服务初始化完成');

  runApp(
    const ZhiduApp(),
  );
}

/// 初始化桌面窗口管理器
Future<void> _initWindowManager() async {
  await windowManager.ensureInitialized();

  // 设置窗口最小尺寸
  await windowManager.setMinimumSize(const Size(600, 400));
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
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService();
    // 添加监听器，当主题模式和语言设置改变时重建UI
    _settingsService.themeMode.addListener(_onAppSettingsChanged);
    _settingsService.languageSettings.addListener(_onAppSettingsChanged);

    // 初始化语言设置
    _updateLocaleFromSettings();
  }

  @override
  void dispose() {
    _settingsService.themeMode.removeListener(_onAppSettingsChanged);
    _settingsService.languageSettings.removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  void _onAppSettingsChanged() {
    // 当主题模式或语言设置发生变化时，重建UI以应用新设置
    setState(() {
      _updateLocaleFromSettings();
    });
  }

  /// 根据应用设置更新语言环境
  void _updateLocaleFromSettings() {
    final languageSettings = _settingsService.settings.languageSettings;
    String languageCode = 'zh'; // 默认中文

    if (languageSettings.uiLanguageMode == 'manual') {
      // 如果手动选择了界面语言，使用选择的语言
      languageCode = languageSettings.uiLanguage;
    } else {
      // 如果跟随系统，获取系统语言（这里简化处理）
      // 实际情况下，可以获取设备的首选语言
      languageCode = WidgetsBinding.instance.window.locale.languageCode;
    }

    // 根据语言代码设置地区
    Locale newLocale;
    switch (languageCode) {
      case 'en':
        newLocale = const Locale('en', 'US');
        break;
      case 'ja':
        newLocale = const Locale('ja', 'JP');
        break;
      case 'zh':
      default:
        newLocale = const Locale('zh', 'CN');
        break;
    }

    if (_currentLocale?.languageCode != newLocale.languageCode) {
      _currentLocale = newLocale;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 将自定义的ThemeMode枚举转换为Flutter的ThemeMode
    ThemeMode flutterThemeMode =
        _mapToFlutterThemeMode(_settingsService.themeMode.value);

    return MaterialApp(
      title: _currentLocale != null
          ? AppLocalizations.of(context)?.appTitle ?? '智读'
          : '智读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: flutterThemeMode, // 使用转换后的Flutter主题模式
      home: const HomeScreen(),
      // 添加国际化支持
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文
        Locale('en', 'US'), // 英文
        Locale('ja', 'JP'), // 日文
      ],
      locale: _currentLocale,
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
