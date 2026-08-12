## Why

When a month closes over budget, that overspend simply vanishes: the new month starts with every category reset to its full configured budget, so the household never actually pays back what it overspent. Users have no prompt or mechanism to carry last month's overspend forward, which makes the budget a soft target rather than a running balance.

## What Changes

- On the first app launch of a new calendar month, if the previous month closed over budget and no one on the ledger has handled it yet, show a **rollover modal**.
- The modal presents a **single pool** equal to the previous month's **net** overspend (total spend less total budget, so underspend in one category offsets overspend in another; a month that nets out under budget prompts nothing) and lets the user distribute it across **any** active budget category with per-category sliders. A running "unallocated" figure shows how much of the pool is still unassigned; allocating the full pool is encouraged but not required.
- Each slider row shows, for its category: the amount **already committed** this month (existing spend, including amortized installments that have already landed), the **configured budget**, the proposed rollover amount, and the resulting **left to spend**. Rows start at zero — the pool is a net figure, so which budgets absorb it is the user's choice.
- Submitting records each non-zero allocation as a **budget adjustment** for the current month — it writes no expense. Expenses continue to reflect only real spending; the month's effective budget for a category becomes `configured − allocation`. **BREAKING** for anything assuming a category's budget is constant: the budget now varies month to month, including the spending report's budget line.
- The modal is **optional**: actions are **Submit** and **I'll do it later**. "Later" dismisses for the session only and re-prompts on the next launch within the same month.
- Completion is recorded **ledger-wide**. Submitting first claims the month in a single-document transaction on the ledger, so two users submitting at once can never produce duplicate rollovers; once either user has claimed or completed, the modal stops appearing — and closes if already open — for everyone on the ledger.
- When one user completes the rollover, **all other users on the ledger are notified** via the existing notification pipeline.

## Capabilities

### New Capabilities
- `monthly-rollover`: Detecting that a new month has begun with unhandled overspend from the prior month, computing the overspend pool and per-category context, presenting the optional allocation modal, recording per-month budget adjustments, tracking ledger-wide completion, and notifying linked users.

### Modified Capabilities
<!-- No existing specs in openspec/specs/ — this is the first change in this repo. -->
None.

## Impact

**Flutter app**
- `lib/providers/expense_stream_provider.dart` — add a previous-month summary query alongside `currentSummaryProvider`.
- `lib/providers/budget_provider.dart` — previous-month overspend derivation, and effective-budget wiring so `activeBudgetCategoriesWithSpend` nets out the month's allocations.
- Effective-budget consumers: `lib/widgets/total_row.dart`, `lib/providers/bar_chart_provider.dart`, `lib/screens/summary/{summary,summary_chart,summary_item}.dart`.
- New: rollover state provider + rollover modal widget under `lib/widgets/` (or `lib/screens/home/`).
- `lib/screens/home/expense_list/expenses_screen.dart` — trigger the modal from the existing post-launch notification-listener hook in `initState`.
- The "later" dismissal is held in memory only, so `local_storage.service.dart` is unchanged.

**Firestore / Cloud Functions**
- `ledger/{ledgerId}` — new `rolloverStatus.{YYYY_MON}` map recording the claim, completion, and the per-category budget adjustments (`{ status, claimedBy, claimedAt, completedAt, total, sourceMonth, allocations }`).
- `firebase/functions/index.js` — a callable (or Firestore trigger on `rolloverStatus`) that fans out `createNotification` to the submitting user's `linkedAccounts`, following the `sendBudgetNotification` pattern.

**Dependencies**: none new. Uses existing Riverpod, Firestore, `cloud_functions`, `shared_preferences`.
