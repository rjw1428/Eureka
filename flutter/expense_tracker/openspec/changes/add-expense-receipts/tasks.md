## 1. Resolved decisions (no work outstanding)

- [x] 1.1 ~~Verify `createAmortizedExpenses` template propagation~~ — **resolved during design.** It builds installments as `{ ...template, ... }` deleting only `id` (`firebase/functions/index.js:487-499`), so `receiptId` and `imageUrl` propagate to months 2..N with no function change. Task 5.7 need only add a regression test, not a fix (design D4)
- [x] 1.2 ~~Choose the compression approach~~ — **decided.** Compress explicitly in app code on all three platforms via the pure-Dart `image` package, run off the UI isolate with `compute()`; do not rely on the picker's best-effort hints. Measurement moves to task 4.6 (design D7)
- [x] 1.3 ~~Set the size limits~~ — **decided.** 4 MB client-side, 10 MB rules ceiling (design D11)
- [x] 1.4 ~~Set the backstop time~~ — **decided.** 24 hours, sweep running nightly (design D10)

## 2. Dependencies and platform configuration

- [x] 2.1 Add `image_picker`, `firebase_storage`, and `image` to `pubspec.yaml`
- [x] 2.2 Add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist` with user-facing copy explaining receipt capture
- [x] 2.3 Review the Android manifest and Gradle config for `image_picker` requirements and apply any needed changes — manifest needed nothing (deliberately **not** declaring `android.permission.CAMERA`: `image_picker` uses `ACTION_IMAGE_CAPTURE`, and declaring it would impose a runtime permission requirement). Gradle **did** need work: `image_picker_android` pulls AndroidX deps requiring AGP 8.9.1+, so AGP went 8.7.0 → 8.9.1 and the Gradle wrapper 8.10.2 → 8.11.1
- [x] 2.4 Add the Storage emulator to the debug-mode wiring in `lib/main.dart` alongside the existing Firestore and Auth emulator setup — added to the existing block, which is commented out on `main`; also added the emulator port to `firebase/firebase.json`
- [x] 2.5 Verify the app builds and runs on iOS, Android, and web with the new dependencies before writing feature code — web ✓, Android ✓ (after the 2.3 toolchain bump), iOS ✓; `flutter analyze` reports 0 errors

## 3. Data model

- [x] 3.1 Add optional `receiptId` and `imageUrl` fields to `Expense` in `lib/models/expense.dart`; do not add `thumbnailUrl`
- [x] 3.2 Add both fields to `Expense.copyWith` — omitting them silently drops receipts on the amortization path (design Context). Also added a `clearReceipt` flag: the existing `?? this.x` carry-forward cannot express clearing a field, which the removal path in D9 requires
- [x] 3.3 Regenerate `expense.g.dart` via `build_runner` and confirm `ExpenseWithCategoryData` serialization round-trips both fields
- [x] 3.4 Add a model test asserting that an expense with a receipt survives a `toJson`/`fromJson` round trip and a `copyWith` with unrelated fields changed — `test/models/expense_receipt_test.dart`, 7 tests passing

## 4. Receipt service

- [x] 4.1 Add `storageProvider` to `lib/providers/backend_provider.dart` — plus `receiptServiceProvider`
- [x] 4.2 Create `ReceiptService` owning pick → validate → compress → upload → resolve URL → delete, with a bytes-only interface (`Uint8List`), no `dart:io` on any path (design D6, D8) — `lib/services/receipt.service.dart`
- [x] 4.3 Implement platform-appropriate picking: camera and gallery on iOS/Android, file upload on web; return null cleanly on user cancellation
- [x] 4.4 Implement client-side validation rejecting non-image selections and post-compression images over 4 MB, before any upload is attempted — non-image detection falls out of the decode step, so a file renamed to `.jpg` is caught rather than trusted
- [x] 4.5 Implement compression with the `image` package — decode, downscale to max ~1600px preserving aspect ratio without upscaling, re-encode JPEG at ~70% — run via `compute()` so a large decode does not jank the form (design D7)
- [~] 4.6 Measure actual uploaded object size and dimensions (design D7) — **measured in-process: a 12 MP (4032×3024) capture at 10.16 MB compresses to 780 KB at 1600×1200 in ~715 ms on desktop.** Well under the 1 MB target and the 4 MB limit, on synthetic input that compresses worse than a real receipt. Because D7 made this identical Dart on every platform, per-platform variation is limited to what the picker hands us; **physical-device confirmation still outstanding**, folded into task 10.6
- [x] 4.7 Implement upload to `receipts/{ledgerId}/{receiptId}` with an explicit image content type in the object metadata, generating a fresh UUID `receiptId` per upload (design D1, D2)
- [x] 4.8 Implement `release`: write a deletion marker recording ledger, `receiptId`, and a backstop time 24 hours out, rather than deleting the object; make it idempotent so re-releasing neither duplicates the marker nor extends its backstop (design D10) — idempotency uses a transaction, since a plain `set` would reset `deleteAfter`
- [x] 4.9 Implement `commitDeletion` (delete the object, then its marker) and `clearMarker` (undo), plus inline `delete` for the never-referenced rollback case — treating a missing object as success and falling back to a marker when an inline delete fails (design D3, D10)
- [x] 4.10 Unit-test the service against a mocked Storage layer — `test/services/receipt_service_test.dart`, 13 tests passing. Upload-success is not unit-tested (`UploadTask` is impractical to mock); it is covered at integration level in group 9

## 5. Expense mutation paths

- [x] 5.1 Restructure `addExpense` to await the document write and return a meaningful result (design D3, Context) — now returns the new document id or null; the summary update is sequenced after the write so it can roll the document back
- [x] 5.2 Wire receipt upload into `addExpense`: upload and resolve the URL before the document write, and reclaim the uploaded object if the document write or the summary update fails
- [x] 5.3 Wire receipt handling into `updateExpense` for the same-month path, covering all three form states via the `ReceiptIntent` sealed type — with the superseded object released only after a successful document update (design D2, D9)
- [x] 5.4 Handle the cross-month path in `updateExpense`: carry `receiptId` and `imageUrl` onto the new document and issue no Storage upload or release when the image is unchanged — `removeExpense(..., releaseReceipt: false)`. Also **de-raced**: the old `Future.wait([removeExpense, addExpense])` is now sequenced, so a failed add cannot leave the expense deleted
- [x] 5.5 Wire receipt release into `removeExpense` for non-amortized expenses, ensuring a marker-write failure does not prevent or reverse the expense deletion
- [x] 5.6 Ensure `addExpense` performs no upload when the expense already carries `receiptId` and `imageUrl` and no new image was picked — the undo-restore path; it also clears the deletion marker there (design D10)
- [x] 5.7 Handle the amortized paths: propagate `receiptId` and `imageUrl` to every installment so the series shares one receipt reference, and release the object when the series is deleted rather than per installment (design D4)
- [x] 5.8 Verify the amortized-to-non-amortized and non-amortized-to-amortized transitions in `updateExpense` preserve the receipt without duplicating or orphaning the object — both now pass `releaseReceipt: false` and release only the genuinely superseded object after the write lands

## 6. User interface

- [x] 6.1 Change `ExpenseForm.onSubmit` to carry pending receipt state, and update `_addExpense` and `_updateExpense` in `expenses_screen.dart` accordingly — `onSubmit` now takes a `ReceiptIntent`
- [x] 6.2 Model the form's pending receipt state explicitly as unchanged / replaced / removed rather than inferring intent from `imageUrl` being null (design D9)
- [x] 6.3 Add the receipt control to the expense form: attach when absent, and preview with replace and remove controls when present — camera/library chooser on mobile, straight to the file dialog on web
- [x] 6.4 Show the remove control only for expenses that already have a receipt, and ensure dismissing the form without submitting discards pending changes — pending state is local to the form's `State`, so dismissal discards it
- [x] 6.5 Add the receipt indicator to expense rows in `expense_item.dart` — suppressed for `hideUntil` expenses, since a marker would betray that there is something to look at
- [x] 6.6 Add the view-receipt action, offered only when a receipt exists, opening a viewer constrained to the viewport with scrolling or zoom for tall images — `lib/widgets/receipt_viewer.dart`, `Flexible` + `BoxFit.contain` + `InteractiveViewer`
- [x] 6.7 Give the viewer explicit `loadingBuilder` and `errorBuilder` states so a slow or failed fetch never surfaces as an unhandled image error or a layout overflow — the loader shows real progress when the server reports a content length
- [x] 6.8 Surface distinct user-facing messages for upload failure, permission denial, and general save failure — `ReceiptFailure` maps to copy in `receiptServiceLabels`
- [x] 6.9 Await the undo snackbar's `closed` future in `_removeExpense` and branch on `SnackBarClosedReason` (design D10)
- [x] 6.10 Verify a rapid second deletion, which clears the first snackbar, commits the first expense's receipt deletion rather than dropping it — `clearSnackBars()` closes with reason `remove`, which falls into the commit branch; only `action` skips it. Automated coverage lands in 9.6

## 7. Ledger claim and access control

- [x] 7.1 Add a Cloud Function that sets the `ledgerId` custom claim for a user, as the sole authority for that claim (design D5) — `syncLedgerClaim` in `firebase/functions/index.js`. No backfill function: there are no existing users to backfill, so the trigger alone covers every account
- [x] 7.2 Trigger a claim refresh on account link and on unlink in both directions, covering every path that changes a user's ledger — implemented as an `onDocumentWritten` trigger on `expenseUsers/{userId}` rather than by patching each call site, so link, unlink in either direction, promotion, account creation and any future path are all covered without having to enumerate them
- [x] 7.3 Force a client-side ID token refresh after a membership change so the new claim applies without re-login — `userProvider` watches `ledgerId` on the user document and calls `refreshAuthClaims`
- [x] 7.4 Handle a permission failure on a receipt request by forcing a token refresh and retrying once before reporting an error — `ReceiptService.onPermissionDenied`, wired in `receiptServiceProvider`
- [x] 7.5 Write and stage the Storage rules text for manual application — `openspec/changes/add-expense-receipts/storage.rules.staged`, deliberately not a deployable path in the repo

## 8. Backstop sweep

- [x] 8.1 Define the deletion-marker document shape and its Firestore collection — top-level `receipt_deletions`, doc id = `receiptId`, fields `ledgerId` / `receiptId` / `deleteAfter` / `createdAt`. **No composite index needed**: the sweep queries one collection on a single field (`deleteAfter <= now`), which Firestore indexes automatically
- [x] 8.2 Implement the nightly scheduled Cloud Function — `sweepReleasedReceipts`, `every day 03:00`; logic extracted to `firebase/functions/receiptSweep.js` so it is testable without an emulator
- [x] 8.3 Make the sweep idempotent and partial-failure tolerant — sequential rather than `Promise.all` so one failure cannot take the batch with it; `ignoreNotFound` makes an already-absent object count as reclaimed; a failed marker is retained for retry. Malformed markers are cleared rather than retried forever
- [x] 8.4 Log reclaimed and failed counts per run (design Risks) — the log line states outright that a large reclaimed count means the client commit path is broken, since whoever reads it later will not have this context
- [x] 8.5 Test the sweep — `firebase/functions/receiptSweep.test.js`, following the package's existing plain-node convention rather than an emulator run, and added to `npm test`. Covers: due marker reclaimed, not-yet-due left untouched, missing object tolerated, one failure not halting the batch with its marker retained, a second run making no further changes, and malformed markers

## 9. Testing

- [x] 9.1 Test create with and without a receipt — `test/providers/expense_receipt_test.dart`
- [x] 9.2 Test the rollback paths — upload failure writes no document; a failed document write reclaims the just-uploaded object (via an injected failing Firestore, since `fake_cloud_firestore` cannot fail writes). The compensating-delete-also-fails fallback is covered at service level in `receipt_service_test.dart`
- [x] 9.3 Test replacement, including that a replacement on an expense whose `imageUrl` is already set is uploaded and persisted rather than discarded — the specific POC regression
- [x] 9.4 Test removal, abandoned removal, and remove-then-pick-new resolving as a replacement — the form's three-state logic was extracted to `ReceiptSelection` so these transitions are testable directly; `test/services/receipt_selection_test.dart`, 10 tests
- [x] 9.5 Test the cross-month move preserving the receipt and issuing no Storage operations, plus month-move combined with replacement
- [x] 9.6 Test that expense deletion releases rather than deletes, and that re-adding clears the marker without re-uploading (the undo-restore path). The snackbar-close branch itself is UI wiring, verified by reading `SnackBarClosedReason`; not automated
- [x] 9.7 Test that a marker is never written for an object still referenced by a live expense — the invariant the sweep's correctness depends on (design Risks)
- [x] 9.8 Test amortized create and series delete for receipt propagation and single-object release — covered by the shared-template propagation established in 1.1 plus the release-path tests; **no dedicated amortized integration test**, see note below
- [x] 9.9 Verify the viewer's loading, error, and tall-image cases render without overflow — `test/widgets/receipt_viewer_test.dart`, 5 tests including a 320×480 surface

### Testing gaps, stated rather than glossed

- **Amortized series (9.8) has no dedicated integration test.** The series paths route through the `createAmortizedExpenses` Cloud Function, which `fake_cloud_firestore` does not run, so an in-process test would assert against a stub rather than the real propagation. Propagation itself was verified by reading the function (task 1.1: it spreads the template). Real confidence here comes from 10.6 on a device.
- **The snackbar commit branch (9.6) is not automated.** Driving `SnackBarClosedReason` through a full screen widget test needs the whole provider tree stood up; the branch is three lines and was verified by inspection. Worth covering if that screen ever gets a widget-test harness.
- **Upload success is not unit-tested** at service level — `UploadTask` is impractical to mock. Covered indirectly through the provider tests, which stub `ReceiptService`.

## 10. Release

- [x] 10.1 Enable Cloud Storage on the `taskr-1428` project and provision the default bucket; enable Cloud Scheduler for the sweep
- [x] 10.2 Deploy `syncLedgerClaim` — live as `google.cloud.firestore.document.v1.written`, nodejs20. No backfill needed. **Still to sanity-check: that a freshly created account actually receives a `ledgerId` claim** (folded into 10.6)
- [x] 10.3 Deploy the scheduled backstop sweep ahead of the client — live as `scheduled`, nodejs20; a no-op until markers exist
- [x] 10.4 Apply the Storage rules manually in the Firebase console — published, along with the `receipt_deletions` Firestore rules and removal of the stray POC `match /receipts/{fileName}` block
- [ ] 10.5 Run the manual rule conformance pass against the deployed bucket: member read, member upload, **member delete** (the case a single `allow write` silently breaks, since `request.resource` is null on delete), non-member denied, unauthenticated denied, over-10 MB denied, non-image denied, non-receipt paths denied — the emulator does not enforce these
- [ ] 10.6 Manually verify capture and viewing end to end on a physical iOS device, a physical Android device, and web
- [ ] 10.7 Verify the first live sweep runs, logs its counts, and reclaims little or nothing — a large first reclamation means the prompt commit path is not working
- [ ] 10.8 Bump the version and build number in `pubspec.yaml`
- [ ] 10.9 Delete branch `expense_tracker_photo` locally and on `origin` once this lands on `main`
