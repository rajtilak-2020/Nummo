# Problem 005: Premature Auto-Lock When Using System FilePicker

- **Status**: Resolved
- **Date**: 2026-09
- **Affects**: `lib/core/security/app_lock_guard.dart`, `lib/main.dart`, `lib/features/export/export_dialog.dart`, `lib/features/settings/settings_screen.dart`

---

## 💥 Symptoms & Issue
When importing or exporting JSON backups, or exporting PDF/Excel statements, the app immediately locked and dismissed all open dialogs as soon as the user picked or saved a file in Android's system document picker.

---

## 🔍 Root Cause
1. **Lifecycle Transition**: Opening Android's system file picker (`DocumentsUI` / `DownloadProvider`) pauses Nummo's MainActivity, transitioning Flutter to `AppLifecycleState.paused`.
2. **Timing Race on Return**: When the user completed the picker action, the plugin's platform channel resolved the `FilePicker` future in Dart **before** or concurrently with Android's `onResume` callback.
3. **Guard Deactivation**: The `finally` block of `runWithPickerGuard` immediately set `_isPickerActive = false`. When `AppLifecycleState.resumed` fired, `!AppLockGuard.isPickerActive` was `true`.
4. **Auto-Lock Trigger**: Because `_pausedTime` was recorded during pause, the time difference exceeded `_autoLockDelaySeconds` (which is `0` when set to "Immediately"), causing `_dismissModalsAndLock()` to pop all dialogs and lock the screen.

---

## 🛠️ Solution & Fix
1. **Grace Period on Resume**: Enhanced `AppLockGuard` with a `shouldSuppressResumeLock` getter and a 4-second grace window (`_suppressResumeUntil`).
2. **Atomic Guard Counter**: Replaced boolean `_isPickerActive` with `_activeGuards` counter to safely handle nested guarded operations.
3. **Lifecycle Handler Update** (`main.dart`):
   - **On `paused`**: If `AppLockGuard.isPickerActive`, pause timestamps and lockouts are skipped.
   - **On `resumed`**: If `AppLockGuard.shouldSuppressResumeLock`, `_pausedTime` is cleared and auto-lock is bypassed. Open dialogs (such as import passphrase prompts and export toasts) remain visible.
4. **Guarded Operations**: Wrapped `downloadExportFile` in `_handleExportPayload` (`main.dart`) and statement exports in `ExportDialog`.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/003-pin-and-biometric-security-guard]]**
- **[[Progress/2026-09-session-log]]**
