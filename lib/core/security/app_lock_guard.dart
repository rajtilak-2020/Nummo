/// System-wide manager to temporarily guard/suppress automatic app lock
/// while native system pickers (e.g. FilePicker), system save dialogs,
/// or external platform activities are active.
class AppLockGuard {
  static int _activeGuards = 0;
  static DateTime? _suppressResumeUntil;

  /// Indicates whether a native file picker or system activity is currently active.
  static bool get isPickerActive => _activeGuards > 0;

  /// Indicates whether auto-lock on app resume should currently be suppressed.
  /// Suppresses lock while a guarded action is active AND for a 4-second grace
  /// window after it returns to ensure Android resume lifecycle events do not trigger lock.
  static bool get shouldSuppressResumeLock {
    if (_activeGuards > 0) return true;
    if (_suppressResumeUntil != null && DateTime.now().isBefore(_suppressResumeUntil!)) {
      return true;
    }
    return false;
  }

  /// Updates the picker active state manually if needed.
  static void setPickerActive(bool active) {
    if (active) {
      _activeGuards = 1;
      _suppressResumeUntil = DateTime.now().add(const Duration(minutes: 30));
    } else {
      _activeGuards = 0;
      _suppressResumeUntil = DateTime.now().add(const Duration(seconds: 4));
    }
  }

  /// Explicitly resets all guard states (useful for test tearDown).
  static void reset() {
    _activeGuards = 0;
    _suppressResumeUntil = null;
  }

  /// Explicitly suppresses auto-lock on resume for a specific duration (default 4 seconds).
  static void suppressLockFor([Duration duration = const Duration(seconds: 4)]) {
    final target = DateTime.now().add(duration);
    if (_suppressResumeUntil == null || target.isAfter(_suppressResumeUntil!)) {
      _suppressResumeUntil = target;
    }
  }

  /// Runs an async [action] (such as opening a system file picker) while guarding
  /// against automatic app lock when the Flutter lifecycle moves to paused / resumed.
  static Future<T> runWithPickerGuard<T>(Future<T> Function() action) async {
    _activeGuards++;
    _suppressResumeUntil = DateTime.now().add(const Duration(minutes: 30));
    try {
      return await action();
    } finally {
      if (_activeGuards > 0) _activeGuards--;
      _suppressResumeUntil = DateTime.now().add(const Duration(seconds: 4));
    }
  }
}
