## Context

The app stores expenses in month-sharded Firestore collections (`ledger/{ledgerId}/{YYYY_MON}/{expenseId}`) with a denormalized `summaries` rollup alongside. Mutations live in `ExpenseNotifier` (`lib/providers/expense_stream_provider.dart`). There is no Cloud Storage usage anywhere in the project today, no `firestore.rules` or `storage.rules` in the repo, and no custom auth claims.

A proof-of-concept on `expense_tracker_photo` (`f03b915`, `b25a1c9`) implemented receipts and was reviewed and rejected. Its defects are the design constraints here: globally readable/writable Storage rules, a cross-month edit that deletes the file while keeping the URL, a replacement path gated on `imageUrl == null` that silently discards new images, no removal path, `dart:io File` on web, missing iOS usage-description keys, orphaned objects on failure, and an unconstrained `Image.network` in the viewer.

Two facts about the current `main` matter and postdate the POC:

1. **Amortization exists.** `addAmortizedExpense` writes the first installment client-side and delegates months 2..N to the `createAmortizedExpenses` Cloud Function. `removeExpense` on any installment deletes the entire series via `deleteAmortizedSeries`. The POC never encountered this.
2. **`Expense.copyWith` exists** and is used by the amortization path. Any new field omitted from it is silently dropped.

Also relevant: `addExpense` today does not await the document write (`collectionRef.add(...)` is called inside a `.then` whose result is discarded) and returns a `List` from `Future.wait`, so the caller's `resp == null` failure check effectively never fires. Reliable rollback requires fixing that.

## Goals / Non-Goals

**Goals:**

- One optional receipt per expense, attachable on create, replaceable and removable on edit, viewable from the list.
- Correct behavior on iOS, Android, and web from a single code path.
- No orphaned Storage objects on any success path, and no receipt loss on any edit path — in particular the cross-month move.
- Real access control: a user can reach only their own ledger's receipts.
- Bounded storage cost via on-device compression, verified rather than assumed.
- Deletion that stays undoable, with unreferenced objects reclaimed on a schedule.

**Non-Goals:**

- Multiple receipts, or non-image attachments such as PDF.
- Server-side thumbnails, OCR, or field extraction from the image.
- Deploying Storage rules from this repo — they are applied manually.
- Guaranteeing zero orphans under process death before a deletion marker can be written. The nightly sweep covers everything short of that.
- Any change to summaries, budgets, or totals.

## Decisions

### D1: Store a `receiptId` and derive the path from it, not from the expense document ID

**Decision.** The expense carries `receiptId` (a UUID, generated at attach time) and `imageUrl`. The object lives at `receipts/{ledgerId}/{receiptId}`.

**Why.** The POC keyed objects by expense document ID. Under month-sharded storage a cross-month edit deletes the old document and creates a new one with a *different* ID, so the key changes under the file — the direct cause of the receipt-destroying bug. Decoupling the object from document identity makes document churn irrelevant: the move carries two fields forward and touches nothing in Storage.

**Alternatives considered.** *Key by expense ID* — rejected, it is the POC bug. *Key by a content hash* — enables dedup but makes deletion unsafe when two expenses share an image, and dedup is not worth that. *Wait for `flatten-ledger-storage`, where a date change is a field update and the hazard disappears* — rejected because receipts ship first; and the stable ID is worth having regardless, since it also survives the flatten migration unchanged.

### D2: Replacement generates a new `receiptId` rather than overwriting in place

**Decision.** Replacing a receipt uploads to a fresh path and deletes the superseded object after the document update succeeds.

**Why.** Overwriting in place makes rollback impossible — a failed document update would leave the expense pointing at a URL whose bytes are already the new image. Writing to a new path keeps the original intact until the switch is durable, and makes the failure path a single compensating delete of the *new* object. It also sidesteps Firebase download-URL token reuse on overwrite.

**Trade-off.** A brief window where two objects exist. Acceptable, and strictly safer than the alternative.

### D3: Upload before the document write; compensate on failure

**Decision.** Order is: compress → upload → resolve download URL → write/update the document → release superseded object (replacement) or nothing (create). If the document write fails, delete the just-uploaded object inline — it was never referenced, so there is nothing to undo and immediate reclamation is correct. If that compensating delete also fails, record a deletion marker so the sweep (D10) reclaims it, and still report failure to the user.

**Why.** The document must never reference an object that does not exist — a broken image is visible and permanent, whereas an orphaned object is invisible and merely costs storage. Uploading first makes the document write the commit point.

**Consequence.** `addExpense` must be restructured to actually await the document write and return a meaningful success/failure result, which today it does not.

**Alternatives considered.** *Write the document first, then upload and patch the URL in* — rejected; it makes a receipt-less intermediate state visible to the partner's live stream, and a failed upload leaves the expense permanently receipt-less with no signal. *A Cloud Function performing both writes transactionally* — rejected as disproportionate; Storage and Firestore cannot share a transaction anyway, so it moves the same compensation logic to the server.

### D4: A receipt belongs to an amortized series, not to a single installment

**Decision.** When a receipt is attached to an amortized expense, every installment document in the series carries the same `receiptId` and `imageUrl`. The object is deleted when the series is deleted, and not when an individual installment is removed.

**Why.** The receipt for a $1,200 annual bill amortized over twelve months is the bill; it is meaningful on every installment. This is also nearly free given existing behavior: `removeExpense` on any installment already deletes the *entire* series through `deleteAmortizedSeries`, so "delete the object when the series goes" needs no reference counting. And propagation is automatic — `createAmortizedExpenses` builds each installment as `{ ...template, ... }`, deleting only `id` (`firebase/functions/index.js:487-499`), so the two new fields reach months 2..N with no function change.

**Alternatives considered.** *Disallow receipts on amortized expenses* — simplest, but arbitrary from the user's perspective and exactly the case where a receipt matters most. *Attach only to the first installment* — the other eleven months show no receipt, which reads as a bug.

**Risk.** If a future change makes single-installment deletion possible without deleting the series, this becomes a shared-object deletion hazard. Called out in Risks.

### D5: `ledgerId` custom claim for Storage access control

**Decision.** A Cloud Function sets a `ledgerId` custom claim on the user's auth token. Storage rules compare that claim to the ledger segment of the object path. The rules are authored and applied manually in the Firebase console.

**Why.** Firebase Storage rules cannot read Firestore — cross-service `get()` is a Firestore-rules feature. Ledger membership therefore has to travel on the token. Per-user path scoping (`receipts/{uid}/...`) would be simpler but breaks the product: the ledger is shared, and a partner must be able to see receipts they did not upload.

**Consequences.** The claim must be set for existing users, not only new ones, and refreshed on link and unlink in both directions, with a client-side `getIdToken(true)` so it takes effect without re-login. Until a user's token carries the claim, receipt reads and writes fail closed.

**Alternatives considered.** *Rely on unguessable ledger IDs with authenticated-only rules* — security by obscurity, and the POC's version of this is what the review flagged. *Proxy all reads and writes through Cloud Functions issuing signed URLs* — genuinely secure and avoids claims entirely, but adds latency and function cost to every image view and is far more machinery than this needs.

### D6: Bytes everywhere, no `dart:io`

**Decision.** Read picked images as `Uint8List` via `XFile.readAsBytes()` and upload with `putData`, including on mobile. No `dart:io File` anywhere in the receipt path.

**Why.** One code path across three platforms. `File(pickedImage.path)` throws on web, and the POC's `kIsWeb` branch on the picker *source* while still constructing a `File` is precisely the trap. Uniform bytes also means the compression step has one input type.

**Trade-off.** Holding a compressed image in memory rather than streaming from disk. At ~1600px and quality 70 this is a few hundred kilobytes, which is immaterial.

### D7: Explicit client-side compression on every platform, then measure

**Decision.** Compress explicitly in our own code rather than delegating to the picker: decode, downscale to a maximum dimension of ~1600px preserving aspect ratio, and re-encode as JPEG at ~70% quality, on all three platforms. Then measure the actual uploaded object size on iOS, Android, and web and adjust from there.

**Why not rely on `image_picker`'s `imageQuality`/`maxWidth`/`maxHeight`.** Those parameters are best-effort and platform-dependent — `image_picker_for_web` has historically ignored `imageQuality` — and a no-op is silent, producing a working feature that quietly uploads full-resolution photos. Since bounding Cloud Storage consumption is the entire point (this is the project's first use of Storage and the only unbounded-growth surface it adds), the compression step needs to be something we control and can verify, not a hint we hope is honored.

**Implementation.** The pure-Dart `image` package works identically on all three platforms and operates on the `Uint8List` that D6 already establishes as the universal input. Run it off the UI isolate via `compute()` so a large decode does not jank the form. Passing the picker's own hints as well is harmless and may save work where they are honored.

**Verify before trusting.** Measure real uploaded byte size and dimensions on a physical iOS device, a physical Android device, and a browser. The target is well under 1 MB for a typical camera capture; if any platform lands far off that, revisit before building on top of it.

### D8: Encapsulate Storage work in a service, not in the provider or the form

**Decision.** A single `ReceiptService` owns pick → validate → compress → upload → resolve URL → delete. `ExpenseNotifier` calls it; the form holds only pending UI state (picked bytes, a remove flag).

**Why.** The POC scattered `FirebaseStorage.instance` across the provider and platform branching across the form, which is how the replace and remove paths ended up inconsistent. One seam also makes the whole feature mockable in tests without a Storage emulator.

### D9: Model the form's pending state explicitly

**Decision.** The edit form tracks a small explicit state — unchanged / replaced-with-new-bytes / removed — rather than inferring intent from whether `imageUrl` is null.

**Why.** The POC's replace bug is entirely an inference bug: it copied `imageUrl` forward and then gated the upload on `imageUrl == null`, making the two cases indistinguishable and silently dropping replacements. Naming the three states makes the logic total and each case directly testable.

### D10: Hold the object for the undo window, delete when it closes, sweep as backstop

**Decision.** Releasing an object writes a marker document to a Firestore collection (ledger, `receiptId`, backstop timestamp) instead of deleting it. The deletion is then committed as soon as the undo window closes without being used: the object is deleted, then the marker. Undo instead clears the marker and leaves the object alone. A nightly scheduled function reclaims any marker still present past its backstop time.

**Why deferred at all.** The app already offers undo on expense deletion. Inline deletion makes that undo lossy in a way the user cannot see coming — the expense comes back, the receipt is gone for good.

**Why commit promptly rather than let the sweep do it.** The undo window is the entire period during which the object might still be needed; once it closes, holding the object serves no purpose. Deleting immediately keeps storage close to what is actually referenced, makes the system's steady state easy to reason about, and reduces the sweep to a genuine exception path — if the sweep starts reclaiming a lot, something is wrong, which is a far more useful signal than a sweep that does routine work.

**The hook — revised after it failed in production.** The first implementation awaited the undo snackbar's `closed` future in `_removeExpense` and committed unless the reason was `action`. In testing on device the release landed correctly but the commit never ran, leaving the object stranded for the sweep. Rules were not the cause (both the Storage `delete` and the Firestore marker `delete` were verified live and correct), nor was the wiring.

The lesson is that a snackbar is a good *undo affordance* and a bad *scheduler*. `controller.closed` only resolves if the widget stays mounted, the messenger survives, and nothing interrupts the route — none of which cleanup should depend on. Worse, `commitDeletion` swallowed its errors by design, so the failure left no trace to diagnose without a device attached.

The commit is therefore scheduled inside `ReceiptService` by a timer it owns, started by `release()` itself so no caller can release an object and forget to commit it. `clearMarker()` cancels that timer, which is what makes undo safe — clearing the marker without cancelling would still delete the object the restored expense points at. Nothing in the path touches a widget.

**Interaction with the existing undo.** Undo calls `_addExpense(expense)`, which re-adds the expense as a *new* document. D1's stable `receiptId` already makes that safe — the object path never referenced the document ID — but the add path must not re-upload when the expense already carries `receiptId` and `imageUrl` and no new image was picked.

**Marker storage.** A Firestore collection, not Storage object metadata. The sweep needs to *find* due objects, and querying on an indexed timestamp is one query, whereas metadata would force a full bucket listing every night.

**Backstop time.** 24 hours — far longer than the 3-second snackbar, so the sweep can never race a live undo or an in-flight commit. Because it is only reached when the prompt path failed, an object left behind is reclaimed within a day at the outside.

**Alternatives considered.** *Inline delete with undo restoring no receipt* — simpler, but silently lossy and the worse product. *Sweep as the only deletion path* — every deleted receipt lingers up to a day, storage drifts above what is referenced, and a broken sweep is invisible because routine work and exceptional work look identical. *Storage lifecycle rules on a `deleted/` prefix* — requires moving objects between prefixes, which is a copy plus delete and invalidates download URLs, making undo harder rather than easier. *Reference counting* — unnecessary; D4 already guarantees one object per series.

**Consequence.** This is the project's first scheduled function; Cloud Scheduler must be enabled. The sweep must be idempotent and partial-failure tolerant, since it spans two systems that cannot share a transaction.

### D11: Client-side size limit, with a generous ceiling in the rules

**Decision.** The client rejects anything over **4 MB** before uploading, with an actionable message. The Storage rules carry a **10 MB** ceiling as an abuse backstop.

**Why.** These serve different purposes and are not redundant. A rules rejection reaches the user as an opaque write failure, so it is a poor place to enforce a limit a normal user might hit — that belongs on the client, before any bytes move. But the client is not a security boundary: without a ceiling in the rules, a modified client can upload arbitrary bulk to the bucket, and there is nothing else in the system to stop it. The ceiling sits high enough that a conforming client never reaches it, making it purely an abuse backstop rather than a second limit to reason about.

**Why 4 MB on the client when D7 targets well under 1 MB.** The client limit is a guard against compression having gone wrong or been skipped, not a target. Leaving headroom means an unusually large legitimate receipt still succeeds, while a full-resolution uncompressed photo — the failure mode that actually matters — is still caught before it reaches Storage. If the D7 measurements show typical output far below this, the limit can be tightened later; starting permissive avoids rejecting real receipts on day one.

## Risks / Trade-offs

- **Users with no `ledgerId` claim cannot use receipts** → The claim is minted by a trigger on writes to the user document, and there are no pre-existing users to backfill, so every account gets one from deployment onward. The residual case is an account whose document has not been written since the trigger went live: touching the document mints the claim. The client also forces a token refresh and retries once when a receipt request fails on permissions, which covers a merely stale token.
- **Manual Storage rules can drift from the client's assumptions, and the emulator will not catch it** → The rule contract is specified in `receipt-storage-access`; a manual conformance pass against the deployed bucket (member, non-member, unauthenticated, oversized, non-image) is a release gate, not an optional check.
- **Orphaned objects when the process dies between upload and document write** → Largely addressed by D10: any path that fails to reclaim an object it uploaded records a deletion marker instead, and the nightly sweep collects it. The residual case is process death before the marker itself is written, which is bounded, invisible, and cheap.
- **A silently broken sweep hides a silently broken commit path** → With prompt commit as the normal route, the sweep should reclaim almost nothing. That makes its reclaimed-count a useful alarm: a rising count means commits are failing. But it only works if someone looks — both counts must be logged per run and checked periodically.
- **A swallowed commit error is undiagnosable** → Exactly this happened on the first device test: the commit failed, the only trace was a `debugPrint`, and the device could not be reattached to read it. `commitDeletion` now writes `lastCommitError` and `lastCommitAttempt` onto the marker, so the next failure is readable straight from Firestore. Silent-by-design was right for the user and wrong for the operator.
- **The commit depends on the app staying alive through the undo window** → A user who force-quits or backgrounds the app during those seconds leaves the object for the backstop. Expected and harmless, but it means storage will always run slightly above the referenced set.
- **A marker written for an object that is still referenced would destroy a live receipt** → Only the three release paths write markers, and undo clears them; the sweep's correctness depends on that invariant holding, so tests must cover release-then-undo and release-then-replace.
- **A future change allowing single-installment deletion would break D4's shared object** → Documented here and in the spec; if installment-level deletion is ever introduced, receipt deletion must become series-aware at that time.
- **`createAmortizedExpenses` may not propagate unrecognized template fields** → Verify against `firebase/functions/index.js` during implementation; if it whitelists fields, it needs the two new ones added and a redeploy.
- **First Storage usage introduces new cost and a new failure domain** → Compression bounds object size; rules cap it independently; receipts are optional so a Storage outage degrades one feature rather than the app.
- **`addExpense`'s current fire-and-forget write means failures are already invisible** → Fixing it is required for rollback and will make previously-silent failures start surfacing to users. That is the correct outcome but is a visible behavior change worth noting in review.
- **Web file upload accepts anything the user selects** → Validate content type client-side before upload; the rules reject non-images as a second line of defense.

## Migration Plan

No data migration — no existing expense has a receipt, and both new fields are optional and absent-by-default. Existing documents and the summaries rollup are untouched.

Deployment order:

1. Enable Cloud Storage on `taskr-1428` and provision the default bucket; enable Cloud Scheduler for the sweep.
2. Deploy the claim-setting Cloud Function. No backfill is required — there are no existing users, so the trigger covers every account from deployment onward.
3. Deploy the scheduled sweep. It is a no-op until markers exist, so it can safely go out before the client.
4. Apply the Storage rules manually in the console and run the conformance pass from `receipt-storage-access`.
5. Release the client.

Rollback: the client release can be reverted independently — the new fields are additive and ignored by prior versions, so an expense created with a receipt still reads correctly on an older build (it simply shows no receipt). The claim and the rules are harmless if left in place.

Forward compatibility: `flatten-ledger-storage` must carry `receiptId` and `imageUrl` through its backfill. Once flattened, the cross-month path collapses to a field update and the D1 hazard disappears, but nothing specified here needs to change.

Cleanup: delete branch `expense_tracker_photo`, local and `origin`, once this lands on `main`.

## Open Questions

All resolved before implementation:

- ~~**Amortized template propagation (D4).**~~ `createAmortizedExpenses` builds each installment as `{ ...template, ... }` and deletes only `id` (`firebase/functions/index.js:487-499`), so `receiptId` and `imageUrl` propagate to months 2..N with no function change or redeploy. The client's `addAmortizedExpense` writes the first installment from the same template, so all N installments share one receipt reference as D4 requires.
- ~~**Compression path (D7).**~~ Compress explicitly in our own code on all three platforms rather than relying on the picker's hints, then measure actual output. See D7.
- ~~**Size limits (D11).**~~ 4 MB client-side, 10 MB rules ceiling.
- ~~**Backstop time (D10).**~~ 24 hours, with the sweep running nightly.

One item remains open by design rather than by omission: the D7 measurements are taken during implementation and could justify revisiting the compression parameters or tightening the 4 MB client limit. Nothing downstream depends on that outcome — a wrong guess costs storage, not correctness.
