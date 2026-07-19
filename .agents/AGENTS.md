# Vitta Codebase Context & Agent Instructions

This document provides context, design constraints, and technical specifications for AI agents developing or modifying the **Vitta** budget tracker.

---

## 1. Project Overview

- **Name**: Vitta
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
  - `pubspec.yaml`: Registers dependencies (`shared_preferences`, `intl`) and asset pathways (`logo/vitta.png`).
  - [lib/models.dart](file:///c:/Users/K%20Rajtilak/Documents/VScode/Vitta/vitta/lib/models.dart): Defines the `Transaction` class, serialization, and deserialization.
  - [lib/main.dart](file:///c:/Users/K%20Rajtilak/Documents/VScode/Vitta/vitta/lib/main.dart): Orchestrates state (add, delete, edit, recalculate) and renders the UI.
  - [LICENSE](file:///c:/Users/K%20Rajtilak/Documents/VScode/Vitta/vitta/LICENSE): Shared Source / Contribution-Only proprietary license.

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
}
```

---

## 4. Brutalist Design System (Non-Negotiable Rules)

Any modifications to the UI **must** adhere strictly to the following aesthetic rules:

1. **Backgrounds**: Pure black `#000000` only. No gradients or off-black surfaces.
2. **Sharp Corners**: Perfect 90-degree angles on all widgets. Set `BorderRadius.zero` everywhere (inputs, bottom sheets, dialogs, buttons).
3. **No Shadows**: Disable drop shadows, elevations, or blur effects. Use solid 1-2px white/grey borders for depth instead.
4. **Color Tokens**:
   - Background: `#000000` (black)
   - Credit / positive entries: `#00FF66` (saturated green)
   - Debit / negative entries: `#FF1E1E` (saturated red)
   - Secondary lines / borders / dividers: `#808080` (mid grey)
   - Primary text: `#FFFFFF` (white)
   - Muted text (times, labels): `#888888` / `#AAAAAA`
5. **No Soft Ripple Effects**: Avoid default Material Ink splash ripples. Use `GestureDetector` or disable splash factory options (`NoSplash.splashFactory`) for crisp, instant tap responses.
6. **Typography**: Monospace (`fontFamily: 'monospace'`) for all numeric values, ledger balances, transaction amounts, and date headers to emphasize the ledger feel. Regular sans-serif font for note text and labels is permitted.
7. **Currency Symbol**: Use the Indian Rupee symbol `₹` for all monetary displays.

---

## 5. Key UI Workflows & Custom Components

### Log Separation & Grouping
The transaction log groups entries by date. The build method groups chronological items, generating section headers (e.g. `// JULY 19, 2026` in monospace format) and displaying rows under their respective date groups showing only their timestamp hour/minute (`HH:mm`).

### Swipeable Actions (`SwipeableLogEntry`)
Instead of standard swipe dismissals, a custom horizontal drag listener slides the foreground row to reveal buttons beneath:
- **EDIT** (Dark grey background, white text) - launches pre-populated bottom sheet.
- **DELETE** (Red background, white text) - opens delete confirmation modal.
- Swipe snaps open or closed based on a 140.0px threshold (70px per action button).

---

## 6. Build Targets & Release Commands

Ensure any code modifications compile successfully on both targets:

- **Web Release** (Vercel deployment):
  `flutter build web --release`
  Outputs compile directly to `build/web`. Logo icon assets override standard favicon files in the project.
- **Android APK**:
  `flutter build apk --release`
  Outputs compile to `build/app/outputs/flutter-apk/app-release.apk`.
