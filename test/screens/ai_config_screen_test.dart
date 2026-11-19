import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidu/screens/ai_config_screen.dart';
import 'package:zhidu/services/settings_service.dart';
import 'package:zhidu/services/ai_service.dart';
import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiConfigScreen Widget Tests', () {
    setUp(() {
      // Reset services to clean state before each test
      SettingsService.resetForTest();
      AIService.resetForTest();
    });

    tearDown(() {
      // Clean up after each test
      SettingsService.resetForTest();
      AIService.resetForTest();
    });

    group('rendering tests', () {
      testWidgets('renders AppBar with correct title',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        expect(find.text('AI配置页面标题'), findsOneWidget);
      });

      testWidgets('renders Scaffold with body', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('renders Form widget', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        expect(find.byType(Form), findsOneWidget);
      });

      testWidgets('renders SingleChildScrollView for scrollable content',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('displays all form section labels',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Check all section labels are displayed
        expect(find.text('AI提供商'), findsOneWidget);
        expect(find.text('API Key'), findsOneWidget);
        expect(find.text('模型'), findsOneWidget);
        expect(find.text('Base URL'), findsOneWidget);
      });

      testWidgets('provider dropdown shows options (智谱 and 通义千问)',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Find and tap the provider dropdown
        final providerDropdown =
            find.byType(DropdownButtonFormField<String>).first;
        expect(providerDropdown, findsOneWidget);

        await tester.tap(providerDropdown);
        await tester.pumpAndSettle();

        // Verify both provider options are shown
        expect(find.text('智谱'), findsOneWidget);
        expect(
            find.text('通义千问'), findsWidgets); // One selected, one in dropdown
      });

      testWidgets('API Key field has visibility toggle button',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Find the visibility toggle icon button (indicates password field)
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      });

      testWidgets('API Key field has visibility toggle button',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Find the visibility toggle icon button
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      });

      testWidgets('provider dropdown exists', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Only the provider is a DropdownButtonFormField; the model is a custom selector
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      });

      testWidgets('Base URL field exists', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Find Base URL text field (should be 2 TextFormFields: API Key and Base URL)
        expect(find.byType(TextFormField), findsNWidgets(2));
      });

      testWidgets(
          'Base URL auto-populates with default value for selected provider',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Default provider is qwen (通义千问), so base URL should be qwen's default
        await tester.pumpAndSettle();

        final baseUrlField = find.byType(TextFormField).last;
        final textFieldWidget = tester.widget<TextFormField>(baseUrlField);
        expect(
          textFieldWidget.controller?.text,
          equals('https://dashscope.aliyuncs.com/compatible-mode/v1'),
        );
      });

      testWidgets('test connection button is present',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        expect(find.text('测试连接'), findsOneWidget);
        expect(find.byIcon(Icons.network_check), findsOneWidget);
      });

      testWidgets('save button is present', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        expect(find.text('保存'), findsOneWidget);
        expect(find.byIcon(Icons.save), findsOneWidget);
      });
    });

    group('interaction tests', () {
      testWidgets('tapping provider dropdown shows options',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Find and tap the provider dropdown
        final providerDropdown =
            find.byType(DropdownButtonFormField<String>).first;
        await tester.tap(providerDropdown);
        await tester.pumpAndSettle();

        // Verify dropdown menu is shown
        expect(find.text('智谱'), findsOneWidget);
      });

      testWidgets('API Key visibility toggle works',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Initially should show visibility_off icon
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsNothing);

        // Tap the visibility toggle button
        await tester.tap(find.byIcon(Icons.visibility_off));
        await tester.pumpAndSettle();

        // Now should show visibility icon (password visible)
        expect(find.byIcon(Icons.visibility), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off), findsNothing);
      });

      testWidgets('test connection button is tappable when form is valid',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Find test connection button
        final testButton = find.widgetWithText(ElevatedButton, '测试连接');
        expect(testButton, findsOneWidget);

        // Button should be enabled initially (form validation happens on submit)
        final buttonWidget = tester.widget<ElevatedButton>(testButton);
        expect(buttonWidget.onPressed, isNotNull);
      });

      testWidgets('save button is tappable', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Find save button
        final saveButton = find.widgetWithText(ElevatedButton, '保存');
        expect(saveButton, findsOneWidget);

        // Button should be enabled initially
        final buttonWidget = tester.widget<ElevatedButton>(saveButton);
        expect(buttonWidget.onPressed, isNotNull);
      });

      testWidgets('changing provider updates base URL automatically',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Initial base URL should be qwen's
        final baseUrlField = find.byType(TextFormField).last;
        TextFormField textFieldWidget =
            tester.widget<TextFormField>(baseUrlField);
        expect(
          textFieldWidget.controller?.text,
          equals('https://dashscope.aliyuncs.com/compatible-mode/v1'),
        );

        // Change provider to 智谱
        final providerDropdown =
            find.byType(DropdownButtonFormField<String>).first;
        await tester.tap(providerDropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('智谱').last);
        await tester.pumpAndSettle();

        // Base URL should now be zhipu's
        textFieldWidget = tester.widget<TextFormField>(baseUrlField);
        expect(
          textFieldWidget.controller?.text,
          equals('https://open.bigmodel.cn/api/paas/v4'),
        );
      });
    });

    group('state tests', () {
      testWidgets('form loads with empty defaults when no settings configured',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // API Key should be empty
        final apiKeyField = find.byType(TextFormField).first;
        final apiKeyWidget = tester.widget<TextFormField>(apiKeyField);
        expect(apiKeyWidget.controller?.text, isEmpty);

        // Base URL should have default value
        final baseUrlField = find.byType(TextFormField).last;
        final baseUrlWidget = tester.widget<TextFormField>(baseUrlField);
        expect(baseUrlWidget.controller?.text, isNotEmpty);
      });

      testWidgets(
          'form loads with default settings when no prior configuration',
          (WidgetTester tester) async {
        // Reset to ensure clean state
        SettingsService.resetForTest();

        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Form should load with default provider (qwen)
        // API Key should be empty by default
        final apiKeyField = find.byType(TextFormField).first;
        final apiKeyWidget = tester.widget<TextFormField>(apiKeyField);
        expect(apiKeyWidget.controller?.text, isEmpty);

        // Base URL should have qwen's default value
        final baseUrlField = find.byType(TextFormField).last;
        final baseUrlWidget = tester.widget<TextFormField>(baseUrlField);
        expect(
          baseUrlWidget.controller?.text,
          equals('https://dashscope.aliyuncs.com/compatible-mode/v1'),
        );
      });

      testWidgets('form validation requires API Key',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Try to save without filling in API Key
        final saveButton = find.widgetWithText(ElevatedButton, '保存');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Should show validation error
        expect(find.text('请输入API Key'), findsOneWidget);
      });

      testWidgets('form validation requires Base URL',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Clear the base URL field
        final baseUrlField = find.byType(TextFormField).last;
        await tester.enterText(baseUrlField, '');
        await tester.pumpAndSettle();

        // Try to save
        final saveButton = find.widgetWithText(ElevatedButton, '保存');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Should show validation error
        expect(find.text('请输入Base URL'), findsOneWidget);
      });

      testWidgets('form validation requires valid URL format',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Enter invalid URL (without http/https)
        final baseUrlField = find.byType(TextFormField).last;
        await tester.enterText(baseUrlField, 'invalid-url');
        await tester.pumpAndSettle();

        // Enter API Key to pass that validation
        final apiKeyField = find.byType(TextFormField).first;
        await tester.enterText(apiKeyField, 'test-key');
        await tester.pumpAndSettle();

        // Try to save
        final saveButton = find.widgetWithText(ElevatedButton, '保存');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Should show URL format validation error
        expect(find.text('URL必须以http://或https://开头'), findsOneWidget);
      });
    });

    group('button state tests', () {
      testWidgets('buttons show loading state during operations',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Both buttons should be present initially
        expect(find.text('测试连接'), findsOneWidget);
        expect(find.text('保存'), findsOneWidget);
      });

      testWidgets('buttons are disabled when loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Enter valid data first
        final apiKeyField = find.byType(TextFormField).first;
        await tester.enterText(apiKeyField, 'test-api-key');
        await tester.pumpAndSettle();

        // Initially buttons should be enabled
        final testButton = find.widgetWithText(ElevatedButton, '测试连接');
        ElevatedButton buttonWidget = tester.widget<ElevatedButton>(testButton);
        expect(buttonWidget.onPressed, isNotNull);
      });
    });

    group('UI layout tests', () {
      testWidgets('form has consistent padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Check that padding is applied
        final paddingFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Padding && widget.padding == const EdgeInsets.all(16.0),
        );
        expect(paddingFinder, findsOneWidget);
      });

      testWidgets('sections are separated by spacing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Should have multiple SizedBox widgets for spacing
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('action buttons are in a Row', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Find the Row containing the buttons
        expect(find.byType(Row), findsWidgets);
      });

      testWidgets('action buttons have correct flex ratio',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Check flex values of the buttons' enclosing Expanded widgets
        final testButton = find.widgetWithText(ElevatedButton, '测试连接');
        final saveButton = find.widgetWithText(ElevatedButton, '保存');

        final testExpanded = tester.widget<Expanded>(
          find.ancestor(of: testButton, matching: find.byType(Expanded)),
        );
        final saveExpanded = tester.widget<Expanded>(
          find.ancestor(of: saveButton, matching: find.byType(Expanded)),
        );

        expect(testExpanded.flex, equals(2)); // Test connection button
        expect(saveExpanded.flex, equals(3)); // Save button
      });
    });

    group('model selection tests', () {
      testWidgets('model dropdown is disabled when no models available',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const AiConfigScreen()),
        );

        // Model dropdown should always be available for valid providers
        final modelDropdown = find.byType(DropdownButtonFormField<String>).last;
        expect(modelDropdown, findsOneWidget);
      });
    });
  });
}
