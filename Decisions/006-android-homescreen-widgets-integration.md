# Decision 006: Android Home Screen Interactive Widgets

- **Status**: Accepted & Implemented
- **Date**: 2026-09
- **Affects**: `android/app/src/main/kotlin/`, `android/app/src/main/res/`, `lib/core/widgets/`, `lib/main.dart`

---

## 🎯 Context & Rationale
Users need immediate glanceable awareness of their current monthly financial health (total expense, credit, remaining balance, and top category breakdown) directly on their Android launcher home screen without having to unlock and open the full app.

---

## 🛠️ Decision
1. Implement native Android AppWidgets using the `home_widget` Flutter plugin bridge:
   - **2x1 Compact Widget**: Shows current period title, total expense balance, and masked privacy state.
   - **4x2 Detailed Widget**: Shows full category donut breakdown, category ranking list with percentage bars, and quick action launcher.
2. Maintain design system alignment:
   - Provide custom theme configurations: Super AMOLED Black, Translucent Obsidian, and Surface Card styles.
3. Decoupled update triggers:
   - `HomeWidgetService.updateCategoryBreakdownWidget()` is called proactively on any transaction add, update, delete, category mutation, or currency change.
   - Data is stored in secure app group shared preferences for instant RemoteViews rendering by Android's widget host.

---

## ⚖️ Consequences & Trade-offs
- **Pros**: Instant glanceability, zero cold-app launch requirement, dynamic live updates on financial mutations.
- **Cons**: Requires Android-specific XML layouts, drawables, and Kotlin AppWidgetProvider implementations.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/001-offline-first-architecture]]**
- **[[Decisions/002-uber-grade-design-system]]**
- **[[Progress/2026-09-session-log]]**
