## ADDED Requirements

### Requirement: Transactions can be read over arbitrary date windows

The data layer SHALL support reading transactions over any date window `[start, end]` in a single query, including windows that are not aligned to calendar-month boundaries. Reads MUST NOT be constrained to a single calendar month.

#### Scenario: Non-month-aligned window
- **WHEN** the data layer requests transactions for the window March 15 → April 15
- **THEN** exactly the transactions whose `date` falls within that window are returned in one query

#### Scenario: Multi-year window
- **WHEN** the data layer requests transactions from a start date to today spanning multiple months or years
- **THEN** all matching transactions are returned without fanning out over multiple collections

### Requirement: Transactions can be filtered by category within a range

The data layer SHALL support combining a `categoryId` equality filter with a `date` range and ordering by `date`, backed by a Firestore composite index.

#### Scenario: Category over a range
- **WHEN** the data layer requests all transactions in category X between two dates, ordered by date
- **THEN** the query executes against a declared composite index and returns the matching transactions

#### Scenario: All transactions in a category, all time
- **WHEN** the data layer requests every transaction in category X with no date bound
- **THEN** the matching transactions are returned (paginated for large result sets)

### Requirement: Monthly summaries remain the source for month-grained reports

Month-by-month reporting and the current-month budget view SHALL continue to read the monthly `summaries` rollup unchanged. Arbitrary-range and sub-month reporting SHALL read raw transactions from the flat collection. The two sources MUST agree at calendar-month granularity.

#### Scenario: Month-grained chart reads summaries
- **WHEN** the Spending Report renders a per-category month-by-month chart
- **THEN** it reads from `summaries` as before, with no change to its read path

#### Scenario: Arbitrary-window total reads raw transactions
- **WHEN** a report totals spending over a window that does not align to whole months
- **THEN** it derives the total from raw transactions in the flat collection rather than from `summaries`

### Requirement: Large or unbounded reads are bounded or paginated

Live snapshot listeners SHALL remain bounded (e.g. to a month or explicit range) to protect the offline cache. All-history or large-range reads SHALL use pagination (`limit` + cursor) rather than an unbounded snapshot listener.

#### Scenario: Live list stays bounded
- **WHEN** the transaction list screen streams the current view
- **THEN** the underlying query is range-bounded and does not stream the entire ledger history

#### Scenario: Browsing all history
- **WHEN** the user scrolls a full-history view past the loaded page
- **THEN** the next page is fetched via a `limit` + `startAfterDocument` cursor
