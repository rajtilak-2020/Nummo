import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/core/storage/secure_storage_repository.dart';
import 'package:nummo/design_system/components/animations.dart';
import 'package:nummo/features/analytics/analytics_screen.dart';
import 'package:nummo/features/ledger/home_swipe_view.dart';
import 'package:nummo/features/ledger/transaction_tile.dart';
import 'package:nummo/models/budget.dart';
import 'package:nummo/models/category.dart';
import 'package:nummo/models/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    SecureStorageRepository.prewarm(prefs);
  });

  group('Dynamic Money Scaling on Low-DPI Devices (320x640)', () {
    testWidgets('Total Balance card scales down dynamically without overflow on 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Huge monetary amounts (e.g., hundreds of millions)
      final now = DateTime.now();
      final massiveTransactions = [
        Transaction(
          amount: 876543210.50,
          isCredit: true,
          note: 'Massive Salary',
          timestamp: now,
        ),
        Transaction(
          amount: 123456789.75,
          isCredit: false,
          note: 'Massive Real Estate Spend',
          timestamp: now,
          tag: 'SHOPPING',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSwipeView(
              transactions: massiveTransactions,
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

      // Verify that NummoCountUp is used and wrapped with FittedBox for dynamic font downscaling
      final countUpFinder = find.byType(NummoCountUp);
      expect(countUpFinder, findsAtLeastNWidgets(3)); // Total Balance, Income, Expenses

      // Verify all NummoCountUp texts have autoScaleDown = true
      for (final widget in tester.widgetList<NummoCountUp>(countUpFinder)) {
        expect(widget.autoScaleDown, isTrue);
      }
    });

    testWidgets('Category Breakdown card scales down amount under donut chart on 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final massiveExpenseTxns = [
        Transaction(
          amount: 999999999.00,
          isCredit: false,
          note: 'Luxury Yacht',
          timestamp: now,
          tag: 'SHOPPING',
        ),
        Transaction(
          amount: 555555555.00,
          isCredit: false,
          note: 'Fine Dining Event',
          timestamp: now,
          tag: 'FOOD',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeCategoryBreakdownCard(
                transactions: massiveExpenseTxns,
                categories: CategoryTag.defaults,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the FittedBox inside the category breakdown
      final fittedBoxes = find.descendant(
        of: find.byType(HomeCategoryBreakdownCard),
        matching: find.byType(FittedBox),
      );
      expect(fittedBoxes, findsWidgets);
    });

    testWidgets('Active Budgets card scales down huge spent/limit values on 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final budget = Budget(
        id: 'test-huge-budget',
        title: 'Massive Corporate Budget',
        scope: 'overall',
        period: BudgetPeriod.monthly,
        amount: 500000000.0,
        startDate: DateTime(now.year, now.month, 1),
      );

      final transactions = [
        Transaction(
          amount: 350000000.0,
          isCredit: false,
          note: 'Huge Expense',
          timestamp: now,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeActiveBudgetsCard(
                budgets: [budget],
                transactions: transactions,
                categories: CategoryTag.defaults,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header title and badges render cleanly
      expect(find.text('Active Budgets'), findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);
    });

    testWidgets('AnalyticsScreen renders KPI cards with zero overflow on low-DPI screen (320x640)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final massiveTransactions = [
        Transaction(
          amount: 876543210.50,
          isCredit: true,
          note: 'Massive Salary',
          timestamp: now,
        ),
        Transaction(
          amount: 123456789.75,
          isCredit: false,
          note: 'Massive Real Estate Spend',
          timestamp: now,
          tag: 'SHOPPING',
        ),
      ];

      final budget = Budget(
        title: 'Monthly Budget',
        amount: 200000000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnalyticsScreen(
              transactions: massiveTransactions,
              budget: budget,
              categories: CategoryTag.defaults,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that KPI cards render without throwing any RenderFlex overflow
      expect(find.text('Total Income'), findsOneWidget);
      expect(find.text('Total Expenses'), findsOneWidget);
      expect(find.text('Net Cashflow'), findsOneWidget);
      expect(find.text('Daily Avg Expense'), findsOneWidget);
    });

    testWidgets('TransactionTile and TransactionDateGroupCard render without overflow on 320dp width with huge amounts', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final massiveTxn = Transaction(
        amount: 987654321.00,
        isCredit: false,
        note: 'Ultra Long Expensive Purchase Description Note',
        timestamp: now,
        tag: 'SHOPPING',
        balanceAfter: 1234567890.00,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionDateGroupCard(
              dateTitle: 'Thursday, 04 September 2026',
              transactions: [massiveTxn, massiveTxn],
              categories: CategoryTag.defaults,
              onEdit: (txn) {},
              onDelete: (txn) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that the date title and transaction tile rendered cleanly with zero overflows
      expect(find.text('Thursday, 04 September 2026'), findsOneWidget);
      expect(find.text('Ultra Long Expensive Purchase Description Note'), findsWidgets);
      final ex = tester.takeException();
      expect(ex, isNull);
    });
  });
}
