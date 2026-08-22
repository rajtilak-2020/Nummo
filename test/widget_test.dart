import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/main.dart';
import 'package:nummo/features/ledger/home_swipe_view.dart';
import 'package:nummo/models/transaction.dart';
import 'package:nummo/models/category.dart';
import 'package:nummo/models/budget.dart';
import 'package:nummo/design_system/components/category_tag_dialog.dart';
import 'package:nummo/design_system/components/budget_dialog.dart';
import 'package:nummo/design_system/components/nummo_card.dart';
import 'package:nummo/design_system/tokens.dart';
import 'package:nummo/features/ledger/add_transaction_sheet.dart';
import 'package:nummo/features/settings/settings_screen.dart';
import 'package:nummo/core/security/app_lock_guard.dart';

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

  testWidgets('Pressing lock button in top right of HomeSwipeView locks the app when PIN is enabled, logo tap does not lock', (WidgetTester tester) async {
    bool lockAppCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSwipeView(
            transactions: const [],
            categories: CategoryTag.defaults,
            budgets: const [],
            isPinEnabled: true,
            onLockApp: () {
              lockAppCalled = true;
            },
            onAddTransaction: (_) async {},
            onUpdateTransaction: (_) async {},
            onDeleteTransaction: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tapping logo/text should NOT lock app
    expect(find.text('Nummo'), findsOneWidget);
    await tester.tap(find.text('Nummo'));
    await tester.pumpAndSettle();
    expect(lockAppCalled, isFalse);

    // Tapping lock button in top right corner should lock app
    expect(find.byKey(const Key('lock_app_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('lock_app_button')));
    await tester.pumpAndSettle();
    expect(lockAppCalled, isTrue);
  });

  testWidgets('AppLifecycleState.inactive (Notification Center) does NOT lock app, paused DOES lock app', (WidgetTester tester) async {
    await tester.pumpWidget(const NummoApp());
    await tester.pump(const Duration(milliseconds: 200));

    // Simulate opening notification center (inactive state)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    // App remains unlocked (no lock screen displayed when PIN not configured or inactive state)
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('AppLockGuard prevents auto-lock when system picker is active during app pause', (WidgetTester tester) async {
    await tester.pumpWidget(const NummoApp());
    await tester.pump(const Duration(milliseconds: 200));

    // Mark system picker active
    AppLockGuard.setPickerActive(true);

    // Simulate app pause while picker is open
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // Verify system remains unlocked
    expect(find.byType(MaterialApp), findsOneWidget);

    // Reset picker state
    AppLockGuard.setPickerActive(false);
  });

  testWidgets('CategoryTagDialog scope switcher allows choosing Debit, Credit, or Both', (WidgetTester tester) async {
    CategoryTag? savedCat;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => CategoryTagDialog.show(
                  context,
                  initialScope: TagScope.both,
                  onSave: (cat) {
                    savedCat = cat;
                  },
                ),
                child: const Text('Open Dialog'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify scope switcher labels are present
    expect(find.text('Debit'), findsOneWidget);
    expect(find.text('Credit'), findsOneWidget);
    expect(find.text('Both'), findsWidgets);

    // Enter tag name
    await tester.enterText(find.byType(TextField).first, 'Freelance Pay');
    await tester.pumpAndSettle();

    // Tap Credit scope option
    await tester.tap(find.text('Credit'));
    await tester.pumpAndSettle();

    // Tap Save Tag
    await tester.tap(find.text('Save Tag'));
    await tester.pumpAndSettle();

    expect(savedCat, isNotNull);
    expect(savedCat!.name, 'Freelance Pay');
    expect(savedCat!.scope, TagScope.credit);
  });

  testWidgets('AddTransactionSheet in Credit mode renders credit categories and saves transaction with tag', (WidgetTester tester) async {
    Transaction? savedTxn;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => AddTransactionSheet.show(
                  context,
                  initialIsCredit: true,
                  availableCategories: CategoryTag.defaults,
                  onSave: (txn) async {
                    savedTxn = txn;
                  },
                ),
                child: const Text('Open Credit Sheet'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Credit Sheet
    await tester.tap(find.text('Open Credit Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Add Credit Entry'), findsOneWidget);
    expect(find.text('Category Tag (Optional)'), findsOneWidget);

    // Credit-applicable categories (Salary, Pocket Money, Freelance, Investment) should be present
    expect(find.text('💰 Salary'), findsOneWidget);
    expect(find.text('💵 Pocket Money'), findsOneWidget);
    expect(find.text('💼 Freelance'), findsOneWidget);
    expect(find.text('📈 Investment'), findsOneWidget);
    // Debit-only categories (Food, Shopping, Fuel) should NOT be present in Credit mode
    expect(find.text('🍔 Food'), findsNothing);

    // Enter Amount and Note
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '15000');
    await tester.enterText(textFields.at(1), 'Monthly Salary');
    await tester.pumpAndSettle();

    // Select Salary category tag
    await tester.tap(find.text('💰 Salary'));
    await tester.pumpAndSettle();

    // Save Entry
    await tester.tap(find.text('Save Entry'));
    await tester.pumpAndSettle();

    expect(savedTxn, isNotNull);
    expect(savedTxn!.amount, 15000.0);
    expect(savedTxn!.isCredit, isTrue);
    expect(savedTxn!.note, 'Monthly Salary');
    expect(savedTxn!.tag, 'SALARY');
  });

  testWidgets('AddTransactionSheet requires note and blocks submission when note is empty', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Transaction? savedTxn;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => AddTransactionSheet.show(
                  context,
                  initialIsCredit: false,
                  availableCategories: CategoryTag.defaults,
                  onSave: (txn) async {
                    savedTxn = txn;
                  },
                ),
                child: const Text('Open Debit Sheet'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Debit Sheet
    await tester.tap(find.text('Open Debit Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Add Debit Entry'), findsOneWidget);
    expect(find.text('Category Tag *'), findsOneWidget);

    // Enter Amount only, leaving Note empty
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '250');
    await tester.pumpAndSettle();

    // Select Food category
    await tester.ensureVisible(find.text('🍔 Food'));
    await tester.tap(find.text('🍔 Food'));
    await tester.pumpAndSettle();

    // Try saving without entering note
    await tester.ensureVisible(find.text('Save Entry'));
    await tester.tap(find.text('Save Entry'));
    await tester.pumpAndSettle();

    // Should block save and show error
    expect(savedTxn, isNull);
    expect(find.text('Please enter a note for this entry'), findsOneWidget);
    expect(find.text('Add Debit Entry'), findsOneWidget);

    // Now enter Note
    await tester.enterText(textFields.at(1), 'Lunch at Diner');
    await tester.pumpAndSettle();

    // Save Entry successfully
    await tester.ensureVisible(find.text('Save Entry'));
    await tester.tap(find.text('Save Entry'));
    await tester.pumpAndSettle();

    expect(savedTxn, isNotNull);
    expect(savedTxn!.amount, 250.0);
    expect(savedTxn!.note, 'Lunch at Diner');
    expect(savedTxn!.tag, 'FOOD');
  });

  testWidgets('CategoryTagDialog prevents duplicate category creation case-insensitively', (WidgetTester tester) async {
    CategoryTag? createdTag;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => CategoryTagDialog.show(
                  context,
                  existingCategories: CategoryTag.defaults,
                  onSave: (cat) {
                    createdTag = cat;
                  },
                ),
                child: const Text('Add Tag'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Tag'));
    await tester.pumpAndSettle();

    final nameField = find.byType(TextField);

    // Enter existing tag name in different casing e.g. "food" (default is "Food")
    await tester.enterText(nameField, 'food');
    await tester.pumpAndSettle();

    // Verify duplicate warning is displayed
    expect(find.text('Category tag "food" already exists'), findsOneWidget);

    // Verify Save Tag button is disabled (cannot tap)
    final saveButtonFinder = find.widgetWithText(FilledButton, 'Save Tag');
    expect(saveButtonFinder, findsOneWidget);
    final FilledButton buttonWidget = tester.widget(saveButtonFinder);
    expect(buttonWidget.onPressed, isNull);

    // Enter a new unique tag name
    await tester.enterText(nameField, 'Gaming');
    await tester.pumpAndSettle();

    // Verify duplicate warning is gone
    expect(find.text('Category tag "food" already exists'), findsNothing);
    final FilledButton enabledButtonWidget = tester.widget(saveButtonFinder);
    expect(enabledButtonWidget.onPressed, isNotNull);

    // Tap Save Tag
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    expect(createdTag, isNotNull);
    expect(createdTag!.name, 'Gaming');
  });

  testWidgets('HomeCategoryBreakdownCard highlights item on long-press hold, not on tap', (WidgetTester tester) async {
    final transactions = [
      Transaction(
        amount: 250,
        isCredit: false,
        note: 'Lunch',
        timestamp: DateTime.now(),
        tag: 'FOOD',
      ),
      Transaction(
        amount: 100,
        isCredit: false,
        note: 'Metro',
        timestamp: DateTime.now(),
        tag: 'TRAVEL',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSwipeView(
            transactions: transactions,
            categories: CategoryTag.defaults,
            budgets: const [],
            isPinEnabled: false,
            onLockApp: () {},
            onAddTransaction: (_) async {},
            onUpdateTransaction: (_) async {},
            onDeleteTransaction: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial state has Category Breakdown title and reset button is not present
    expect(find.text('Category Breakdown'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    // Tapping on "Food" should NOT select/highlight or show close button
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    // Long-pressing (holding) on "Food" should highlight it and display the close reset button
    await tester.longPress(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Tapping the close reset button resets selection
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('BudgetDialog Add Budget requires user to select category scope and is not pre-selected by default', (WidgetTester tester) async {
    Budget? savedBudget;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => BudgetDialog.show(
                  context,
                  categories: CategoryTag.defaults,
                  onSave: (b) {
                    savedBudget = b;
                  },
                ),
                child: const Text('Add Budget'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Budget'));
    await tester.pumpAndSettle();

    // Verify preview card shows 'Select Category Scope'
    expect(find.textContaining('Select Category Scope'), findsOneWidget);

    // Enter title and amount
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, 'Groceries');
    await tester.enterText(textFields.last, '4000');
    await tester.pumpAndSettle();

    // Save button should still be disabled because scope is not chosen
    final saveButtonFinder = find.widgetWithText(FilledButton, 'Save Budget');
    final FilledButton buttonWidget = tester.widget(saveButtonFinder);
    expect(buttonWidget.onPressed, isNull);

    // Select '🍔 Food' category scope
    await tester.tap(find.text('🍔 Food'));
    await tester.pumpAndSettle();

    // Verify preview card updated and Save button is enabled
    expect(find.textContaining('Food'), findsWidgets);
    final FilledButton enabledButtonWidget = tester.widget(saveButtonFinder);
    expect(enabledButtonWidget.onPressed, isNotNull);

    // Tap Save Budget
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    expect(savedBudget, isNotNull);
    expect(savedBudget!.title, 'Groceries');
    expect(savedBudget!.amount, 4000);
    expect(savedBudget!.scope, 'FOOD');
  });

  testWidgets('Super AMOLED theme tokens provide pure black background and surface', (WidgetTester tester) async {
    final amoledTheme = AppTheme.buildTheme(
      brightness: Brightness.dark,
      primaryAccent: const Color(0xFF4F46E5),
      isAmoled: true,
    );

    expect(amoledTheme.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(amoledTheme.colorScheme.surface, const Color(0xFF07080A));

    await tester.pumpWidget(
      MaterialApp(
        theme: amoledTheme,
        home: Builder(
          builder: (context) {
            return Scaffold(
              backgroundColor: AppColors.scaffoldBackground(context),
              body: Center(
                child: NummoCard(
                  child: Text(
                    'AMOLED Text',
                    style: TextStyle(color: AppColors.textPrimary(context)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF000000));
    expect(find.text('AMOLED Text'), findsOneWidget);
  });

  testWidgets('Settings appearance renders Auto, Light, Dark, and AMOLED theme options', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? selectedMode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            isPinEnabled: false,
            isBioEnabled: false,
            isFingerprintEnabled: false,
            currentAccent: 'Indigo Slate',
            currentThemeMode: 'system',
            categories: CategoryTag.defaults,
            budgets: const [],
            transactions: const [],
            activeBudgetName: 'Nummo Personal Account',
            onTogglePin: (context, enabled) async {},
            onToggleBio: (enabled) async => true,
            onToggleFingerprint: (enabled) async => true,
            onSelectAccent: (_) {},
            onSelectThemeMode: (mode) {
              selectedMode = mode;
            },
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

    await tester.scrollUntilVisible(find.text('AMOLED'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('AMOLED'), findsOneWidget);

    await tester.tap(find.text('AMOLED'));
    await tester.pumpAndSettle();

    expect(selectedMode, 'amoled');
  });

  testWidgets('Logs page search bar and filter feature works interactively', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final transactions = [
      Transaction(
        id: '1',
        amount: 350.0,
        isCredit: false,
        note: 'Burger and fries',
        tag: 'FOOD',
        timestamp: DateTime.now(),
      ),
      Transaction(
        id: '2',
        amount: 8000.0,
        isCredit: true,
        note: 'Freelance Design',
        tag: 'INCOME',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Transaction(
        id: '3',
        amount: 1500.0,
        isCredit: false,
        note: 'Internet Wifi Bill',
        tag: 'BILLS',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
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

    // Switch to Logs tab
    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();

    // Verify search bar and filter button are present
    expect(find.text('Search logs...'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // Verify all 3 transactions initially shown
    expect(find.text('Burger and fries'), findsOneWidget);
    expect(find.text('Freelance Design'), findsOneWidget);
    expect(find.text('Internet Wifi Bill'), findsOneWidget);

    // Test Search input
    await tester.enterText(find.byType(TextField).first, 'wifi');
    await tester.pumpAndSettle();

    expect(find.text('Internet Wifi Bill'), findsOneWidget);
    expect(find.text('Burger and fries'), findsNothing);
    expect(find.text('Freelance Design'), findsNothing);

    // Clear search with clear icon button
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Burger and fries'), findsOneWidget);

    // Open Filter Sheet Modal
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Filter Logs'), findsOneWidget);
    expect(find.text('Transaction Type'), findsOneWidget);
    expect(find.text('Time Period'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Sort Order'), findsOneWidget);
    expect(find.text('Amount Range (₹)'), findsOneWidget);

    // Select Income inside filter sheet
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // Tap Apply Filters
    await tester.tap(find.textContaining('Apply Filters'));
    await tester.pumpAndSettle();

    // Modal closed and filter applied
    expect(find.text('Filter Logs'), findsNothing);
    expect(find.text('Freelance Design'), findsOneWidget);
    expect(find.text('Burger and fries'), findsNothing);
    expect(find.text('Internet Wifi Bill'), findsNothing);

    // Verify active filter tag chip appears
    expect(find.text('📥 Income'), findsOneWidget);

    // Dismiss active filter tag chip via clear icon
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    // All transactions restored
    expect(find.text('Burger and fries'), findsOneWidget);
    expect(find.text('Freelance Design'), findsOneWidget);
    expect(find.text('Internet Wifi Bill'), findsOneWidget);
  });
}







