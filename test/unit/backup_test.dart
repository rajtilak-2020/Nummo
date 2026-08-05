import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/models/transaction.dart';
import 'package:nummo/models/category.dart';
import 'package:nummo/models/budget.dart';
import 'package:nummo/core/storage/backup_service.dart';

void main() {
  group('BackupService Schema v3 Tests', () {
    test('Unencrypted backup v3 payload exports and imports cleanly', () {
      final txns = [
        Transaction(amount: 500, isCredit: false, note: 'Groceries', tag: 'FOOD'),
      ];
      final cats = CategoryTag.defaults;
      final budgets = [Budget(title: 'Overall', amount: 20000)];
      final prefs = {'accent': 'Indigo Slate'};

      final payload = BackupService.createBackupPayload(
        transactions: txns,
        categories: cats,
        budgets: budgets,
        preferences: prefs,
      );

      final restored = BackupService.parseAndValidateBackup(rawInput: payload);
      expect(restored, isNotNull);
      expect(restored!['transactionCount'], 1);
      expect(restored['budgetCount'], 1);
    });

    test('AES-GCM encrypted backup payload with passphrase decrypts correctly', () {
      final txns = [
        Transaction(amount: 1500, isCredit: false, note: 'Utilities', tag: 'BILLS'),
      ];
      const pass = 'SuperSecretKey123!';

      final payload = BackupService.createBackupPayload(
        transactions: txns,
        categories: CategoryTag.defaults,
        budgets: [],
        preferences: {},
        passphrase: pass,
      );

      expect(payload.contains('ciphertext'), true);

      final restored = BackupService.parseAndValidateBackup(
        rawInput: payload,
        passphrase: pass,
      );

      expect(restored, isNotNull);
      final list = restored!['transactions'] as List<Transaction>;
      expect(list.first.note, 'Utilities');
    });
  });
}
