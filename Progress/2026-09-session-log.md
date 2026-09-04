# Progress Log: September 2026

- **Timeframe**: September 2026
- **Milestones**: Android Home Screen Widgets, Large Dataset Export Scaling (Isolates), AppLockGuard Lifecycle Fix, iOS Safari Web Fixes & Responsive Hardening

---

## 📅 Session Entries

### Session: 2026-09-04 — System FilePicker Premature Auto-Lock Fix
- **Changed**:
  - Enhanced `AppLockGuard` (`lib/core/security/app_lock_guard.dart`) with `shouldSuppressResumeLock`, a 4-second resume grace period (`_suppressResumeUntil`), and an atomic counter `_activeGuards`.
  - Updated `didChangeAppLifecycleState` in `lib/main.dart` to bypass locking and clear pause timestamps on resume from guarded activities.
  - Wrapped `downloadExportFile` in `_handleExportPayload` (`lib/main.dart`) and statement exports in `ExportDialog` with `AppLockGuard.runWithPickerGuard`.
  - Added unit and widget tests covering picker pause and resume lifecycle transitions.
- **Why**: When users exported PDF/Excel statements or exported/imported JSON backups, returning from Android's system `FilePicker` activity triggered immediate auto-lock and dismissed open dialogs.
- **Affects**: `lib/core/security/app_lock_guard.dart`, `lib/main.dart`, `lib/features/export/export_dialog.dart`, `test/`.
- **Reference**: **[[Problems/005-system-file-picker-premature-auto-lock]]**.

### Session: 2026-09-04 — iOS Safari Input Auto-Zoom & Viewport W3C Fix
- **Changed**:
  - Injected 16px CSS font-size rules into `web/index.html` covering HTML form elements and Flutter Web editing hosts (`flt-text-editing-host input`, `flt-glass-pane input`).
  - Standardized `<meta name="viewport">` in `web/index.html` to `width=device-width, initial-scale=1.0, viewport-fit=cover`, removing `maximum-scale=1.0` and `user-scalable=no`.
  - Added visual viewport blur reset listener to restore page offset on keyboard dismissal.
  - Configured `ThemeData.textTheme.bodyLarge` fontSize to 16px in `tokens.dart` and `AddTransactionSheet`.
- **Why**: WebKit on iOS auto-zooms viewport on inputs $< 16\text{px}$. Previous attempts with `maximum-scale` triggered W3C / WCAG accessibility validation errors.
- **Affects**: `web/index.html`, `lib/design_system/tokens.dart`, `lib/features/ledger/add_transaction_sheet.dart`.
- **Reference**: **[[Problems/006-ios-safari-input-auto-zoom-viewport]]**.

### Session: 2026-09-04 — Large Dataset Export: Background Isolates & Unicode Sanitization
- **Changed**:
  - Offloaded PDF and Excel file generation to background worker isolates using Flutter `compute()` (`_generatePdfInternal`, `_generateExcelInternal`).
  - Added dynamic `maxPages: math.max(1000, (txns.length / 5).ceil() + 200)` to `pw.MultiPage`.
  - Sanitized financial text via `_sanitizePdfText()`: converted `₹` to `Rs. `, stripped unsupported Unicode/emojis for standard Type1 Helvetica fonts.
  - Added unit test suite for 1000+ transaction isolate exports.
- **Why**: Exporting large transaction datasets blocked the main thread (1688 frame drops, Android Signal 3 tombstone) and crashed with `TooManyPagesException`.
- **Affects**: `lib/features/export/export_service.dart`, `lib/features/export/export_dialog.dart`, `test/unit/export_large_dataset_test.dart`.
- **Reference**: **[[Problems/004-pdf-export-toomanypages-and-anr-lag]]**, **[[Decisions/007-isolate-background-export-processing]]**.

### Session: 2026-09-04 — Android Home Screen Widgets (2x1 & 4x2)
- **Changed**:
  - Implemented `CategoryBreakdownWidgetProvider.kt` and `WidgetConfigurationActivity.kt` supporting 2x1 and 4x2 home screen widgets.
  - Created `HomeWidgetService` (`lib/core/widgets/home_widget_service.dart`) to sync live spending balances, category breakdowns, and privacy masking.
  - Designed native XML drawables and layouts with AMOLED black, translucent obsidian, and card backgrounds.
- **Why**: Allowed users to view current month expense breakdowns and category targets directly from their Android launcher without launching the app.
- **Affects**: `android/app/src/main/kotlin/`, `android/app/src/main/res/`, `lib/core/widgets/`, `lib/main.dart`.
- **Reference**: **[[Decisions/006-android-homescreen-widgets-integration]]**.

### Session: 2026-09-04 — Responsive Overflows & Logs Screen Polish
- **Changed**:
  - Fixed RenderFlex overflows in Custom Color Studio (21px), PIN setup dialog (0.375px), and ExportDialog date picker grid (13px) on 320dp screens.
  - Removed category tags from individual transaction rows in `LedgerScreen`.
  - Added hardware-efficient horizontal marquee scrolling (`NummoMarqueeText`) for long transaction titles that pauses when off-screen.
  - Extracted `BudgetsScreen` and `CategoryTagsScreen` into dedicated settings views.
- **Why**: Ensured low-end and small-screen Android devices render without layout exceptions and polished transaction legibility.
- **Affects**: `lib/features/settings/`, `lib/features/ledger/`, `lib/design_system/components/`.
- **Reference**: **[[Problems/007-renderflex-overflows-narrow-screens]]**.

### 5. Home Active Budgets Card Pill Alignment
- **Date**: 2026-09-04
- **Author**: Assistant & Pair Programmer
- **Changed**:
  - Replaced rogue `Flexible` wrapper around the "amount left / over" pill in `HomeActiveBudgetsCard` with a responsive `ConstrainedBox(maxWidth: maxPillWidth)` and `FittedBox`.
  - Maintained `Expanded` exclusively on the budget info column, ensuring the pill is cleanly anchored flush against the right edge of the card across all screen sizes.
  - Sized `maxPillWidth` with `(constraints.maxWidth * 0.42).clamp(90.0, 160.0)` in a `LayoutBuilder` to prevent `RenderFlex` overflows when huge monetary values are displayed on 320dp narrow screens.
  - Added regression test `HomeActiveBudgetsCard aligns amount left pill to the far right edge of the card` in `test/widget/budget_targets_card_test.dart`.
- **Why**: The pill was floating inward towards the left/middle of the card due to 50/50 flex partitioning with `Flexible(fit: FlexFit.loose)`.
- **Affects**: `lib/features/ledger/home_swipe_view.dart`, `test/widget/budget_targets_card_test.dart`.
- **Reference**: **[[Problems/008-home-budget-pill-left-alignment]]**.

### 6. Android Release Build & Global JDK 17 Configuration
- **Date**: 2026-09-04
- **Author**: Assistant & Pair Programmer
- **Changed**:
  - Configured Flutter's global Android toolchain to OpenJDK 17 (`flutter config --jdk-dir="/usr/lib/jvm/java-17-openjdk"`), overriding the VS Code Pleiades extension JDK 26 default.
  - Removed fragile hardcoded `org.gradle.java.home` path from `android/gradle.properties`.
  - Verified clean release APK compilation (`flutter build apk --release` -> 63.3MB) and Web compilation (`flutter build web --release`).
- **Why**: Prevented `(Java home supplied is invalid)` Gradle failure when building across diverse environments and terminal shells.
- **Affects**: `android/gradle.properties`, Flutter SDK global config.
- **Reference**: **[[Problems/009-gradle-java-home-invalid-property]]**.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Problems/004-pdf-export-toomanypages-and-anr-lag]]**
- **[[Problems/005-system-file-picker-premature-auto-lock]]**
- **[[Problems/006-ios-safari-input-auto-zoom-viewport]]**
- **[[Problems/007-renderflex-overflows-narrow-screens]]**
- **[[Problems/008-home-budget-pill-left-alignment]]**
- **[[Problems/009-gradle-java-home-invalid-property]]**
- **[[Decisions/006-android-homescreen-widgets-integration]]**
- **[[Decisions/007-isolate-background-export-processing]]**
