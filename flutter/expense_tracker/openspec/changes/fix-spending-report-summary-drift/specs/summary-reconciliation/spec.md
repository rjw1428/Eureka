## ADDED Requirements

### Requirement: Recompute a summary from raw transactions

The system SHALL provide an operation that recomputes a category-month summary's `count` and `total` directly from the raw transaction documents in `ledger/<id>/<YYYY_MON>` for that category, and writes the corrected values to the summary document. The recomputed `count` MUST equal the number of matching raw transactions and `total` MUST equal the sum of their amounts.

#### Scenario: Reconciling a drifted bucket corrects it

- **WHEN** a category-month summary reports `count` 0 (or any value) but raw transactions exist for that category-month
- **THEN** reconciliation sets the summary `count` and `total` to match the raw transactions

#### Scenario: Reconciling a bucket with no transactions

- **WHEN** reconciliation runs for a category-month that has no raw transactions
- **THEN** the summary `count` is 0 and `total` is 0 (or the summary is removed), and no phantom bucket remains

#### Scenario: Reconciliation is idempotent

- **WHEN** reconciliation runs twice on the same already-consistent bucket
- **THEN** the second run produces no change to `count` or `total`

### Requirement: Heal existing drift across a ledger

The system SHALL be able to reconcile the summaries of a ledger that was corrupted before the integrity fixes were in place, so that after healing every category-month summary is consistent with its raw transactions.

#### Scenario: Ledger-wide heal makes report accurate

- **WHEN** a ledger with pre-existing drift is healed
- **THEN** every Spending Report bucket's `count` and `total` match the raw transactions for its category-month

#### Scenario: Healing does not corrupt concurrent writes

- **WHEN** reconciliation runs while a transaction is being added or removed
- **THEN** the final summary values remain consistent with the raw transactions once both operations complete
