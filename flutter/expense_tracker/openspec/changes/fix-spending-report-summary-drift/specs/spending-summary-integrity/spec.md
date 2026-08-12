## ADDED Requirements

### Requirement: Summary aggregates reflect their raw transactions

Each category-month summary document (`ledger/<id>/summaries/<YYYY_MON>_<categoryId>`) SHALL maintain a `count` equal to the number of raw transaction documents for that category in that month, and a `total` equal to the sum of those transactions' `amount` values. After any single mutation completes successfully, the summary MUST be consistent with the raw transaction documents.

#### Scenario: Adding a transaction increments its summary

- **WHEN** a transaction is added for a category-month
- **THEN** that category-month summary's `count` increases by 1 and `total` increases by the transaction amount
- **AND** the summary's `startDate` and `categoryId` identify the correct bucket

#### Scenario: Removing a transaction decrements its summary

- **WHEN** a transaction is removed
- **THEN** its category-month summary's `count` decreases by 1 and `total` decreases by the transaction amount

#### Scenario: Report bucket count matches tap-through transactions

- **WHEN** the Spending Report displays a bucket with `count` N for a category-month
- **THEN** opening that bucket lists exactly N transactions for that category-month

### Requirement: Summary writes are atomic and create-if-missing

Every mutation that changes a summary's `count` or `total` SHALL apply the change atomically in a single write that both creates the summary document if it does not exist and applies the increment, without a separate non-atomic read-then-write sequence. No summary write may overwrite (reset) a concurrently written `count` or `total`.

#### Scenario: First transaction in a new bucket creates and increments atomically

- **WHEN** a transaction is added for a category-month that has no summary document yet
- **THEN** the summary document is created with `count` 1 and `total` equal to the amount in a single atomic operation
- **AND** `startDate` and `categoryId` are set

#### Scenario: Concurrent additions to the same new bucket do not lose increments

- **WHEN** two transactions are added to the same previously-nonexistent category-month bucket concurrently
- **THEN** the resulting summary has `count` 2 and `total` equal to the sum of both amounts
- **AND** neither writer's increment is overwritten by the other

### Requirement: Category re-assignment updates both summaries correctly

When a transaction's category changes within the same month, the system SHALL decrement the previous category's summary (`count` by 1, `total` by the previous amount) and increment the new category's summary (`count` by 1, `total` by the new amount), creating the new category's summary if it does not exist.

#### Scenario: Moving a transaction to another category

- **WHEN** an existing transaction's category changes from A to B in the same month
- **THEN** category A's summary `count` decreases by 1 and `total` decreases by the previous amount
- **AND** category B's summary `count` increases by 1 and `total` increases by the new amount

#### Scenario: Moving a transaction into a category with no existing summary

- **WHEN** a transaction is re-categorized into a category-month that has no summary document
- **THEN** the destination summary is created and reflects `count` 1 and `total` equal to the amount
- **AND** the operation does not fail

### Requirement: Decrements tolerate missing summaries

A remove, edit, or delete operation SHALL NOT fail or abort its accompanying raw-document write because a target summary document is missing. If the summary is absent, the operation completes without throwing and leaves the raw transactions and summaries in a state that reconciliation can repair.

#### Scenario: Removing a transaction whose summary is missing

- **WHEN** a transaction is removed but its category-month summary document does not exist
- **THEN** the raw transaction document is still removed
- **AND** no error aborts the operation

#### Scenario: Deleting an amortized series with a missing summary

- **WHEN** an amortized series is deleted and one of its month summaries is already missing
- **THEN** the remaining summaries are still decremented and the remaining expense documents are still deleted
- **AND** the batch is not aborted by the missing summary

### Requirement: Amortized create and delete preserve aggregate balance

Creating an amortized series SHALL increment each affected month-summary exactly once per generated transaction, and deleting the series SHALL decrement the same summaries by the same amounts, so a create followed by a delete returns every affected summary to its prior `count` and `total`.

#### Scenario: Amortized create then delete is balanced

- **WHEN** an amortized expense over N months is created and then the series is deleted
- **THEN** every affected category-month summary's `count` and `total` return to their values before the create

#### Scenario: Amortized months each counted once

- **WHEN** an amortized expense over N months is created
- **THEN** each of the N month-summaries has `count` increased by exactly 1 and `total` increased by the per-month amount
