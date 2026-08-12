## 1. Data model and test scaffolding

- [x] 1.1 ~~Add a `rollover` field to `Expense`~~ — dropped: rollovers are budget adjustments, not expenses, so the model is unchanged
- [x] 1.2 ~~Regenerate serialization~~ — nothing to regenerate once the field is dropped
- [x] 1.3 ~~Verify backward-compatible deserialization~~ — no model change to be compatible with
- [x] 1.4 Add `fake_cloud_firestore` and `mocktail` to `dev_dependencies` in `pubspec.yaml`
- [x] 1.5 Add a `test/helpers/rollover_fixtures.dart` builder for ledgers, budget configs, summaries, and status records so tests read as data rather than setup boilerplate

## 2. Summary providers

- [x] 2.1 Extract `monthSummaryProvider = StreamProvider.family<List<SummaryEntry>, DateTime>` in `lib/providers/expense_stream_provider.dart`, carrying over the ±24h `startDate` bounds from `currentSummaryProvider` verbatim
- [x] 2.2 Redefine `currentSummaryProvider` in terms of `monthSummaryProvider(DateTime(now.year, now.month))` and confirm the expense form's "Remaining" figures are unchanged
- [x] 2.3 Add a `previousMonthSummaryProvider` bound to `DateTime(now.year, now.month - 1)`

## 3. Pure rollover core

Plain Dart in `lib/services/rollover_calculator.dart` — no Firebase, Riverpod, or Flutter imports, so all of it is unit-testable without mocks.

- [x] 3.1 `computePool(categories, previousMonthSummaries)` returning per-category overspend `max(0, spent - budget)` and the summed pool, counting deleted categories toward the sum
- [x] 3.2 `effectiveBudget(configuredBudget, allocation)` and `effectiveBudgets(...)` applying a month's allocations to a set of configured budgets
- [x] 3.3 `maxForRow(rowAllocation, unallocated, pool)` and a `clampAllocations` invariant helper guaranteeing the total never exceeds the pool
- [x] 3.4 `leftToSpend(budget, committed, allocation)` matching the expense form's Remaining/Over semantics
- [x] 3.5 `isLiveRolloverRecord(record, now)`: live if `status == 'complete'`, or `status == 'pending'` with `claimedAt` within two minutes of `now` — `now` injected, never read from the clock
- [x] 3.6 `isEligible(...)` predicate over plain inputs: account-initialized month, live-record state, pool, session deferral

## 4. Provider wiring

- [x] 4.1 Add a `rolloverPoolProvider` joining `budgetProvider` with `previousMonthSummaryProvider` through `computePool`
- [x] 4.2 Add a `rolloverCandidatesProvider` exposing active categories (from `activeBudgetCategoryProvider`) each paired with this month's committed spend from `currentSummaryProvider` and its configured budget
- [x] 4.3 Add a `rolloverStatusProvider` streaming `ledger/{ledgerId}.rolloverStatus`, plus a current-month-key helper using `formatMonth` from `lib/providers/expense_provider.dart`
- [x] 4.4 Add an in-memory `rolloverDeferredProvider` (`StateProvider<String?>` holding the deferred month key)
- [x] 4.5 Add a `rolloverEligibilityProvider` delegating to `isEligible`

## 5. Rollover modal UI

- [x] 5.1 Create the modal widget (`lib/widgets/rollover_modal.dart`) with header showing the source month, total pool, and live unallocated remainder
- [x] 5.2 Build the per-category row: label/icon, committed-this-month, configured budget, `Slider` (whole-dollar steps), and left-to-spend rendered "Remaining"/"Over" matching `lib/widgets/expense_form.dart:250`
- [x] 5.3 Bound each slider via `maxForRow` so the total allocation can never exceed the pool
- [x] 5.4 Start every row at zero with the full pool unallocated — the net pool is not tied to which categories overspent
- [x] 5.5 Add "Submit" and "I'll do it later" actions; "later" sets `rolloverDeferredProvider` and closes without writing
- [x] 5.6 Watch `rolloverStatusProvider` while open: if any record for the current month written by another user appears — `pending` or `complete` — close the modal and show an explanatory snackbar naming which case it was
- [x] 5.7 Make the modal scroll and remain usable with many categories and on small screens

## 6. Submission

- [x] 6.1 Add a `claimRollover` method that runs a Firestore transaction over `ledger/{ledgerId}` alone: read `rolloverStatus.{YYYY_MON}`, and only if no live record exists (per 3.5) write `{ status: 'pending', claimedBy, claimedAt: serverTimestamp, sourceMonth }`; return whether the claim was won
- [x] 6.2 Add a `submitRollover` method that aborts unless `claimRollover` succeeded, then records the non-zero allocations as budget adjustments — writing no expense and touching no spend summary
- [x] 6.3 Flip the record to `{ status: 'complete', completedAt: serverTimestamp, total, allocations }` via an overridable `recordCompletion`, preserving `claimedBy`, `claimedAt`, and `sourceMonth`
- [x] 6.4 On write failure after a won claim, clear `rolloverStatus.{YYYY_MON}` so the month can be retried, and surface a non-destructive error
- [x] 6.5 Route the `sendRolloverNotification` call through the existing `functionsProvider` seam (not `FirebaseFunctions.instance`) so it is mockable; call it only when the total is non-zero, and catch and log failures so submission still reports success
- [x] 6.6 Handle the zero-total submit: claim, write the completion record, create no expenses, send no notification
- [x] 6.7 Show a confirmation snackbar on success, and on a lost claim close the modal with a message that another user is handling the rollover

## 6b. Effective budget

- [x] 6b.1 Add `rolloverStatusesProvider` streaming every month's rollover record off the ledger doc, and `monthAllocationsProvider(month)` exposing that month's per-category adjustments
- [x] 6b.2 Add `adjustedCategoriesProvider(month)` returning active categories with budgets net of that month's allocations, plus `selectedMonthCategoriesProvider` following `selectedTimeProvider`
- [x] 6b.3 Point `activeBudgetCategoriesWithSpend` at the current month's adjusted categories so the expense form's "Remaining" nets out the rollover
- [x] 6b.4 Point `barColumnProvider` and `TotalRow` at `selectedMonthCategoriesProvider`
- [x] 6b.5 Make the spending report's budget line per-month: pass `budgetByMonth` into `ReportChart`, draw it as a stepped dashed series instead of a constant `HorizontalLine`, and base `yMax` on the highest monthly budget
- [x] 6b.6 Use each month's effective budget for the report's `totalDelta` and each `SummaryItem`, leaving the configured figure on the budget-config screens

## 7. Launch trigger

- [x] 7.1 In `lib/screens/home/expense_list/expenses_screen.dart`, chain the rollover check after the existing 3-second `linkRequestNotificationListener` delay in `initState`
- [x] 7.2 Skip the rollover prompt for that launch when an account-link/unlink notification was handled
- [x] 7.3 Guard on `mounted` and on eligibility resolving to data before presenting the modal

## 8. Cloud Function

- [x] 8.1 Extract the pure notification logic into `firebase/functions/rolloverNotification.js` — recipient selection (exclude the submitter) and title/body construction — following the `dateKey.js` precedent
- [x] 8.2 Add `exports.sendRolloverNotification = onCall(...)` in `firebase/functions/index.js` accepting `{ ledgerId, monthKey, total }`, using the imported `HttpsError` (not `functions.https.HttpsError`)
- [x] 8.3 Resolve the caller's `linkedAccounts` and fan out via the existing `createNotification` helper; do not notify the caller and do not gate on `userSettings.notification`
- [x] 8.4 Validate inputs and require authentication; log and continue past individual user failures, matching `sendBudgetNotification`
- [ ] 8.5 Deploy the function before shipping the client

## 9. Unit tests — pure core

`test/services/rollover_calculator_test.dart`, table-driven, no mocks. Each bullet maps to scenarios in `specs/monthly-rollover/spec.md`.

- [x] 9.1 Pool: multiple overspent categories sum ($120 + $45 = $165); a single overspent category; no overspend yields zero
- [x] 9.2 Pool: underspend offsets overspend ($200 over + $150 under = $50); a month netting out under budget carries nothing
- [x] 9.3 Pool: a deleted category counts on both sides (spend and budget) but is excluded from allocation targets
- [x] 9.4 Pool edge cases: category with spend but no configured budget, category with budget and no summary, exactly-at-budget contributing zero, floating-point totals rounding cleanly
- [x] 9.5 Effective budget: an allocation reduces the month's budget, a missing allocation leaves it configured, an over-budget allocation goes negative, and unknown categories are ignored
- [x] 9.6 Slider max: a row at $0 with $145 of a $165 pool allocated elsewhere is capped at $20; a row's own current allocation is included in its own max
- [x] 9.7 Allocation invariant: property-style test over randomized allocation sequences asserting the total never exceeds the pool
- [x] 9.8 Left-to-spend: committed + allocation under budget shows Remaining; over budget shows Over; the $50-committed / $400-budget / $100-allocation case yields $250
- [x] 9.9 Record liveness: `complete` is always live regardless of age; `pending` at 1:59 is live; `pending` at 2:01 is stale; malformed or absent records are not live
- [x] 9.10 Eligibility: prompts when all conditions hold; blocked individually by zero pool, completion record, fresh claim, account initialized this month, and session deferral; still prompts on a later day of the month; stale claim does not block

## 10. Provider and widget tests

- [x] 10.1 `monthSummaryProvider` against `fake_cloud_firestore`: returns only the requested month, and the ±24h bounds still exclude an adjacent-month summary written at local midnight of the 1st (the regression the existing comment warns about)
- [x] 10.2 `previousMonthSummaryProvider` resolves the previous month across a year boundary (January → previous December)
- [x] 10.3 `rolloverStatusProvider` emits on ledger-doc updates and tolerates a ledger with no `rolloverStatus` field
- [x] 10.4 `rolloverEligibilityProvider` end-to-end over seeded fake Firestore data for the prompt and each blocked case
- [x] 10.5 Widget test: modal renders one row per active category with correct committed/budget/left-to-spend text, no row for deleted categories, and every row starting at zero
- [x] 10.11 Provider test: allocations reduce that month's budgets, later months keep configured budgets, over-budget allocations go negative, and `budgetProvider` still reports configured values
- [x] 10.6 Widget test: dragging a slider updates that row's left-to-spend and the unallocated figure, and cannot push the total past the pool
- [x] 10.7 Widget test: "I'll do it later" writes nothing, sets the deferral state, and closes
- [x] 10.8 Widget test: Submit with mixed allocations calls submission with exactly the non-zero rows; Submit with all-zero completes without creating expenses
- [x] 10.9 Widget test: a `pending` record from another user appearing on the status stream closes the open modal with the "being handled" message; a `complete` record closes it with the "already completed" message
- [x] 10.10 Widget test: a record written by the local user does not close the modal

## 11. Submission and integration tests

- [x] 11.1 `submitRollover` against `fake_cloud_firestore`: records each non-zero allocation as a budget adjustment and writes no expense
- [x] 11.2 No side effects on spend: no category-month summary is created or changed
- [x] 11.3 Claim decision logic: `claimRollover` refuses when a completion or fresh pending record exists, succeeds when absent or stale, and writes no expenses on refusal
- [x] 11.4 Completion transition: the record moves `pending` → `complete` with the total, preserving `claimedBy`
- [x] 11.5 Failure path: a completion-write failure after a won claim clears the claim, leaving the month re-promptable
- [x] 11.6 Notification: mock `functionsProvider` and assert `sendRolloverNotification` is called once with the ledger id, month key, and total for a non-zero submit; not called for a zero-total submit
- [x] 11.7 Notification failure: a throwing callable still leaves expenses and the completion record written, and reports success
- [x] 11.8 Server-side unit tests in `firebase/functions/rolloverNotification.test.js` (plain `node` asserts, per the `dateKey.test.js` pattern): the submitter is excluded from recipients, an unlinked user yields no recipients, and title/body include the submitter name and formatted total
- [x] 11.9 Wire the new server test into `firebase/functions/package.json`'s `test` script alongside `dateKey.test.js`

## 12. Emulator and manual verification

- [ ] 12.1 Emulator: issue two claims concurrently and confirm exactly one wins, the loser writes no expenses, and a cleared claim can be re-won
- [ ] 12.2 Emulator: seed an overspent prior month, submit, and confirm the expense list is unchanged while the expense form's Remaining, the totals row, the bar chart limits, and the spending report all show the reduced budgets
- [ ] 12.3 Emulator: confirm the deployed `sendRolloverNotification` creates notification documents for linked users and none for the submitter
- [ ] 12.4 Manual paired-user run: second account is notified, is not re-prompted, and an open modal closes on both a concurrent claim and a concurrent completion
- [ ] 12.5 Manual: kill the app after claiming but before writing, then confirm the month is re-promptable after two minutes
- [ ] 12.6 Manual: deferral re-prompts on next cold launch and does not re-prompt within the session
- [ ] 12.7 Run `flutter analyze`, `flutter test`, and `npm test --prefix firebase/functions`; all green
