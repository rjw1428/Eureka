## ADDED Requirements

### Requirement: Transactions stored in a single flat per-ledger collection

Raw transactions SHALL be stored at `ledger/{ledgerId}/expenses/{expenseId}`, one flat collection per ledger. The transaction's month MUST NOT be encoded in the collection name; the calendar month is derived from the `date` field. Each transaction's document ID SHALL be preserved across the migration so that `amortized.groupId` and `amortized.nextId` references remain valid.

#### Scenario: A new transaction is written to the flat collection
- **WHEN** a user adds a transaction to their ledger
- **THEN** the system writes a single document under `ledger/{ledgerId}/expenses/`
- **AND** no per-month collection (e.g. `2026_JUL`) is created or written for the raw transaction

#### Scenario: Transaction fields are unchanged
- **WHEN** a transaction is stored in the flat collection
- **THEN** it retains all existing fields (`amount`, `date`, `categoryId`, `note`, `submittedBy`, `reactions`, `hideUntil`, `amortized`, `notify`) with the same meanings as before

### Requirement: The `date` field is a queryable Timestamp

Every transaction's `date` SHALL be persisted as a Firestore `Timestamp`. The system MUST NOT write `date` as an ISO string or any other type, so that Firestore range predicates on `date` match every transaction.

#### Scenario: A normal write persists a Timestamp
- **WHEN** any mutation path (add, edit, amortized create) writes a transaction
- **THEN** the stored `date` field is a Firestore `Timestamp`

#### Scenario: Range query matches all transactions in the window
- **WHEN** the data layer queries `where('date' >= start).where('date' <= end)`
- **THEN** every transaction whose date falls in `[start, end]` is returned, including transactions that originated from an amortized series

### Requirement: Cross-month move is a field update

When a transaction's `date` changes such that it moves to a different calendar month, the system SHALL update the `date` field on the existing document rather than deleting it from one collection and adding it to another. Summary maintenance SHALL adjust the old and new `(month, category)` buckets to remain consistent with the retained monthly rollup.

#### Scenario: Editing a transaction's date across months
- **WHEN** a user edits a transaction's date from one month to another
- **THEN** the same `expenses/{expenseId}` document is updated in place with the new `date`
- **AND** the summary for the old month-category is decremented and the new month-category is incremented

### Requirement: Amortized series are grouped by groupId without a manifest

Amortized transactions SHALL be created as N documents in the flat `expenses` collection, each with its own `date` and a shared `amortized.groupId`. Deleting a series SHALL locate its documents via a query on `amortized.groupId` rather than reading a stored path manifest. The `amortization_series` manifest collection SHALL NOT be required for deletion.

#### Scenario: Creating an amortized expense
- **WHEN** a user creates an expense amortized over N months
- **THEN** N documents are written to `expenses/`, each with the same `amortized.groupId` and a `date` in its respective month
- **AND** each corresponding month-category summary is incremented

#### Scenario: Deleting an amortized series
- **WHEN** a user deletes a member of an amortized series
- **THEN** the system queries `where('amortized.groupId', '==', groupId)` to find every member and deletes them
- **AND** the corresponding month-category summaries are decremented
- **AND** no `amortization_series/{groupId}` manifest read is required
