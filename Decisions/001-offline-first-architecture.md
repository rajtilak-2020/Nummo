# Decision 001: Offline-First Architecture & Dual-Write Storage

- **Status**: Accepted & Implemented
- **Date**: 2026-08
- **Affects**: `lib/core/storage/`, `lib/models/`, `lib/main.dart`

---

## 🎯 Context & Rationale
Personal finance tracking requires maximum privacy, instantaneous launch speeds, and 100% offline availability without requiring user accounts or third-party servers.

## 🛠️ Decision
1. All user financial records, tags, budgets, and security settings are stored locally on device.
2. Data is managed via `SecureStorageRepository` using a **dual-write mechanism**:
   - Immediate in-memory RAM cache for 60/120fps synchronous access.
   - Persistent storage to `SharedPreferences` for standard fast access.
   - Encrypted storage to `FlutterSecureStorage` for sensitive credentials/keys.
3. Cross-device synchronization is supported via user-controlled, encrypted JSON backups (`BackupService`).

## ⚖️ Consequences & Trade-offs
- **Pros**: Zero backend server costs, complete user privacy, instantaneous startup, zero network failure states.
- **Cons**: Users must manually export/import backups to transfer data between devices.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Problems/001-android-secure-storage-caching]]**
- **[[Decisions/003-pin-and-biometric-security-guard]]**
