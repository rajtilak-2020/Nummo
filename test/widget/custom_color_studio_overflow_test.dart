import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/features/settings/settings_screen.dart';
import 'package:nummo/models/category.dart';
import 'package:nummo/models/transaction.dart';

void main() {
  group('Custom Color Studio Dialog Responsive Layout Test', () {
    testWidgets('Custom Color Studio renders without overflow on 320dp narrow device', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final categories = [
        const CategoryTag(id: 'food', name: 'Food', colorValue: 0xFF10B981, emoji: '🍔'),
      ];
      final transactions = <Transaction>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              isPinEnabled: false,
              isBioEnabled: false,
              isFingerprintEnabled: false,
              currentAccent: 'Indigo Slate',
              currentThemeMode: 'system',
              categories: categories,
              budgets: const [],
              transactions: transactions,
              activeBudgetName: 'Nummo Personal Account',
              onTogglePin: (context, enabled) async {},
              onToggleBio: (enabled) async => true,
              onToggleFingerprint: (enabled) async => true,
              onSelectAccent: (_) {},
              onSelectThemeMode: (_) {},
              onUpdateCategories: (_) async {},
              onUpdateBudgets: (_) async {},
              onImportPayload: (rawJson, {isMerge = false, passphrase}) async {},
              onExportPayload: (rawJson) async {},
              onResetData: () async {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final customColorFinder = find.text('Custom Color');
      expect(customColorFinder, findsOneWidget);
      await tester.ensureVisible(customColorFinder);
      await tester.pumpAndSettle();

      // Open Custom Color Studio dialog
      await tester.tap(customColorFinder);
      await tester.pumpAndSettle();

      // Ensure dialog title and contents render without any RenderFlex overflow
      expect(find.text('Custom Color Studio'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close dialog
      final cancelFinder = find.text('Cancel');
      expect(cancelFinder, findsOneWidget);
      await tester.tap(cancelFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
