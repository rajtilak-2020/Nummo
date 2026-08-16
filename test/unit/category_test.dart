import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/models/category.dart';

void main() {
  group('CategoryTag Tests', () {
    test('CategoryTag preserves emoji and scope separately from name', () {
      const cat = CategoryTag(
        id: 'CUSTOM',
        name: 'Coffee & Tea',
        emoji: '☕',
        colorValue: 0xFFF59E0B,
        scope: TagScope.debit,
      );
      expect(cat.name, 'Coffee & Tea');
      expect(cat.emoji, '☕');
      expect(cat.scope, TagScope.debit);

      final json = cat.toJson();
      expect(json['scope'], 'debit');
      final restored = CategoryTag.fromJson(json);
      expect(restored.name, 'Coffee & Tea');
      expect(restored.emoji, '☕');
      expect(restored.scope, TagScope.debit);
    });

    test('CategoryTag.fromJson safely falls back to TagScope.debit for legacy custom JSON lacking scope', () {
      final legacyJson = {
        'id': 'CUSTOM_EXPENSE',
        'name': 'Groceries Expense',
        'emoji': '🥦',
        'colorValue': 0xFF64748B,
      };
      final restored = CategoryTag.fromJson(legacyJson);
      expect(restored.scope, TagScope.debit);
      expect(restored.scope.isApplicableToDebit, isTrue);
      expect(restored.scope.isApplicableToCredit, isFalse);
    });

    test('CategoryTag.fromJson preserves legacy default tag scopes correctly', () {
      final legacySalaryJson = {
        'id': 'SALARY',
        'name': 'Salary',
        'emoji': '💰',
        'colorValue': 0xFF10B981,
      };
      final restoredSalary = CategoryTag.fromJson(legacySalaryJson);
      expect(restoredSalary.scope, TagScope.credit);

      final legacyInvestmentJson = {
        'id': 'INVESTMENT',
        'name': 'Investment',
        'emoji': '📈',
        'colorValue': 0xFF06B6D4,
      };
      final restoredInvestment = CategoryTag.fromJson(legacyInvestmentJson);
      expect(restoredInvestment.scope, TagScope.both);
    });

    test('TagScope applicability checks', () {
      expect(TagScope.debit.isApplicableToDebit, isTrue);
      expect(TagScope.debit.isApplicableToCredit, isFalse);

      expect(TagScope.credit.isApplicableToDebit, isFalse);
      expect(TagScope.credit.isApplicableToCredit, isTrue);

      expect(TagScope.both.isApplicableToDebit, isTrue);
      expect(TagScope.both.isApplicableToCredit, isTrue);
    });

    test('CategoryTag.fromString migrates legacy tags safely', () {
      final foodCat = CategoryTag.fromString('FOOD');
      expect(foodCat.emoji, '🍔');
      expect(foodCat.scope, TagScope.debit);

      final salaryCat = CategoryTag.fromString('SALARY');
      expect(salaryCat.emoji, '💰');
      expect(salaryCat.scope, TagScope.credit);

      final pocketMoneyCat = CategoryTag.fromString('POCKETMONEY');
      expect(pocketMoneyCat.emoji, '💵');
      expect(pocketMoneyCat.scope, TagScope.credit);

      final customCat = CategoryTag.fromString('MY_SPECIAL_TAG');
      expect(customCat.emoji, '🏷️');
      expect(customCat.name, 'MY_SPECIAL_TAG');
      expect(customCat.scope, TagScope.debit);
    });

    test('CategoryTag created in transaction modal updates category list', () {
      final categories = List<CategoryTag>.from(CategoryTag.defaults);
      final initialCount = categories.length;
      const newCat = CategoryTag(
        id: 'MOVIES',
        name: 'Movies',
        emoji: '🍿',
        colorValue: 0xFF8B5CF6,
        scope: TagScope.debit,
      );

      if (!categories.any((c) => c.name.toLowerCase() == newCat.name.toLowerCase())) {
        categories.add(newCat);
      }

      expect(categories.length, initialCount + 1);
      expect(categories.any((c) => c.name == 'Movies' && c.emoji == '🍿'), isTrue);
    });
  });
}
