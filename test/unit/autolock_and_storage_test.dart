import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nummo/core/storage/secure_storage_repository.dart';
import 'package:nummo/models/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageRepository Storage & Balance Recalculation Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('recalculateRunningBalances computes chronological balances and returns reversed list', () {
      final t1 = Transaction(
        id: '1',
        amount: 1000,
        isCredit: true,
        timestamp: DateTime(2026, 1, 1, 10, 0),
      );
      final t2 = Transaction(
        id: '2',
        amount: 300,
        isCredit: false,
        timestamp: DateTime(2026, 1, 1, 12, 0),
      );
      final t3 = Transaction(
        id: '3',
        amount: 200,
        isCredit: true,
        timestamp: DateTime(2026, 1, 1, 14, 0),
      );

      final result = SecureStorageRepository.recalculateRunningBalances([t3, t1, t2]);

      expect(result.length, 3);
      // Descending order (newest first)
      expect(result[0].id, '3');
      expect(result[0].balanceAfter, 900.0); // 1000 - 300 + 200

      expect(result[1].id, '2');
      expect(result[1].balanceAfter, 700.0); // 1000 - 300

      expect(result[2].id, '1');
      expect(result[2].balanceAfter, 1000.0); // 1000
    });

    test('loadCurrencyCode and saveCurrencyCode work with backward compatibility', () async {
      final repo = SecureStorageRepository();
      expect(await repo.loadCurrencyCode(), 'INR');

      await repo.saveCurrencyCode('USD');
      expect(await repo.loadCurrencyCode(), 'USD');
    });

    test('loadAutoLockDelay and saveAutoLockDelay default to 0 and persist', () async {
      final repo = SecureStorageRepository();
      expect(await repo.loadAutoLockDelay(), 0);

      await repo.saveAutoLockDelay(300);
      expect(await repo.loadAutoLockDelay(), 300);
    });

    test('prewarm and migration completion flag enables instantaneous RAM lookup on cold launch', () async {
      SharedPreferences.setMockInitialValues({
        'nummo_storage_migrated_v3': true,
        'nummo_secure_currency_code': 'EUR',
        'nummo_secure_accent_preset': 'Emerald Mint',
      });
      final prefs = await SharedPreferences.getInstance();
      SecureStorageRepository.prewarm(prefs);

      final repo = SecureStorageRepository();
      expect(await repo.loadCurrencyCode(), 'EUR');
      expect(await repo.loadAccentPreset(), 'Emerald Mint');
      expect(await repo.isPinEnabled(), false); // Missing key returns false immediately without KeyStore delay
    });
  });
}
