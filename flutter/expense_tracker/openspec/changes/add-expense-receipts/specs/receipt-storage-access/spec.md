## ADDED Requirements

### Requirement: Ledger-scoped Storage path layout

Receipt objects SHALL be stored under a path scoped by ledger, of the form `receipts/{ledgerId}/{receiptId}`. The ledger segment SHALL be the ledger that owns the expense, and no receipt SHALL be written outside its owning ledger's prefix. A flat, unscoped namespace SHALL NOT be used, because it makes per-ledger access control impossible to express.

#### Scenario: Object written under the owning ledger

- **WHEN** a user attaches a receipt to an expense in ledger `L`
- **THEN** the object SHALL be written under the `receipts/L/` prefix

#### Scenario: Path segments are non-empty

- **WHEN** a receipt upload is attempted and the ledger ID or receipt ID is unavailable
- **THEN** the upload SHALL be aborted rather than writing to a malformed or unscoped path

### Requirement: Ledger membership carried by a custom auth claim

Because Firebase Storage rules cannot read Firestore, ledger membership SHALL be carried on the user's auth token as a custom `ledgerId` claim. A Cloud Function SHALL be the sole authority that sets this claim, and SHALL set it to the ledger the user currently belongs to. Clients SHALL NOT be able to set or alter the claim.

#### Scenario: Claim present for an established user

- **WHEN** an authenticated user who belongs to a ledger obtains an ID token
- **THEN** that token SHALL carry a `ledgerId` claim matching their ledger

#### Scenario: Claim is server-authored

- **WHEN** a client attempts to set or modify its own `ledgerId` claim
- **THEN** the attempt SHALL have no effect on the token issued by the auth service

#### Scenario: New account receives a claim

- **WHEN** a new user account is created and assigned a ledger
- **THEN** the `ledgerId` claim SHALL be set before receipt upload or viewing is expected to succeed

### Requirement: Claim refresh on ledger membership change

When a user's ledger membership changes — on account link and on unlink, in either direction — the `ledgerId` claim SHALL be updated to the user's new ledger, and the affected clients SHALL force an ID token refresh so the new claim takes effect without requiring the user to sign out and back in.

#### Scenario: User links to a partner's ledger

- **WHEN** an account link completes and the user's ledger changes
- **THEN** their `ledgerId` claim SHALL be updated to the new ledger and their client SHALL force a token refresh

#### Scenario: User unlinks to their own ledger

- **WHEN** an unlink completes and the user is moved to a different ledger
- **THEN** their `ledgerId` claim SHALL be updated accordingly and their client SHALL force a token refresh

#### Scenario: Access follows the claim after unlinking

- **WHEN** a user has been unlinked from a ledger and their token has refreshed
- **THEN** they SHALL no longer be able to read receipts under the former ledger's prefix

#### Scenario: Stale token before refresh

- **WHEN** a membership change has been applied but the client still holds a token carrying the previous `ledgerId`
- **THEN** receipt requests authorized by the stale claim SHALL be treated as a transient condition the client resolves by refreshing the token, and SHALL NOT be surfaced as data loss

### Requirement: Storage rule contract for receipt objects

The deployed Storage rules SHALL permit read and write on `receipts/{ledgerId}/{receiptId}` only when the requester is authenticated and their token's `ledgerId` claim equals the `{ledgerId}` path segment. Uploads SHALL additionally be rejected unless the object's content type is an image type and its size is at or below a defined ceiling. Deletion by a ledger member SHALL be permitted on the membership check alone — a delete request carries no resource to inspect, so applying the content-type and size checks to it would deny every deletion. All other paths in the bucket SHALL deny access by default.

The rules ceiling SHALL be 10 MB. It is an abuse backstop against a modified or malicious client, not the limit users encounter: the size limit users actually experience is 4 MB, enforced client-side before upload.

These rules are authored and applied manually via the Firebase console rather than being deployed from this repository. This requirement defines the contract the client depends on; the emulator does not enforce it, so conformance SHALL be verified manually against the deployed bucket before release.

#### Scenario: Member reads a receipt in their ledger

- **WHEN** an authenticated user whose `ledgerId` claim is `L` requests an object under `receipts/L/`
- **THEN** the request SHALL be permitted

#### Scenario: Non-member is denied

- **WHEN** an authenticated user whose `ledgerId` claim is not `L` requests an object under `receipts/L/`
- **THEN** the request SHALL be denied, for both read and write

#### Scenario: Unauthenticated request is denied

- **WHEN** an unauthenticated request targets any receipt object
- **THEN** it SHALL be denied

#### Scenario: Oversized upload is rejected

- **WHEN** an upload exceeds the 10 MB rules ceiling
- **THEN** the write SHALL be denied by the rules

#### Scenario: Member deletes their own ledger's receipt

- **WHEN** an authenticated member of ledger `L` deletes an object under `receipts/L/`
- **THEN** the request SHALL be permitted, and SHALL NOT be denied for lacking a content type or size

#### Scenario: Conforming client never reaches the ceiling

- **WHEN** a receipt is uploaded by a conforming client that has applied client-side compression and validation
- **THEN** its size SHALL be below the rules ceiling, so the rejection path is reachable only by a non-conforming client

#### Scenario: Non-image upload is rejected

- **WHEN** an upload declares a content type that is not an image type
- **THEN** the write SHALL be denied by the rules

#### Scenario: Unrelated bucket paths are closed

- **WHEN** any request targets a path outside the `receipts/` prefix
- **THEN** it SHALL be denied

#### Scenario: Manual conformance check before release

- **WHEN** the feature is prepared for release
- **THEN** the deployed rules SHALL be verified against the member, non-member, unauthenticated, oversized, and non-image cases above, since the emulator does not enforce them

### Requirement: Client behavior when Storage denies a request

The client SHALL treat a Storage permission denial as an expected, recoverable outcome rather than an unhandled error. A denied upload SHALL surface an explanatory message and SHALL NOT leave the expense in a partially saved state. A denied download SHALL render the viewer's error state.

#### Scenario: Upload denied by rules

- **WHEN** a receipt upload is rejected by Storage rules
- **THEN** the expense SHALL NOT be written, and the user SHALL be shown a message distinguishing a permission problem from a network failure

#### Scenario: Download denied by rules

- **WHEN** fetching a receipt image is rejected by Storage rules
- **THEN** the viewer SHALL present its error state rather than an unhandled image exception

#### Scenario: Oversized upload rejected client-side first

- **WHEN** a compressed image still exceeds the 4 MB client-side limit
- **THEN** the client SHALL report the problem with an actionable message before attempting the upload, rather than letting the user encounter an opaque write error from the rules
