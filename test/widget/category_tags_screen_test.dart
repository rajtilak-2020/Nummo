import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/features/settings/settings_screen.dart';
import 'package:nummo/features/settings/category_tags_screen.dart';
import 'package:nummo/models/category.dart';
import 'package:nummo/models/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCategories = [
    const CategoryTag(id: 'food', name: 'Food', emoji: '🍔', colorValue: 0xFFF59E0B, scope: TagScope.debit),
    const CategoryTag(id: 'travel', name: 'Travel', emoji: '✈️', colorValue: 0xFF06B6D4, scope: TagScope.debit),
    const CategoryTag(id: 'salary', name: 'Salary', emoji: '💼', colorValue: 0xFF10B981, scope: TagScope.credit),
    const CategoryTag(id: 'investments', name: 'Investments', emoji: '📈', colorValue: 0xFF8B5CF6, scope: TagScope.both),
  ];

  final testTransactions = [
    Transaction(
      id: 't1',
      amount: 1200,
      isCredit: false,
      note: 'Dinner',
      timestamp: DateTime.now(),
      balanceAfter: 8800,
      tag: 'food',
    ),
    Transaction(
      id: 't2',
      amount: 45000,
      isCredit: true,
      note: 'Monthly salary',
      timestamp: DateTime.now(),
      balanceAfter: 53800,
      tag: 'salary',
    ),
  ];

  Widget buildSettingsApp({
    required List<CategoryTag> categories,
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
    );
  }

  Widget buildCategoryTagsScreenApp({
    required List<CategoryTag> categories,
    required List<Transaction> transactions,
    Future<void> Function(List<CategoryTag>)? onUpdate,
  }) {
    return MaterialApp(
      home: CategoryTagsScreen(
        categories: categories,
        transactions: transactions,
        onUpdateCategories: onUpdate ?? (_) async {},
      ),
    );
  }

  group('Category Tags Navigation & Dedicated Screen Tests', () {
    testWidgets('SettingsScreen renders Category Tags summary tile with count and breakdown', (tester) async {
      await tester.pumpWidget(
        buildSettingsApp(
          categories: testCategories,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      // Verify category tags section header
      expect(find.text('CATEGORY TAGS'), findsOneWidget);

      // Verify summary tile contents
      expect(find.text('Category Tags'), findsOneWidget);
      expect(find.textContaining('4 Tags (2 Debit, 1 Credit, 1 Shared)'), findsOneWidget);
      expect(find.text('4 tags'), findsOneWidget);
      expect(find.text('Manage All'), findsOneWidget);

      // Verify preview chips
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
    });

    testWidgets('Tapping Category Tags summary tile in SettingsScreen navigates to CategoryTagsScreen', (tester) async {
      await tester.pumpWidget(
        buildSettingsApp(
          categories: testCategories,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the summary tile
      await tester.tap(find.text('Manage All'));
      await tester.pumpAndSettle();

      // Verify CategoryTagsScreen opened
      expect(find.text('Category Portfolio'), findsOneWidget);
      expect(find.text('4 Total'), findsOneWidget);
      expect(find.text('DEBIT'), findsOneWidget);
      expect(find.text('CREDIT'), findsOneWidget);
      expect(find.text('SHARED'), findsOneWidget);
    });

    testWidgets('CategoryTagsScreen filters tags by scope', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildCategoryTagsScreenApp(
          categories: testCategories,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      // Initially all tags are shown
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Investments'), findsOneWidget);

      // Tap 'Credit' filter pill in the horizontal filter row
      final creditPill = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Credit'),
      );
      await tester.tap(creditPill);
      await tester.pumpAndSettle();

      // Only Salary should be visible
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
      expect(find.text('Travel'), findsNothing);

      // Tap 'Shared' filter pill
      final sharedPill = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Shared'),
      );
      await tester.tap(sharedPill);
      await tester.pumpAndSettle();

      // Only Investments should be visible
      expect(find.text('Investments'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);

      // Tap 'All' filter pill
      final allPill = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('All'),
      );
      await tester.tap(allPill);
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
    });

    testWidgets('CategoryTagsScreen searches tags by name query', (tester) async {
      await tester.pumpWidget(
        buildCategoryTagsScreenApp(
          categories: testCategories,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query 'sal'
      await tester.enterText(find.byType(TextField), 'sal');
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
      expect(find.text('Travel'), findsNothing);
    });

    testWidgets('CategoryTagsScreen displays correct transaction usage counts', (tester) async {
      await tester.pumpWidget(
        buildCategoryTagsScreenApp(
          categories: testCategories,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      // Food and Salary each have 1 transaction
      expect(find.text('1 txns'), findsNWidgets(2));
      // Travel has 0 transactions
      expect(find.text('Unused'), findsWidgets);
    });

    testWidgets('Low DPI screen (320x640) renders cleanly without RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildCategoryTagsScreenApp(
          categories: testCategories,
          transactions: testTransactions,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Category Portfolio'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('Empty category tags renders empty state cleanly in Settings and CategoryTagsScreen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildSettingsApp(
          categories: const [],
          transactions: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No category tags configured'), findsOneWidget);
      expect(find.text('Configure'), findsOneWidget);

      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();

      expect(find.text('No Category Tags Configured'), findsOneWidget);
      expect(find.text('Add Category Tag'), findsOneWidget);
    });
  });
}
