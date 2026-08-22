import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/features/ledger/logs_filter_sheet.dart';
import 'package:nummo/models/transaction.dart';

void main() {
  group('LogsFilterOptions Unit Tests', () {
    final now = DateTime.now();
    final todayTxn = Transaction(
      id: '1',
      amount: 250.0,
      isCredit: false,
      note: 'Grocery store snacks',
      tag: 'FOOD',
      timestamp: now,
    );

    final salaryTxn = Transaction(
      id: '2',
      amount: 5000.0,
      isCredit: true,
      note: 'Monthly salary',
      tag: 'INCOME',
      timestamp: now.subtract(const Duration(days: 2)),
    );

    final oldBillTxn = Transaction(
      id: '3',
      amount: 1200.0,
      isCredit: false,
      note: 'Electricity Bill',
      tag: 'BILLS',
      timestamp: DateTime(2023, 1, 15),
    );

    final txns = [todayTxn, salaryTxn, oldBillTxn];

    test('default filter options returns all transactions sorted newest first', () {
      const options = LogsFilterOptions();
      expect(options.isDefault, isTrue);
      expect(options.activeFilterCount, 0);

      final result = options.apply(transactions: txns, searchQuery: '');
      expect(result.length, 3);
      expect(result.first.id, '1'); // Today is latest
      expect(result.last.id, '3'); // 2023 is oldest
    });

    test('typeFilter filters credits and debits accurately', () {
      // In (Credit only)
      const inOptions = LogsFilterOptions(typeFilter: TransactionTypeFilter.inOnly);
      expect(inOptions.isDefault, isFalse);
      expect(inOptions.activeFilterCount, 1);
      final inResult = inOptions.apply(transactions: txns, searchQuery: '');
      expect(inResult.length, 1);
      expect(inResult.first.id, '2');

      // Out (Debit only)
      const outOptions = LogsFilterOptions(typeFilter: TransactionTypeFilter.outOnly);
      expect(outOptions.activeFilterCount, 1);
      final outResult = outOptions.apply(transactions: txns, searchQuery: '');
      expect(outResult.length, 2);
      expect(outResult.map((t) => t.id), containsAll(['1', '3']));
    });

    test('category filter isolates selected categories', () {
      final foodOptions = const LogsFilterOptions(selectedCategoryIds: {'FOOD'});
      expect(foodOptions.activeFilterCount, 1);
      final foodResult = foodOptions.apply(transactions: txns, searchQuery: '');
      expect(foodResult.length, 1);
      expect(foodResult.first.note, 'Grocery store snacks');

      final multiCatOptions = const LogsFilterOptions(selectedCategoryIds: {'FOOD', 'BILLS'});
      final multiResult = multiCatOptions.apply(transactions: txns, searchQuery: '');
      expect(multiResult.length, 2);
    });

    test('dateFilter filters today, thisMonth, thisYear, and customRange', () {
      // Today filter
      const todayFilter = LogsFilterOptions(dateFilter: LogsDateFilter.today);
      final todayResult = todayFilter.apply(transactions: txns, searchQuery: '');
      expect(todayResult.length, 1);
      expect(todayResult.first.id, '1');

      // Custom range filter
      final customFilter = LogsFilterOptions(
        dateFilter: LogsDateFilter.customRange,
        customStartDate: DateTime(2023, 1, 1),
        customEndDate: DateTime(2023, 1, 31),
      );
      final customResult = customFilter.apply(transactions: txns, searchQuery: '');
      expect(customResult.length, 1);
      expect(customResult.first.id, '3');
    });

    test('sortOrder correctly re-orders transactions', () {
      // Highest amount first
      const highSort = LogsFilterOptions(sortOrder: LogsSortOrder.highestAmount);
      final highResult = highSort.apply(transactions: txns, searchQuery: '');
      expect(highResult.map((t) => t.amount), [5000.0, 1200.0, 250.0]);

      // Lowest amount first
      const lowSort = LogsFilterOptions(sortOrder: LogsSortOrder.lowestAmount);
      final lowResult = lowSort.apply(transactions: txns, searchQuery: '');
      expect(lowResult.map((t) => t.amount), [250.0, 1200.0, 5000.0]);

      // Oldest first
      const oldestSort = LogsFilterOptions(sortOrder: LogsSortOrder.oldestFirst);
      final oldestResult = oldestSort.apply(transactions: txns, searchQuery: '');
      expect(oldestResult.first.id, '3');
      expect(oldestResult.last.id, '1');
    });

    test('amount bounds (minAmount & maxAmount) filter amounts properly', () {
      const rangeOptions = LogsFilterOptions(minAmount: 300.0, maxAmount: 2000.0);
      expect(rangeOptions.activeFilterCount, 1);
      final rangeResult = rangeOptions.apply(transactions: txns, searchQuery: '');
      expect(rangeResult.length, 1);
      expect(rangeResult.first.id, '3'); // 1200.0
    });

    test('search query matches note, amount, and category tag', () {
      const options = LogsFilterOptions();

      // Note match
      final noteMatch = options.apply(transactions: txns, searchQuery: 'grocery');
      expect(noteMatch.length, 1);
      expect(noteMatch.first.id, '1');

      // Amount match
      final amountMatch = options.apply(transactions: txns, searchQuery: '5000');
      expect(amountMatch.length, 1);
      expect(amountMatch.first.id, '2');

      // Category Tag match
      final tagMatch = options.apply(transactions: txns, searchQuery: 'bills');
      expect(tagMatch.length, 1);
      expect(tagMatch.first.id, '3');
    });

    test('combined multi-criteria filtering', () {
      final combined = LogsFilterOptions(
        typeFilter: TransactionTypeFilter.outOnly,
        selectedCategoryIds: const {'FOOD', 'BILLS'},
        minAmount: 100.0,
        maxAmount: 1000.0,
      );
      expect(combined.activeFilterCount, 3); // type, category, amount

      final result = combined.apply(transactions: txns, searchQuery: 'snack');
      expect(result.length, 1);
      expect(result.first.id, '1');
    });
  });
}
