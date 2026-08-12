## Why

Expenses today are a number, a category, and an optional note — there is no way to keep the evidence behind a transaction. Users reconciling a shared ledger (returns, warranties, reimbursements, "what was this $84 at Target?") have to find the paper or the email separately, and the answer is usually gone. A receipt image attached to the expense puts the evidence where the question gets asked.

A proof-of-concept exists on the unmerged branch `expense_tracker_photo` (commits `f03b915`, `b25a1c9`). It is reference material only: a prior review found that its Storage rules let any authenticated user read or overwrite any receipt in the project, editing an expense's date into a different month deletes the file while keeping the URL, replacing an existing receipt is silently discarded, removing a receipt is impossible, and the picker crashes on web. This change reimplements the feature correctly and retires that branch.

## What Changes

- **Attach one optional receipt image to an expense.** Available when creating an expense and when editing one. An expense has at most one receipt.
- **Replace and remove.** Editing an expense with an existing receipt allows swapping the image or clearing it outright. Both are currently impossible in the POC.
- **View from the expense list.** Expenses carrying a receipt are marked in the list and the image is openable in a constrained, scrollable viewer with explicit loading and error states.
- **Capture per platform.** iOS and Android offer camera or gallery. Web offers file upload. The implementation uses the bytes path (`XFile.readAsBytes` + `putData`) on every platform rather than `dart:io File`, which is unavailable on web.
- **Compress on device before upload** (target quality ~70, max dimension ~1600px), primarily to bound Cloud Storage consumption and secondarily so a single stored image renders inline anywhere. Actual output size is verified on all three platforms rather than assumed. The POC's `thumbnailUrl` field — declared, serialized, never populated — is **not** carried forward.
- **Object size enforced on the client.** The size limit is applied before upload so the user gets an actionable message rather than an opaque write error. The Storage rules carry only a generous abuse ceiling, well above any legitimate compressed receipt.
- **Stable receipt identity.** Files are keyed by a generated receipt ID stored on the expense, not by the expense document ID. This decouples the stored object from document churn, so moving an expense between month collections cannot orphan or destroy its receipt.
- **Ordered, reversible mutations.** Upload precedes the Firestore write, and a failed write releases the uploaded object. A month-change edit never touches Storage.
- **Deletion deferred only for the length of the undo window.** Deleting an expense does not delete its receipt immediately; the object is marked and held while the undo snackbar is on screen. If the snackbar is dismissed without undo, the object is deleted right then. If undo is used, the mark is cleared and the restored expense keeps its receipt. This keeps the existing undo affordance whole without leaving objects lying around.
- **A nightly sweep as backstop only.** A scheduled job reclaims marked objects whose deletion never completed — the app was killed mid-window, the delete failed, or a failed write orphaned an object. It is a safety net for the cases the prompt path misses, not the normal route.
- **Ledger-scoped Storage access, enforced by a custom auth claim.** Receipts live under a per-ledger prefix. Because Firebase Storage rules cannot read Firestore, membership is enforced via a `ledgerId` custom claim minted by a Cloud Function and refreshed when ledger membership changes. Rules additionally cap object size and restrict content type to images. **The Storage rules themselves are authored and deployed manually, outside this repo.** This change specifies the rule behavior the client depends on and ships the claim that makes it enforceable; applying the rules is a release step, not a code task.
- **iOS usage-description keys added.** `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are absent from `ios/Runner/Info.plist` today; without them iOS terminates the app on first picker use.
- **Retire the POC branch.** `expense_tracker_photo` is deleted once this lands on `main`.

### Not in scope

- Multiple receipts or non-image attachments (PDF) per expense.
- Server-side thumbnail generation, OCR, or any extraction of amount/merchant from the image.
- Backfilling receipts onto existing expenses (there are none to backfill).
- Any change to the summaries rollup. Receipts do not participate in totals.

### Sequencing against `flatten-ledger-storage`

This change **lands before** `flatten-ledger-storage` and is written against the current month-sharded layout (`ledger/{ledgerId}/{YYYY_MON}/*`). That ordering matters: under today's layout a date change across months is implemented as delete-from-old plus add-to-new, which is exactly the mechanism behind the POC's receipt-destroying bug. Handling it is therefore a hard requirement here, not a deferred one — the stable receipt ID and the "never touch Storage on a month change" rule exist to make that delete+add survivable.

The later flatten must carry the receipt fields through its migration and preserve them across the layout change. Once flattened, a cross-month move becomes a single field update and the hazard disappears on its own; the requirements written here remain correct and simply become easier to satisfy.

## Capabilities

### New Capabilities

- `expense-receipts`: Attaching, viewing, replacing, and removing a single optional receipt image on an expense. Covers per-platform capture (camera/gallery on mobile, file upload on web), on-device compression, the receipt indicator and viewer in the expense list, and the lifecycle guarantees binding a receipt to its expense across create, edit, category change, cross-month date change, and delete — including upload-before-write ordering and rollback on failure.
- `receipt-deferred-cleanup`: Reclamation of receipt objects that are no longer referenced. Covers marking an object rather than deleting it inline, holding it for the duration of the undo window, deleting it promptly when that window closes without an undo, clearing the mark when undo is used, and the scheduled backstop job that reclaims objects whose deletion never completed.
- `receipt-storage-access`: The access-control model for stored receipt objects. Covers the ledger-scoped Storage path layout, the `ledgerId` custom auth claim that carries ledger membership into Storage rules and its refresh on account link and unlink, and the rule behavior the client relies on — membership enforcement, object size cap, image-only content type. The rules are applied manually; this capability defines the contract they must satisfy and the client behavior when they reject a request.

### Modified Capabilities

None. `openspec/specs/` currently holds no established specs, so there are no existing requirements to delta against.

## Impact

**Client — data model**
- `lib/models/expense.dart` / `expense.g.dart`: new `receiptId` and `imageUrl` fields on `Expense`; `ExpenseWithCategoryData` inherits them. `Expense.copyWith` must carry the new fields or edits will silently drop receipts — the POC predates `copyWith` and does not account for it.

**Client — data layer**
- `lib/providers/expense_stream_provider.dart`: `addExpense`, `updateExpense`, `removeExpense` gain receipt handling with explicit ordering and rollback. The cross-month branch of `updateExpense` (currently `Future.wait([removeExpense, addExpense])`) must stop deleting the Storage object.
- `lib/providers/backend_provider.dart`: new `storageProvider`.
- New service encapsulating pick → compress → upload → delete, so platform branching lives in one place rather than in the form.

**Client — UI**
- `lib/widgets/expense_form.dart`: receipt picker, current-receipt preview, replace and remove controls; `onSubmit` signature changes to carry the picked image.
- `lib/screens/home/expense_list/expense_item.dart`: receipt indicator and the viewer dialog (constrained, scrollable, with `loadingBuilder` and `errorBuilder`).
- `lib/screens/home/expense_list/expenses_screen.dart`: `_addExpense` / `_updateExpense` plumbing.

**Infrastructure**
- Storage rules are authored and deployed **manually via the Firebase console** — no `firebase/storage.rules` file and no `storage` entry in `firebase/firebase.json`. This matches existing practice: the repo carries no `firestore.rules` either. The rule contract is specified in `receipt-storage-access` and must be applied before release; the emulator does not enforce it, so rule behavior needs a manual verification pass against the deployed bucket.
- Storage emulator wiring for debug builds in `lib/main.dart`.
- Cloud Storage must be enabled on the `taskr-1428` project and its default bucket provisioned.
- New Cloud Function in `firebase/functions/` to mint and refresh the `ledgerId` custom claim; the account link and unlink paths must trigger a refresh, and clients must force a token refresh so the claim takes effect without a re-login.
- New scheduled Cloud Function running nightly as a backstop, reclaiming marked receipt objects whose prompt deletion never completed, plus a new Firestore collection holding those markers. This is the project's first scheduled function, so Cloud Scheduler must be enabled.
- `_removeExpense` in `expenses_screen.dart` must await the undo snackbar's closed reason to decide between committing the deletion and clearing the mark.

**Platform config**
- `ios/Runner/Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`.
- Android manifest and Gradle config reviewed for `image_picker` requirements.

**Dependencies**
- Adds `image_picker`, `firebase_storage`, and an image compression package.

**Cost and quota**
- First use of Cloud Storage in this project; introduces storage and egress cost proportional to receipt volume, which on-device compression is intended to bound.

**Repository**
- Branch `expense_tracker_photo` (local and `origin`) deleted after this lands.
