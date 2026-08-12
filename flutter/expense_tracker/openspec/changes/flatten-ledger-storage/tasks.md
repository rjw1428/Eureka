## 0. Preconditions

- [ ] 0.1 Confirm `fix-spending-report-summary-drift` is complete and archived before starting (this change ports its hardened summary logic, does not redo it)
- [ ] 0.2 Snapshot/export current Firestore data (or confirm a backup exists) as a pre-migration safety net

## 1. Schema prep (deployable ahead of cutover)

- [ ] 1.1 Add `firestore.indexes.json` composite index: `categoryId ==` + `date` range + `orderBy(date desc)`
- [ ] 1.2 (No `hideUntil` composite index — filtering stays client-side, per design)
- [ ] 1.3 Update security rules to authorize `ledger/{ledgerId}/expenses/{id}` with the existing ledger-membership check, keeping old `YYYY_MON` path rules allowed during transition
- [ ] 1.4 Deploy indexes + rules; confirm indexes finish building

## 2. Migration admin script

- [ ] 2.1 Write a one-off local admin **script** (not an `onCall` function) that enumerates ALL `ledger` documents (including backup/orphaned ledgers)
- [ ] 2.2 For each ledger, iterate every `YYYY_MON` collection and copy each doc → `ledger/{lid}/expenses/{sameId}`, preserving document IDs
- [ ] 2.3 Normalize every `date` to a Firestore `Timestamp` during copy (convert ISO-string dates via the shared `toDate` helper)
- [ ] 2.4 Batch writes in ≤450-op chunks (reuse the chunking pattern from `reconcileLedgerSummaries`)
- [ ] 2.5 Make the routine idempotent/re-runnable (safe to resume if interrupted)

## 3. Verification tooling

- [ ] 3.1 Per-ledger count parity check: `Σ(docs in old YYYY_MON collections) == count(expenses)`
- [ ] 3.2 Date-type invariant check: assert zero non-`Timestamp` `date` fields in `expenses`
- [ ] 3.3 Per-`(month, category)` total parity check between flat-collection-derived totals and rebuilt summaries
- [ ] 3.4 Amortized integrity spot-check: for sampled `groupId`s, confirm member count and intact `nextId` chain
- [ ] 3.5 Verification reports discrepancies and exits non-zero on any failure (blocks cutover)

## 4. Client mutation paths (`lib/providers/expense_stream_provider.dart`)

- [ ] 4.1 Replace `_expenseCollection(date)` with a single `expenses` collection reference (drop month derivation for raw storage)
- [ ] 4.2 Update `addExpense` to write to `expenses/`, persisting `date` as `Timestamp`; keep the atomic `set(merge:true)` + `increment` summary update (ported from drift fix)
- [ ] 4.3 Update `removeExpense` to delete from `expenses/` and decrement the summary (guarded against missing summary)
- [ ] 4.4 Rewrite `updateExpense` cross-month move as an in-place `date` field update (no delete+add); adjust old/new `(month, category)` summary buckets
- [ ] 4.5 Update `react` to target `expenses/{id}`
- [ ] 4.6 Keep `monthKey`/`_summaryId` for deriving summary doc IDs from `date`
- [ ] 4.7 Timezone consistency (D8): compute month boundaries in the user's LOCAL tz for both range queries and summary bucket ids; ensure the amortized Cloud Function uses the client's tz (accept a tz offset or have the client pass the month key) rather than the runtime UTC tz

## 5. Client read paths

- [ ] 5.1 Rewrite `expenseProvider` stream: query `expenses` with `where('date' in current-month range).orderBy('date' desc)` instead of `collection(month)`
- [ ] 5.2 Add a range-query provider (family over `{start, end, categoryId?}`) for arbitrary-window reads
- [ ] 5.3 Wire the dormant `PaginationNotifier` (`limit` + `startAfterDocument`) for all-history / large-range browsing
- [ ] 5.4 Confirm `expenseSummaryProvider`, `currentSummaryProvider`, `latestSummaryDateProvider`, `budget_provider` are UNCHANGED (still read summaries — Option A)
- [ ] 5.5 Confirm live listeners stay range-bounded (offline-cache safety)

## 6. Cloud Functions (`firebase/functions/index.js`)

- [ ] 6.1 Rewrite `createAmortizedExpenses` to write N docs into `expenses/` (Timestamp dates) + increment N summary buckets; stop writing the `amortization_series` manifest
- [ ] 6.2 Rewrite `deleteAmortizedSeries` to find members via `where('amortized.groupId','==',groupId)` and decrement their summary buckets; remove manifest dependency
- [ ] 6.3 Re-point `reconcileLedgerSummaries` to read the flat `expenses` collection and bucket by `(monthKey(date), categoryId)`; retire the `listCollections()` + `MONTH_COLLECTION_RE` sweep
- [ ] 6.4 Trim `dateKey.js`: keep `monthKey`/`toDate`, remove the now-unused `MONTH_COLLECTION_RE` (or leave until cleanup)
- [ ] 6.5 Verify `sendExpenseNotification` still fires correctly on `expenses/` writes (wildcard collection trigger — no path change) and ignores non-expense subcollection writes

## 7. Cutover

- [ ] 7.1 Freeze writes (maintenance/downtime signal to clients)
- [ ] 7.2 Run migration (section 2) across all ledgers
- [ ] 7.3 Rebuild summaries via reconcile against the flat collection; confirm they match pre-migration values
- [ ] 7.4 Run verification (section 3); do not proceed unless all checks pass
- [ ] 7.5 Bump `pubspec.yaml` version to `2.0.0` (major/breaking) and increment the build number (e.g. `2.0.0+21`)
- [ ] 7.6 Deploy cutover build (client + functions from sections 4–6)
- [ ] 7.7 Unfreeze; smoke-test add / edit / delete / amortize / cross-month move / month browse / arbitrary-range read

## 8. Post-cutover cleanup (after soak)

- [ ] 8.1 Soak in production; monitor for report/summary drift and missing-transaction reports
- [ ] 8.2 Delete old `ledger/{lid}/{YYYY_MON}` collections and `amortization_series/*`
- [ ] 8.3 Tighten security rules to remove old-path allowances
- [ ] 8.4 Remove any remaining month-collection code paths and dead helpers

## 9. Follow-on (out of scope here — track separately)

- [ ] 9.1 Note that Algolia/full-text search and any arbitrary-range report UI are now unblocked and belong to future changes
