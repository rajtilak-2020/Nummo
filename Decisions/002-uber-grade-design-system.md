# Decision 002: Uber-Grade Modern Design System & Tokenization

- **Status**: Accepted & Implemented
- **Date**: 2026-08
- **Affects**: `lib/design_system/`, `lib/features/`

---

## 🎯 Context & Rationale
Finance apps require clear visual hierarchy, high contrast in low-light environments, and strong tactile feedback to minimize user input errors and fatigue.

## 🛠️ Decision
Established a rigid design system in `lib/design_system/tokens.dart`:
1. **Surfaces**: Obsidian `#0F1117` scaffold, `#181A22` elevated surface cards, `#262A36` subtle borders (no pitch-black AMOLED `#000000` scaffolds, except optional user theme overrides).
2. **Geometry**: 20px card border radius, 14px button/input radius, 28px bottom sheet radius, pill category chips (`Radius.circular(100)`).
3. **Monetary Semantics**: Emerald Mint `#10B981` (10% alpha container) for Credits (+), Coral Crimson `#F43F5E` (10% alpha container) for Debits (-).
4. **Typography**: Clean sans-serif system font for titles/body; tabular monospace font for currency amounts (`₹`) and timestamps.
5. **Haptics**: `HapticFeedback.lightImpact()` on navigation, `selectionClick()` on toggles, `heavyImpact()` on deletions.

## ⚖️ Consequences & Trade-offs
- **Pros**: Premium, coherent look-and-feel across all screens; high readability of numeric data.
- **Cons**: All new UI additions must strictly adopt tokenized components rather than ad-hoc Material defaults.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Reference/tech-stack-and-versions]]**
