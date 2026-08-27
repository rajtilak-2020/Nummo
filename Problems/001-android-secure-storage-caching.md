# Problem 001: Android EncryptedSharedPreferences Cold Startup Lag

- **Status**: Resolved
- **Date**: 2026-08
- **Affects**: `lib/core/storage/secure_storage_repository.dart`, `lib/main.dart`

---

## 💥 Symptoms & Issue
On Android devices, reading encrypted transactions and configuration keys via `flutter_secure_storage` during application launch caused a noticeable UI stutter (50-200ms) on cold starts.

## 🔍 Root Cause
`flutter_secure_storage` interacts with the Android Keystore and `EncryptedSharedPreferences` via asynchronous platform channels. Repeated individual reads for ledger items incurred platform channel IPC serialization and hardware cryptographic decryption overhead.

## 🛠️ Solution & Fix
1. Introduced an in-memory RAM cache layer in `SecureStorageRepository`.
2. On app startup, data is hydrated once into memory during a lightweight splash screen (`lib/main.dart`).
3. Subsequent ledger reads are served synchronously from memory. Writes update the RAM cache immediately and flush asynchronously to persistent storage.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/001-offline-first-architecture]]**
