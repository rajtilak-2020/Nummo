import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nummo/core/storage/secure_storage_repository.dart';
import 'package:nummo/models/category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Migration Tests', () {
    test('migrateLegacyStorageIfNeeded converts single JSON string transactions safely', () async {
      SharedPreferences.setMockInitialValues({
        'transactions': '[{"id":"old-1","amount":150.0,"isCredit":false,"note":"Coffee","timestamp":"2026-08-01T10:00:00.000Z","tag":"FOOD"}]',
        'custom_tags': ['COFFEE', 'SNACKS'],
        'app_pin': '4321',
        'local_auth_enabled': true,
      });

      final repo = SecureStorageRepository();
      await repo.migrateLegacyStorageIfNeeded();

      final pinEnabled = await repo.isPinEnabled();
      expect(pinEnabled, true);

      final isPinValid = await repo.verifyPin('4321');
      expect(isPinValid, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('app_pin'), false);

      final cats = await repo.loadCategories();
      expect(cats.any((c) => c.name == 'COFFEE' && c.scope == TagScope.debit), true);
      expect(cats.any((c) => c.name == 'SNACKS' && c.scope == TagScope.debit), true);

      final txns = await repo.loadTransactions();
      expect(txns.length, 1);
      expect(txns.first.note, 'Coffee');
      expect(txns.first.tag, 'FOOD');
    });

    test('Old storage JSON with transactions and legacy categories retains 100% data integrity', () async {
      FlutterSecureStorage.setMockInitialValues({
        'nummo_secure_categories_v3': '[{"id":"OLD_CUSTOM_1","name":"Electricity","emoji":"⚡","colorValue":4283141205}]',
        'nummo_secure_transactions_v3': '[{"id":"t-old-1","amount":2500.0,"isCredit":false,"note":"Power Bill","timestamp":"2026-07-15T12:00:00.000","tag":"OLD_CUSTOM_1"},{"id":"t-old-2","amount":50000.0,"isCredit":true,"note":"Salary Deposit","timestamp":"2026-07-01T09:00:00.000"}]',
      });

      final repo = SecureStorageRepository();
      final cats = await repo.loadCategories();
      expect(cats.length, 1);
      expect(cats.first.id, 'OLD_CUSTOM_1');
      expect(cats.first.name, 'Electricity');
      expect(cats.first.emoji, '⚡');
      expect(cats.first.scope, TagScope.debit); // Safely defaults to debit

      final txns = await repo.loadTransactions();
      expect(txns.length, 2);
      expect(txns[0].note, 'Power Bill');
      expect(txns[0].isCredit, false);
      expect(txns[0].tag, 'OLD_CUSTOM_1');
      expect(txns[1].note, 'Salary Deposit');
      expect(txns[1].isCredit, true);
      expect(txns[1].tag, null);
    });

    test('v1.1.9 FlutterSecureStorage data restores completely and dual-writes to SharedPreferences', () async {
      FlutterSecureStorage.setMockInitialValues({
        'nummo_secure_transactions_v3': '[{"id":"v119-1","amount":999.0,"isCredit":false,"note":"Dinner","timestamp":"2026-08-20T20:00:00.000Z"}]',
        'nummo_secure_accent_preset': 'Coral Crimson',
        'nummo_secure_theme_mode': 'amoled',
        'nummo_secure_privacy_mode': 'true',
        'nummo_secure_pin_enabled': 'true',
        'nummo_secure_pin_hash': 'testhash',
        'nummo_secure_pin_salt': 'testsalt',
      });

      final repo = SecureStorageRepository();
      
      final txns = await repo.loadTransactions();
      expect(txns.length, 1);
      expect(txns.first.note, 'Dinner');
      expect(txns.first.amount, 999.0);

      final accent = await repo.loadAccentPreset();
      expect(accent, 'Coral Crimson');

      final theme = await repo.loadThemeMode();
      expect(theme, 'amoled');

      final privacy = await repo.loadPrivacyMode();
      expect(privacy, true);

      final pinEnabled = await repo.isPinEnabled();
      expect(pinEnabled, true);

      // Verify it was copied to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nummo_secure_accent_preset'), 'Coral Crimson');
      expect(prefs.getString('nummo_secure_theme_mode'), 'amoled');
      expect(prefs.getString('nummo_secure_privacy_mode'), 'true');
    });
  });
}
