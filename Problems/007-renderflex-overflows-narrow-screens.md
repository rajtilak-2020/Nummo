# Problem 007: RenderFlex Overflows on Narrow / Low-DPI Screens

- **Status**: Resolved
- **Date**: 2026-09
- **Affects**: `lib/features/settings/settings_screen.dart`, `lib/design_system/components/pin_setup_dialog.dart`, `lib/features/export/export_dialog.dart`

---

## 💥 Symptoms & Issue
On compact Android screens (320dp width, e.g. compact mode or high accessibility display zoom), Flutter threw multiple layout assertions:
1. `RenderFlex overflowed by 21 pixels on the right` in `SettingsScreen` (Custom Color Studio preset row).
2. `RenderFlex overflowed by 0.375 pixels on the right` in `PinSetupDialog` (Header row).
3. `RenderFlex overflowed by 13 pixels on the bottom` in `ExportDialog` (Date range selector grid).

---

## 🔍 Root Cause
1. **Unconstrained Row Children**: Fixed icon widths and horizontal margins inside `Row` widgets exceeded available viewport width without `Expanded` or `Flexible` wrappers.
2. **Sub-pixel Floating Point Inaccuracies**: Fractional border widths and padding sum exceeded parent constraints by fractions of a pixel on non-integer device pixel ratios.
3. **Fixed Grid Heights**: Grid items in dialogs relied on hardcoded aspect ratios that exceeded vertical bottom sheet constraints on small heights.

---

## 🛠️ Solution & Fix
1. **Adaptive Flex & Scrolling**:
   - Wrapped text labels in `Expanded(child: Text(..., overflow: TextOverflow.ellipsis))` across dialog headers.
   - Replaced rigid rows in `Custom Color Studio` with flexible horizontal scroll containers or wrapped layouts.
   - Made bottom sheets scrollable with `SingleChildScrollView` to accommodate keyboard insets and compact screen heights.
2. **Automated Regression Tests**:
   - Added `test/widget/custom_color_studio_overflow_test.dart` (320dp width check).
   - Added `test/widget/pin_dialog_overflow_test.dart` (320dp width check).
   - Added `test/widget/export_dialog_overflow_test.dart` (320dp width check).

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/002-uber-grade-design-system]]**
- **[[Progress/2026-09-session-log]]**
