# 008: Home Active Budgets Amount Left Pill Shifted Left

---

- **Status**: ✅ Resolved
- **Date**: 2026-09-04
- **Severity**: Low (Visual UI / Layout Alignment)
- **Component**: `lib/features/ledger/home_swipe_view.dart` (`HomeActiveBudgetsCard`)
- **Tags**: #ui #layout #flexbox #flutter #budgets #responsiveness

---

## 🔍 Symptom & User Report
In the home screen ledger view, inside the **Active Budgets** card (`HomeActiveBudgetsCard`), the amount left pill badge (e.g. `₹3,800 left` or `+₹500 over`) appeared noticeably shifted towards the left/center of the card instead of anchoring firmly flush against the right edge of the card.

---

## 🔬 Root Cause Analysis
In `lib/features/ledger/home_swipe_view.dart`, the top row of each active budget item was constructed as follows:

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Container(width: 32, height: 32, ...), // Category/overall emoji
    const SizedBox(width: 10),
    Expanded( // flex: 1, tight
      child: Column(...),
    ),
    const SizedBox(width: 8),
    Flexible( // flex: 1, loose
      child: Container(...), // Amount Left pill
    ),
  ],
)
```

### The Flex Split Issue:
1. `Expanded` has `flex: 1` and `fit: FlexFit.tight`.
2. `Flexible` defaults to `flex: 1` and `fit: FlexFit.loose`.
3. In Flutter's `RenderFlex.performLayout`, remaining space was divided equally (50% / 50%) between the `Expanded` column and the `Flexible` pill.
4. Because the pill had `fit: FlexFit.loose`, it only consumed its intrinsic width (e.g. ~75px) within its 50% allocation (e.g. ~150px).
5. With the default `MainAxisAlignment.start`, the pill was rendered at the start of its 50% slot, leaving the remaining ~75px completely blank on the far right edge of the card.
6. This caused the pill to look detached and pushed inward toward the center.

---

## 🛠️ Solution & Architecture
1. **Removed `Flexible` from the Pill**:
   - Replaced `Flexible` with a `ConstrainedBox(constraints: BoxConstraints(maxWidth: maxPillWidth))` directly in the `Row`.
   - `Expanded` on the middle column is now the **only** flex widget in the `Row`, causing it to consume 100% of all available remaining space.
   - This pushes the amount left pill flush against the card's right boundary.

2. **Responsive Scaling with `ConstrainedBox` & `FittedBox`**:
   - On low-DPI narrow screens (320dp width) with huge numbers (e.g., `₹15,00,00,000.00 left`), an unconstrained pill could consume too much space and cause horizontal `RenderFlex` overflows.
   - Sized `maxPillWidth` dynamically using `(constraints.maxWidth * 0.42).clamp(90.0, 160.0)` inside a `LayoutBuilder`.
   - Retained `FittedBox(fit: BoxFit.scaleDown)` inside the pill so giant numbers scale down smoothly without overflow, while standard amounts retain their exact natural font size.

3. **Ellipsis on Cycle Date Text**:
   - Added `maxLines: 1, overflow: TextOverflow.ellipsis` to the cycle dates subtitle inside the title column to prevent vertical wrapping on compact screen widths.

4. **Regression Automated Test**:
   - Added `testWidgets('HomeActiveBudgetsCard aligns amount left pill to the far right edge of the card')` in `test/widget/budget_targets_card_test.dart` verifying that `tester.getTopRight(pillFinder).dx` sits on the far right (> 325dp on 390dp screen) and aligns within `< 15dp` with the percentage text and header badge.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Progress/2026-09-session-log]]**
- **[[Problems/007-renderflex-overflows-narrow-screens]]**
- **[[Decisions/002-uber-grade-design-system]]**
