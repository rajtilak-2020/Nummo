# Nummo Codebase Context & Agent Instructions

This document provides context, design constraints, and technical specifications for AI agents developing or modifying the **Nummo** budget tracker.

---

## 1. Project Overview

- **Name**: Nummo
- **Description**: A single-screen, fully offline personal finance ledger that runs on Android and Web (Vercel static build).
- **Core Architecture**:
  - No backend, no authentication, 100% local persistence.
  - Data stored via `shared_preferences` as a serialized list of transaction JSON objects.
  - State management uses a single `StatefulWidget` (`HomeScreen`) in `lib/main.dart` with manual list sorting and chronological running-balance calculations.

---

## 2. Technical Stack & File Structure

- **Language**: Dart (Sound Null Safety)
- **Framework**: Flutter (targets Web and Android builds)
- **Key Files**:
  - `pubspec.yaml`: Registers dependencies (`shared_preferences`, `intl`, `fl_chart`) and asset pathways (`logo/nummo.svg`).
  - [lib/models.dart](file:///home/krajtilak/vscode/Nummo/lib/models.dart): Defines the `Transaction` class, tag helpers, serialization, and deserialization.
  - [lib/theme.dart](file:///home/krajtilak/vscode/Nummo/lib/theme.dart): Uber-grade design system, color tokens, theme mode controller, and accent preset swatches.
  - [lib/main.dart](file:///home/krajtilak/vscode/Nummo/lib/main.dart): Orchestrates state (add, delete, edit, recalculate) and renders the main ledger UI and PIN lock screen.
  - [lib/analytics.dart](file:///home/krajtilak/vscode/Nummo/lib/analytics.dart): Modern analytics dashboard, breakdown charts, category statistics, and timeline filter sheets.
  - [lib/calculator.dart](file:///home/krajtilak/vscode/Nummo/lib/calculator.dart): Integrated expense math calculator keyboard sheet.
  - [lib/settings.dart](file:///home/krajtilak/vscode/Nummo/lib/settings.dart): Settings management screen (Theme & Accent Presets, Category Tag management, Security, Reset data).

---

## 3. Data Model

```dart
class Transaction {
  final String id; // Timestamp-based string
  final double amount;
  final bool isCredit; // true = Credit (In), false = Debit (Out)
  final String note; // Default is 'Untitled' if empty
  final DateTime timestamp;
  double balanceAfter; // Calculated dynamically in chronological order
  final String? tag; // Category tag label (e.g. FOOD, SHOPPING)
}
```

---

## 4. Uber-Grade Modern Design System

Any modifications to the UI **must** adhere strictly to the following aesthetic rules:

1. **Backgrounds & Surfaces**:
   - Light Mode: Warm Slate `#F8F9FA` scaffold with crisp `#FFFFFF` surface cards and `#E2E8F0` soft borders.
   - Dark Mode: Rich Charcoal Obsidian `#0F1117` scaffold with elevated `#181A22` surface cards and `#262A36` borders. No pitch-black AMOLED `#000000` backgrounds.
2. **Rounded Geometry**:
   - Cards: `BorderRadius.circular(20)`
   - Buttons & Input Fields: `BorderRadius.circular(14)`
   - Bottom Sheets & Dialogs: `BorderRadius.vertical(top: Radius.circular(28))` / `BorderRadius.circular(24)`
   - Chips & Category Badges: `BorderRadius.circular(100)` full pills.
3. **Elevated Depth & Shadows**:
   - Subtle multi-layered micro-shadows (`BoxShadow` with 3-6% opacity) for smooth layer separation.
4. **Theme Presets & Color Tokens**:
   - `Uber Platinum` (Signature Sky Blue / Platinum Accent)
   - `Emerald Mint` (`#10B981`)
   - `Electric Cyan` (`#06B6D4`)
   - `Gold Amber` (`#F59E0B`)
   - `Coral Crimson` (`#F43F5E`)
   - `Royal Violet` (`#8B5CF6`)
   - `Custom` (User Accent Color Swatch)
5. **Credit & Debit System Tokens**:
   - Credit / Positive Entries: Vibrant Emerald Mint `#10B981` (10% alpha fill for pills/cards).
   - Debit / Negative Entries: Vivid Coral Crimson `#F43F5E` (10% alpha fill for pills/cards).
6. **Tactile Feedback & Animations**:
   - Crisp haptic responses (`HapticFeedback.lightImpact()`, `HapticFeedback.selectionClick()`, `HapticFeedback.heavyImpact()`).
   - Smooth 60/120fps curves (`Curves.easeOutCubic`) on state changes and bottom sheets.
7. **Typography**:
   - Clean sans-serif system font for UI titles, body text, buttons, and note labels.
   - Tabular Monospace (`fontFamily: 'monospace'`) for monetary displays (`₹`), balance totals, and timestamp values for numeric precision.
8. **Currency Symbol**: Use the Indian Rupee symbol `₹` for all monetary displays.

---

## 5. Key UI Workflows & Custom Components

### Log Separation & Grouping
The transaction log groups entries by date, generating section headers (e.g. `EEE, dd MMM yyyy`) and displaying rows under their respective date groups showing timestamp hour/minute (`hh:mm a`).

### Swipeable Actions (`SwipeableLogEntry`)
Horizontal drag listener slides the foreground card row to reveal smooth rounded action buttons beneath:
- **EDIT** (Primary Accent background, white text) - launches pre-populated bottom sheet.
- **DELETE** (Crimson background, white text) - opens delete confirmation modal.
- Swipe snaps open or closed based on a 140.0px threshold.

---

## 6. Build Targets & Release Commands

Ensure any code modifications compile successfully on both targets:

- **Web Release** (Vercel deployment):
  `flutter build web --release`
  Outputs compile directly to `build/web`. Logo icon assets override standard favicon files in the project.
- **Android APK**:
  `flutter build apk --release`
  Outputs compile to `build/app/outputs/flutter-apk/app-release.apk`.

---

## 7. Pre-Release Data Safety Audit

Before deploying any feature or version update, AI agents and developers must audit the codebase against the data safety protocol defined in [.agents/PRE_RELEASE_AUDIT.md](file:///home/krajtilak/vscode/Nummo/.agents/PRE_RELEASE_AUDIT.md) to ensure backward compatibility and zero data loss for existing users.
