# Decision 004: Multiplatform Export Engine

- **Status**: Accepted & Implemented
- **Date**: 2026-08
- **Affects**: `lib/features/export/`

---

## 🎯 Context & Rationale
Nummo targets both Android APK and static Web (Vercel). Android handles file export via native filesystem and storage access framework (`dart:io`), while Web uses in-memory Blobs and browser anchor download dispatch. Direct usage of `dart:io` crashes Web release builds.

## 🛠️ Decision
Implemented conditional compilation via Dart export facades:
- `file_saver.dart`: Abstract interface.
- `file_saver_io.dart`: Mobile implementation using `file_picker` and native file streams.
- `file_saver_web.dart`: Web implementation converting bytes to `Blob`, creating Object URLs, and triggering programmatic `<a download>` click events.
- `file_saver_stub.dart`: Fallback stub for unsupported runtimes.

Supported formats: PDF statements (`pdf`), Excel workbooks (`excel`), and CSV spreadsheets (`csv`).

## ⚖️ Consequences & Trade-offs
- **Pros**: Single shared codebase compiles cleanly for both Android APK and Vercel Web release.
- **Cons**: Requires keeping conditional import signatures strictly in sync.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Problems/002-web-export-blob-download-failure]]**
