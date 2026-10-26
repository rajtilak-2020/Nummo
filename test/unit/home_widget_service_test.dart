import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/core/storage/secure_storage_repository.dart';
import 'package:nummo/core/widgets/home_widget_service.dart';
import 'package:nummo/features/ledger/home_swipe_view.dart';
import 'package:nummo/models/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    SecureStorageRepository.prewarm(prefs);
  });

  group('HomeCategoryBreakdownCard Date Range Calculations', () {
    test('calculateRange thisWeek starts strictly on Monday (ISO-8601)', () {
      final range = HomeCategoryBreakdownCard.calculateRange(HomeCategoryPeriod.thisWeek);
      // Monday in Dart DateTime has weekday == DateTime.monday (1)
      expect(range.start.weekday, equals(DateTime.monday));
      expect(range.start.hour, equals(0));
      expect(range.start.minute, equals(0));
      expect(range.start.second, equals(0));
    });

    test('calculateRange today covers midnight to 23:59:59.999', () {
      final now = DateTime.now();
      final range = HomeCategoryBreakdownCard.calculateRange(HomeCategoryPeriod.today);
      expect(range.start.year, equals(now.year));
      expect(range.start.month, equals(now.month));
      expect(range.start.day, equals(now.day));
      expect(range.start.hour, equals(0));
      expect(range.start.minute, equals(0));

      expect(range.end.year, equals(now.year));
      expect(range.end.month, equals(now.month));
      expect(range.end.day, equals(now.day));
      expect(range.end.hour, equals(23));
      expect(range.end.minute, equals(59));
      expect(range.end.second, equals(59));
      expect(range.end.millisecond, equals(999));
    });

    test('calculateRange thisMonth starts on the 1st of current month', () {
      final now = DateTime.now();
      final range = HomeCategoryBreakdownCard.calculateRange(HomeCategoryPeriod.thisMonth);
      expect(range.start.year, equals(now.year));
      expect(range.start.month, equals(now.month));
      expect(range.start.day, equals(1));
      expect(range.start.hour, equals(0));
      expect(range.start.minute, equals(0));
    });

    test('calculateRange thisYear starts on Jan 1st and ends on Dec 31st', () {
      final now = DateTime.now();
      final range = HomeCategoryBreakdownCard.calculateRange(HomeCategoryPeriod.thisYear);
      expect(range.start.year, equals(now.year));
      expect(range.start.month, equals(1));
      expect(range.start.day, equals(1));

      expect(range.end.year, equals(now.year));
      expect(range.end.month, equals(12));
      expect(range.end.day, equals(31));
      expect(range.end.hour, equals(23));
      expect(range.end.minute, equals(59));
    });
  });

  group('HomeCategoryBreakdownCard Spend Map Business Logic', () {
    test('calculateCategorySpendMap includes only debit transactions and excludes credit', () {
      final now = DateTime.now();
      final txns = [
        Transaction(
          amount: 500,
          isCredit: false,
          note: 'Groceries',
          timestamp: now,
          tag: 'FOOD',
        ),
        Transaction(
          amount: 250,
          isCredit: false,
          note: 'Snacks',
          timestamp: now,
          tag: 'FOOD',
        ),
        Transaction(
          amount: 10000,
          isCredit: true, // Income / Credit
          note: 'Salary',
          timestamp: now,
          tag: 'SALARY',
        ),
        Transaction(
          amount: 300,
          isCredit: false,
          note: 'Fuel',
          timestamp: now,
          tag: 'FUEL',
        ),
      ];

      final spendMap = HomeCategoryBreakdownCard.calculateCategorySpendMap(
        txns,
        HomeCategoryPeriod.today,
      );

      // FOOD: 500 + 250 = 750
      expect(spendMap['FOOD'], equals(750.0));
      // FUEL: 300
      expect(spendMap['FUEL'], equals(300.0));
      // SALARY: credit must not be in spend map
      expect(spendMap.containsKey('SALARY'), isFalse);
    });

    test('calculateCategorySpendMap with empty transactions returns empty map', () {
      final spendMap = HomeCategoryBreakdownCard.calculateCategorySpendMap(
        const [],
        HomeCategoryPeriod.thisMonth,
      );
      expect(spendMap, isEmpty);
    });
  });

  group('HomeWidgetService Concurrency and Synchronization', () {
    test('Handles empty and rapid consecutive updateCategoryBreakdownWidget calls safely', () async {
      final now = DateTime.now();
      final t1 = Transaction(amount: 100, isCredit: false, timestamp: now, tag: 'FOOD');
      final t2 = Transaction(amount: 200, isCredit: false, timestamp: now, tag: 'SHOPPING');

      // Rapid consecutive calls to simulate user typing or fast edits
      final f1 = HomeWidgetService.updateCategoryBreakdownWidget(transactions: [t1]);
      final f2 = HomeWidgetService.updateCategoryBreakdownWidget(transactions: [t1, t2]);
      final f3 = HomeWidgetService.updateCategoryBreakdownWidget(transactions: const []);

      await Future.wait([f1, f2, f3]);
      // Should complete without throwing any exception
      expect(true, isTrue);
    });
  });
}
