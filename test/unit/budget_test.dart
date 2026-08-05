import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/models/budget.dart';
import 'package:nummo/models/transaction.dart';

void main() {
  group('Budget Calculation Tests', () {
    test('calculateSpent calculates debit transactions only within inclusive date range', () {
      final now = DateTime.now();
      final b = Budget(title: 'Monthly Budget', amount: 10000, period: BudgetPeriod.monthly);

      final txns = [
        Transaction(amount: 1500, isCredit: false, timestamp: now, tag: 'FOOD'),
        Transaction(amount: 3000, isCredit: true, timestamp: now, tag: 'SALARY'), // Income ignored
        Transaction(amount: 500, isCredit: false, timestamp: now, tag: 'SHOPPING'),
      ];

      final spent = b.calculateSpent(txns, now);
      expect(spent, 2000.0);
    });

    test('calculateSpent respects category scope filter', () {
      final now = DateTime.now();
      final catBudget = Budget(title: 'Food Budget', amount: 5000, scope: 'FOOD', period: BudgetPeriod.monthly);

      final txns = [
        Transaction(amount: 1200, isCredit: false, timestamp: now, tag: 'FOOD'),
        Transaction(amount: 3000, isCredit: false, timestamp: now, tag: 'TRANSPORT'),
      ];

      final spent = catBudget.calculateSpent(txns, now);
      expect(spent, 1200.0);
    });
  });
}
