/// Tracks failed PIN attempts and enforces exponential backoff lockout.
class LockoutManager {
  static const int maxAllowedAttempts = 5;
  static const int baseLockoutSeconds = 30;

  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;

  int get failedAttempts => _failedAttempts;

  bool get isLockedOut {
    if (_lockoutEndTime == null) return false;
    final now = DateTime.now();
    if (now.isAfter(_lockoutEndTime!)) {
      _lockoutEndTime = null;
      return false;
    }
    return true;
  }

  int get remainingLockoutSeconds {
    if (_lockoutEndTime == null) return 0;
    final diff = _lockoutEndTime!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Records a failed attempt and sets a lockout timer if max attempts reached.
  void recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= maxAllowedAttempts) {
      final multiplier = (_failedAttempts - maxAllowedAttempts) + 1;
      final lockoutDuration = Duration(seconds: baseLockoutSeconds * multiplier);
      _lockoutEndTime = DateTime.now().add(lockoutDuration);
    }
  }

  /// Resets attempts counter on successful PIN verification.
  void resetAttempts() {
    _failedAttempts = 0;
    _lockoutEndTime = null;
  }
}
