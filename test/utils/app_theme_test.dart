import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/utils/app_theme.dart';

void main() {
  group('AppTheme Color Constants', () {
    test('primaryColor should be correct value', () {
      expect(AppTheme.primaryColor, const Color(0xFF2C3E50));
    });

    test('accentColor should be correct value', () {
      expect(AppTheme.accentColor, const Color(0xFFFF5722));
    });

    test('dangerColor should be deep red', () {
      expect(AppTheme.dangerColor, const Color(0xFFB71C1C));
    });

    test('backgroundColor should be correct value', () {
      expect(AppTheme.backgroundColor, const Color(0xFFF8F9FA));
    });

    test('cardColor should be Colors.white', () {
      expect(AppTheme.cardColor, Colors.white);
    });
  });

  group('AppTheme lightTheme', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.lightTheme;
    });

    test('should use Material 3', () {
      expect(theme.useMaterial3, true);
    });

    test('colorScheme should be generated from primaryColor', () {
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('scaffoldBackgroundColor should be backgroundColor', () {
      expect(theme.scaffoldBackgroundColor, AppTheme.backgroundColor);
    });

    test('appBarTheme should be configured correctly', () {
      expect(theme.appBarTheme.centerTitle, true);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.backgroundColor, AppTheme.primaryColor);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
    });

    test('cardTheme should have elevation 2 and rounded corners', () {
      expect(theme.cardTheme.elevation, 2);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(12)));
    });

    test('floatingActionButtonTheme should use accentColor', () {
      expect(theme.floatingActionButtonTheme.backgroundColor,
          AppTheme.accentColor);
      expect(theme.floatingActionButtonTheme.foregroundColor, Colors.white);
      expect(theme.floatingActionButtonTheme.shape, isA<CircleBorder>());
    });

    test('bottomNavigationBarTheme should have correct colors', () {
      expect(theme.bottomNavigationBarTheme.selectedItemColor,
          AppTheme.primaryColor);
      expect(theme.bottomNavigationBarTheme.unselectedItemColor, Colors.grey);
    });

    test('textTheme headlineLarge should be configured correctly', () {
      final style = theme.textTheme.headlineLarge;
      expect(style?.fontSize, 28);
      expect(style?.fontWeight, FontWeight.bold);
      expect(style?.color, AppTheme.primaryColor);
    });

    test('textTheme headlineMedium should be configured correctly', () {
      final style = theme.textTheme.headlineMedium;
      expect(style?.fontSize, 24);
      expect(style?.fontWeight, FontWeight.bold);
      expect(style?.color, AppTheme.primaryColor);
    });

    test('textTheme headlineSmall should be configured correctly', () {
      final style = theme.textTheme.headlineSmall;
      expect(style?.fontSize, 20);
      expect(style?.fontWeight, FontWeight.w600);
      expect(style?.color, AppTheme.primaryColor);
    });

    test('textTheme bodyLarge should be configured correctly', () {
      final style = theme.textTheme.bodyLarge;
      expect(style?.fontSize, 16);
      expect(style?.color, Colors.black87);
    });

    test('textTheme bodyMedium should be configured correctly', () {
      final style = theme.textTheme.bodyMedium;
      expect(style?.fontSize, 14);
      expect(style?.color, Colors.black87);
    });
  });

  group('AppTheme darkTheme', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.darkTheme;
    });

    test('should use Material 3', () {
      expect(theme.useMaterial3, true);
    });

    test('scaffoldBackgroundColor should be dark', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFF121212));
    });

    test('appBarTheme should be configured correctly', () {
      expect(theme.appBarTheme.centerTitle, true);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.backgroundColor, AppTheme.primaryColor);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
    });

    test('cardTheme should have elevation 2 and rounded corners', () {
      expect(theme.cardTheme.elevation, 2);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(12)));
    });

    test('floatingActionButtonTheme should use accentColor', () {
      expect(theme.floatingActionButtonTheme.backgroundColor,
          AppTheme.accentColor);
      expect(theme.floatingActionButtonTheme.foregroundColor, Colors.white);
      expect(theme.floatingActionButtonTheme.shape, isA<CircleBorder>());
    });

    test('colorScheme brightness should be dark', () {
      expect(theme.colorScheme.brightness, Brightness.dark);
    });
  });

  group('Theme Consistency', () {
    test('light and dark themes should have same primaryColor in appBarTheme',
        () {
      expect(
        AppTheme.lightTheme.appBarTheme.backgroundColor,
        AppTheme.darkTheme.appBarTheme.backgroundColor,
      );
    });

    test(
        'light and dark themes should have same accentColor in floatingActionButtonTheme',
        () {
      expect(
        AppTheme.lightTheme.floatingActionButtonTheme.backgroundColor,
        AppTheme.darkTheme.floatingActionButtonTheme.backgroundColor,
      );
    });

    test('light and dark themes should both use Material 3', () {
      expect(AppTheme.lightTheme.useMaterial3, true);
      expect(AppTheme.darkTheme.useMaterial3, true);
    });

    test('light and dark themes should have same cardTheme elevation and shape',
        () {
      expect(
        AppTheme.lightTheme.cardTheme.elevation,
        AppTheme.darkTheme.cardTheme.elevation,
      );
      expect(
        AppTheme.lightTheme.cardTheme.shape,
        AppTheme.darkTheme.cardTheme.shape,
      );
    });
  });
}
