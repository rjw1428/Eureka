## Why

The Spending Report is built entirely from a denormalized `summaries` collection (one `{count, total}` doc per category-month), maintained by hand-rolled `FieldValue.increment` calls scattered across add/remove/update on both the client and Cloud Functions. Several of those write paths are incorrect or non-atomic, so the aggregates drift away from the raw transaction documents they are supposed to summarize. The visible result: report buckets show "Total transactions: 0" (or wrong totals) while tapping the same bucket lists real transactions, because the report reads the drifted summary and the tap-through reads the raw monthly collection. There is no reconciliation anywhere, so every drift event is permanent.

## What Changes

- **Make summary writes atomic and idempotent.** Replace the get→set→update sequences (client `addExpense`, Cloud Function `createAmortizedExpenses`) with a single atomic `set(..., merge: true)` carrying `FieldValue.increment`, or a Firestore transaction. Removes the non-merge `set` overwrite race that wipes concurrent/double-submit increments.
- **Fix same-month category re-assignment** in `updateExpense`: correct the new-category `total` sign (currently subtracts instead of adds), decrement/increment `count` on the old/new category (currently untouched), and create-if-missing the destination summary so the write no longer throws when the target category-month has no summary yet.
- **Guard all decrements/deletes against missing summaries** so a single already-missing doc can no longer throw and abort a write (client `removeExpense`, `updateExpense`; Cloud Function `deleteAmortizedSeries` batch).
- **Add a reconcile/heal capability** that recomputes a category-month summary's `{count, total}` from the raw transaction docs, to repair ledgers already corrupted by past drift (existing fixes only prevent new drift). Exposed as a callable/maintenance operation and/or a lazy self-heal when the report loads a bucket.
- Keep the denormalized-summary architecture (report continues to read `summaries`); this change corrects and heals it rather than re-architecting to raw aggregation.

## Capabilities

### New Capabilities
- `spending-summary-integrity`: The invariant that each category-month summary aggregate (`count`, `total`, `startDate`, `categoryId`) stays consistent with the raw transaction documents in the corresponding monthly collection, across all mutation paths (add, remove, edit, category change, date change, amortized create/update/delete), including concurrent writers.
- `summary-reconciliation`: The ability to detect and repair drift by recomputing a summary's `count` and `total` from the underlying raw transaction documents, healing ledgers already corrupted before the integrity fixes were in place.

### Modified Capabilities
<!-- None: no existing specs in openspec/specs/. -->

## Impact

- **Client:** `lib/providers/expense_stream_provider.dart` — `addExpense`, `addAmortizedExpense`, `removeExpense`, `updateExpense`, and the `expenseSummaryProvider` read/zero-fill path.
- **Cloud Functions:** `firebase/functions/index.js` — `createAmortizedExpenses`, `deleteAmortizedSeries`; likely a new callable for reconciliation.
- **Data:** the `ledger/<id>/summaries/<YYYY_MON>_<categoryId>` documents; raw transaction collections `ledger/<id>/<YYYY_MON>` are the source of truth for healing.
- **Behavior:** Spending Report counts/totals become accurate; already-drifted buckets are corrected once healed. No schema/shape change to summary documents; no user-facing API change beyond a maintenance/reconcile trigger.
- **Risk:** reconciliation must read raw docs (extra reads) and must be safe against concurrent writes; write-path changes touch the hot add/edit path and need care around atomicity and offline behavior.
