/// Pure rollover arithmetic and rules.
///
/// Deliberately free of Firebase, Riverpod, and Flutter imports: everything
/// here is a function of plain values, so the whole of the rollover's
/// behaviour can be tested without mocks, streams, or a widget tree. Providers
/// map domain models onto these inputs and do nothing else.
library;

import 'dart:math' as math;

/// How long a `pending` claim stays authoritative before another client may
/// take the month over. Long enough for a handful of expense writes, short
/// enough that a user who crashed mid-submit is not locked out for long.
const Duration kClaimStaleAfter = Duration(minutes: 2);

/// Rollover status values as stored on `ledger/{id}.rolloverStatus.{YYYY_MON}`.
const String kRolloverPending = 'pending';
const String kRolloverComplete = 'complete';

/// The minimal shape the calculator needs from a budget category. Keeping this
/// separate from [CategoryDataWithId] is what lets this library stay free of
/// Flutter imports (that model carries an `IconData` accessor).
class RolloverCategory {
  const RolloverCategory({
    required this.id,
    required this.budget,
    this.deleted = false,
  });

  final String id;
  final double budget;
  final bool deleted;
}

/// Rounds money to whole cents, so a sum of doubles cannot surface as
/// `165.00000000000003`.
double roundMoney(double value) => (value * 100).round() / 100;

/// Rounds to whole dollars, the granularity the allocation sliders work in.
double roundDollars(double value) => value.roundToDouble();

/// The net amount the closed month ran over budget, floored at zero.
///
/// The pool is the ledger's *net* overage — everything spent, less everything
/// budgeted — because the rollover exists to make the household give back what
/// it actually ended up down by. Underspend therefore offsets overspend: a
/// month that came in under budget overall carries nothing forward, however
/// uneven the individual categories were.
///
/// Which categories ran over is deliberately not computed. The pool is a
/// single figure and the user chooses which budgets absorb it.
///
/// Deleted categories count on both sides. Their spend was real, and their
/// budget was genuinely in effect for the month being closed; counting the
/// spend alone would invent an overage. Spend in a category no longer in the
/// budget configuration is ignored, having no budget to measure against.
double computeNetOverspend({
  required List<RolloverCategory> categories,
  required Map<String, double> previousMonthSpendByCategory,
}) {
  var totalSpent = 0.0;
  var totalBudget = 0.0;

  for (final category in categories) {
    totalSpent += previousMonthSpendByCategory[category.id] ?? 0;
    totalBudget += category.budget;
  }

  return roundMoney(math.max(0, totalSpent - totalBudget));
}

/// The far right of a category's slider: its own configured budget.
///
/// Fixed per row and independent of what other rows hold, so the thumb never
/// shifts position because a different category changed. Sliding fully right
/// takes the category's budget to exactly zero.
double sliderMaxFor(double configuredBudget) =>
    roundDollars(math.max(0, configuredBudget));

/// Total currently allocated across all rows.
double totalAllocated(Map<String, double> allocations) =>
    roundMoney(allocations.values.fold(0.0, (sum, v) => sum + v));

/// Pool left to distribute. Never negative.
double unallocated(Map<String, double> allocations, double pool) =>
    roundMoney(math.max(0, pool - totalAllocated(allocations)));

/// Applies a new value to one row while preserving the invariant that the
/// total allocation never exceeds the pool. The requested value is clamped to
/// that row's available headroom rather than rejected.
Map<String, double> clampAllocations({
  required Map<String, double> allocations,
  required String categoryId,
  required double requested,
  required double pool,
}) {
  final others = Map<String, double>.from(allocations)..remove(categoryId);
  final headroom = roundMoney(pool - totalAllocated(others));
  final clamped = roundDollars(math.max(0, math.min(requested, headroom)));

  final next = Map<String, double>.from(allocations);
  if (clamped <= 0) {
    next.remove(categoryId);
  } else {
    next[categoryId] = clamped;
  }
  return next;
}

/// A category's budget for a given month, net of any rollover allocation
/// recorded against that month.
///
/// The configured budget is never modified; the reduction applies to the one
/// month the allocation was recorded against. The result may be negative when
/// a category is allocated more than it was budgeted, which simply reads as
/// over budget.
double effectiveBudget({
  required double configuredBudget,
  required double allocation,
}) {
  return roundMoney(configuredBudget - allocation);
}

/// Applies a month's allocations to a set of configured budgets.
Map<String, double> effectiveBudgets({
  required Map<String, double> configuredBudgets,
  required Map<String, double> allocations,
}) {
  return {
    for (final entry in configuredBudgets.entries)
      entry.key: effectiveBudget(
        configuredBudget: entry.value,
        allocation: allocations[entry.key] ?? 0,
      ),
  };
}

/// What remains spendable in a category this month once the proposed rollover
/// is charged against it. Negative means the category is already over.
double leftToSpend({
  required double budget,
  required double committed,
  required double allocation,
}) {
  return roundMoney(budget - committed - allocation);
}

/// Whether a stored rollover record still governs the month.
///
/// A completion is permanent. A pending claim only holds for
/// [kClaimStaleAfter]; past that it is treated as abandoned so a crashed
/// submit cannot lock the month forever. A pending claim whose `claimedAt` has
/// not yet resolved — Firestore surfaces `serverTimestamp()` as null on the
/// local echo until the server confirms — is treated as live, erring toward
/// blocking a second claim rather than risking a duplicate.
bool isLiveRolloverRecord(Map<String, dynamic>? record, DateTime now) {
  if (record == null) return false;

  switch (record['status']) {
    case kRolloverComplete:
      return true;
    case kRolloverPending:
      final claimedAt = record['claimedAt'];
      if (claimedAt is! DateTime) return true;
      return now.difference(claimedAt) < kClaimStaleAfter;
    default:
      return false;
  }
}

/// Whether the rollover modal should be offered on this launch.
///
/// Note there is no check for a particular day of the month: a user who misses
/// the 1st is still prompted on the 4th. "First launch of the month" is the
/// effect of the record and deferral checks, not a date rule.
bool isEligible({
  required DateTime now,
  required DateTime accountInitialized,
  required double poolTotal,
  required Map<String, dynamic>? rolloverRecord,
  required String currentMonthKey,
  String? deferredMonthKey,
}) {
  // A brand-new account is never asked to account for a month it did not use.
  final initializedMonth =
      DateTime(accountInitialized.year, accountInitialized.month);
  final currentMonth = DateTime(now.year, now.month);
  if (!initializedMonth.isBefore(currentMonth)) return false;

  if (poolTotal <= 0) return false;
  if (isLiveRolloverRecord(rolloverRecord, now)) return false;
  if (deferredMonthKey == currentMonthKey) return false;

  return true;
}
