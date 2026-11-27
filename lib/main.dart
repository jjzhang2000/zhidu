import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform, exit;

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
import 'services/storage_config.dart';
import 'utils/app_theme.dart';

/// 判断当前是否为桌面平台（Windows/macOS/Linux）
bool isDesktopPlatform() {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// 窗口状态文件名（保存在 Documents/zhidu/ 下）
const _windowStateFileName = 'window_state.json';

/// 最小窗口尺寸（与 setMinimumSize 保持一致）
const _minWindowSize = Size(600, 400);

/// 上次退出时保存的窗口状态
class _SavedWindowState {
  /// 窗口位置与尺寸（最大化时为最大化前的尺寸）
  final Rect bounds;

  /// 退出时是否处于最大化
  final bool maximized;

  const _SavedWindowState(this.bounds, this.maximized);
}

/// 读取上次保存的窗口状态（不存在或数据损坏时返回 null）
Future<_SavedWindowState?> _readSavedWindowState() async {
  try {
    final dir = await StorageConfig.getAppDirectory();
    final file = File('${dir.path}/$_windowStateFileName');
    if (!await file.exists()) return null;

    final json = jsonDecode(await file.readAsString());
    if (json is! Map) return null;

    final left = (json['left'] as num?)?.toDouble();
    final top = (json['top'] as num?)?.toDouble();
    final width = (json['width'] as num?)?.toDouble();
    final height = (json['height'] as num?)?.toDouble();
    if (left == null || top == null || width == null || height == null) {
      return null;
    }
    if (width < _minWindowSize.width || height < _minWindowSize.height) {
      return null;
    }
    return _SavedWindowState(
      Rect.fromLTWH(left, top, width, height),
      json['maximized'] == true,
    );
  } catch (_) {
    return null;
  }
}

/// 保存窗口状态（位置/尺寸/是否最大化）
Future<void> _writeSavedWindowState(Rect bounds, bool maximized) async {
  try {
    final dir = await StorageConfig.getAppDirectory();
    final file = File('${dir.path}/$_windowStateFileName');
    await file.writeAsString(jsonEncode({
      'left': bounds.left,
      'top': bounds.top,
      'width': bounds.width,
      'height': bounds.height,
      'maximized': maximized,
    }));
  } catch (_) {
    // 保存失败不影响退出流程
  }
}

/// 窗口矩形是否仍落在某个显示器的可见区域内
///
/// 显示器被拔掉/分辨率变化后，保存的坐标可能完全落在屏幕外，此时应回退默认位置。
Future<bool> _isWindowVisibleOnSomeDisplay(Rect bounds) async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    for (final display in displays) {
      final pos = display.visiblePosition ?? Offset.zero;
      final size = display.visibleSize ?? display.size;
      final visible = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
      final overlap = bounds.intersect(visible);
      if (overlap.width >= 120 && overlap.height >= 80) return true;
    }
  } catch (_) {
    // 无法获取显示器信息时按不可见处理，回到默认位置
  }
  return false;
}

/// 初始化桌面窗口：恢复上次窗口状态，首次运行时居中显示
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

  // 恢复上次退出时的窗口位置/尺寸；显示器变化导致不可见时退回默认位置
  final saved = await _readSavedWindowState();
  final restored = saved != null && await _isWindowVisibleOnSomeDisplay(saved.bounds);

  if (restored) {
    await windowManager.setBounds(saved.bounds);
  } else {
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
  }

  await windowManager.setMinimumSize(_minWindowSize);
  // 恢复最大化：先最大化再显示，避免「普通窗口先出现、再跳成最大化」的闪烁。
  // （runner 首帧的 Show 已改为 SW_SHOW，不会再把这个状态还原成普通窗口）
  if (restored && saved.maximized) {
    await windowManager.maximize();
  }
  await windowManager.show();
  // 个别平台在隐藏状态下忽略最大化，显示后再确认一次
  if (restored && saved.maximized && !await windowManager.isMaximized()) {
    await windowManager.maximize();
  }
  // 拦截关闭事件，以便退出前保存书库导入进度与窗口状态
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

  /// 最近一次「非最大化」时的窗口位置/尺寸
  ///
  /// 最大化状态下 getBounds 返回的是最大化后的尺寸，直接保存会丢掉用户平时的
  /// 窗口大小，因此持续记录非最大化尺寸，退出时与最大化标记一起保存。
  Rect? _lastNormalBounds;

  @override
  void initState() {
    super.initState();
    if (isDesktopPlatform()) {
      windowManager.addListener(this);
      unawaited(_captureNormalWindowBounds());
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
    super.dispose();
  }

  /// 窗口尺寸/位置变化时记录非最大化状态下的窗口矩形
  @override
  void onWindowResize() {
    unawaited(_captureNormalWindowBounds());
  }

  @override
  void onWindowMove() {
    unawaited(_captureNormalWindowBounds());
  }

  /// 记录非最大化状态下的窗口矩形（最大化/最小化时跳过）
  Future<void> _captureNormalWindowBounds() async {
    if (!isDesktopPlatform()) return;
    try {
      if (await windowManager.isMinimized()) return;
      if (await windowManager.isMaximized()) return;
      final bounds = await windowManager.getBounds();
      if (_isUsableWindowBounds(bounds)) _lastNormalBounds = bounds;
    } catch (_) {
      // 窗口信息暂不可用，忽略
    }
  }

  /// 窗口矩形是否可当作「普通窗口」尺寸保存
  ///
  /// 最小化时 `getBounds()` 返回的是任务栏图标坐标（尺寸远小于最小值），
  /// 直接保存会让下次启动回退到默认位置，需过滤。
  bool _isUsableWindowBounds(Rect? bounds) {
    if (bounds == null) return false;
    return bounds.width >= _minWindowSize.width &&
        bounds.height >= _minWindowSize.height;
  }

  /// 保存窗口状态（最大化时保留最大化前的窗口尺寸）
  Future<void> _saveWindowState() async {
    if (!isDesktopPlatform()) return;
    try {
      final maximized = await windowManager.isMaximized();
      final minimized = await windowManager.isMinimized();

      // 最大化/最小化时 getBounds() 不是可恢复的普通窗口矩形，改用最近一次
      // 记录的普通窗口尺寸；没有记录时沿用上次文件中的窗口尺寸
      Rect? bounds;
      if (!maximized && !minimized) {
        bounds = await windowManager.getBounds();
      }
      if (!_isUsableWindowBounds(bounds)) bounds = _lastNormalBounds;
      if (!_isUsableWindowBounds(bounds)) {
        bounds = (await _readSavedWindowState())?.bounds;
      }
      if (!_isUsableWindowBounds(bounds)) return;

      await _writeSavedWindowState(bounds!, maximized);
    } catch (_) {
      // 保存失败不影响退出流程
    }
  }

  /// 窗口关闭前回调：保存窗口状态、书库导入进度，关闭日志后立即退出
  @override
  void onWindowClose() async {
    final stopwatch = Stopwatch()..start();
    await _saveWindowState();
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
        : WidgetsBinding.instance.platformDispatcher.locale.languageCode;

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
