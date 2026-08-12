## ADDED Requirements

### Requirement: Rollover prompt eligibility

The system SHALL offer the rollover modal on app launch when, and only when, all of the following hold: the current calendar month is later than the month in which the user account was initialized; the ledger holds no live rollover record for the current month, meaning neither a completion nor a pending claim less than two minutes old; the computed overspend pool for the previous month is greater than zero; the modal has not been deferred during the current app session; and no account-link notification is being handled.

#### Scenario: New month with prior-month overspend

- **WHEN** a user opens the app in a month for which the ledger has no rollover completion record, and the previous month's overspend pool is greater than zero
- **THEN** the rollover modal SHALL be presented after the existing post-launch delay

#### Scenario: Previous month ended within budget

- **WHEN** a user opens the app in a new month and every category's previous-month spend was at or under its configured budget
- **THEN** the rollover modal SHALL NOT be presented

#### Scenario: Ledger already completed this month's rollover

- **WHEN** a user opens the app and the ledger holds a completion record for the current month
- **THEN** the rollover modal SHALL NOT be presented, regardless of which user on the ledger created that record

#### Scenario: Prompt is not restricted to the first day of the month

- **WHEN** a user opens the app on a later day of the month having never been prompted, and all eligibility conditions still hold
- **THEN** the rollover modal SHALL be presented

#### Scenario: Account created during the current month

- **WHEN** a user whose account was initialized during the current calendar month opens the app
- **THEN** the rollover modal SHALL NOT be presented

#### Scenario: Account-link notification takes precedence

- **WHEN** the user has a pending account-link, primary-unlink, or secondary-unlink notification to handle at launch
- **THEN** that dialog SHALL be shown and the rollover modal SHALL NOT be presented during that launch

### Requirement: Overspend pool calculation

The system SHALL compute the overspend pool as the ledger's net overage for the closed month: total previous-month spend minus total configured budget, across every category in the ledger's budget configuration, floored at zero. Underspend in one category SHALL offset overspend in another. Categories marked deleted SHALL contribute both their spend and their budget. Spend in a category absent from the budget configuration SHALL be ignored.

#### Scenario: Multiple overspent categories

- **WHEN** the previous month closed with Groceries $120 over budget and Dining $45 over budget, and no category under budget
- **THEN** the pool SHALL be $165

#### Scenario: Underspend offsets overspend

- **WHEN** the previous month closed with Groceries $200 over budget and Travel $150 under budget
- **THEN** the pool SHALL be $50

#### Scenario: A month that nets out under budget carries nothing

- **WHEN** the previous month closed with Groceries $120 over budget and Travel $150 under budget
- **THEN** the pool SHALL be zero and no rollover SHALL be prompted

#### Scenario: A deleted category counts on both sides

- **WHEN** a category that was overspent last month has since been marked deleted
- **THEN** both its spend and its configured budget SHALL be included in the net, and it SHALL NOT appear as an allocation row

#### Scenario: Spend in a category no longer configured

- **WHEN** a previous-month summary refers to a category absent from the budget configuration
- **THEN** that spend SHALL be excluded from the net

### Requirement: Per-category allocation display

The rollover modal SHALL present one allocation row per active budget category. Each row SHALL show the amount already committed against that category in the current month — including amortized installments already written into the current month — the category's configured budget, the currently allocated rollover amount, and the resulting amount left to spend for the month.

#### Scenario: Row reflects amortized spend already booked for the current month

- **WHEN** a category has a $50 amortized installment already recorded in the current month and a $400 configured budget, and $100 of rollover is allocated to it
- **THEN** the row SHALL show $50 committed, a $400 budget, a $100 allocation, and $250 left to spend

#### Scenario: Allocation pushes a category over budget

- **WHEN** the allocation and committed spend together exceed the category's configured budget
- **THEN** the row SHALL present the resulting figure as an over-budget amount rather than as remaining

#### Scenario: Row updates live as the slider moves

- **WHEN** the user drags a category's slider
- **THEN** that row's left-to-spend figure and the unallocated pool figure SHALL update immediately

### Requirement: Allocation constraints

The modal SHALL display the total pool and the amount still unallocated. The sum of all allocations SHALL NOT exceed the pool. Each category slider SHALL range from zero to the lesser of the pool and the sum of that row's current allocation plus the unallocated remainder. Allocations SHALL be settable in whole dollars. Allocating the full pool SHALL NOT be required in order to submit.

#### Scenario: Slider is bounded by the unallocated remainder

- **WHEN** the pool is $165 and $145 is already allocated across other categories
- **THEN** a category currently allocated $0 SHALL be limited to a maximum of $20

#### Scenario: Partial allocation may be submitted

- **WHEN** the user has allocated less than the full pool and taps Submit
- **THEN** the submission SHALL proceed with the amounts allocated and the unallocated remainder SHALL be discarded

#### Scenario: Allocations start empty

- **WHEN** the modal opens
- **THEN** every category SHALL be allocated zero and the entire pool SHALL be shown as unallocated, leaving the user to choose which budgets absorb it

#### Scenario: The pool may be allocated to a category that did not overspend

- **WHEN** the user allocates part of the pool to a category that stayed within budget last month
- **THEN** the allocation SHALL be accepted

### Requirement: Submitting rollover allocations

On submit, the system SHALL record each non-zero allocation as a budget adjustment against the current month, stored with that month's rollover record on the ledger. The system SHALL NOT create any expense, and SHALL NOT alter any category-month spend summary.

#### Scenario: Allocations are recorded as budget adjustments

- **WHEN** the user submits with $250 allocated to Travel and $250 to Gifts for September 2026
- **THEN** the ledger's September 2026 rollover record SHALL hold allocations of $250 for Travel and $250 for Gifts

#### Scenario: No expense is created

- **WHEN** a rollover is submitted
- **THEN** no expense document SHALL be written, the expense list SHALL be unchanged, and every spend total SHALL continue to reflect only real purchases

#### Scenario: Spend summaries are untouched

- **WHEN** a rollover is submitted
- **THEN** no category-month summary total or count SHALL change

#### Scenario: Categories with a zero allocation

- **WHEN** the user submits with a category allocated zero
- **THEN** no adjustment SHALL be recorded for that category

### Requirement: Effective budget for an adjusted month

For any month with recorded rollover allocations, the system SHALL treat a category's budget for that month as its configured budget less that month's allocation for the category. The configured budget SHALL NOT be modified. Adjustments SHALL apply only to the month they were recorded against.

#### Scenario: The month's budget is reduced

- **WHEN** Travel is configured at $400 and has a $250 rollover allocation for September 2026
- **THEN** Travel's September 2026 budget SHALL be $150

#### Scenario: Remaining, totals, and charts all reflect the reduction

- **WHEN** a month has rollover allocations
- **THEN** the expense form's remaining figure, the totals row, the bar chart's per-category limit, and the spending report SHALL all use the reduced budget for that month

#### Scenario: Later months are unaffected

- **WHEN** a rollover is recorded against September 2026
- **THEN** October 2026's budgets SHALL be the configured values

#### Scenario: The budget line varies across months

- **WHEN** the spending report renders a category across several months, some of which carry allocations
- **THEN** the budget shown for each month SHALL be that month's effective budget rather than one constant figure

#### Scenario: Configured budgets remain visible where they are edited

- **WHEN** the user opens the budget configuration screen
- **THEN** the configured budget SHALL be shown, unreduced

#### Scenario: An allocation larger than the budget

- **WHEN** a category configured at $100 receives a $165 allocation
- **THEN** its effective budget SHALL be -$65 and the category SHALL read as over budget

### Requirement: Deferring the rollover

The modal SHALL offer an "I'll do it later" action alongside Submit. Choosing it SHALL dismiss the modal without writing any expenses or completion record, and SHALL suppress the prompt only for the remainder of the current app session.

#### Scenario: Deferring writes nothing

- **WHEN** the user taps "I'll do it later"
- **THEN** no expenses SHALL be created, no completion record SHALL be written, and no notification SHALL be sent

#### Scenario: Deferral does not persist across launches

- **WHEN** the user defers and later relaunches the app in the same month with all other eligibility conditions still met
- **THEN** the rollover modal SHALL be presented again

#### Scenario: Deferral does not re-prompt within the session

- **WHEN** the user defers and then navigates away and back within the same app session
- **THEN** the rollover modal SHALL NOT be presented again during that session

### Requirement: Ledger-wide completion record

After the rollover expenses are written, the system SHALL transition the current month's ledger record from its pending claim to completion, capturing the submitting user, the completion time, the total amount rolled over, and the source month. This record SHALL suppress the prompt for every user on the ledger for that month, permanently and regardless of elapsed time.

#### Scenario: Completion suppresses the prompt for the paired user

- **WHEN** one user on a shared ledger submits the rollover
- **THEN** the other user on that ledger SHALL NOT be prompted for that month on any subsequent launch

#### Scenario: Submitting a zero total still completes

- **WHEN** the user submits with every category allocated zero
- **THEN** the completion record SHALL be written, no expenses SHALL be created, and no notification SHALL be sent

#### Scenario: Completion is scoped to a single month

- **WHEN** a completion record exists for the previous month only
- **THEN** the user SHALL still be prompted for the current month if the other eligibility conditions hold

### Requirement: Notifying linked users on completion

When a user submits a rollover with a non-zero total, the system SHALL notify every other user linked to the submitting user, identifying who completed the rollover and the total amount carried forward. Delivery SHALL use the existing notification-document and push pipeline. A failure to send the notification SHALL NOT fail the submission.

#### Scenario: Paired user is notified

- **WHEN** a user on a shared ledger submits a rollover totalling $165
- **THEN** a notification SHALL be created for each linked user naming the submitting user and the $165 total

#### Scenario: Submitting user is not notified

- **WHEN** a user submits a rollover
- **THEN** no notification SHALL be created for that submitting user

#### Scenario: Unlinked user

- **WHEN** a user with no linked accounts submits a rollover
- **THEN** the submission SHALL succeed and no notification SHALL be created

#### Scenario: Notification failure does not fail submission

- **WHEN** the notification call fails
- **THEN** the rollover expenses and completion record SHALL remain written and the user SHALL see the submission as successful

### Requirement: Exclusive claim before writing

Submission SHALL begin by claiming the current month's rollover in a transaction over the ledger document that records a pending claim only if no live record exists for that month. A client SHALL write rollover expenses only after winning that claim. A client that loses the claim SHALL write no expenses and SHALL inform the user that another user is handling the rollover.

#### Scenario: Two users submit simultaneously

- **WHEN** both users on a shared ledger tap Submit at the same instant
- **THEN** exactly one SHALL win the claim and write its expenses, and the other SHALL write no expenses and SHALL be told the rollover is already being handled

#### Scenario: Claim precedes the expense writes

- **WHEN** a user taps Submit
- **THEN** the pending claim SHALL be recorded on the ledger before any rollover expense is written

#### Scenario: Claim released when writing fails

- **WHEN** the rollover expense writes fail after the claim was won
- **THEN** the claim SHALL be cleared so that the rollover can be attempted again

#### Scenario: Stale claim may be reclaimed

- **WHEN** a pending claim is older than two minutes and has not become a completion
- **THEN** it SHALL be treated as stale and a subsequent submission SHALL be able to claim the month

#### Scenario: Fresh claim blocks a new prompt

- **WHEN** a user launches the app while another user holds a pending claim less than two minutes old for the current month
- **THEN** the rollover modal SHALL NOT be presented

### Requirement: Concurrent activity closes an open modal

While the rollover modal is open, the system SHALL observe the ledger's rollover record for the current month. If a record created by another user appears — whether a pending claim or a completion — the modal SHALL close without submitting and SHALL inform the user what happened.

#### Scenario: Paired user completes while the modal is open

- **WHEN** the paired user completes the rollover while this user has the modal open with unsubmitted allocations
- **THEN** the modal SHALL close, no expenses SHALL be written from this user's allocations, and a message SHALL explain that the other user completed the rollover

#### Scenario: Paired user claims while the modal is open

- **WHEN** the paired user wins the claim and is still writing while this user has the modal open
- **THEN** this user's modal SHALL close and a message SHALL explain that the other user is handling the rollover
