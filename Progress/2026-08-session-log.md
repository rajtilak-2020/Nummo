# Progress Log: August 2026

- **Timeframe**: August 2026
- **Milestones**: Releases v1.1.8, v1.1.9, v1.2.0, Storage Optimization & Environment Setup

---

## 📅 Session Entries

### Session: 2026-08-27 — Global VS Code Tooling & Obsidian Knowledge Vault
- **Changed**:
  - Configured global VS Code User settings (`~/.config/Code/User/settings.json`) with OLED pure black theme customizations, global file watcher exclusions, project spell check dictionary words, and disabled heavy Java auto-builds.
  - Resolved trailing comma syntax error in user `settings.json`.
  - Built Obsidian-style project knowledge vault (`Home.md`, `Structure.md`, `Decisions/`, `Progress/`, `Problems/`, `Reference/`).
- **Why**: Prevented repetitive manual configuration across `/home/krajtilak/Documents/VScode` projects and provided instant contextual onboarding for developers and AI agents.
- **Affects**: Workspace developer environment, project documentation.

### Session: 2026-08-24 — Dual-Write Secure Storage & Startup Splash
- **Changed**:
  - Enhanced `SecureStorageRepository` with warm in-memory RAM cache and asynchronous dual-write persistence.
  - Added splash screen initialization phase during early storage hydration in `main.dart`.
- **Why**: Eliminated cold-start Android Keystore latency and prevented ledger UI frame drops.
- **Affects**: `lib/core/storage/secure_storage_repository.dart`, `lib/main.dart`.

### Session: 2026-08-22 — v1.2.0 Release: Unified Date Cards & Privacy Masking
- **Changed**:
  - Released `v1.2.0` (commit `f96030a`).
  - Added unified date card grouping, privacy masking toggle (eye icon to hide balances), undo snackbar toast, and optional transaction notes with category fallbacks.
- **Why**: Streamlined ledger log readability and added quick privacy protection in public environments.
- **Affects**: `lib/features/ledger/`, `lib/models/transaction.dart`.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/001-offline-first-architecture]]**
- **[[Problems/003-json-trailing-comma-config-syntax-error]]**
