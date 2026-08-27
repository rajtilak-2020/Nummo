# Decision 005: Chronological Running Balance Computation

- **Status**: Accepted & Implemented
- **Date**: 2026-08
- **Affects**: `lib/models/transaction.dart`, `lib/features/ledger/`

---

## 🎯 Context & Rationale
Users frequently add or edit transactions backdated to earlier dates or times. If running balance (`balanceAfter`) is statically stored per transaction without dynamic re-computation, inserting a backdated transaction would invalidate all subsequent balance numbers.

## 🛠️ Decision
1. Transactions store their raw amount, credit/debit flag, timestamp, category, and note.
2. Whenever transactions are loaded, added, updated, or deleted, the full list is sorted in chronological ascending order (`timestamp.compareTo`).
3. Running balance is calculated iteratively:
   `balanceAfter = (previousBalance) + (isCredit ? amount : -amount)`
4. The list is then presented to the UI in reverse chronological order (newest first) grouped by date sections.

## ⚖️ Consequences & Trade-offs
- **Pros**: Guaranteed mathematical integrity across past edits and new entries.
- **Cons**: O(N log N) sort on mutation (negligible for tens of thousands of offline personal transactions).

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Decisions/001-offline-first-architecture]]**
