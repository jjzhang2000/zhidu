import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zhidu/main.dart';
import 'package:zhidu/utils/app_theme.dart';
import 'package:zhidu/screens/home_screen.dart';
import 'package:zhidu/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZhiduApp Widget Tests', () {
    setUp(() {
      SettingsService.resetForTest();
    });

    testWidgets('ZhiduApp renders MaterialApp', (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('MaterialApp has correct title', (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.onGenerateTitle, isNotNull);
      final context = tester.element(find.byType(HomeScreen));
      expect(materialApp.onGenerateTitle!(context), isNotEmpty);
    });

    testWidgets('MaterialApp hides debug banner', (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('MaterialApp uses system theme mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.system));
    });

    testWidgets('MaterialApp has light theme configured',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
      expect(materialApp.theme?.useMaterial3, isTrue);
      expect(materialApp.theme?.scaffoldBackgroundColor,
          equals(AppTheme.backgroundColor));
    });

    testWidgets('MaterialApp has dark theme configured',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.darkTheme, isNotNull);
      expect(materialApp.darkTheme?.useMaterial3, isTrue);
    });

    testWidgets('HomeScreen is set as home widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('ZhiduApp builds without errors', (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      expect(tester.takeException(), isNull);
    });
  });

  group('Theme Configuration Tests', () {
    test('AppTheme primaryColor is defined', () {
      expect(AppTheme.primaryColor, isA<Color>());
      expect(AppTheme.primaryColor.toARGB32(), equals(0xFF2C3E50));
    });

    test('AppTheme accentColor is defined', () {
      expect(AppTheme.accentColor, isA<Color>());
      expect(AppTheme.accentColor.toARGB32(), equals(0xFFFF5722));
    });

    test('AppTheme backgroundColor is defined', () {
      expect(AppTheme.backgroundColor, isA<Color>());
      expect(AppTheme.backgroundColor.toARGB32(), equals(0xFFF8F9FA));
    });

    test('AppTheme cardColor is defined', () {
      expect(AppTheme.cardColor, isA<Color>());
      expect(AppTheme.cardColor, equals(Colors.white));
    });

    test('Light theme uses Material 3', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.useMaterial3, isTrue);
    });

    test('Dark theme uses Material 3', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.useMaterial3, isTrue);
    });

    test('Light theme has correct AppBar configuration', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.appBarTheme.centerTitle, isTrue);
      expect(lightTheme.appBarTheme.elevation, equals(0));
      expect(lightTheme.appBarTheme.backgroundColor,
          equals(AppTheme.primaryColor));
      expect(lightTheme.appBarTheme.foregroundColor, equals(Colors.white));
    });

    test('Light theme has correct card configuration', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.cardTheme.elevation, equals(2));
    });

    test('Light theme has correct FAB configuration', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.floatingActionButtonTheme.backgroundColor,
          equals(AppTheme.accentColor));
      expect(lightTheme.floatingActionButtonTheme.foregroundColor,
          equals(Colors.white));
    });

    test('Light theme has correct bottom navigation bar configuration', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.bottomNavigationBarTheme.selectedItemColor,
          equals(AppTheme.primaryColor));
      expect(lightTheme.bottomNavigationBarTheme.unselectedItemColor,
          equals(Colors.grey));
    });

    test('Light theme text styles are configured', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.textTheme.headlineLarge, isNotNull);
      expect(lightTheme.textTheme.headlineMedium, isNotNull);
      expect(lightTheme.textTheme.headlineSmall, isNotNull);
      expect(lightTheme.textTheme.bodyLarge, isNotNull);
      expect(lightTheme.textTheme.bodyMedium, isNotNull);
    });

    test('Dark theme has correct scaffold background color', () {
      final darkTheme = AppTheme.darkTheme;
      expect(
          darkTheme.scaffoldBackgroundColor, equals(const Color(0xFF121212)));
    });

    test('Dark theme has correct AppBar configuration', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.appBarTheme.centerTitle, isTrue);
      expect(
          darkTheme.appBarTheme.backgroundColor, equals(AppTheme.primaryColor));
      expect(darkTheme.appBarTheme.foregroundColor, equals(Colors.white));
    });

    test('Dark theme has correct FAB configuration', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.floatingActionButtonTheme.backgroundColor,
          equals(AppTheme.accentColor));
      expect(darkTheme.floatingActionButtonTheme.foregroundColor,
          equals(Colors.white));
    });

    test('Light theme headlineLarge has correct style', () {
      final lightTheme = AppTheme.lightTheme;
      final headlineLarge = lightTheme.textTheme.headlineLarge!;
      expect(headlineLarge.fontSize, equals(28));
      expect(headlineLarge.fontWeight, equals(FontWeight.bold));
      expect(headlineLarge.color, equals(AppTheme.primaryColor));
    });

    test('Light theme headlineMedium has correct style', () {
      final lightTheme = AppTheme.lightTheme;
      final headlineMedium = lightTheme.textTheme.headlineMedium!;
      expect(headlineMedium.fontSize, equals(24));
      expect(headlineMedium.fontWeight, equals(FontWeight.bold));
      expect(headlineMedium.color, equals(AppTheme.primaryColor));
    });

    test('Light theme headlineSmall has correct style', () {
      final lightTheme = AppTheme.lightTheme;
      final headlineSmall = lightTheme.textTheme.headlineSmall!;
      expect(headlineSmall.fontSize, equals(20));
      expect(headlineSmall.fontWeight, equals(FontWeight.w600));
      expect(headlineSmall.color, equals(AppTheme.primaryColor));
    });

    test('Light theme bodyLarge has correct style', () {
      final lightTheme = AppTheme.lightTheme;
      final bodyLarge = lightTheme.textTheme.bodyLarge!;
      expect(bodyLarge.fontSize, equals(16));
      expect(bodyLarge.color, equals(Colors.black87));
    });

    test('Light theme bodyMedium has correct style', () {
      final lightTheme = AppTheme.lightTheme;
      final bodyMedium = lightTheme.textTheme.bodyMedium!;
      expect(bodyMedium.fontSize, equals(14));
      expect(bodyMedium.color, equals(Colors.black87));
    });
  });

  group('ZhiduApp Widget Structure Tests', () {
    setUp(() {
      SettingsService.resetForTest();
    });

    testWidgets('MaterialApp home property is HomeScreen widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.home, isA<HomeScreen>());
    });

    testWidgets('Theme is properly applied from AppTheme',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ZhiduApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.scaffoldBackgroundColor,
          equals(AppTheme.lightTheme.scaffoldBackgroundColor));
      expect(materialApp.theme?.useMaterial3,
          equals(AppTheme.lightTheme.useMaterial3));
      expect(materialApp.darkTheme?.scaffoldBackgroundColor,
          equals(AppTheme.darkTheme.scaffoldBackgroundColor));
      expect(materialApp.darkTheme?.useMaterial3,
          equals(AppTheme.darkTheme.useMaterial3));
    });

    test('ZhiduApp is a StatefulWidget', () {
      expect(const ZhiduApp(), isA<StatefulWidget>());
    });

    test('ZhiduApp has correct const key', () {
      const app1 = ZhiduApp();
      const app2 = ZhiduApp();

      expect(app1.key, equals(app2.key));
    });
  });
}
