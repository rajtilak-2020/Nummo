import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric authentication service wrapping local_auth with explicit security fallback.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) return false;

      final List<BiometricType> available = await _auth.getAvailableBiometrics();
      // Strictly exclude face unlock
      if (available.contains(BiometricType.face) && !available.contains(BiometricType.fingerprint)) {
        return false;
      }
      return available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong) ||
          (canCheck && !available.contains(BiometricType.face));
    } catch (_) {
      return false;
    }
  }

  /// Checks whether Fingerprint sensor is available on device. Excludes face unlock.
  Future<bool> isFingerprintAvailable() async {
    if (kIsWeb) return false;
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) return false;

      final List<BiometricType> available = await _auth.getAvailableBiometrics();
      // Exclude face unlock
      if (available.contains(BiometricType.face) && !available.contains(BiometricType.fingerprint)) {
        return false;
      }
      return available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong) ||
          canCheck;
    } catch (_) {
      return false;
    }
  }



  /// Authenticates using biometrics explicitly without failing silently over to device PIN/Pattern.
  Future<bool> authenticateBiometricOnly({required String reason}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Authenticates using biometrics with device credential fallback (Passcode/Pattern).
  Future<bool> authenticateWithDeviceFallback({required String reason}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
