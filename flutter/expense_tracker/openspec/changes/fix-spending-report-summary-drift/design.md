## Context

The Spending Report renders from a denormalized `summaries` collection: one document per category-month keyed `ledger/<id>/summaries/<YYYY_MON>_<categoryId>`, holding `{count, total, startDate, categoryId, lastUpdate}`. These aggregates are maintained by hand-rolled `FieldValue.increment` calls in `lib/providers/expense_stream_provider.dart` (client) and `firebase/functions/index.js` (amortized create/delete). The report (`expenseSummaryProvider`) reads only summaries and zero-fills months with no summary doc; tapping a bucket instead reads the raw monthly collection `ledger/<id>/<YYYY_MON>`. When the aggregate drifts below reality, a bucket shows `count 0` while the tap-through lists real transactions.

Investigated drift sources:

1. `updateExpense` same-month category change (`expense_stream_provider.dart:228-246`): new-category `total` uses the wrong sign (`-amount`), `count` is never adjusted on either category, and the write uses `.update()` with no create-if-missing — so moving a transaction into a category-month with no summary throws, and the summary is never created.
2. `addExpense` (`:110-140`): a non-atomic get → `set({startDate, categoryId})` (no `merge`) → `update(increment)` sequence. A concurrent/double-submit `set` overwrites an already-committed increment, undercounting.
3. Unguarded `.update()` decrements in `removeExpense`/`updateExpense` and the `deleteAmortizedSeries` batch (`index.js:579-584`): a missing summary makes `update()` throw; a Firestore batch is all-or-nothing, so one missing doc aborts the whole delete silently (the client call is not awaited).
4. Over-decrements can drive a real summary to `count:0` while the document persists (increment never deletes).
5. No reconciliation exists anywhere — drift is permanent.

Constraint: this is a shared-ledger app (linked accounts) with offline-capable Firestore writes, so summary mutations can race and must not depend on read-then-write ordering.

## Goals / Non-Goals

**Goals:**
- Every summary mutation path (add, remove, edit, category change, date change, amortized create/update/delete) keeps `count`/`total` consistent with raw transactions.
- Summary writes are atomic and create-if-missing; concurrent writers never overwrite each other's increments.
- Decrements/deletes never throw or abort their raw-doc write due to a missing summary.
- A reconciliation operation can recompute a bucket (and a whole ledger) from raw transactions to heal pre-existing drift.

**Non-Goals:**
- Re-architecting the report to aggregate raw monthly collections directly (rejected below).
- Changing the summary document shape or the report UI.
- Backfilling/altering historical raw transaction documents (they are the source of truth).

## Decisions

### D1: Keep denormalized summaries; fix and heal rather than re-architect
The report already depends on `summaries`, and raw aggregation would mean reading up to 12 monthly collections per report open. Keep the cache; make its writes correct and add a heal path. Alternative (raw aggregation, accurate by construction) is deferred as a possible future change — heavier reads, larger blast radius.

### D2: Single atomic create-or-increment write
Replace every get→set→update with one `set(..., SetOptions(merge: true))` carrying `FieldValue.increment` for `count`/`total`, plus `startDate`/`categoryId`/`lastUpdate`. `merge: true` creates the doc if absent and never clobbers concurrent increments (increments commute). This removes the D2/#2 race and the create-if-missing gap in one move. Applies to client `addExpense`, the category-change branches, and the Cloud Function amortized loop.
- Alternative: Firestore transactions. Correct but heavier, and a plain merged increment is already atomic and commutative for counters — transactions reserved for cases needing read-then-conditional-write.

### D3: Fix category-change math explicitly
In the same-month category-change branch: previous category `count -1, total -prevAmount`; new category `count +1, total +newAmount` (correct sign), both via the D2 merged-increment write. When category is unchanged but amount changed, keep the existing `total` delta and leave `count` untouched.

### D4: Make decrements tolerant of missing summaries
Client remove/edit decrements use the D2 merged-increment write (which no longer throws on a missing doc — merge upserts). For the `deleteAmortizedSeries` batch, either `set(..., merge:true)` each decrement or pre-read existence and skip/repair missing ones, so a single missing summary can never abort the batch. Any resulting temporary inconsistency is repairable by reconciliation (D5).

### D5: Reconciliation as an idempotent recompute
Provide a reconcile operation that, for a category-month, reads the raw `ledger/<id>/<YYYY_MON>` docs filtered by `categoryId`, computes `count = len`, `total = sum(amount)`, and writes them with `set(merge:true)`. Expose it as a Cloud Function callable (single bucket + whole-ledger sweep) for a one-time/maintenance heal. Recompute writes the absolute values (not increments), so it is idempotent and self-correcting even against a small concurrent-write window.
- Delivery fork (open): also invoke lazily when the report loads a bucket vs. keep it purely manual/scheduled. Lean manual/callable first (predictable, no added reads on the hot report path); lazy self-heal can layer on later. See Open Questions.

### D6: Client/Cloud month-key consistency
Confirmed client `_formatMonth` and `formatMonth` produce identical `"${year}_${DateFormat('MMM').toUpperCase()}"`. Keep the amortized Cloud Function's month formatting aligned to the same scheme so the summary id, the `startDate` field, and the raw collection name always agree; add a test/assertion around month-boundary dates.

## Risks / Trade-offs

- **[Merged-increment on delete can create a summary that should be absent]** → after decrements a bucket may sit at `count:0` rather than being deleted; reconciliation may remove empty summaries, or the report already renders `count:0` harmlessly. Decide whether empty summaries are deleted or left at zero.
- **[Reconciliation reads all raw docs for a bucket/ledger]** → cost on large ledgers; run whole-ledger heal as a maintenance job, not on every report open.
- **[Concurrent write during recompute]** → a mutation landing between the raw read and the summary write could be missed; mitigate by recompute being cheap to re-run and idempotent, and re-running after a heal sweep.
- **[Offline writes]** → increments queue and apply on reconnect; merged increments remain commutative so ordering does not matter. Recompute must run online (needs the authoritative raw docs).
- **[Cloud Function batch changes]** → altering `deleteAmortizedSeries` risks regressing amortized deletes; cover with the balance scenarios in the spec.

## Migration Plan

1. Ship write-path fixes (D2–D4, D6) — stops new drift.
2. Deploy the reconcile callable (D5).
3. Run a one-time whole-ledger heal across existing ledgers to correct accumulated drift.
4. Optionally re-run the heal after a short window to catch anything mutated mid-sweep.
Rollback: write-path changes are backward-compatible with the existing summary shape; reverting the client/functions restores prior behavior without a data migration. Reconciliation is additive and can be disabled independently.

## Open Questions

- Reconcile delivery: manual/scheduled callable only, or also lazy self-heal on report bucket load? (Default: callable first.)
- Should empty (`count:0`) summaries be deleted during reconciliation or left in place?
- Is the whole-ledger heal a one-time backfill, or a recurring scheduled safety net?
