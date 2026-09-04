# Problem 004: PDF Export TooManyPagesException & Main Thread ANR Lag

- **Status**: Resolved
- **Date**: 2026-09
- **Affects**: `lib/features/export/export_service.dart`, `lib/features/export/export_dialog.dart`

---

## 💥 Symptoms & Issue
1. When exporting statements with thousands of transactions, users encountered `TooManyPagesException` from the `pdf` package.
2. The UI thread froze completely for several seconds, dropping 1688+ frames and triggering Android Signal 3 (ANR tombstone) warnings.
3. Logcat reported: `Helvetica-Bold has no Unicode support` and `Helvetica has no Unicode support`.

---

## 🔍 Root Cause
1. **Thread Blocking**: PDF layout and Excel binary construction were executing synchronously on Flutter's main UI thread, starving the Choreographer of VSYNC ticks.
2. **Default Page Cap**: `pw.MultiPage` in the `pdf` package defaults to a safety limit of 100 pages to avoid infinite layout loops. Datasets with > 500 transactions exceeded this cap.
3. **Font Limitations**: Standard PDF Type1 Helvetica fonts do not support multi-byte Unicode glyphs like the Indian Rupee symbol `₹` or user-entered emojis in transaction notes.

---

## 🛠️ Solution & Fix
1. **Background Worker Isolates**: Refactored `ExportService.exportPdf` and `ExportService.exportExcel` to execute via Flutter's `compute(_generatePdfInternal, params)` and `compute(_generateExcelInternal, params)`. The main UI thread remains at 60/120fps with an active loading indicator.
2. **Dynamic Page Threshold**: Configured `maxPages: math.max(1000, (sortedTxns.length / 5).ceil() + 200)` to comfortably support large multidecade ledgers.
3. **Glyph & Currency Sanitization**: Implemented `_sanitizePdfText()` to automatically map `₹` to `Rs. `, normalize quotation marks and dashes, and filter non-Latin1 glyphs.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/004-export-multiplatform-strategy]]**
- **[[Decisions/007-isolate-background-export-processing]]**
- **[[Progress/2026-09-session-log]]**
