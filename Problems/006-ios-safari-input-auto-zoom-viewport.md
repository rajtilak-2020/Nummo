# Problem 006: iOS Safari Input Auto-Zoom & Viewport Validation

- **Status**: Resolved
- **Date**: 2026-09
- **Affects**: `web/index.html`, `lib/design_system/tokens.dart`, `lib/features/ledger/add_transaction_sheet.dart`

---

## 💥 Symptoms & Issue
1. On iOS Safari (Web version), tapping any text field or amount input caused Safari to automatically zoom the page in. Dismissing the keyboard or blurring the field left the screen permanently zoomed in and displaced.
2. Adding `maximum-scale=1.0` and `user-scalable=no` to the viewport meta tag triggered W3C and WCAG 1.4.4 accessibility validator errors: `The 'viewport' meta element 'content' attribute value should not contain 'maximum-scale'`.

---

## 🔍 Root Cause
1. **WebKit 16px Heuristic**: Mobile Safari automatically zooms into any form input whose computed CSS `font-size` is strictly less than `16px`. Flutter Web generates off-screen HTML `<input>` elements inside `<flt-text-editing-host>` and `<flt-glass-pane>` that defaulted below 16px.
2. **WCAG Standards**: Restricting user scalability (`maximum-scale`, `user-scalable=no`) violates modern HTML accessibility rules and is intentionally ignored or flagged as an error by browser engines and linters.

---

## 🛠️ Solution & Fix
1. **Global 16px CSS Override** (`web/index.html`):
   ```css
   input, textarea, select, [contenteditable],
   flt-text-editing-host input, flt-text-editing-host textarea,
   flt-glass-pane input, flt-glass-pane textarea {
     font-size: 16px !important;
   }
   ```
2. **Compliant Viewport Meta Tag**:
   ```html
   <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
   ```
   Removed `maximum-scale` and `user-scalable=no` to comply fully with W3C / WCAG guidelines while keeping notch/safe-area support.
3. **Blur Reset Listener**:
   Added a window `blur` event listener to reset `window.scrollTo(0, 0)` whenever an input element loses focus.
4. **Flutter Theme Baseline**: Set `ThemeData.textTheme.bodyLarge` to 16px in `tokens.dart` and styled `AddTransactionSheet` notes with 16px.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/002-uber-grade-design-system]]**
- **[[Progress/2026-09-session-log]]**
