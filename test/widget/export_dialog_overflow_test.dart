import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/features/export/export_dialog.dart';
import 'package:nummo/features/ledger/add_transaction_sheet.dart';
import 'package:nummo/models/transaction.dart';
import 'package:nummo/models/category.dart';

void main() {
  group('ExportDialog & AddTransactionSheet Responsive Layout Tests', () {
    testWidgets('ExportDialog Year & Month grid render without bottom overflow on 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final transactions = [
        Transaction(
          amount: 2500,
          isCredit: true,
          note: 'Salary',
          timestamp: DateTime(2026, 9, 1),
        ),
        Transaction(
          amount: 500,
          isCredit: false,
          note: 'Dinner',
          timestamp: DateTime(2025, 5, 1),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportDialog(
              transactions: transactions,
              budgetName: 'Nummo',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      // Switch to By Year mode to test Year Grid rendering on 320dp screen
      final byYearFinder = find.text('By Year');
      expect(byYearFinder, findsOneWidget);
      await tester.tap(byYearFinder);
      await tester.pumpAndSettle();

      expect(find.text('Financial Record Years'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddTransactionSheet header and date row render cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddTransactionSheet(
              availableCategories: CategoryTag.defaults,
              initialIsCredit: false,
              onSave: (txn) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add Debit Entry'), findsOneWidget);
    });
  });
}
