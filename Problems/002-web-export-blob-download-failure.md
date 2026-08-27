# Problem 002: Cross-Platform File Downloader Failure on Web vs Android

- **Status**: Resolved
- **Date**: 2026-08
- **Affects**: `lib/features/export/`

---

## 💥 Symptoms & Issue
Building and running the Web target (`flutter build web`) failed or threw runtime errors when exporting PDF, Excel, or CSV files due to unresolved `dart:io` references.

## 🔍 Root Cause
`dart:io` (`File`, `Directory`, `Platform`) is strictly a native mobile/desktop library and is unavailable in Web browsers. Web requires `dart:html` / `package:web` Blob URL creation and anchor click dispatch.

## 🛠️ Solution & Fix
1. Created conditional import facade in `lib/features/export/`:
   - `file_saver.dart` (exports conditional implementation)
   - `file_saver_web.dart` (uses HTML Blob and `window.URL.createObjectURL`)
   - `file_saver_io.dart` (uses `file_picker` and native file writing)
   - `file_saver_stub.dart` (default fallback)

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/004-export-multiplatform-strategy]]**
