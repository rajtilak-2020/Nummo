# Codebase Structure & File Map 🗺️

This document outlines the architecture, layer responsibilities, and directory structure of the **Nummo** repository.

---

## 🕸️ Interactive Subsystem Flowchart

```mermaid
flowchart TB
    %% Styling tokens
    classDef entry fill:#1e1e2e,stroke:#89b4fa,stroke-width:2px,color:#cdd6f4;
    classDef feature fill:#181825,stroke:#a6e3a1,stroke-width:1.5px,color:#cdd6f4;
    classDef core fill:#181825,stroke:#fab387,stroke-width:1.5px,color:#cdd6f4;
    classDef ui fill:#181825,stroke:#cba6f7,stroke-width:1.5px,color:#cdd6f4;
    classDef model fill:#181825,stroke:#f9e2af,stroke-width:1.5px,color:#cdd6f4;

    Main["🚀 lib/main.dart (Bootstrap & Routing)"]:::entry

    subgraph Features ["🎯 Features Layer (`lib/features/`)"]
        Ledger["📊 ledger/
(LedgerScreen, TransactionTile)"]:::feature
        Analytics["📈 analytics/
(AnalyticsScreen, FlChart)"]:::feature
        Calc["🔢 calculator/
(CalculatorSheet)"]:::feature
        Export["📁 export/
(ExportDialog, FileSavers)"]:::feature
        Settings["⚙️ settings/
(SettingsScreen)"]:::feature
        SecurityUI["🔒 security/
(LockScreen)"]:::feature
    end

    subgraph DesignSystem ["🎨 Design System (`lib/design_system/`)"]
        Tokens["💎 tokens.dart
(Obsidian #0F1117, Emerald/Coral)"]:::ui
        Components["🧩 components/
(NummoButton, NummoCard, NummoDialog)"]:::ui
    end

    subgraph CoreServices ["⚡ Core Layer (`lib/core/`)"]
        Storage["💾 storage/
(SecureStorageRepository, RAM Cache)"]:::core
        SecurityCore["🛡️ security/
(AppLockGuard, BiometricService)"]:::core
        Crypto["🔐 crypto/
(PinCrypto PBKDF2/SHA256)"]:::core
        Utils["🛠️ utils/
(MoneyFormatter ₹, Validators)"]:::core
    end

    subgraph DomainModels ["📦 Models (`lib/models/`)"]
        TxnModel["📝 transaction.dart
(Running Balance Math)"]:::model
        BudgetModel["🎯 budget.dart"]:::model
        CatModel["🏷️ category.dart"]:::model
    end

    %% Dependency flow
    Main --> Features
    Features --> DesignSystem
    Features --> DomainModels
    Features --> CoreServices
    CoreServices --> DomainModels
    DesignSystem --> Tokens
    SecurityUI --> SecurityCore
    SecurityCore --> Crypto
```

---

## 📂 Directory Layout

```
Nummo/
├── .agents/                   # AI agent instructions & pre-release audit rules
│   ├── AGENTS.md              # Core constraints & Uber-grade design principles
│   ├── PRE_RELEASE_AUDIT.md   # Zero-data-loss verification checklist
│   └── mcp_config.json        # MCP server tool connections
├── android/                   # Native Android host configuration
│   ├── app/
│   │   ├── build.gradle.kts   # App-level build config, signing & target SDKs
│   │   └── nummo-release.jks  # Production release keystore file
│   └── key.properties         # Local signing properties (ignored in public VCS)
├── lib/                       # Flutter source code
│   ├── main.dart              # App entrypoint, theme bootstrap, root router
│   ├── core/                  # Shared system-level services
│   │   ├── crypto/            # Cryptographic hashing & PIN security
│   │   ├── security/          # App lock lifecycle guard & biometric auth
│   │   ├── storage/           # Dual-write storage repository & encrypted backups
│   │   └── utils/             # Money formatting (₹) & input validators
│   ├── design_system/         # Reusable UI tokens & atomic components
│   │   ├── tokens.dart        # Obsidian colors, spacing, radii & typography
│   │   └── components/        # NummoButton, NummoCard, NummoDialog, NummoFab
│   ├── features/              # Feature domain modules
│   │   ├── analytics/         # Spending analytics & FlChart visualizations
│   │   ├── calculator/        # Inline expense math calculator sheet
│   │   ├── export/            # Multiplatform PDF, Excel & CSV export engine
│   │   ├── ledger/            # Main transaction ledger, swipe views & filters
│   │   ├── security/          # Lock screen & PIN verification dialogs
│   │   └── settings/          # Themes, categories, backups & preferences
│   └── models/                # Domain entities & serialization
│       ├── budget.dart        # Monthly budget targets & alerts
│       ├── category.dart      # Category tags, icons & color presets
│       └── transaction.dart   # Transaction entity & chronological running balance
├── logo/                      # Vector SVGs, raster PNGs & app icon generation
├── test/                      # Unit & widget test suites
│   ├── unit/                  # Unit tests for models, crypto, storage & filters
│   └── widget_test.dart       # Widget UI tests
├── web/                       # Web release assets, PWA manifest & favicon
├── pubspec.yaml               # Flutter dependencies & assets registry
├── vercel.json                # Vercel static build & header routing configuration
└── Home.md                    # Knowledge Vault Home Hub
```

---

## 🧩 Key Subsystems & Layers

### 1. Presentation & Design System (`lib/design_system/`)
- All surfaces use the tokens defined in `lib/design_system/tokens.dart` (Obsidian `#0F1117`, `#181A22` cards, Emerald Mint `#10B981` credits, Coral Crimson `#F43F5E` debits).
- See **[[Decisions/002-uber-grade-design-system]]**.

### 2. Core Storage & Caching (`lib/core/storage/`)
- Managed by `SecureStorageRepository`. Implements warm in-memory caching and dual-write persistence (`SharedPreferences` + `FlutterSecureStorage`).
- See **[[Decisions/001-offline-first-architecture]]** and **[[Problems/001-android-secure-storage-caching]]**.

### 3. Security & App Lock Guard (`lib/core/security/` & `lib/core/crypto/`)
- Handles PIN hashing with PBKDF2/SHA256, biometric authentication, and app backgrounding lock timer.
- See **[[Decisions/003-pin-and-biometric-security-guard]]**.

### 4. Cross-Platform Export Engine (`lib/features/export/`)
- Uses conditional imports (`file_saver_web.dart` vs `file_saver_io.dart`) to download files seamlessly across Web and Android.
- See **[[Decisions/004-export-multiplatform-strategy]]** and **[[Problems/002-web-export-blob-download-failure]]**.

---

## 🔗 Related Notes
- **[[Home]]** — Knowledge Vault Home
- **[[Reference/tech-stack-and-versions]]** — Package and tool versions
- **[[Reference/deployment-and-build-commands]]** — Build and execution scripts
