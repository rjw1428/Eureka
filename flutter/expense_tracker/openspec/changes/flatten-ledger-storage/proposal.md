## Why

Transactions are stored in **per-month subcollections** (`ledger/{ledgerId}/{YYYY_MON}/{expenseId}`), which makes the calendar month the only unit of storage — and therefore the only unit of query. This structure caps reporting at whole calendar months, makes cross-month and arbitrary-range queries impossible without fanning out over N collections, blocks full-text search (a `collectionGroup` query can't span collections with different names), and forces avoidable complexity: amortized series need a path manifest, moving an expense across months is a delete + add, and summary reconciliation must `listCollections()` and regex-match month names. Flattening to a single per-ledger transaction collection with a queryable `date` field removes the cage: reports can span any window, aggregations get simpler, and full-text search (a later Algolia release) becomes a single-collection sync.

This change is scoped as a **later release** that builds on `fix-spending-report-summary-drift` (landing first). It deliberately **keeps** the denormalized monthly `summaries` architecture that change is hardening — it only moves the raw transactions and re-points the reconcile source at the flat collection.

## What Changes

- **BREAKING (storage layout):** Move raw transactions from `ledger/{ledgerId}/{YYYY_MON}/*` to a single flat collection `ledger/{ledgerId}/expenses/*`. The month is no longer encoded in the collection name; the transaction's `date` (Timestamp) is the query key. This ships as a **major version bump to `2.0.0`** (from `1.5.x`), reflecting the breaking data-layout change and one-time migration.
- **Migrate all existing data.** One-time backfill copies every transaction from every month collection (across every ledger) into `expenses/`, **normalizing every `date` to a Firestore `Timestamp`** (some amortized docs currently store `date` as an ISO string, which would be invisible to range queries). Old month collections are retained as a rollback net, then deleted after a soak.
- **Keep monthly summaries (Option A).** `ledger/{ledgerId}/summaries/{YYYY_MON}_{categoryId}` stays exactly as-is. The month-by-month Spending Report and the current-month budget view continue to read summaries unchanged. Only the **reconcile source** changes: it sweeps the one flat `expenses` collection and buckets by `monthKey(date)` in code, instead of `listCollections()` + `MONTH_COLLECTION_RE`.
- **Enable arbitrary-range queries at the data layer.** Reading transactions over any date window (`where('date', >=, start).where('date', <=, end)`, optionally `+ categoryId`), including non-month-aligned spans and all-category ranges. New report UIs and full-text search consume this but are out of scope here.
- **Simplify mutation paths:**
  - Cross-month move becomes a single `date` field update (no delete-from-old + add-to-new).
  - Amortized create writes N docs to one collection; amortized delete queries `where('amortized.groupId', ==, groupId)` — **the `amortization_series` path manifest is removed.**
- **Rewrite Firestore security rules** for the `expenses/` path (preserving ledger-membership enforcement) and **add composite indexes** for `categoryId + date range + orderBy(date)`.
- **Out of scope (future releases):** Algolia/full-text search integration, and any new arbitrary-range report UI. This change is the enabler.

## Capabilities

### New Capabilities
- `flat-transaction-storage`: Raw transactions live in one flat per-ledger collection (`ledger/{ledgerId}/expenses/*`) with `date` stored as a queryable `Timestamp`. All mutation paths (add, remove, edit, category change, date change, amortized create/update/delete) read and write this collection; cross-month moves are a field update; amortized series are grouped by `amortized.groupId` rather than a path manifest. The monthly `summaries` rollup is maintained alongside, unchanged in shape.
- `transaction-range-queries`: The data layer can read transactions and derive report data over **arbitrary date windows** (any start/end, not bound to calendar months) and across categories, in a single query. Monthly summaries remain the source for month-grained charts; raw range queries serve arbitrary/sub-month windows and drill-downs.
- `ledger-data-migration`: A one-time, verifiable migration from the month-sharded layout to the flat layout — backfill (with `date` normalized to `Timestamp` and document IDs preserved), pre-cutover verification (doc-count and per-category-month total parity), a downtime cutover, a retained-collections rollback net, and post-soak cleanup of old collections and the amortization manifest.

### Modified Capabilities
<!-- None: openspec/specs/ has no established specs yet. The sibling change
     fix-spending-report-summary-drift defines `summary-reconciliation` and
     `spending-summary-integrity`; this change re-points reconcile's source to the
     flat collection (see design.md) but those specs are not yet in openspec/specs/,
     so no formal delta is emitted here. -->

## Impact

- **Client (`lib/providers/expense_stream_provider.dart`):** `_expenseCollection`/`_summaryCollection`, `addExpense`, `addAmortizedExpense`, `removeExpense`, `updateExpense`, `react`, the `expenseProvider` stream (month collection → date-range query), and any new range-query providers. `expense_provider.dart` (`formatMonth`, dormant `PaginationNotifier`) — pagination finally used for all-history lists.
- **Client (reporting/budget):** `expenseSummaryProvider`, `currentSummaryProvider`, `latestSummaryDateProvider`, `budget_provider` — **read paths unchanged** (still read summaries), because Option A keeps the rollup.
- **Cloud Functions (`firebase/functions/index.js`):** `createAmortizedExpenses` and `deleteAmortizedSeries` (flat writes, manifest removed), `reconcileLedgerSummaries`/`reconcileSummary`/`reconcileLedger` (source becomes the flat collection). `sendExpenseNotification` already triggers on a wildcard collection and needs no path change. `firebase/functions/dateKey.js` — `monthKey()` retained for summary IDs; `MONTH_COLLECTION_RE`/`listCollections` sweep retired.
- **Data:** New `ledger/{ledgerId}/expenses/*`; retired (post-soak) `ledger/{ledgerId}/{YYYY_MON}/*` and `ledger/{ledgerId}/amortization_series/*`. `summaries` unchanged.
- **Infra:** New Firestore composite indexes (`firestore.indexes.json`); rewritten security rules; a one-time migration admin script.
- **Versioning:** `pubspec.yaml` bumps to `2.0.0` (major, breaking) from the current `1.5.x`, with the build number incremented.
- **Migration constraints (settled):** date types normalized to `Timestamp`; performed during a **downtime/freeze window** (no dual-write); **all** ledgers migrated including backup/orphaned ones (few ledgers exist).
- **Risk:** the `date` normalization is a silent corruptor if missed (string-typed dates skip range queries); reconcile and mutation-path rewrites touch the same hot code the drift fix hardens, so this change must land after it.
