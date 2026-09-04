# Nummo Knowledge Vault 🧭

Welcome to the central knowledge system for **Nummo** — a high-performance, offline-first personal finance ledger built with Flutter for Android and Web.

---

## 🕸️ Interactive Knowledge Graph

```mermaid
graph TD
    %% Styling tokens
    classDef hub fill:#1e1e2e,stroke:#89b4fa,stroke-width:3px,color:#ffffff;
    classDef struct fill:#181825,stroke:#cba6f7,stroke-width:2px,color:#cdd6f4;
    classDef decision fill:#181825,stroke:#a6e3a1,stroke-width:2px,color:#cdd6f4;
    classDef problem fill:#181825,stroke:#f38ba8,stroke-width:2px,color:#cdd6f4;
    classDef progress fill:#181825,stroke:#fab387,stroke-width:2px,color:#cdd6f4;
    classDef ref fill:#181825,stroke:#f9e2af,stroke-width:2px,color:#cdd6f4;

    Home["🧭 Home Vault Hub"]:::hub
    Structure["🗺️ [[Structure]]"]:::struct

    subgraph Decisions ["🧠 Architectural Decisions"]
        D1["[[Decisions/001-offline-first-architecture|001: Offline Storage & RAM Cache]]"]:::decision
        D2["[[Decisions/002-uber-grade-design-system|002: Uber Design System]]"]:::decision
        D3["[[Decisions/003-pin-and-biometric-security-guard|003: PIN Crypto & Lock Guard]]"]:::decision
        D4["[[Decisions/004-export-multiplatform-strategy|004: Multiplatform Export]]"]:::decision
        D5["[[Decisions/005-chronological-running-balance|005: Running Balance Engine]]"]:::decision
        D6["[[Decisions/006-android-homescreen-widgets-integration|006: Android Home Widgets]]"]:::decision
        D7["[[Decisions/007-isolate-background-export-processing|007: Isolate Background Export]]"]:::decision
    end

    subgraph Problems ["🛠️ Problems & Bug Solves"]
        P1["[[Problems/001-android-secure-storage-caching|001: Android Keystore Startup Lag]]"]:::problem
        P2["[[Problems/002-web-export-blob-download-failure|002: Web Blob Export Crash]]"]:::problem
        P3["[[Problems/003-json-trailing-comma-config-syntax-error|003: JSON Trailing Comma Error]]"]:::problem
        P4["[[Problems/004-pdf-export-toomanypages-and-anr-lag|004: PDF TooManyPages & ANR]]"]:::problem
        P5["[[Problems/005-system-file-picker-premature-auto-lock|005: FilePicker Auto-Lock Race]]"]:::problem
        P6["[[Problems/006-ios-safari-input-auto-zoom-viewport|006: iOS Safari Auto-Zoom]]"]:::problem
        P7["[[Problems/007-renderflex-overflows-narrow-screens|007: RenderFlex Overflows]]"]:::problem
    end

    subgraph Progress ["📈 Progress Logs"]
        PR1["[[Progress/2026-08-session-log|2026-08: v1.2.0 & Storage Refactor]]"]:::progress
        PR2["[[Progress/2026-09-session-log|2026-09: Widgets, Isolates & Web Fixes]]"]:::progress
    end

    subgraph Reference ["📚 Reference & Configs"]
        R1["[[Reference/tech-stack-and-versions|Tech Stack & Dependencies]]"]:::ref
        R2["[[Reference/credentials-and-keystore-locations|Keystore & Key Locations]]"]:::ref
        R3["[[Reference/deployment-and-build-commands|Build & Release Commands]]"]:::ref
        R4["[[Reference/external-links-and-resources|External Links & Assets]]"]:::ref
    end

    %% Central connections
    Home --> Structure
    Home --> Decisions
    Home --> Problems
    Home --> Progress
    Home --> Reference

    %% Inter-note knowledge relationships
    P1 -.->|Resolved by| D1
    P2 -.->|Resolved by| D4
    P3 -.->|Logged in| PR1
    P4 -.->|Resolved by| D7
    P5 -.->|Resolved by| D3
    P6 -.->|Logged in| PR2
    P7 -.->|Logged in| PR2
    D1 -.->|Used in| Structure
    D2 -.->|Applied to| Structure
    D3 -.->|Protects| D1
    D5 -.->|Calculated in| Structure
    D6 -.->|Exposes data to| Structure
    D7 -.->|Powers export in| D4
    R3 -.->|Builds| Structure
```

---

## 🗺️ Navigation Index

### 1. 🏗️ Architecture & Structure
- **[[Structure]]** — Full structural map of codebase files, module layers, and architectural responsibilities.

### 2. 🧠 Architecture & Design Decisions (`Decisions/`)
- **[[Decisions/001-offline-first-architecture|001: Offline-First Architecture & Dual-Write Storage]]** — Zero-backend local persistence with RAM caching + encrypted storage.
- **[[Decisions/002-uber-grade-design-system|002: Uber-Grade Modern Design System & Tokenization]]** — Obsidian surfaces, haptics, rounded geometry, and monospace tabular currency.
- **[[Decisions/003-pin-and-biometric-security-guard|003: PIN Hashing & Biometric App Lock Guard]]** — Cryptographic PIN security, `local_auth`, and lifecycle lockout enforcement.
- **[[Decisions/004-export-multiplatform-strategy|004: Multiplatform Export Engine]]** — Conditional import abstraction supporting PDF, Excel, and CSV across Web & Android.
- **[[Decisions/005-chronological-running-balance|005: Chronological Running Balance Computation]]** — Dynamic recalculation engine for transaction consistency.
- **[[Decisions/006-android-homescreen-widgets-integration|006: Android Home Screen Interactive Widgets]]** — Native 2x1 and 4x2 AppWidgets syncing real-time category breakdowns and balances.
- **[[Decisions/007-isolate-background-export-processing|007: Isolate Background Export Processing]]** — Offloading heavy PDF & Excel compilation to background worker isolates.

---

### 3. 📈 Development Progress (`Progress/`)
- **[[Progress/2026-09-session-log|2026-09: Android Widgets, Isolate Exports, AppLockGuard Fix & Web Polish]]** — Current sprint milestone log detailing Android AppWidgets, background isolate exports, FilePicker lock lifecycle fix, and Safari 16px zoom fix.
- **[[Progress/2026-08-session-log|2026-08: Dual-Write Secure Storage, V1.2.0 Release & Global Tooling Setup]]** — V1.2.0 release milestones, storage optimizations, and VS Code user environment setup.

---

### 4. 🛠️ Troubleshooting & Issue Log (`Problems/`)
- **[[Problems/001-android-secure-storage-caching|001: Android EncryptedSharedPreferences Cold Startup Lag]]** — Resolved Keystore latency with in-memory dual-write RAM caching.
- **[[Problems/002-web-export-blob-download-failure|002: Cross-Platform File Downloader Failure on Web vs Android]]** — Resolved `dart:io` Web crashes with conditional browser Blob downloads.
- **[[Problems/003-json-trailing-comma-config-syntax-error|003: VS Code User Settings JSON Trailing Comma Error]]** — Fixed syntax validation breakage in global settings.
- **[[Problems/004-pdf-export-toomanypages-and-anr-lag|004: PDF Export TooManyPagesException & Main Thread ANR Lag]]** — Resolved 1688 frame drops and page limits with isolates and dynamic pagination.
- **[[Problems/005-system-file-picker-premature-auto-lock|005: Premature Auto-Lock When Using System FilePicker]]** — Resolved premature locking upon returning from Android document picker.
- **[[Problems/006-ios-safari-input-auto-zoom-viewport|006: iOS Safari Input Auto-Zoom & Viewport Validation]]** — Resolved WebKit auto-zoom with 16px CSS overrides and W3C compliant viewport.
- **[[Problems/007-renderflex-overflows-narrow-screens|007: RenderFlex Overflows on Narrow / Low-DPI Screens]]** — Fixed 320dp width layout overflows across settings and dialogs.

---

### 5. 📚 Quick Reference & Ops (`Reference/`)
- **[[Reference/tech-stack-and-versions|Tech Stack & Dependency Matrix]]** — SDKs, plugins, and package versions.
- **[[Reference/credentials-and-keystore-locations|Keystore & Key Locations]]** — Paths to release keystores and config files (no secrets).
- **[[Reference/deployment-and-build-commands|Build & Release Commands]]** — Web, APK, and testing CLI recipes.
- **[[Reference/external-links-and-resources|External Links & Documentation]]** — Repository URLs, deployment targets, and assets.
