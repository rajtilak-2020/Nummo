/// System-wide manager to temporarily guard/suppress automatic app lock
/// while native system pickers (e.g. FilePicker) or native system dialogs are active.
class AppLockGuard {
  static bool _isPickerActive = false;

  /// Indicates whether a native file picker or system activity is currently active.
  static bool get isPickerActive => _isPickerActive;

  /// Updates the picker active state manually if needed.
  static void setPickerActive(bool active) {
    _isPickerActive = active;
  }

  /// Runs an async [action] (such as opening a system file picker) while guarding
  /// against automatic app lock when the Flutter lifecycle moves to paused.
  static Future<T> runWithPickerGuard<T>(Future<T> Function() action) async {
    _isPickerActive = true;
    try {
      return await action();
    } finally {
      _isPickerActive = false;
    }
  }
}
