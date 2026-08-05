import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nummo/core/storage/secure_storage_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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
    });
  });
}
