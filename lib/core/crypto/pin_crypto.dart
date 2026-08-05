import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Cryptographic helper for PIN hashing using salted PBKDF2 / HMAC-SHA256.
class PinCrypto {
  static const int iterations = 10000;
  static const int saltLengthBytes = 16;

  /// Generates a cryptographically random salt string.
  static String generateSalt() {
    final Random random = Random.secure();
    final List<int> values = List<int>.generate(saltLengthBytes, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Hashes the input PIN with salt using iterated HMAC-SHA256.
  static String hashPin(String pin, String salt) {
    List<int> bytes = utf8.encode('$pin:$salt');
    Hmac hmac = Hmac(sha256, utf8.encode(salt));
    for (int i = 0; i < iterations; i++) {
      bytes = hmac.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }

  /// Verifies an input PIN against a stored salted hash.
  static bool verifyPin(String inputPin, String storedHash, String salt) {
    if (storedHash.isEmpty || salt.isEmpty) return false;
    final computedHash = hashPin(inputPin, salt);
    return _constantTimeCompare(computedHash, storedHash);
  }

  /// Constant-time string comparison to prevent timing attacks.
  static bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
