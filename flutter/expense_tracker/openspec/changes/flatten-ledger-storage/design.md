## Context

Raw transactions are sharded into per-month subcollections `ledger/{ledgerId}/{YYYY_MON}/{expenseId}` (e.g. `ledger/abc/2026_JUL/xyz`). The month is encoded in the collection name, so it is the only unit of both storage and query. A denormalized rollup `ledger/{ledgerId}/summaries/{YYYY_MON}_{categoryId}` (`{count, total, startDate, categoryId}`) powers the Spending Report and the current-month budget view; it is maintained by inline `FieldValue.increment` writes on every mutation path and healed by a reconcile that `listCollections()` + regex-matches month names.

Consequences of the sharding:
- Reporting/listing is capped at whole calendar months; arbitrary and non-month-aligned windows are impossible without fanning out over N collections.
- Full-text search is blocked — a `collectionGroup` query can't span collections with different names, and the official Algolia Firebase Extension watches a single literal collection path.
- Amortized series need an `amortization_series/{groupId}` manifest storing full document paths; cross-month moves are delete-from-old + add-to-new; reconcile must enumerate collections.
- Some amortized docs store `date` as an ISO **string** (via `createAmortizedExpenses`) while normal writes store a `Timestamp`; `_dateFromJson` tolerates both, so the inconsistency is currently invisible.

Constraints (settled during exploration):
- **Sequencing:** lands *after* `fix-spending-report-summary-drift`. That change hardens the summaries counters; this change keeps them (Option A) and only re-points the reconcile source.
- **Migration window:** performed during **downtime** (freeze), no dual-write.
- **Scope of data:** all ledgers migrated, including backup/orphaned ones (few ledgers exist).
- **Summaries:** kept as a monthly rollup (Option A), unchanged in shape.

## Goals / Non-Goals

**Goals:**
- Store raw transactions in one flat per-ledger collection `ledger/{ledgerId}/expenses/*` with `date` as a queryable `Timestamp`.
- Enable arbitrary-range and cross-category transaction queries at the data layer.
- Migrate all existing data safely and verifiably, normalizing every `date` to `Timestamp`.
- Simplify mutation paths: cross-month move → field update; amortized delete → group query; drop the amortization manifest.
- Keep the monthly `summaries` rollup and its consumers unchanged; only change reconcile's source.

**Non-Goals:**
- Algolia / full-text search integration (future release; this change is the enabler).
- New arbitrary-range report UI (future; only the data-layer capability lands here).
- Retiring or re-architecting the summaries rollup (that was Option B — explicitly not chosen).
- Changing the summary document shape or the report/budget read paths.

## Decisions

### D1 — Flat collection named `expenses`, document IDs preserved
Store all transactions at `ledger/{ledgerId}/expenses/{expenseId}`, reusing existing Firestore auto-IDs during migration. Preserving IDs keeps the amortized `nextId` linked-list chain and `groupId` grouping valid with no path rewriting.
- *Alternatives:* new IDs (breaks `nextId` chains, needs remap table) — rejected. A single global `collectionGroup('expenses')` across ledgers is unnecessary because reads are always ledger-scoped.

### D2 — `date` is the query key; normalize all dates to `Timestamp`
Month browsing becomes `where('date', >=, monthStart).where('date', <, nextMonthStart).orderBy('date', desc)`; arbitrary windows use the same shape with any bounds. Because Firestore range predicates don't match string-typed fields against a `Timestamp` bound, the backfill MUST convert every ISO-string `date` to a `Timestamp`, and all future writes MUST persist `Timestamp`.
- *Alternatives:* keep mixed types + `_dateFromJson` tolerance — rejected: string-dated docs would silently vanish from every range query, report, and search.

### D3 — Keep monthly summaries (Option A); change only the reconcile source
`summaries/{YYYY_MON}_{categoryId}` is unchanged. `monthKey(date)` is retained to derive summary IDs. Reconcile stops using `listCollections()` + `MONTH_COLLECTION_RE` and instead reads the flat `expenses` collection (optionally range-limited) and buckets each doc by `(monthKey(date), categoryId)`.
- *Rationale:* the report/budget read paths and the drift-fix counter work carry over untouched; the flatten stays a storage-layer change. Reads for month-grained charts remain ~1 doc/category/month.
- *Alternatives:* Option B (derive all totals from raw range reads, delete summaries) — cleaner but changes report providers and discards drift-fix work; deferred. Option A′ (rollup rebuilt, never incremented) — more machinery than a household ledger needs.

### D4 — Amortized series grouped by `groupId`, manifest removed
`createAmortizedExpenses` writes N docs into `expenses` (different `date`s) + increments N summary buckets. `deleteAmortizedSeries` deletes via `where('amortized.groupId', ==, groupId)` and decrements the corresponding summary buckets computed from the fetched docs, instead of reading `amortization_series/{groupId}`. The manifest collection is dropped.
- *Alternatives:* keep the manifest with rewritten flat paths — rejected: pure redundancy once a group query works.

### D5 — Cross-month move is a `date` field update
In `updateExpense`, a date change that crosses months no longer removes + re-adds the doc; it updates `date` in place. Summary maintenance still adjusts the two affected `(month, category)` buckets (decrement old, increment new) to keep Option A consistent.

### D6 — Composite indexes + rewritten security rules
Declare `firestore.indexes.json` composites for `categoryId ==` + `date` range + `orderBy(date)` (and any server-side `hideUntil` filtering). Rewrite rules to authorize `ledger/{ledgerId}/expenses/{id}` with the same ledger-membership check the month-collection rules enforced. `sendExpenseNotification` triggers on a wildcard collection and needs no path change; when the later Algolia sync trigger is added it must filter to `col == 'expenses'`.

### D7 — Bounded listeners; pagination for all-history
The live list keeps using a **bounded** query (current-month range) to protect the 10 MB offline cache. All-history / large-range views use the dormant `PaginationNotifier` (`limit` + `startAfterDocument`) rather than an unbounded snapshot listener.

### D8 — Store `date` in UTC, compute month boundaries in local time (consistently)
`date` is stored as an absolute Firestore `Timestamp` (UTC instant). Month-range queries compute their bounds from the **user's local timezone** — e.g. July = `[DateTime(2026,7,1) local, DateTime(2026,8,1) local)` converted to Timestamps. The **invariant**: the summary bucket id (`monthKey(date)`) MUST be derived using the *same* local-time month boundaries as the range query, or an edge-of-month transaction (e.g. Jul 31 11pm local = Aug 1 UTC) buckets into one month while the query returns it in another, reintroducing drift.
- *Caveat:* "local" is the device timezone. The amortized Cloud Function currently derives month keys from the runtime tz (UTC); it must instead use the client's tz (accept a tz offset, or have the client compute and pass the month key). For same-timezone household users this is a non-issue; linked users in different timezones are the edge case to watch.
- *Alternatives:* pick a single fixed tz (e.g. UTC) for all boundary math — simpler and fully drift-proof, but months would shift relative to what the user sees as "their" month; rejected in favor of local-time display correctness.

## Risks / Trade-offs

- **[Silent date corruption]** String-typed `date`s skip range queries → amortized expenses disappear from browse/reports/search. → Backfill normalizes every `date` to `Timestamp`; verification asserts zero non-Timestamp `date` fields and per-category-month total parity before cutover.
- **[Hot-path code overlap with drift fix]** Mutation + reconcile rewrites touch the same code `fix-spending-report-summary-drift` hardens. → Sequence this change strictly after it; port the atomic `set(merge:true)` + `increment` logic rather than rewriting it.
- **[Data loss during migration]** A missed or mis-copied doc. → Downtime freeze (no concurrent writes); per-ledger doc-count parity + spot-checked amortized chains; old collections retained as rollback net until post-soak cleanup.
- **[Missing composite index at runtime]** Range + category queries throw until indexed. → Pre-declare in `firestore.indexes.json` and deploy before cutover.
- **[Offline cache blowup]** An unbounded flat listener caches all history. → D7: bounded/paginated queries only.
- **[Orphaned/backup ledgers skipped]** Linking juggles `ledgerId`/`backupLedgerId`/`restoreLedgerId`. → Migration enumerates all `ledger` docs, not just active users'.

## Migration Plan

1. **Land drift fix first.** Do not start until `fix-spending-report-summary-drift` is complete.
2. **Deploy schema prep (no cutover):** `firestore.indexes.json` composites and updated rules that allow `expenses/` (old paths still allowed during transition).
3. **Freeze writes** (downtime window).
4. **Backfill (script/callable):** for every `ledger` doc, for every `YYYY_MON` collection, copy each doc → `ledger/{lid}/expenses/{sameId}`, converting `date` to `Timestamp`; batch in ≤450-op chunks.
5. **Rebuild summaries** via reconcile against the flat collection (Option A) and confirm they match pre-migration values.
6. **Verify:** per-ledger `Σ(old month collections) == count(expenses)`; per-`(month, category)` total parity; every `expenses` doc has a `Timestamp` `date`; amortized `groupId`/`nextId` chains intact.
7. **Cutover:** deploy client + functions that read/write only `expenses/`; manifest logic removed.
8. **Unfreeze.**
9. **Soak**, then **cleanup:** delete old `YYYY_MON` collections and `amortization_series/*`; tighten rules to remove old-path allowances.

**Rollback:** before cutover, revert code and unfreeze — old collections are still the source of truth. After cutover but pre-cleanup, old collections remain intact for re-pointing if a defect surfaces.

## Resolved Decisions (previously open)

- **Timezone:** Store `date` in UTC; compute month boundaries in local time for both queries and summary bucketing (see D8).
- **Migration mechanism:** A one-off **local admin script** (not an `onCall` function) — zero attack surface, runs once against few ledgers.
- **`hideUntil` filtering:** Stays **client-side** as today; no server-side filter, no extra composite index for it.
- **Downtime signaling:** None — the freeze is performed during off-hours; the few household users are not gated by a maintenance flag.
- **Reconcile read cost:** The one-time summary rebuild is part of the migration/cutover (reads all expenses once). The *ongoing* reconcile/heal function inherits the flat-collection source and also reads all of a ledger's expenses; acceptable at current scale. A range-scoped reconcile variant is deferred until/unless a ledger grows large.

## Open Questions

- None outstanding. (Revisit the D8 cross-timezone caveat only if linked users in different timezones become common.)
