## ADDED Requirements

### Requirement: Single optional receipt per expense

An expense SHALL carry at most one receipt image. The receipt is optional: expenses without one remain valid and unchanged in every existing behavior. The expense document SHALL record a generated `receiptId` and the resolved download `imageUrl` when a receipt is present, and SHALL record neither when it is absent. Receipts SHALL NOT participate in any total, summary, or budget calculation.

#### Scenario: Expense created without a receipt

- **WHEN** a user submits the expense form without picking an image
- **THEN** the expense SHALL be written with no `receiptId` and no `imageUrl`, and no Storage object SHALL be created

#### Scenario: Expense created with a receipt

- **WHEN** a user picks an image and submits the expense form
- **THEN** the expense SHALL be written with a generated `receiptId` and the download URL of the uploaded object

#### Scenario: Receipts do not affect totals

- **WHEN** a receipt is attached to, replaced on, or removed from an expense
- **THEN** the expense amount and every category summary total SHALL be unchanged by that action alone

#### Scenario: Picking a second image before submitting replaces the first

- **WHEN** a user picks an image, then picks another image without having submitted the form
- **THEN** the form SHALL hold only the most recently picked image, and only that image SHALL be uploaded on submit

### Requirement: Platform-appropriate capture sources

The system SHALL offer image sources appropriate to the running platform: on iOS and Android both device camera and photo gallery, and on web file upload from the local filesystem. Image data SHALL be read as bytes on every platform and uploaded via a bytes-based Storage write. The system SHALL NOT construct a `dart:io` `File` on any code path reachable from web, as that type is unavailable there.

#### Scenario: Mobile user chooses the camera

- **WHEN** a user on iOS or Android taps the receipt control and selects the camera source
- **THEN** the device camera SHALL open and the captured photo SHALL become the pending receipt

#### Scenario: Mobile user chooses the gallery

- **WHEN** a user on iOS or Android taps the receipt control and selects the gallery source
- **THEN** the photo gallery SHALL open and the selected photo SHALL become the pending receipt

#### Scenario: Web user uploads a file

- **WHEN** a user on web taps the receipt control
- **THEN** a file selection dialog SHALL open, and the selected image SHALL become the pending receipt without any `dart:io` `File` being constructed

#### Scenario: User cancels the picker

- **WHEN** a user opens any picker and dismisses it without choosing an image
- **THEN** the form SHALL retain whatever receipt state it had before, and no upload SHALL occur

#### Scenario: Non-image file selected on web

- **WHEN** a user on web selects a file that is not an image
- **THEN** the system SHALL reject the selection with an explanatory message and SHALL NOT attempt an upload

### Requirement: On-device compression before upload

The system SHALL compress and downscale a picked image on the device before uploading it, targeting approximately 70% JPEG quality and a maximum dimension of approximately 1600 pixels, preserving aspect ratio. Compression SHALL be performed by the application on every platform rather than delegated to the picker, whose sizing hints are best-effort and platform-dependent. Images already smaller than the maximum dimension SHALL NOT be upscaled. The uploaded object SHALL carry an image content type in its Storage metadata.

#### Scenario: Large camera photo is reduced

- **WHEN** a user attaches a multi-megabyte full-resolution camera photo
- **THEN** the uploaded object SHALL be the compressed, downscaled derivative rather than the original bytes

#### Scenario: Small image is not upscaled

- **WHEN** a user attaches an image whose largest dimension is already below the maximum
- **THEN** its dimensions SHALL be preserved rather than enlarged

#### Scenario: Compression is effective on every platform

- **WHEN** an equivalent full-resolution photo is attached on iOS, on Android, and on web
- **THEN** the uploaded object SHALL be materially smaller than the original on each of them, with no platform silently uploading the original bytes

#### Scenario: Content type is set

- **WHEN** any receipt is uploaded
- **THEN** the stored object SHALL have an image content type recorded in its metadata, not a generic binary type

### Requirement: Stable receipt identity independent of the expense document

Each receipt SHALL be identified by a `receiptId` generated at attach time and stored on the expense. The Storage object path SHALL be derived from the ledger and this `receiptId`, and SHALL NOT incorporate the expense document ID. The `receiptId` SHALL remain stable for the life of the receipt, including when the expense document is deleted and recreated under a different ID as part of an edit.

#### Scenario: Path does not depend on the document ID

- **WHEN** a receipt is uploaded for any expense
- **THEN** its Storage path SHALL be derived from the ledger ID and `receiptId` only

#### Scenario: Identity survives document recreation

- **WHEN** an edit causes the expense document to be deleted and recreated under a new document ID while keeping its receipt
- **THEN** the `receiptId` and the Storage object SHALL be unchanged, and the new document SHALL carry the same `receiptId` and `imageUrl`

#### Scenario: Replacing a receipt yields a new identity

- **WHEN** a user replaces an existing receipt with a different image
- **THEN** a new `receiptId` SHALL be generated for the replacement rather than overwriting the object at the existing path

### Requirement: Upload precedes the document write and rolls back on failure

When creating an expense with a receipt, the system SHALL upload the image and resolve its download URL before writing the expense document. If the document write fails, the system SHALL delete the uploaded object so that no unreferenced object remains, and SHALL report the failure to the user. If the upload itself fails, no expense document SHALL be written.

#### Scenario: Document write fails after a successful upload

- **WHEN** the receipt uploads successfully but the expense document write fails
- **THEN** the uploaded object SHALL be deleted, no expense SHALL be created, and the user SHALL be shown a failure message

#### Scenario: Upload fails

- **WHEN** the receipt upload fails
- **THEN** no expense document SHALL be written and the user SHALL be shown a failure message distinguishing the upload failure from a general save failure

#### Scenario: Rollback deletion itself fails

- **WHEN** the compensating delete of an uploaded object fails after a failed document write
- **THEN** the user SHALL still be shown the save failure, and the object SHALL be marked for deferred deletion so the scheduled sweep reclaims it rather than leaving it orphaned indefinitely

#### Scenario: Summary update fails after the expense is written

- **WHEN** the expense document is written successfully but the subsequent summary update fails and the expense document is rolled back
- **THEN** the receipt object SHALL also be released so it does not outlive the expense

### Requirement: Replacing a receipt on an existing expense

A user editing an expense that already has a receipt SHALL be able to replace it. On submit, the system SHALL upload the new image, point the expense at it, and release the previously stored object only after the expense document has been successfully updated. Replacement SHALL NOT be conditional on the expense having no existing receipt.

#### Scenario: Receipt replaced on an expense that already had one

- **WHEN** a user edits an expense with an existing receipt, picks a different image, and submits
- **THEN** the new image SHALL be uploaded, the expense SHALL reference the new `receiptId` and URL, and the previous object SHALL be released

#### Scenario: Replacement is never silently discarded

- **WHEN** a user picks a replacement image for an expense whose `imageUrl` is already set
- **THEN** the system SHALL upload and persist that replacement, and SHALL NOT complete the edit while leaving the original receipt in place

#### Scenario: Document update fails during replacement

- **WHEN** the replacement uploads but the expense document update fails
- **THEN** the newly uploaded object SHALL be deleted, the original receipt SHALL remain attached and intact, and the user SHALL be shown a failure message

#### Scenario: Releasing the superseded object fails

- **WHEN** the expense is successfully repointed at the replacement but releasing the superseded object fails
- **THEN** the edit SHALL be reported as successful, and the object SHALL be logged so the scheduled sweep reclaims it

### Requirement: Removing a receipt from an existing expense

A user editing an expense that has a receipt SHALL be able to remove it, leaving the expense intact without a receipt. On submit, the system SHALL clear `receiptId` and `imageUrl` on the document and release the stored object. Removal SHALL be reachable from the edit form as an explicit control.

#### Scenario: User removes a receipt

- **WHEN** a user edits an expense with a receipt, activates the remove control, and submits
- **THEN** the expense SHALL be saved with no `receiptId` and no `imageUrl`, and the stored object SHALL be released

#### Scenario: Removal is abandoned

- **WHEN** a user activates the remove control and then dismisses the form without submitting
- **THEN** the receipt SHALL remain attached to the expense and the stored object SHALL NOT be released

#### Scenario: Remove then pick a new image before submitting

- **WHEN** a user removes the existing receipt, then picks a new image, then submits
- **THEN** the outcome SHALL be a replacement: the new image attached and the original object released

#### Scenario: Remove control is absent without a receipt

- **WHEN** a user edits an expense that has no receipt
- **THEN** no remove control SHALL be offered

### Requirement: Receipts survive a cross-month date change

Editing an expense's date into a different calendar month SHALL preserve its receipt. Because the current storage layout implements a cross-month move as a delete of the old document plus creation of a new one, that path SHALL carry `receiptId` and `imageUrl` onto the new document and SHALL NOT delete, re-upload, or otherwise modify the Storage object.

#### Scenario: Date moved to another month with a receipt attached

- **WHEN** a user edits an expense that has a receipt, changing only its date to a different month, and submits
- **THEN** the resulting expense SHALL carry the same `receiptId` and a working `imageUrl`, and the stored object SHALL be untouched

#### Scenario: Storage is not touched by a month move

- **WHEN** a cross-month date change is processed for an expense with a receipt and no new image was picked
- **THEN** no Storage upload and no Storage delete SHALL be issued

#### Scenario: Month move combined with a replacement

- **WHEN** a user changes an expense's month and picks a replacement image in the same edit
- **THEN** the new object SHALL be uploaded exactly once, the new document SHALL reference it, and only the superseded object SHALL be released

#### Scenario: Month move combined with a removal

- **WHEN** a user changes an expense's month and removes its receipt in the same edit
- **THEN** the new document SHALL carry no receipt fields and the stored object SHALL be released

### Requirement: Deleting an expense marks its receipt for deletion

Deleting an expense SHALL release its receipt object rather than deleting it inline, so that the deletion remains undoable for as long as the undo affordance is offered. The expense document SHALL be deleted immediately. Once the undo affordance closes without being used, the object's deletion SHALL be committed. A failure to record the deletion mark SHALL NOT prevent or reverse the deletion of the expense.

#### Scenario: Expense with a receipt is deleted

- **WHEN** a user deletes an expense that has a receipt
- **THEN** the expense document SHALL be deleted and the receipt object SHALL be released while remaining readable

#### Scenario: Undo of a delete restores the receipt

- **WHEN** a deletion is undone by the existing undo affordance
- **THEN** the restored expense SHALL carry its original `receiptId` and a working `imageUrl`, and the deletion mark SHALL be cleared

#### Scenario: Undo window closes without undo

- **WHEN** the undo affordance for a deleted expense is dismissed without being used
- **THEN** the receipt object SHALL be deleted promptly rather than left for the scheduled backstop

#### Scenario: Marking fails

- **WHEN** an expense is deleted and the deletion mark cannot be recorded
- **THEN** the expense deletion SHALL still complete successfully, and the unreferenced object SHALL be logged so the sweep can reclaim it

#### Scenario: Removing a receipt during an edit also defers

- **WHEN** a user removes a receipt from an expense during an edit, or replaces it, superseding the previous object
- **THEN** the superseded object SHALL be marked for deferred deletion rather than deleted inline

### Requirement: Receipt indicator and viewer in the expense list

The expense list SHALL visually indicate which expenses carry a receipt, and SHALL offer an action to view it. The viewer SHALL constrain the image to the available viewport, allow scrolling or zooming when the image exceeds it, and present explicit loading and error states. The view action SHALL be offered only for expenses that have a receipt.

#### Scenario: Expense with a receipt is marked

- **WHEN** the expense list renders an expense carrying a receipt
- **THEN** a receipt indicator SHALL be shown on that row

#### Scenario: Viewing a receipt

- **WHEN** a user activates the view action on an expense with a receipt
- **THEN** the image SHALL be displayed in a viewer constrained to the viewport

#### Scenario: Tall image does not overflow

- **WHEN** the viewer displays an image taller than the available space
- **THEN** the image SHALL be scrollable or scaled to fit, and SHALL NOT produce a layout overflow

#### Scenario: Image is still loading

- **WHEN** the viewer is opened and the image has not finished downloading
- **THEN** a loading indicator SHALL be shown in place of the image

#### Scenario: Image fails to load

- **WHEN** the viewer is opened and the image cannot be retrieved
- **THEN** an explanatory error state SHALL be shown rather than an unhandled image error

#### Scenario: No view action without a receipt

- **WHEN** a user opens the action menu for an expense with no receipt
- **THEN** no view-receipt action SHALL be present
