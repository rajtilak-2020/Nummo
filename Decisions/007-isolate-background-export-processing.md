# Decision 007: Isolate Background Export Processing

- **Status**: Accepted & Implemented
- **Date**: 2026-09
- **Affects**: `lib/features/export/export_service.dart`, `lib/features/export/export_dialog.dart`

---

## 🎯 Context & Rationale
Exporting thousands of financial records into PDF documents or Excel spreadsheets involves heavy CPU-bound tasks: cell layout calculation, table pagination, XML serialization, and file compression. Executing these operations on Flutter's main UI isolate causes severe frame drops, UI freezes, and OS-level ANR (Application Not Responding) terminations.

---

## 🛠️ Decision
1. All PDF and Excel byte-generation pipelines must execute in a background Dart isolate using Flutter's high-level `compute()` API:
   - `compute(_generatePdfInternal, params)` for PDF compilation.
   - `compute(_generateExcelInternal, params)` for Excel binary sheet generation.
2. The main thread only handles displaying the responsive progress spinner, passing immutable parameter structs (`_PdfExportParams`), and receiving the final byte array for file saving.
3. Keep isolate entry points top-level static functions with primitive/serializable data arguments.

---

## ⚖️ Consequences & Trade-offs
- **Pros**: UI remains fully responsive at 60/120fps during massive statement exports; zero ANR risk.
- **Cons**: Isolate communication requires serialization across memory boundaries; isolated functions cannot access Flutter UI context directly.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/004-export-multiplatform-strategy]]**
- **[[Problems/004-pdf-export-toomanypages-and-anr-lag]]**
- **[[Progress/2026-09-session-log]]**
