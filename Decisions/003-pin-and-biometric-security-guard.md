# Decision 003: PIN Hashing & Biometric App Lock Guard

- **Status**: Accepted & Implemented
- **Date**: 2026-08
- **Affects**: `lib/core/security/`, `lib/core/crypto/`, `lib/features/security/`

---

## 🎯 Context & Rationale
Because Nummo holds private personal ledger data on the physical device, it must protect against unauthorized physical access when the device is unlocked or handed to others.

## 🛠️ Decision
1. **Cryptographic PIN Storage**: PINs are never stored in plaintext. They are salted and hashed using PBKDF2/SHA256 in `PinCrypto`.
2. **AppLockGuard Lifecycle**: An `AppLockGuard` listener monitors `AppLifecycleState.paused` and `AppLifecycleState.resumed` to lock the UI after a configured inactivity timeout.
3. **Biometric Support**: Uses `local_auth` (`BiometricService`) on Android with hardware-backed fallback to PIN.
4. **Brute Force Defense**: `LockoutManager` applies exponential backoff delays on consecutive failed PIN attempts.

## ⚖️ Consequences & Trade-offs
- **Pros**: High security grade without impacting everyday usability.
- **Cons**: PIN recovery requires knowing the master PIN or resetting app storage.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/001-offline-first-architecture]]**
