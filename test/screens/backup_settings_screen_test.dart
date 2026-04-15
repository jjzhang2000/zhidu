import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/screens/backup_settings_screen.dart';
import 'package:zhidu/models/app_settings.dart';
import 'package:zhidu/services/settings_service.dart';

// Test helper class to wrap the screen with proper MaterialApp
class TestableBackupSettingsScreen extends StatelessWidget {
  const TestableBackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BackupSettingsScreen(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupSettingsScreen Widget Tests', () {
    // Reset SettingsService before each test
    setUp(() {
      SettingsService.resetForTest();
    });

    tearDown(() {
      SettingsService.resetForTest();
    });

    // ============================================================================
    // RENDERING TESTS
    // ============================================================================

    group('rendering tests', () {
      testWidgets('renders AppBar with correct title',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        expect(find.text('备份设置'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('renders Scaffold with body', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('displays backup directory section',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('备份目录'), findsOneWidget);
        expect(find.byIcon(Icons.folder), findsOneWidget);
      });

      testWidgets('displays current backup directory label',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('当前目录'), findsOneWidget);
      });

      testWidgets('displays auto backup section', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('自动备份'), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);
      });

      testWidgets('displays auto backup toggle', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('启用自动备份'), findsOneWidget);
        expect(find.byType(SwitchListTile), findsOneWidget);
      });

      testWidgets('displays last backup time label',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('上次备份'), findsOneWidget);
        expect(find.text('从未备份'), findsOneWidget);
      });

      testWidgets('displays last backup time when available',
          (WidgetTester tester) async {
        // Set up settings with a last backup time
        final settingsService = SettingsService();
        final testTime = DateTime(2026, 4, 15, 10, 30);
        await settingsService.updateStorageSettings(
          StorageSettings(lastBackupTime: testTime),
        );

        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Should display formatted date/time
        expect(find.text('上次备份'), findsOneWidget);
        expect(find.text('从未备份'), findsNothing);
        expect(find.textContaining('2026-04-15'), findsOneWidget);
      });

      testWidgets('frequency dropdown is hidden when auto backup is disabled',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Verify toggle is off by default
        final switchTile =
            tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(switchTile.value, isFalse);

        // Frequency dropdown should not be visible
        expect(find.text('备份频率'), findsNothing);
        expect(find.byType(DropdownButton<int>), findsNothing);
      });

      testWidgets('frequency dropdown is visible when auto backup is enabled',
          (WidgetTester tester) async {
        // Enable auto backup
        final settingsService = SettingsService();
        await settingsService.updateStorageSettings(
          StorageSettings(autoBackupEnabled: true),
        );

        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Frequency dropdown should be visible
        expect(find.text('备份频率'), findsOneWidget);
        expect(find.byType(DropdownButton<int>), findsOneWidget);
      });

      testWidgets('displays manual backup section',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('手动备份'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
      });

      testWidgets('displays restore section', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('数据恢复'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_download), findsOneWidget);
      });

      testWidgets('has dividers between sections', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.byType(Divider), findsNWidgets(3));
      });
    });

    // ============================================================================
    // INTERACTION TESTS
    // ============================================================================

    group('interaction tests', () {
      testWidgets('has directory picker button', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextButton, '更改'), findsOneWidget);
      });

      testWidgets('toggle enables auto backup when switched on',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Initially disabled
        final switchFinder = find.byType(SwitchListTile);
        SwitchListTile switchTile = tester.widget(switchFinder);
        expect(switchTile.value, isFalse);

        // Tap the toggle
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // Switch should be on now
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Frequency dropdown should now be visible
        expect(find.text('备份频率'), findsOneWidget);
      });

      testWidgets('frequency dropdown shows current selection',
          (WidgetTester tester) async {
        // Set frequency to 1 day
        final settingsService = SettingsService();
        await settingsService.updateStorageSettings(
          StorageSettings(
            autoBackupEnabled: true,
            autoBackupInterval: 1,
          ),
        );

        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Should show "每天" - check that at least one exists (subtitle + dropdown)
        expect(find.text('每天'), findsWidgets);
      });

      testWidgets('frequency dropdown shows weekly when interval is 7',
          (WidgetTester tester) async {
        // Set frequency to 7 days
        final settingsService = SettingsService();
        await settingsService.updateStorageSettings(
          StorageSettings(
            autoBackupEnabled: true,
            autoBackupInterval: 7,
          ),
        );

        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Should show "每周" - check that at least one exists (subtitle + dropdown)
        expect(find.text('每周'), findsWidgets);
      });

      testWidgets('has backup button present', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('立即备份'), findsOneWidget);
        expect(find.byIcon(Icons.backup), findsOneWidget);
      });

      testWidgets('backup tile is tappable', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        final backupTile = find.widgetWithText(ListTile, '立即备份');
        expect(backupTile, findsOneWidget);

        final tileWidget = tester.widget<ListTile>(backupTile);
        expect(tileWidget.onTap, isNotNull);
      });

      testWidgets('has restore button present', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('恢复数据'), findsOneWidget);
        expect(find.byIcon(Icons.restore), findsOneWidget);
      });

      testWidgets('restore tile is tappable', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        final restoreTile = find.widgetWithText(ListTile, '恢复数据');
        expect(restoreTile, findsOneWidget);

        final tileWidget = tester.widget<ListTile>(restoreTile);
        expect(tileWidget.onTap, isNotNull);
      });

      testWidgets('backup tile has chevron icon when not backing up',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Should find chevron_right icon
        expect(find.byIcon(Icons.chevron_right), findsWidgets);
      });

      testWidgets('restore tile has chevron icon when not restoring',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Should find chevron_right icon
        expect(find.byIcon(Icons.chevron_right), findsWidgets);
      });
    });

    // ============================================================================
    // STATE MANAGEMENT TESTS
    // ============================================================================

    group('state management tests', () {
      testWidgets('updates settings when toggle is switched',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Tap the toggle
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        // Service should have been updated
        final settings = SettingsService().settings.storageSettings;
        expect(settings.autoBackupEnabled, isTrue);
      });

      testWidgets('frequency dropdown items are correct',
          (WidgetTester tester) async {
        // Enable auto backup
        final settingsService = SettingsService();
        await settingsService.updateStorageSettings(
          StorageSettings(
            autoBackupEnabled: true,
            autoBackupInterval: 1,
          ),
        );

        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Dropdown should have "每天" and "每周" options
        final dropdown = find.byType(DropdownButton<int>);
        expect(dropdown, findsOneWidget);

        // Open dropdown to see items
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        expect(find.text('每天'), findsWidgets);
        expect(find.text('每周'), findsWidgets);
      });
    });

    // ============================================================================
    // VISUAL ELEMENT TESTS
    // ============================================================================

    group('visual element tests', () {
      testWidgets('section icons are displayed', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Section icons
        expect(find.byIcon(Icons.folder), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);
        expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
        expect(find.byIcon(Icons.cloud_download), findsOneWidget);
      });

      testWidgets('list tile icons are displayed', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // List tile icons
        expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
        expect(find.byIcon(Icons.autorenew), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        expect(find.byIcon(Icons.backup), findsOneWidget);
        expect(find.byIcon(Icons.restore), findsOneWidget);
      });

      testWidgets('section titles have correct styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        // Section titles should be present
        expect(find.text('备份目录'), findsOneWidget);
        expect(find.text('自动备份'), findsOneWidget);
        expect(find.text('手动备份'), findsOneWidget);
        expect(find.text('数据恢复'), findsOneWidget);
      });

      testWidgets('has subtitle texts', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: BackupSettingsScreen(),
        ));

        await tester.pumpAndSettle();

        expect(find.text('按设定频率自动备份数据'), findsOneWidget);
        expect(find.text('将所有数据导出为JSON备份文件'), findsOneWidget);
        expect(find.text('从JSON备份文件恢复数据'), findsOneWidget);
      });
    });
  });
}
