import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'models/app_settings.dart' as models;
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/ai_service.dart';
import 'services/book_service.dart';
import 'services/library_import_service.dart';
import 'services/log_service.dart';
import 'services/parsers/book_format_parser.dart';
import 'services/parsers/epub_parser.dart';
import 'services/parsers/pdf_parser.dart';
import 'services/settings_service.dart';
import 'services/summary_service.dart';
import 'utils/app_theme.dart';

/// 判断当前是否为桌面平台（Windows/macOS/Linux）
bool isDesktopPlatform() {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// 初始化桌面窗口：设置标题、居中、显示
///
/// 移动/Web 平台直接返回，不执行任何操作。
Future<void> initDesktopWindow() async {
  if (!isDesktopPlatform()) return;

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: '智读',
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: true,
    ),
  );

  try {
    final display = await screenRetriever.getPrimaryDisplay();
    final displayPos = display.visiblePosition ?? const Offset(0, 0);
    final visibleSize = display.visibleSize ?? display.size;
    final double screenHeight = visibleSize.height;
    final double screenWidth = visibleSize.width;

    final double windowHeight = screenHeight;
    double windowWidth = windowHeight * 0.75;
    if (windowWidth > screenWidth) windowWidth = screenWidth;

    final double windowLeft = displayPos.dx + (screenWidth - windowWidth) / 2;
    final double windowTop = displayPos.dy + (screenHeight - windowHeight) / 2;

    await windowManager.setBounds(
      Rect.fromLTWH(windowLeft, windowTop, windowWidth, windowHeight),
    );
  } catch (e) {
    await windowManager.setSize(const Size(960, 720));
    await windowManager.center();
  }

  await windowManager.setMinimumSize(const Size(600, 400));
  await windowManager.show();
  // 拦截关闭事件，以便退出前保存书库导入进度
  await windowManager.setPreventClose(true);
}

/// 应用入口，初始化窗口、日志、服务后启动 ZhiduApp
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initDesktopWindow();

  await LogService().init(writeToFile: true);
  LogService().info('Main', '应用启动');

  _initializeFormatRegistry();

  await SettingsService().init();
  await BookService().init();
  await AIService().init();
  await SummaryService().init();
  await LibraryImportService().init();

  LogService().info('Main', '所有服务初始化完成');

  runApp(const ZhiduApp());
}

/// 注册所有支持的书籍格式解析器
void _initializeFormatRegistry() {
  FormatRegistry.register('.epub', EpubParser());
  FormatRegistry.register('.pdf', PdfParser());
  LogService().info('Main', '格式注册表初始化完成，支持: epub, pdf');
}

/// 应用根 Widget，监听设置变化驱动主题和语言切换
class ZhiduApp extends StatefulWidget {
  const ZhiduApp({super.key});

  @override
  State<ZhiduApp> createState() => _ZhiduAppState();
}

/// 根状态，管理主题和语言 Locale，通过监听 SettingsService 响应设置变更
class _ZhiduAppState extends State<ZhiduApp> with WindowListener {
  late final SettingsService _settingsService;
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    if (isDesktopPlatform()) {
      windowManager.addListener(this);
    }
    _settingsService = SettingsService();
    _settingsService.themeMode.addListener(_onAppSettingsChanged);
    _settingsService.languageSettings.addListener(_onAppSettingsChanged);
    _updateLocaleFromSettings();
  }

  @override
  void dispose() {
    if (isDesktopPlatform()) {
      windowManager.removeListener(this);
    }
    _settingsService.themeMode.removeListener(_onAppSettingsChanged);
    _settingsService.languageSettings.removeListener(_onAppSettingsChanged);
    _settingsService.dispose();
    SummaryService().dispose();
    super.dispose();
  }

  /// 窗口关闭前回调：保存书库导入进度、关闭日志后立即退出
  @override
  void onWindowClose() async {
    final stopwatch = Stopwatch()..start();
    await LibraryImportService().saveProgress();
    LogService().info('Main', '退出保存进度耗时: ${stopwatch.elapsedMilliseconds}ms');
    await LogService().dispose();
    exit(0);
  }

  /// 设置变更时触发重建，以更新主题和语言
  void _onAppSettingsChanged() {
    setState(_updateLocaleFromSettings);
  }

  /// 根据语言设置计算当前 Locale（跟随系统或用户自选）
  void _updateLocaleFromSettings() {
    final languageSettings = _settingsService.settings.languageSettings;
    final String languageCode = languageSettings.languageMode == 'manual'
        ? languageSettings.language
        : WidgetsBinding.instance.window.locale.languageCode;

    final Locale newLocale = switch (languageCode) {
      'en' => const Locale('en', 'US'),
      'ja' => const Locale('ja', 'JP'),
      _ => const Locale('zh', 'CN'),
    };

    if (_currentLocale?.languageCode != newLocale.languageCode) {
      _currentLocale = newLocale;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? '智读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _mapToFlutterThemeMode(_settingsService.themeMode.value),
      home: const HomeScreen(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
        Locale('ja', 'JP'),
      ],
      locale: _currentLocale,
    );
  }

  /// 将自定义 ThemeMode 映射为 Flutter ThemeMode
  ThemeMode _mapToFlutterThemeMode(models.ThemeMode appThemeMode) {
    return switch (appThemeMode) {
      models.ThemeMode.light => ThemeMode.light,
      models.ThemeMode.dark => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
