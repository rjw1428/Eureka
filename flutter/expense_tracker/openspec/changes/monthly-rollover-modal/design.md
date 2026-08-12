## Context

The app tracks a shared household ledger. Budget categories live in `ledger/{ledgerId}.budgetConfig` (`lib/providers/budget_provider.dart`), raw expenses in per-month subcollections keyed `YYYY_MON` (`formatMonth`, `lib/providers/expense_provider.dart:12`; mirrored server-side by `monthKey` in `firebase/functions/dateKey.js`), and per-category-per-month roll-ups in `ledger/{ledgerId}/summaries/{YYYY_MON}_{categoryId}`.

`currentSummaryProvider` (`lib/providers/expense_stream_provider.dart:392`) already computes this month's spend per category, and `activeBudgetCategoriesWithSpend` (`lib/providers/budget_provider.dart:50`) already derives `delta = budget - spent`, which the expense form renders as "Remaining / Over". Amortized expenses are written ahead into future months by the `createAmortizedExpenses` Cloud Function, so a future month's summary can already be non-zero on day one — this is exactly the "already committed" figure the rollover modal must display.

Nothing today reacts to a month boundary. When the calendar flips, every category silently resets to its full budget and last month's overspend disappears.

Constraints: Flutter + Riverpod, Firestore, `firebase-functions` v2 (`onCall` / `onDocumentCreated` only are currently imported). Two users may be on one ledger simultaneously; both may launch the app on the 1st.

## Goals / Non-Goals

**Goals:**
- Detect the first launch of a new month with unhandled prior-month overspend, per ledger (not per device).
- Let the user distribute the single overspend pool across any active category, with live per-category context (committed / budget / left to spend).
- Make the resulting rollovers indistinguishable from ordinary expenses to every downstream consumer (summaries, bar chart, totals, remaining-budget math, edit/delete).
- Record completion once, ledger-wide, and notify the other users on the ledger.
- Keep the modal strictly optional and non-blocking.

**Non-Goals:**
- Automatic rollover without user confirmation.
- Rolling *under*spend forward as extra budget (credit). Only overspend is carried.
- Backfilling rollovers for months already skipped. If a user misses the prompt for a month, that month's overspend is gone once the month passes.
- Changing configured budgets. `budgetConfig.budget` is never mutated.
- A notification-settings toggle for the rollover notification (see Decisions).

## Decisions

### D1: Rollovers reduce the month's budget; they are not expenses

A rollover writes no expense. Each non-zero allocation is stored as a per-month **budget adjustment**, and the month's effective budget for a category becomes `configured budget − allocation`.

*Why:* an expense record asserts that money was spent, and a rollover is not a purchase. Recording one would corrupt the thing the ledger exists to report — the expense list, the per-category totals, and every spend figure derived from them would overstate what the household actually spent last month. Reducing the budget expresses the real intent ("we have less to spend this month because we overspent last month") without inventing a transaction. The visible consequence, and an intended one, is that **budget varies month to month**: the summary chart's budget line becomes a per-month step rather than a constant.

Allocations live alongside the claim on the ledger document:

```
ledger/{ledgerId}.rolloverStatus["2026_SEP"].allocations = {
  travel: 250, gifts: 250
}
```

This is deliberate: `budgetProvider` already streams that exact document for `budgetConfig`, so effective budgets cost no extra reads, no new collection, and no second consistency story. The allocation and the completion record are written in one update.

An allocation reduces that one month only — it is not recurring. A category may be allocated more than its budget; the effective budget simply goes negative and renders as over.

*Consequence — the cost this design accepts:* every consumer of `category.budget` must read the effective figure. There are five (`budget_provider.dart:68` feeding the expense form's "Remaining", `total_row.dart:38`, `bar_chart.dart:115`, `summary_chart.dart:92,177`, `summary_item.dart:13`). The budget-configuration screens deliberately keep reading the configured value, since that is what they edit.

*Alternative rejected:* writing rollovers as `Expense` documents flagged `rollover: true`. It needs no new plumbing — summaries, charts, and totals pick it up for free — but it makes the expense list lie about what was spent, which defeats the purpose of the ledger.

### D2: Single pool = the ledger's net overspend

`pool = max(0, Σ prevMonthSpend - Σ budget)` across every category in `budgetConfig`.

The rollover exists to make the household actually *save* what it overspent, so the number that matters is what it ended up down by overall. Underspend in one category genuinely offsets overspend in another: a month that came in under budget in aggregate costs nothing to carry, however lumpy the individual categories were, and does not prompt at all.

The pool is deliberately **not** tied to which categories ran over. Having overspent $500, the user decides where next month should give it back — $250 off travel, $250 off gifts — regardless of whether travel or gifts were the categories that overspent. Only **active** categories (`activeBudgetCategoryProvider`) can receive an allocation.

Categories marked `deleted` count on **both** sides of the subtraction: their spend was real, and their budget was genuinely in effect for the month being closed. Counting the spend without the budget would overstate the overage.

Summaries for a category no longer in `budgetConfig` at all are ignored, since there is no budget to compare them against.

*Alternative rejected:* `pool = Σ max(0, spend - budget)`, summing only the categories that ran over. It enforces per-category discipline, but it charges a household for a grocery overage in a month where it came in comfortably under budget overall — which is not what the rollover is for.

`RolloverPool` still carries `overspendByCategory` alongside the net total. It no longer drives anything, but it identifies which categories caused the overage and stays available for surfacing that.

### D1a: Effective budget is applied per displayed month

The adjustment belongs to a month, so the month a view is showing decides which adjustment it uses. The bar chart and total row follow `selectedTimeProvider` and therefore take the **selected** month's adjustments; the expense form's "Remaining" is derived from `currentSummaryProvider` and takes the **current** month's; the spending report walks a 12-month window and takes each month's own.

A `Provider.family` keyed by month returns categories with their budgets already adjusted, so consumers keep reading `category.budget` and are simply pointed at a different provider. `budgetProvider` continues to expose the configured values untouched, for the config screens.

### D3: Previous-month summaries via a generalized provider

`currentSummaryProvider` hardcodes this month's bounds, including a deliberate ±24h buffer that absorbs the timezone skew in how `startDate` is stored (local midnight of the 1st, persisted as a UTC instant). Rather than copy that subtlety, extract a `monthSummaryProvider = StreamProvider.family<List<SummaryEntry>, DateTime>` carrying the identical bounds logic, and redefine `currentSummaryProvider` as `monthSummaryProvider(DateTime(now.year, now.month))`.

*Why:* one place to get the skew handling right. The buffer bug class (future-month summaries leaking in) is precisely what the existing comment warns about.

### D4: Eligibility and dismissal

The modal is offered when **all** of:
1. `DateTime.now()` is in a month strictly later than the user's `initialized` month — brand-new accounts are never prompted for a month they did not use.
2. `ledger/{ledgerId}.rolloverStatus["<current YYYY_MON>"]` holds no live record — i.e. it is absent, or it is a stale `pending` claim per D6.
3. The computed pool is `> 0`.
4. The session-local "later" flag for the current month is unset.
5. No account-link notification is currently being handled (the existing `linkRequestNotificationListener` dialogs take precedence).

Nothing restricts the prompt to literally the 1st: a user who opens the app on the 4th having missed the 1st still gets it. "First launch of the month" is the practical effect of conditions 2–4, not a separate date check.

"I'll do it later" sets an **in-memory** flag (a Riverpod `StateProvider<String?>` holding the dismissed month key), so it re-prompts on the next cold launch within the same month. This deliberately does not use `LocalStorageService`/`shared_preferences` — persisting the dismissal would make it effectively permanent for that device, which is stronger than "later". `LocalStorageService` therefore needs no change.

The trigger point is `ExpenseScreen.initState` (`lib/screens/home/expense_list/expenses_screen.dart:217`), which already defers notification handling by 3 seconds to let providers settle; the rollover check chains after that same delay.

### D5: Ledger-wide completion + notification via a callable

The ledger doc carries a per-month status record that moves through two states, `pending` (someone has claimed the rollover and is writing it) and `complete`:

```
ledger/{ledgerId}.rolloverStatus["2026_SEP"] = {
  status: "pending" | "complete",
  claimedBy: <uid>, claimedAt: <serverTimestamp>,
  completedAt: <serverTimestamp>,          // set on transition to complete
  total: <allocated sum>, sourceMonth: "2026_AUG"
}
```

Submission is claim-then-write (see D6 for how the claim is arbitrated): the client first wins the `pending` claim, then writes the expenses, then flips the record to `complete` and stamps the total. Only after that does it call a new `sendRolloverNotification` callable with `{ ledgerId, monthKey, total }`. The function resolves the caller's `linkedAccounts` and fans out through the existing `createNotification` helper (`firebase/functions/index.js:18`), which in turn drives FCM via the `onNotificationCreated` trigger.

*Why a callable over a Firestore trigger on the ledger doc:* `onDocumentUpdated` is not currently imported, and a ledger-doc trigger would fire on every unrelated `budgetConfig` edit, requiring before/after diffing. The callable matches the established `sendBudgetNotification` / `sendReactionNotification` shape.

Unlike `sendBudgetNotification`, this notification is **not** gated on `userSettings.notification[type]`. That gate treats a missing key as disabled, so a new rollover setting would silently suppress every notification until users toggled it; and this is a coordination event about shared state, not an optional nag.

Note when writing the new function: `sendBudgetNotification` throws `functions.https.HttpsError` although `functions` is never imported in `index.js` — those paths would `ReferenceError`. The new function must use the imported `HttpsError` from `firebase-functions/v2/https`. Fixing the existing occurrences is out of scope here.

### D6: Concurrent submission is prevented by a claim transaction

Both users can be looking at the modal at once, so duplicate rollover expenses must be structurally impossible rather than merely unlikely. Two mechanisms combine.

**The claim (prevents the duplicate).** Submitting does not begin by writing expenses. It begins with a Firestore transaction over the **single** `ledger/{ledgerId}` document that reads `rolloverStatus[monthKey]` and writes `{ status: 'pending', claimedBy, claimedAt }` **only if** no live record is already there. Firestore guarantees exactly one concurrent transaction commits, so exactly one client is authorized to write expenses; the loser aborts before writing anything and closes its modal. The expense writes stay outside the transaction — the transaction only arbitrates the claim.

This is why the earlier concern about transaction cost does not apply: a single-document conditional claim is cheap and involves none of the cross-collection expense writes.

**The subscription (keeps the other modal honest).** The modal watches `rolloverStatus` for the current month, off the same `ledger/{ledgerId}` snapshot stream `budgetProvider` already consumes. Any record for the current month written by another user — `pending` or `complete` — closes the open modal with an alert naming what happened. `pending` closes it too: the other user has already committed to submitting, so leaving the modal open would only invite a submit that is guaranteed to lose the claim.

Ordering matters: because the claim lands *before* the expense writes, the paired user's modal closes at the start of the submit rather than at the end, which is what shrinks the window to nothing.

**Abandoned claims.** A client that claims and then dies (crash, connectivity loss, app kill) would otherwise lock the month in `pending` forever. Two guards: the client clears its own claim if the expense writes throw, and a claim whose `claimedAt` is older than **two minutes** and still `pending` is treated as stale and may be re-claimed by the same transaction. Two minutes is far longer than a handful of expense writes needs and short enough that a user who relaunches after a crash is not blocked.

The residual failure mode is now a partial write, not a duplicate: a claimant that dies mid-way may leave some rollover expenses written with the record stale-reclaimable, so a later claimant could add a second set. This is strictly rarer than the original race (it needs a crash inside the write window), and the leftovers are ordinary editable expenses.

### D7: Slider mechanics

Each active category row is a `Slider` from `0` to `min(pool, thisRowAllocation + unallocated)` — i.e. a row can never claim more than what is left plus what it already holds, so the total allocation can never exceed the pool. Values snap to whole dollars.

Rows start at **zero**, with the full pool showing as unallocated. Since the pool is a net figure detached from which categories overspent (D2), there is no defensible default: pre-filling each category with its own overage would suggest the money must come back out of the categories that caused it, which is exactly the choice the modal exists to let the user make.

Each row displays: committed this month (from `monthSummaryProvider(currentMonth)`, which already includes amortized installments landed for this month), the configured budget, the slider value, and `left = budget - committed - allocation` — rendered "Remaining"/"Over" to match the expense form's existing treatment (`lib/widgets/expense_form.dart:250`).

Submitting with zero total allocation is treated as a completion (records `rolloverStatus`, writes no expenses, sends no notification) — the user has consciously decided to carry nothing.

### D8: Testability seams

This feature is mostly arithmetic (the pool, allocation clamping, left-to-spend) plus a concurrency protocol, and both are cheap to test only if they are kept out of the Firestore/Riverpod layer. The repo currently has two test files and no mocking dependencies, so the seams have to be created deliberately rather than assumed.

**A pure core.** All rollover math lives in plain Dart with no Firebase, Riverpod, or Flutter imports — a `lib/services/rollover_calculator.dart` exposing pool computation, seeded defaults, per-slider clamping, left-to-spend, record liveness/staleness, and the eligibility predicate as pure functions over plain inputs. Providers become thin wiring that feeds streams into these functions. Every scenario in the specs' pool, allocation, and eligibility requirements is then a table-driven unit test with no mocks and no async.

**Firestore.** `backendProvider` already returns `FirebaseFirestore.instance` behind a `Provider`, so `ProviderContainer` overrides can substitute `fake_cloud_firestore` for provider-level tests of the summary queries and the ledger status stream.

**Cloud Functions.** `ExpenseNotifier` calls `FirebaseFunctions.instance` directly (`lib/providers/expense_stream_provider.dart:97`, `:156`, `:264`) even though a `functionsProvider` seam exists in `backend_provider.dart` and is used elsewhere. The rollover code MUST go through `functionsProvider` so the notification call can be mocked and asserted; the existing direct usages are left alone as out of scope.

**Server side.** Following the `dateKey.js` precedent, the notification's pure logic — recipient selection (exclude the submitter) and title/body construction — is extracted into a `rolloverNotification.js` module testable with plain `node` asserts, leaving the callable itself as thin Firestore I/O.

**What unit tests cannot cover.** `fake_cloud_firestore` implements `runTransaction` but does not model real contention, so it can verify the claim's *decision logic* (rejects a live record, accepts an absent or stale one) but not the "exactly one winner" guarantee, which is a property of Firestore itself. That guarantee is verified against the emulator with concurrently issued claims, and is otherwise taken as a documented platform behavior rather than re-proved.

New dev dependencies: `fake_cloud_firestore` and `mocktail`.

## Risks / Trade-offs

- **Simultaneous submission by both paired users → duplicate rollover expenses.** → Structurally prevented by the single-document claim transaction in D6; the loser aborts before writing. The remaining exposure is a claimant crashing mid-write, which a later stale reclaim could double up on.
- **An abandoned `pending` claim locks the month.** → Cleared by the claimant on write failure, and treated as stale and reclaimable after two minutes.
- **The pool is computed from `summaries`, which can drift from raw expenses.** → The existing `reconcileSummaries` callable is the established repair path; the modal shows the source-month figures per category so a wrong number is visible before submitting, and the user can always defer.
- **Timezone skew on `startDate` could pull the wrong month's summaries.** → Addressed by centralizing the ±24h bounds in `monthSummaryProvider` (D3) rather than duplicating them.
- **A user who never opens the app during a month loses that month's rollover.** → Accepted (explicit non-goal). Backfill across multiple missed months multiplies the UI and the arithmetic for a rare case.
- **Rollover expenses inflate the new month's spend, which can immediately trip the "over budget" state and the bar chart.** → This is the intended semantic: the money is genuinely committed. The `rollover` flag allows a later UI affordance to distinguish it.
- **Prompt fatigue on the 1st.** → The modal is fully optional, ledger-wide completion means only one person needs to act, and dismissal lasts the session.

## Migration Plan

No data migration. `rolloverStatus` and `Expense.rollover` are additive optional fields; existing documents lacking them behave as "never rolled over" and "not a rollover".

Deploy order: Cloud Function first (`sendRolloverNotification`), then the client. A client shipped ahead of the function would still write expenses and the completion record correctly and only fail the notification call, which is caught and logged rather than surfaced as a submit failure.

Rollback: revert the client. Any `rolloverStatus` entries and `rollover: true` expenses already written remain valid and inert.

## Open Questions

- Should rollover expenses be visually distinguished in the expense list (icon/label), or is the `"Rollover from <Mon YYYY>"` note sufficient for v1? Assumed sufficient.
- Should a future "undo this month's rollover" action exist, deleting the flagged expenses and clearing `rolloverStatus`? Out of scope; the `rollover` flag is written specifically so it stays cheap to add.
