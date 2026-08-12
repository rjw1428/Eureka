## ADDED Requirements

### Requirement: Releasing an object marks it rather than deleting it

Releasing a receipt object SHALL mean recording a deletion marker for it, not immediately deleting it from Storage. A released object SHALL remain readable until its deletion is committed. The marker SHALL record the object's ledger, its `receiptId`, and a backstop eligibility time after which the scheduled sweep may reclaim it unconditionally.

Throughout the receipt specifications, "release" refers to this operation and "delete" to actual removal from Storage. The paths that release an object are: deleting an expense that has a receipt, removing a receipt during an edit, and superseding a receipt by replacement.

#### Scenario: Released object remains readable

- **WHEN** a receipt object is released
- **THEN** a deletion marker SHALL be recorded and the object SHALL still be retrievable from Storage

#### Scenario: Marker records ledger, receipt, and backstop time

- **WHEN** a deletion marker is recorded
- **THEN** it SHALL carry the ledger, the `receiptId`, and the backstop eligibility timestamp

#### Scenario: Releasing an already-released object

- **WHEN** an object that already has a deletion marker is released again
- **THEN** the operation SHALL succeed without creating a duplicate marker or extending the existing backstop time

### Requirement: Deletion is committed when the undo window closes

When an expense deletion is presented with an undo affordance, the system SHALL hold the released object for the lifetime of that affordance and SHALL commit the deletion as soon as the affordance is dismissed without being used. Committing SHALL delete the Storage object and then delete its marker. The system SHALL NOT wait for the scheduled sweep to reclaim an object whose undo window has closed normally.

#### Scenario: Undo window closes without being used

- **WHEN** the undo affordance for a deleted expense is dismissed without the user activating undo
- **THEN** the receipt object SHALL be deleted and its marker SHALL be deleted

#### Scenario: Undo window is superseded by another deletion

- **WHEN** the undo affordance is dismissed because a subsequent action replaced it, rather than by timing out
- **THEN** the deletion SHALL still be committed, since the user did not undo

#### Scenario: Commit failure leaves the marker in place

- **WHEN** committing the deletion fails
- **THEN** the marker SHALL be retained so the scheduled sweep reclaims the object later, and the failure SHALL NOT be surfaced to the user

#### Scenario: Expense deletion is not blocked by the commit

- **WHEN** an expense with a receipt is deleted
- **THEN** the expense document SHALL be removed immediately, independent of when the receipt object's deletion is committed

### Requirement: Deletion markers are writable only by the owning ledger

A marker causes the sweep to delete the object it names, so the marker collection is a deletion-trigger surface and SHALL be protected accordingly. Firestore rules SHALL permit a client to read, create, and delete a marker only when its `ledgerId` matches the requester's ledger. Markers SHALL NOT be updatable, and the collection SHALL NOT be queryable by clients.

Because the release path reads a marker inside a transaction and usually finds none, reading a non-existent marker SHALL be permitted — otherwise releasing throws and the object is never reclaimed.

#### Scenario: Member marks their own ledger's object

- **WHEN** a member of ledger `L` creates a marker whose `ledgerId` is `L`
- **THEN** the write SHALL be permitted

#### Scenario: Marking another ledger's object is denied

- **WHEN** any client creates a marker whose `ledgerId` is not their own
- **THEN** the write SHALL be denied, so no one can schedule the destruction of another ledger's receipt

#### Scenario: Reading a marker that does not exist

- **WHEN** the release transaction reads a marker that has never been written
- **THEN** the read SHALL be permitted and report absence, rather than being denied

#### Scenario: Markers cannot be rewritten

- **WHEN** any client attempts to update an existing marker
- **THEN** the write SHALL be denied, so a backstop time cannot be pushed out indefinitely

### Requirement: Undo clears the marker and restores the receipt

Activating undo SHALL clear the deletion marker and SHALL NOT delete the object, so the restored expense keeps a working receipt. Because undo re-adds the expense as a new document, the restored document SHALL carry the original `receiptId` and `imageUrl`, and the restore SHALL NOT re-upload the image.

#### Scenario: Undo restores a working receipt

- **WHEN** a user activates undo on a deleted expense that had a receipt
- **THEN** the marker SHALL be cleared, the object SHALL remain in Storage, and the restored expense SHALL display its receipt

#### Scenario: Restore does not re-upload

- **WHEN** an expense carrying `receiptId` and `imageUrl` is added with no newly picked image, as happens on undo
- **THEN** no upload SHALL be performed and the existing fields SHALL be written through unchanged

#### Scenario: Restored expense has a different document ID

- **WHEN** undo re-adds the expense under a new document ID
- **THEN** the receipt SHALL still resolve, because the object path derives from `receiptId` rather than the document ID

#### Scenario: Marker clearing fails

- **WHEN** undo succeeds but the deletion marker cannot be cleared
- **THEN** the failure SHALL be logged, and the object SHALL be treated as at risk of backstop reclamation rather than the restore being reversed

### Requirement: Backstop eligibility outlasts the undo window

The backstop eligibility time SHALL be far longer than any undo window, and SHALL be at least 24 hours. The sweep SHALL NOT reclaim an object before its backstop time, so it can never race a live undo affordance or an in-flight commit.

#### Scenario: Object not reclaimed while undo is still possible

- **WHEN** the sweep runs while an undo affordance for a marked object is still on screen
- **THEN** that object SHALL be left intact, because its backstop time has not passed

#### Scenario: Backstop is not the normal path

- **WHEN** deletions proceed normally
- **THEN** their objects SHALL have been committed long before their backstop time, and the sweep SHALL find no markers for them

### Requirement: Scheduled sweep reclaims whatever the prompt path missed

A scheduled job SHALL run nightly, find every deletion marker whose backstop time has passed, delete the corresponding Storage object, and delete the marker. It exists to catch deletions that never committed — the app was killed during the undo window, the commit failed, or a failed write orphaned an object. The sweep SHALL be idempotent and SHALL tolerate partial failure: an error on one object SHALL NOT prevent the remaining objects from being processed, and a failed object SHALL retain its marker so a later run retries it.

#### Scenario: Deletion that never committed is reclaimed

- **WHEN** the app is terminated while an undo affordance is on screen, leaving the marker in place past its backstop time
- **THEN** the sweep SHALL delete the object and its marker

#### Scenario: Object already absent

- **WHEN** the sweep processes a marker whose Storage object no longer exists
- **THEN** the marker SHALL be deleted and the run SHALL NOT be treated as failed

#### Scenario: One failure does not halt the run

- **WHEN** deleting one object fails during a sweep
- **THEN** the remaining eligible objects SHALL still be processed, and the failed object's marker SHALL be retained for a subsequent run

#### Scenario: Repeated runs are safe

- **WHEN** the sweep runs twice in succession over the same data
- **THEN** the second run SHALL make no further changes and SHALL NOT error

#### Scenario: Sweep observability

- **WHEN** a sweep run completes
- **THEN** it SHALL log the number of objects reclaimed and the number of failures, so a persistently failing commit path is detectable as a rising backstop-reclamation count

### Requirement: Sweep reclaims orphaned objects from failed writes

Objects left unreferenced by a failed write — where the compensating inline delete could not complete — SHALL be reclaimable by the same sweep. Any path that fails to delete an object it uploaded SHALL record a deletion marker for it so the object does not persist indefinitely.

#### Scenario: Failed rollback is swept

- **WHEN** an upload succeeds, the expense write fails, and the compensating delete also fails
- **THEN** a deletion marker SHALL be recorded and the sweep SHALL reclaim the object once its backstop time passes

#### Scenario: Orphan does not require a live expense

- **WHEN** the sweep processes a marker for an object never referenced by any expense document
- **THEN** it SHALL be reclaimed on the same terms as any other marked object
