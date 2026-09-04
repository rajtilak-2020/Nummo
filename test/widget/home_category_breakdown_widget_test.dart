import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/core/storage/secure_storage_repository.dart';
import 'package:nummo/core/utils/money_formatter.dart';
import 'package:nummo/core/widgets/home_widget_service.dart';
import 'package:nummo/features/ledger/home_swipe_view.dart';
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

  group('HomeCategoryBreakdownCard Range Customization Tests', () {
    testWidgets('Renders Category Breakdown with default range button (This Month)', (WidgetTester tester) async {
      final now = DateTime.now();
      final transactions = [
        Transaction(
          amount: 500,
          isCredit: false,
          note: 'Groceries',
          timestamp: now,
          tag: 'FOOD',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCategoryBreakdownCard(
              transactions: transactions,
              categories: CategoryTag.defaults,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Category Breakdown'), findsOneWidget);
      expect(find.byKey(const Key('category_breakdown_range_picker')), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('Tapping range picker opens bottom sheet and selecting Today filters transactions', (WidgetTester tester) async {
      final now = DateTime.now();
      final todayTxn = Transaction(
        amount: 200,
        isCredit: false,
        note: 'Coffee',
        timestamp: now,
        tag: 'FOOD',
      );
      final oldTxn = Transaction(
        amount: 1500,
        isCredit: false,
        note: 'Clothes',
        timestamp: now.subtract(const Duration(days: 45)),
        tag: 'SHOPPING',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCategoryBreakdownCard(
              transactions: [todayTxn, oldTxn],
              categories: CategoryTag.defaults,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially "This Month": todayTxn is in this month, oldTxn is 45 days ago
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Shopping'), findsNothing);

      // Open period picker
      await tester.tap(find.byKey(const Key('category_breakdown_range_picker')));
      await tester.pumpAndSettle();

      // Expect bottom sheet title and options
      expect(find.text('Select Time Range'), findsOneWidget);
      expect(find.byKey(const Key('period_option_allTime')), findsOneWidget);
      expect(find.byKey(const Key('period_option_today')), findsOneWidget);

      // Select "All Time"
      await tester.tap(find.byKey(const Key('period_option_allTime')));
      await tester.pumpAndSettle();

      // Range label updated to "All Time"
      expect(find.text('All Time'), findsOneWidget);
      // Both categories should be visible
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
    });

    testWidgets('Displays empty state when no expenses exist for selected range', (WidgetTester tester) async {
      final now = DateTime.now();
      // Transaction is from 60 days ago
      final oldTxn = Transaction(
        amount: 400,
        isCredit: false,
        note: 'Old Book',
        timestamp: now.subtract(const Duration(days: 60)),
        tag: 'ENTERTAINMENT',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCategoryBreakdownCard(
              transactions: [oldTxn],
              categories: CategoryTag.defaults,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open picker and switch to "Today"
      await tester.tap(find.byKey(const Key('category_breakdown_range_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('period_option_today')));
      await tester.pumpAndSettle();

      expect(find.text('No expenses for today'), findsOneWidget);
      expect(find.text('Expenses in this range will appear here'), findsOneWidget);

      // The period picker button in header is still interactive
      expect(find.byKey(const Key('category_breakdown_range_picker')), findsOneWidget);
    });

    testWidgets('HomeCategoryBreakdownCard highlights slice on long-press and shows close button', (WidgetTester tester) async {
      final now = DateTime.now();
      final transactions = [
        Transaction(
          amount: 250,
          isCredit: false,
          note: 'Lunch',
          timestamp: now,
          tag: 'FOOD',
        ),
        Transaction(
          amount: 100,
          isCredit: false,
          note: 'Metro',
          timestamp: now,
          tag: 'TRAVEL',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCategoryBreakdownCard(
              transactions: transactions,
              categories: CategoryTag.defaults,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Long press on Food
      await tester.longPress(find.text('Food'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Reset
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('Respects privacy mode masking', (WidgetTester tester) async {
      final now = DateTime.now();
      final transactions = [
        Transaction(
          amount: 500,
          isCredit: false,
          note: 'Lunch',
          timestamp: now,
          tag: 'FOOD',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCategoryBreakdownCard(
              transactions: transactions,
              categories: CategoryTag.defaults,
              isMasked: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(MoneyFormatter.masked), findsOneWidget);
    });

    test('HomeCategoryPeriod calculations and map generation work accurately', () {
      final now = DateTime.now();
      final txns = [
        Transaction(
          amount: 100,
          isCredit: false,
          note: 'Debit 1',
          timestamp: now,
          tag: 'FOOD',
        ),
        Transaction(
          amount: 500,
          isCredit: true, // Credit - should NOT be included in breakdown
          note: 'Salary',
          timestamp: now,
          tag: 'INCOME',
        ),
        Transaction(
          amount: 300,
          isCredit: false,
          note: 'Past Year Expense',
          timestamp: DateTime(now.year - 2, 1, 15),
          tag: 'TRAVEL',
        ),
      ];

      final todayMap = HomeCategoryBreakdownCard.calculateCategorySpendMap(txns, HomeCategoryPeriod.today);
      expect(todayMap['FOOD'], 100);
      expect(todayMap.containsKey('INCOME'), false);
      expect(todayMap.containsKey('TRAVEL'), false);

      final weekMap = HomeCategoryBreakdownCard.calculateCategorySpendMap(txns, HomeCategoryPeriod.thisWeek);
      expect(weekMap['FOOD'], 100);
      expect(weekMap.containsKey('TRAVEL'), false);

      final yearMap = HomeCategoryBreakdownCard.calculateCategorySpendMap(txns, HomeCategoryPeriod.thisYear);
      expect(yearMap['FOOD'], 100);
      expect(yearMap.containsKey('TRAVEL'), false);

      final allTimeMap = HomeCategoryBreakdownCard.calculateCategorySpendMap(txns, HomeCategoryPeriod.allTime);
      expect(allTimeMap['FOOD'], 100);
      expect(allTimeMap['TRAVEL'], 300);
      expect(allTimeMap.containsKey('INCOME'), false);
    });

    test('HomeWidgetService.updateCategoryBreakdownWidget executes without throwing', () async {
      final now = DateTime.now();
      final txns = [
        Transaction(
          amount: 250,
          isCredit: false,
          note: 'Dinner',
          timestamp: now,
          tag: 'FOOD',
        ),
      ];

      // Should run safely without uncaught exceptions
      await HomeWidgetService.updateCategoryBreakdownWidget(
        transactions: txns,
        categories: CategoryTag.defaults,
        period2x1: HomeCategoryPeriod.thisMonth,
      );
    });

    test('HomeWidgetService pin request helpers execute safely for 2x1', () async {
      final res2x1 = await HomeWidgetService.requestPinWidget2x1();
      final resDefault = await HomeWidgetService.requestPinWidget();
      // On headless test environment with MissingPluginException, it catches and returns false safely
      expect(res2x1, isA<bool>());
      expect(resDefault, isA<bool>());
    });

    test('SecureStorageRepository saves and loads 2x1 widget period', () async {
      final repo = SecureStorageRepository();
      expect(await repo.loadWidget2x1Period(), isNull);

      await repo.saveWidget2x1Period(HomeCategoryPeriod.thisYear.name);

      expect(await repo.loadWidget2x1Period(), 'thisYear');
    });
  });
}
