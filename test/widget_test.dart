import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/main.dart';
import 'package:nummo/features/ledger/home_swipe_view.dart';
import 'package:nummo/models/transaction.dart';
import 'package:nummo/models/category.dart';
import 'package:nummo/models/budget.dart';
import 'package:nummo/design_system/components/category_tag_dialog.dart';
import 'package:nummo/design_system/components/budget_dialog.dart';

void main() {
  testWidgets('Nummo app smoke & UI launch test', (WidgetTester tester) async {
    await tester.pumpWidget(const NummoApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('HomeSwipeView renders top segment switcher and threshold swiping changes tabs', (WidgetTester tester) async {
    final transactions = [
      Transaction(id: '1', amount: 50.0, isCredit: true, note: 'Salary Deposit', timestamp: DateTime.now()),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSwipeView(
            transactions: transactions,
            categories: CategoryTag.defaults,
            budgets: const [],
            onAddTransaction: (_) async {},
            onUpdateTransaction: (_) async {},
            onDeleteTransaction: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Top segment switcher is present below header
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Active Budgets'), findsOneWidget);

    // Small drag (<90px) does NOT switch tab
    await tester.drag(find.byType(TabBarView), const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(find.text('Active Budgets'), findsOneWidget);

    // Deliberate drag (>90px threshold) switches tab to Logs
    await tester.drag(find.byType(TabBarView), const Offset(-120, 0));
    await tester.pumpAndSettle();

    // Page should now be Logs (showing search bar)
    expect(find.text('Search logs...'), findsOneWidget);
  });

  testWidgets('BudgetDialog and CategoryTagDialog render cleanly without intrinsic width errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => CategoryTagDialog.show(
                      context,
                      onSave: (_) {},
                    ),
                    child: const Text('Open Tag Dialog'),
                  ),
                  ElevatedButton(
                    onPressed: () => BudgetDialog.show(
                      context,
                      categories: CategoryTag.defaults,
                      onSave: (_) {},
                    ),
                    child: const Text('Open Budget Dialog'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open CategoryTagDialog
    await tester.tap(find.text('Open Tag Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Create Category Tag'), findsOneWidget);

    // Close CategoryTagDialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Open BudgetDialog
    await tester.tap(find.text('Open Budget Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Add Budget'), findsOneWidget);
  });

  testWidgets('Budget deletion triggers double-confirmation modal before calling onDelete', (WidgetTester tester) async {
    bool deleteCalled = false;
    final testBudget = Budget(id: 'b1', title: 'Fuel Budget', amount: 5000.0);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => BudgetDialog.show(
                  context,
                  existingBudget: testBudget,
                  categories: CategoryTag.defaults,
                  onSave: (_) {},
                  onDelete: () {
                    deleteCalled = true;
                  },
                ),
                child: const Text('Edit Budget'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Edit Budget Dialog
    await tester.tap(find.text('Edit Budget'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDialog), findsOneWidget);

    // Tap Delete button inside dialog
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    // Confirmation dialog should be visible asking for confirmation
    expect(find.text('Delete Budget'), findsOneWidget);
    expect(deleteCalled, isFalse);

    // Confirm deletion
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteCalled, isTrue);
  });

  testWidgets('CategoryTagDialog supports deletion with double confirmation', (WidgetTester tester) async {
    bool deleteCalled = false;
    const testCat = CategoryTag(id: 'FUEL', name: 'Fuel', emoji: '⛽', colorValue: 0xFF3B82F6);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => CategoryTagDialog.show(
                  context,
                  existingCategory: testCat,
                  onSave: (_) {},
                  onDelete: () {
                    deleteCalled = true;
                  },
                ),
                child: const Text('Edit Tag'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Tag'));
    await tester.pumpAndSettle();

    // Tap Delete button
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Category Tag'), findsOneWidget);
    expect(deleteCalled, isFalse);

    // Confirm deletion
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteCalled, isTrue);
  });
}




