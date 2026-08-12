## ADDED Requirements

### Requirement: All ledgers and transactions are migrated to the flat collection

The migration SHALL copy every transaction from every per-month collection (`ledger/{ledgerId}/{YYYY_MON}/*`) into the flat collection (`ledger/{ledgerId}/expenses/*`) for every ledger, including backup and orphaned ledgers not currently owned by an active user. Document IDs SHALL be preserved. Writes SHALL be batched within Firestore's 500-operation limit.

#### Scenario: Every month collection is copied
- **WHEN** the migration runs for a ledger
- **THEN** each document in every `YYYY_MON` collection is written to `expenses/` under the same document ID

#### Scenario: Backup and orphaned ledgers are included
- **WHEN** the migration enumerates ledgers
- **THEN** it processes all `ledger` documents, not only those referenced by an active user's current `ledgerId`

### Requirement: Dates are normalized to Timestamp during migration

The migration SHALL convert every transaction `date` to a Firestore `Timestamp`, including documents that currently store `date` as an ISO string. After migration, no document in the flat collection SHALL have a non-Timestamp `date`.

#### Scenario: ISO-string date is converted
- **WHEN** the migration copies a transaction whose `date` is an ISO string
- **THEN** the written document's `date` is a Firestore `Timestamp` representing the same instant

#### Scenario: Post-migration date-type invariant
- **WHEN** verification scans the flat collection
- **THEN** every document's `date` field is a `Timestamp`

### Requirement: Migration is verified before cutover

Before the application cuts over to the flat collection, the migration SHALL be verified by: per-ledger document-count parity between the old month collections and the flat collection; per-`(month, category)` total parity against the rebuilt summaries; a date-type invariant check; and spot-checks that amortized `groupId`/`nextId` chains are intact.

#### Scenario: Count parity holds
- **WHEN** verification compares counts
- **THEN** the sum of documents across a ledger's old month collections equals the count in its flat `expenses` collection

#### Scenario: Total parity holds
- **WHEN** verification compares per-category-month totals derived from the flat collection against the rebuilt summaries
- **THEN** they match

#### Scenario: Verification failure blocks cutover
- **WHEN** any parity or invariant check fails
- **THEN** cutover does not proceed and the discrepancy is reported

### Requirement: Migration performed during downtime with rollback safety

The migration SHALL be performed during a downtime/freeze window with no concurrent writes; dual-write is not required. Old month collections and the `amortization_series` manifest SHALL be retained until a post-cutover soak completes, and SHALL only be deleted after the flat collection is confirmed correct.

#### Scenario: Freeze prevents concurrent writes
- **WHEN** the migration is running
- **THEN** application writes are frozen so no transaction is written to an old collection after it has been copied

#### Scenario: Rollback before cleanup
- **WHEN** a defect is found after cutover but before cleanup
- **THEN** the retained old month collections remain a valid source of truth to revert to

#### Scenario: Cleanup after soak
- **WHEN** the soak period completes with the flat collection confirmed correct
- **THEN** the old `YYYY_MON` collections and `amortization_series` documents are deleted
