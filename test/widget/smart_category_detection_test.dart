import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/features/ledger/add_transaction_sheet.dart';
import 'package:nummo/features/settings/settings_screen.dart';
import 'package:nummo/models/category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smart Category Detection & Settings Enhancements Widget Tests', () {
    testWidgets('AddTransactionSheet suggests Food category when note contains coffee or food', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddTransactionSheet(
              initialIsCredit: false,
              availableCategories: CategoryTag.defaults,
              onSave: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter amount
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '120');
      await tester.pumpAndSettle();

      // Type "Starbucks coffee" in note field
      await tester.enterText(textFields.at(1), 'Starbucks coffee');
      await tester.pumpAndSettle();

      // Verify smart category suggestion appears
      expect(find.text('Suggested: '), findsOneWidget);
      expect(find.text('🍔 Food'), findsWidgets);

      // Tap the suggested pill
      await tester.tap(find.text('Suggested: '));
      await tester.pumpAndSettle();
    });

    testWidgets('SettingsScreen opens Currency Picker and allows changing currency', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? selectedCurrency;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              isPinEnabled: true,
              isBioEnabled: false,
              isFingerprintEnabled: false,
              currentAccent: 'Indigo Slate',
              currentThemeMode: 'system',
              currentCurrency: 'INR',
              autoLockDelaySeconds: 0,
              categories: CategoryTag.defaults,
              budgets: const [],
              transactions: const [],
              activeBudgetName: 'Nummo Account',
              onTogglePin: (context, enabled) async {},
              onToggleBio: (enabled) async => true,
              onToggleFingerprint: (enabled) async => true,
              onSelectAccent: (_) {},
              onSelectThemeMode: (_) {},
              onSelectCurrency: (code) {
                selectedCurrency = code;
              },
              onSelectAutoLockDelay: (_) {},
              onUpdateCategories: (_) async {},
              onUpdateBudgets: (_) async {},
              onImportPayload: (raw, {isMerge = false, passphrase}) async {},
              onExportPayload: (raw) async {},
              onResetData: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Primary Currency
      await tester.scrollUntilVisible(find.text('Primary Currency'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Primary Currency'), findsOneWidget);
      expect(find.text('Indian Rupee (₹)'), findsOneWidget);

      // Tap to open currency picker bottom sheet
      await tester.tap(find.text('Primary Currency'));
      await tester.pumpAndSettle();

      expect(find.text('Select Currency'), findsOneWidget);
      expect(find.text('US Dollar (\$)'), findsOneWidget);

      // Tap USD
      await tester.tap(find.text('US Dollar (\$)'));
      await tester.pumpAndSettle();

      expect(selectedCurrency, 'USD');
    });

    testWidgets('SettingsScreen renders Auto-Lock Delay when PIN is enabled and allows setting delay', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int? selectedDelay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              isPinEnabled: true,
              isBioEnabled: false,
              isFingerprintEnabled: false,
              currentAccent: 'Indigo Slate',
              currentThemeMode: 'system',
              currentCurrency: 'INR',
              autoLockDelaySeconds: 0,
              categories: CategoryTag.defaults,
              budgets: const [],
              transactions: const [],
              activeBudgetName: 'Nummo Account',
              onTogglePin: (context, enabled) async {},
              onToggleBio: (enabled) async => true,
              onToggleFingerprint: (enabled) async => true,
              onSelectAccent: (_) {},
              onSelectThemeMode: (_) {},
              onSelectCurrency: (_) {},
              onSelectAutoLockDelay: (val) {
                selectedDelay = val;
              },
              onUpdateCategories: (_) async {},
              onUpdateBudgets: (_) async {},
              onImportPayload: (raw, {isMerge = false, passphrase}) async {},
              onExportPayload: (raw) async {},
              onResetData: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Auto-Lock Delay should be visible
      expect(find.text('Auto-Lock Delay'), findsOneWidget);
      expect(find.text('Immediately'), findsOneWidget);

      // Tap dropdown / popup
      await tester.tap(find.text('Immediately'));
      await tester.pumpAndSettle();

      // Expect options in popup menu
      expect(find.text('After 5 Minutes'), findsOneWidget);

      await tester.tap(find.text('After 5 Minutes'));
      await tester.pumpAndSettle();

      expect(selectedDelay, 300);
    });
  });
}
