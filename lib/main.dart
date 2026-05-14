import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'utils/window_utils.dart';
import 'services/settings_service.dart';
import '../models/app_settings.dart' as AppModels;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 在桌面平台上初始化窗口管理（内部会检查平台）
  await initDesktopWindow();

  await LogService().init(
    minLevel: LogLevel.verbose,
    writeToFile: true,
  );

  LogService().info('Main', '应用启动');

  _initializeFormatRegistry();

  await SettingsService().init();
  await BookService().init();
  await AIService().init();
  await SummaryService().init();

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
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService();
    _settingsService.themeMode.addListener(_onAppSettingsChanged);
    _settingsService.languageSettings.addListener(_onAppSettingsChanged);

    _updateLocaleFromSettings();
  }

  @override
  void dispose() {
    _settingsService.themeMode.removeListener(_onAppSettingsChanged);
    _settingsService.languageSettings.removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  void _onAppSettingsChanged() {
    setState(() {
      _updateLocaleFromSettings();
    });
  }

  void _updateLocaleFromSettings() {
    final languageSettings = _settingsService.settings.languageSettings;
    String languageCode = 'zh';

    if (languageSettings.uiLanguageMode == 'manual') {
      languageCode = languageSettings.uiLanguage;
    } else {
      languageCode = WidgetsBinding.instance.window.locale.languageCode;
    }

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
    ThemeMode flutterThemeMode =
        _mapToFlutterThemeMode(_settingsService.themeMode.value);

    return MaterialApp(
      title: _currentLocale != null
          ? AppLocalizations.of(context)?.appTitle ?? '智读'
          : '智读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: flutterThemeMode,
      home: const HomeScreen(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
        Locale('ja', 'JP'),
      ],
      locale: _currentLocale,
    );
  }

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
