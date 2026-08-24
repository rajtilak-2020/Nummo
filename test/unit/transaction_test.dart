import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/models/transaction.dart';
import 'package:nummo/core/utils/input_validators.dart';
import 'package:nummo/core/utils/money_formatter.dart';

void main() {
  group('Transaction Model Tests', () {
    test('Transaction generates unique UUID if id is omitted', () {
      final t1 = Transaction(amount: 100, isCredit: false);
      final t2 = Transaction(amount: 100, isCredit: false);
      expect(t1.id.isNotEmpty, true);
      expect(t2.id.isNotEmpty, true);
      expect(t1.id, isNot(equals(t2.id)));
    });

    test('Defensive deserialization handles numeric casts safely', () {
      final json = {
        'id': 'test-123',
        'amount': 250, // int instead of double
        'isCredit': true,
        'note': '  Salary Payment  ',
        'timestamp': '2026-08-04T12:00:00.000Z',
        'tag': 'SALARY',
      };

      final txn = Transaction.fromJson(json);
      expect(txn.amount, 250.0);
      expect(txn.isCredit, true);
      expect(txn.note, 'Salary Payment');
    });

    test('InputValidators rejects NaN, Infinity, negative, and out of bound values', () {
      expect(InputValidators.parseAndValidateAmount('abc'), null);
      expect(InputValidators.parseAndValidateAmount('-500'), null);
      expect(InputValidators.parseAndValidateAmount('0'), null);
      expect(InputValidators.parseAndValidateAmount('NaN'), null);
      expect(InputValidators.parseAndValidateAmount('Infinity'), null);
      expect(InputValidators.parseAndValidateAmount('1500.50'), 1500.50);
    });

    test('Empty note falls back to category tag name instead of Untitled', () {
      final tDebit = Transaction(amount: 200, isCredit: false, note: '', tag: 'FOOD');
      expect(tDebit.note, 'Food');

      final tCredit = Transaction(amount: 5000, isCredit: true, note: null, tag: 'SALARY');
      expect(tCredit.note, 'Salary');

      final tUntitledLegacy = Transaction(amount: 100, isCredit: false, note: 'Untitled', tag: 'FUEL');
      expect(tUntitledLegacy.note, 'Fuel');

      final tNoTagCredit = Transaction(amount: 1000, isCredit: true, note: '');
      expect(tNoTagCredit.note, 'Credit');

      final tNoTagDebit = Transaction(amount: 500, isCredit: false, note: '');
      expect(tNoTagDebit.note, 'Expense');

      final tCustom = Transaction(amount: 300, isCredit: false, note: 'Dinner with team', tag: 'FOOD');
      expect(tCustom.note, 'Dinner with team');
    });

    test('MoneyFormatter formats negative amounts with minus sign', () {
      expect(MoneyFormatter.format(-1000.0), '-₹1,000.00');
      expect(MoneyFormatter.format(1000.0), '₹1,000.00');
    });
  });
}
