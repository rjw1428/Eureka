## 1. Atomic summary write helper (client)

- [x] 1.1 Add a single create-or-increment helper in `expense_stream_provider.dart` that writes a summary via `set(..., SetOptions(merge: true))` with `FieldValue.increment` for `count`/`total` plus `startDate`, `categoryId`, `lastUpdate`
- [x] 1.2 Route `addExpense` through the helper, removing the get → `set` → `update` sequence (kills the non-merge overwrite race)
- [x] 1.3 Route `addAmortizedExpense`'s first-month summary write through the helper

## 2. Fix category-change and decrement paths (client)

- [x] 2.1 In `updateExpense` same-month category change, decrement previous category (`count -1`, `total -prevAmount`) via the helper
- [x] 2.2 In `updateExpense` same-month category change, increment new category (`count +1`, `total +newAmount`, correct sign) via the helper, creating the summary if missing
- [x] 2.3 Keep the amount-only delta path (same category, changed amount) updating `total` only, leaving `count` unchanged
- [x] 2.4 Route `removeExpense` decrement through the helper so a missing summary no longer throws or aborts the raw-doc delete
- [x] 2.5 Route the cross-month `updateExpense` (remove + add) through the corrected paths

## 3. Fix amortized Cloud Functions (`firebase/functions/index.js`)

- [x] 3.1 Replace the get → `set` → `update` loop in `createAmortizedExpenses` with a single `set(..., {merge: true})` create-or-increment per month
- [x] 3.2 Make `deleteAmortizedSeries` tolerant of missing summaries (merge-increment or skip missing) so one missing doc cannot abort the batch
- [x] 3.3 Align the amortized month-key/`startDate` formatting with the client scheme; add a month-boundary assertion/test

## 4. Reconciliation (`firebase/functions/index.js`)

- [x] 4.1 Add a callable that recomputes one category-month summary from raw `ledger/<id>/<YYYY_MON>` docs (`count = len`, `total = sum(amount)`) and writes absolute values via `set(merge:true)` — `reconcileSummary`
- [x] 4.2 Add a whole-ledger sweep that reconciles every category-month bucket for a ledger — `reconcileLedger`
- [x] 4.3 Decide and implement empty-bucket behavior (delete `count:0` summaries vs. leave at zero) consistently in recompute and report — chose DELETE empty summaries; report already zero-fills absent months

## 5. Verification & heal

- [ ] 5.1 Add tests for the integrity scenarios: add/remove increments, concurrent add to a new bucket, category move (incl. into a bucket with no summary), missing-summary decrement, amortized create/delete balance
- [ ] 5.2 Add tests for reconciliation: drifted bucket correction, empty bucket, idempotence
- [ ] 5.3 Run the whole-ledger heal across existing ledgers; spot-check that report bucket counts match tap-through transaction lists
- [ ] 5.4 Re-run the heal after a short window to catch buckets mutated mid-sweep
