import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/features/settings/settings_screen.dart';
import 'package:nummo/features/settings/budgets_screen.dart';
import 'package:nummo/models/budget.dart';
import 'package:nummo/models/category.dart';
import 'package:nummo/models/transaction.dart';
import 'package:nummo/features/ledger/home_swipe_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCategories = [
    const CategoryTag(id: 'food', name: 'Food', emoji: '🍔', colorValue: 0xFFF59E0B),
    const CategoryTag(id: 'travel', name: 'Travel', emoji: '✈️', colorValue: 0xFF06B6D4),
  ];

  final testBudgets = [
    Budget(
      id: 'b1',
      title: 'Groceries Ceiling',
      amount: 5000,
      scope: 'food',
      period: BudgetPeriod.monthly,
      isRecurring: true,
    ),
    Budget(
      id: 'b2',
      title: 'Overall Limit Exceeded',
      amount: 2000,
      scope: 'overall',
      period: BudgetPeriod.weekly,
      isRecurring: true,
    ),
  ];

  final testTransactions = [
    Transaction(
      id: 't1',
      amount: 1500,
      isCredit: false,
      note: 'Grocery store',
      timestamp: DateTime.now(),
      balanceAfter: 8500,
      tag: 'food',
    ),
    Transaction(
      id: 't2',
      amount: 2500,
      isCredit: false,
      note: 'Shopping spree',
      timestamp: DateTime.now(),
      balanceAfter: 6000,
      tag: 'travel',
    ),
  ];

  Widget buildSettingsApp({
    required List<Budget> budgets,
    required List<Transaction> transactions,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SettingsScreen(
          isPinEnabled: false,
          isBioEnabled: false,
          isFingerprintEnabled: false,
          currentAccent: 'Indigo Slate',
          currentThemeMode: 'system',
          categories: testCategories,
          budgets: budgets,
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
    );
  }

  Widget buildBudgetsScreenApp({
    required List<Budget> budgets,
    required List<Transaction> transactions,
  }) {
    return MaterialApp(
      home: BudgetsScreen(
        budgets: budgets,
        categories: testCategories,
        transactions: transactions,
        onUpdateBudgets: (_) async {},
      ),
    );
  }

  group('Budget Targets Navigation & Screen Tests', () {
    testWidgets('SettingsScreen renders compact summary tile with zero overflow on low-DPI screen (320x640)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildSettingsApp(
          budgets: testBudgets,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and summary card
      expect(find.text('BUDGET TARGETS'), findsOneWidget);
      expect(find.text('Budget Targets'), findsOneWidget);
      expect(find.text('2 Active Targets'), findsOneWidget);
      expect(find.text('TOTAL SPENT'), findsOneWidget);
      expect(find.text('TOTAL CEILING'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('Tapping summary tile in Settings navigates to dedicated BudgetsScreen', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildSettingsApp(
          budgets: testBudgets,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the summary tile
      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();

      // Verify we have navigated to BudgetsScreen
      expect(find.text('Overall Budget'), findsOneWidget);
      expect(find.text('Groceries Ceiling'), findsOneWidget);
      expect(find.text('Overall Limit Exceeded'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('🌐 Overall'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
    });

    testWidgets('BudgetsScreen renders properly with zero overflow on low-DPI screen (320x640)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildBudgetsScreenApp(
          budgets: testBudgets,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overall Budget'), findsOneWidget);
      expect(find.text('Groceries Ceiling'), findsOneWidget);
      expect(find.text('Overall Limit Exceeded'), findsOneWidget);
      expect(find.text('Exceeded (200%)'), findsOneWidget);
    });

    testWidgets('Tapping on a budget card in BudgetsScreen opens the BudgetDialog', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildBudgetsScreenApp(
          budgets: testBudgets,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Groceries Ceiling card
      await tester.tap(find.text('Groceries Ceiling'));
      await tester.pumpAndSettle();

      // Verify BudgetDialog appears with the existing title
      expect(find.text('Edit Budget'), findsOneWidget);
      expect(find.text('Groceries Ceiling'), findsWidgets);
    });

    testWidgets('Empty budgets renders empty state card cleanly in SettingsScreen and BudgetsScreen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildSettingsApp(
          budgets: const [],
          transactions: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No spending ceilings configured'), findsOneWidget);
      expect(find.text('Setup'), findsOneWidget);

      // Tap Setup to navigate to BudgetsScreen
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      expect(find.text('No Budget Targets Configured'), findsOneWidget);
      expect(find.text('Create Budget Target'), findsOneWidget);
    });

    testWidgets('HomeActiveBudgetsCard aligns amount left pill to the far right edge of the card', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final budget = Budget(
        id: 'b1',
        title: 'Dining Out',
        amount: 5000,
        scope: 'food',
        period: BudgetPeriod.monthly,
      );
      final tx = Transaction(
        id: 't1',
        amount: 1200,
        isCredit: false,
        note: 'Restaurant',
        timestamp: DateTime.now(),
        tag: 'food',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: HomeActiveBudgetsCard(
                budgets: [budget],
                transactions: [tx],
                categories: testCategories,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pillFinder = find.textContaining('left');
      expect(pillFinder, findsOneWidget);

      final percentageFinder = find.text('24%');
      expect(percentageFinder, findsOneWidget);

      final activeBadgeFinder = find.text('1 active');
      expect(activeBadgeFinder, findsOneWidget);

      final pillRight = tester.getTopRight(pillFinder).dx;
      final percentageRight = tester.getTopRight(percentageFinder).dx;
      final activeBadgeRight = tester.getTopRight(activeBadgeFinder).dx;

      // On a 390dp screen, the card has 16dp outer padding and 16dp inner padding.
      // So the right edge of inner content is around 390 - 32 = 358dp.
      // The pill right coordinate must be anchored near the right edge (> 330dp)
      // and aligned with the percentage indicator, NOT shifted towards the middle.
      expect(pillRight, greaterThan(325.0));
      expect((percentageRight - pillRight).abs(), lessThan(15.0));
      expect((activeBadgeRight - pillRight).abs(), lessThan(15.0));
    });
  });
}
