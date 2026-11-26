import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus_platform_interface/package_info_data.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';
import 'package:zhidu/models/app_settings.dart';
import 'package:zhidu/screens/settings_screen.dart';
import 'package:zhidu/services/settings_service.dart';
import '../helpers/test_app.dart';

class _FakePackageInfoPlatform extends PackageInfoPlatform {
  @override
  Future<PackageInfoData> getAll({String? baseUrl}) async {
    return PackageInfoData(
      appName: '智读',
      packageName: 'com.zhidu.app',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  }
}

/// 以较大的测试窗口渲染设置页，确保下方区块（书库/关于）能被 ListView 构建
Future<void> _pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(buildTestApp(const SettingsScreen()));
}

void main() {
  setUp(() {
    SettingsService.resetForTest();
    PackageInfoPlatform.instance = _FakePackageInfoPlatform();
  });

  tearDown(() {
    SettingsService.resetForTest();
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('renders AppBar with correct title',
        (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('renders Scaffold with body', (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders ListView with sections', (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders all section headers', (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.text('AI'), findsOneWidget);
      expect(find.text('主题'), findsOneWidget);
      expect(find.text('语言'), findsOneWidget);
      expect(find.text('书库'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('renders AI service section', (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.text('AI 服务设置'), findsOneWidget);
      expect(find.text('未配置（点击设置）'), findsOneWidget);
      expect(find.byIcon(Icons.api), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('renders theme mode radio options', (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.byType(RadioListTile<ThemeMode>), findsNWidgets(3));
      expect(find.text('浅色'), findsOneWidget);
      expect(find.text('深色'), findsOneWidget);
      // '跟随系统' 同时出现在主题与语言两个区块
      expect(find.text('跟随系统'), findsNWidgets(2));
    });

    testWidgets('renders language mode radio options',
        (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.byType(RadioListTile<String>), findsNWidgets(2));
      expect(find.text('用户自选'), findsOneWidget);
    });

    testWidgets('renders library section', (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.text('Calibre书库位置：'), findsOneWidget);
      expect(find.text('浏览'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('清空书架'), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
    });

    testWidgets('renders about section', (WidgetTester tester) async {
      await _pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(find.text('智读'), findsOneWidget);
      expect(find.text('版本 0.1.0'), findsOneWidget);
      expect(find.text('AI 分层阅读器'), findsOneWidget);
      expect(find.text('先读薄，再读厚'), findsOneWidget);
    });

    testWidgets('has dividers between sections', (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('AI section tile is tappable', (WidgetTester tester) async {
      await _pumpSettings(tester);

      final aiTile = find.widgetWithText(ListTile, 'AI 服务设置');
      expect(aiTile, findsOneWidget);

      final tileWidget = tester.widget<ListTile>(aiTile.first);
      expect(tileWidget.onTap, isNotNull);
    });
  });
}
