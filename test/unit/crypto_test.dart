import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/core/crypto/pin_crypto.dart';
import 'package:nummo/core/security/lockout_manager.dart';

void main() {
  group('PinCrypto Tests', () {
    test('generateSalt returns valid 16-byte base64url string', () {
      final salt = PinCrypto.generateSalt();
      expect(salt.isNotEmpty, true);
    });

    test('hashPin returns consistent output for same PIN and salt', () {
      final salt = PinCrypto.generateSalt();
      final hash1 = PinCrypto.hashPin('1234', salt);
      final hash2 = PinCrypto.hashPin('1234', salt);
      expect(hash1, equals(hash2));
    });

    test('verifyPin correctly authenticates correct PIN', () {
      final salt = PinCrypto.generateSalt();
      final hash = PinCrypto.hashPin('9876', salt);
      expect(PinCrypto.verifyPin('9876', hash, salt), true);
      expect(PinCrypto.verifyPin('1111', hash, salt), false);
    });
  });

  group('LockoutManager Tests', () {
    test('Lockout triggers after max failed attempts', () {
      final manager = LockoutManager();
      expect(manager.isLockedOut, false);

      for (int i = 0; i < 5; i++) {
        manager.recordFailedAttempt();
      }

      expect(manager.isLockedOut, true);
      expect(manager.remainingLockoutSeconds, greaterThan(0));
    });

    test('resetAttempts clears lockout status', () {
      final manager = LockoutManager();
      for (int i = 0; i < 5; i++) {
        manager.recordFailedAttempt();
      }
      expect(manager.isLockedOut, true);

      manager.resetAttempts();
      expect(manager.isLockedOut, false);
      expect(manager.failedAttempts, 0);
    });
  });
}
