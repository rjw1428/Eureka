import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart' show formatMonth;
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/rollover_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Wiring only. Every decision and every sum lives in
/// `lib/services/rollover_calculator.dart`; these providers just feed it.

final _sourceMonthLabelFormat = DateFormat('MMM yyyy');

/// The month being rolled *into* — the month in progress.
DateTime currentRolloverMonth([DateTime? now]) {
  final at = now ?? DateTime.now();
  return DateTime(at.year, at.month);
}

/// The closed month whose overspend is being carried forward.
DateTime sourceRolloverMonth([DateTime? now]) {
  final at = now ?? DateTime.now();
  return DateTime(at.year, at.month - 1);
}

/// Human-readable source month, e.g. "Aug 2026", used in the rollover note.
String sourceMonthLabel([DateTime? now]) =>
    _sourceMonthLabelFormat.format(sourceRolloverMonth(now));

/// Storage key for the month in progress, e.g. "2026_SEP".
String currentMonthKey([DateTime? now]) => formatMonth(currentRolloverMonth(now));

Map<String, double> _spendByCategory(List<SummaryEntry> summaries) {
  return {for (final s in summaries) s.categoryId: s.total};
}

/// The previous month's net overspend — the amount to carry forward.
final rolloverPoolProvider = Provider<AsyncValue<double>>((ref) {
  final categories = ref.watch(budgetProvider);
  final summaries = ref.watch(previousMonthSummaryProvider);

  return categories.when(
    error: AsyncError.new,
    loading: () => const AsyncLoading(),
    data: (categories) => summaries.when(
      error: AsyncError.new,
      loading: () => const AsyncLoading(),
      data: (summaries) => AsyncData(
        computeNetOverspend(
          // Deleted categories are included deliberately: both their spend and
          // their budget were real for the month being closed.
          categories: categories
              .map((c) => RolloverCategory(
                    id: c.id,
                    budget: c.budget,
                    deleted: c.deleted,
                  ))
              .toList(),
          previousMonthSpendByCategory: _spendByCategory(summaries),
        ),
      ),
    ),
  );
});

/// A category the rollover may be allocated to, with what is already committed
/// against it this month (including amortized installments already written).
class RolloverCandidate {
  const RolloverCandidate({required this.category, required this.committed});

  final CategoryDataWithId category;
  final double committed;

  String get id => category.id;
  double get budget => category.budget;
}

final rolloverCandidatesProvider =
    Provider<AsyncValue<List<RolloverCandidate>>>((ref) {
  final categories = ref.watch(activeBudgetCategoryProvider);
  final summaries = ref.watch(currentSummaryProvider);

  return categories.when(
    error: AsyncError.new,
    loading: () => const AsyncLoading(),
    data: (categories) => summaries.when(
      error: AsyncError.new,
      loading: () => const AsyncLoading(),
      data: (summaries) {
        final spend = _spendByCategory(summaries);
        return AsyncData([
          for (final category in categories)
            RolloverCandidate(
              category: category,
              committed: spend[category.id] ?? 0,
            ),
        ]);
      },
    ),
  );
});

/// Normalises Firestore `Timestamp`s to `DateTime` so the pure calculator never
/// has to know about Firestore types.
Map<String, dynamic>? normalizeRolloverRecord(dynamic raw) {
  if (raw is! Map) return null;
  return {
    for (final entry in raw.entries)
      entry.key.toString():
          entry.value is Timestamp ? (entry.value as Timestamp).toDate() : entry.value,
  };
}

/// Every month's rollover record, streamed off the ledger document, keyed by
/// month key. Shares the same document `budgetProvider` already watches, so
/// effective budgets cost no additional reads.
final rolloverStatusesProvider =
    StreamProvider<Map<String, Map<String, dynamic>>>((ref) {
  final user = ref.watch(userProvider).value;
  final firestore = ref.read(backendProvider);

  if (user == null) {
    return Stream.value(const {});
  }

  return firestore
      .collection('ledger')
      .doc(user.ledgerId)
      .snapshots()
      .map((snapshot) {
    final status = snapshot.data()?['rolloverStatus'];
    if (status is! Map) return <String, Map<String, dynamic>>{};
    return {
      for (final entry in status.entries)
        if (normalizeRolloverRecord(entry.value) case final record?)
          entry.key.toString(): record,
    };
  });
});

/// The budget adjustments recorded against a given month, per category.
final monthAllocationsProvider =
    Provider.family<Map<String, double>, DateTime>((ref, month) {
  final statuses = ref.watch(rolloverStatusesProvider).valueOrNull ?? const {};
  final raw = statuses[formatMonth(DateTime(month.year, month.month))]?['allocations'];
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      entry.key.toString(): (entry.value as num).toDouble(),
  };
});

/// Active categories with their budgets reduced by the given month's rollover
/// allocations. Consumers keep reading `category.budget`; only the provider
/// they watch changes.
final adjustedCategoriesProvider =
    Provider.family<AsyncValue<List<CategoryDataWithId>>, DateTime>((ref, month) {
  final categories = ref.watch(activeBudgetCategoryProvider);
  final allocations = ref.watch(monthAllocationsProvider(month));

  return categories.whenData((categories) => [
        for (final category in categories)
          CategoryDataWithId(
            id: category.id,
            label: category.label,
            icon: category.icon,
            deleted: category.deleted,
            budget: effectiveBudget(
              configuredBudget: category.budget,
              allocation: allocations[category.id] ?? 0,
            ),
          ),
      ]);
});

/// Active categories adjusted for the month the user is currently viewing.
/// The expense list, bar chart, and totals row all follow `selectedTimeProvider`.
final selectedMonthCategoriesProvider =
    Provider<AsyncValue<List<CategoryDataWithId>>>((ref) {
  final selected = ref.watch(selectedTimeProvider);
  return ref.watch(adjustedCategoriesProvider(DateTime(selected.year, selected.month)));
});

/// The rollover record for the month in progress, streamed off the ledger doc.
final rolloverStatusProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(userProvider).value;
  final firestore = ref.read(backendProvider);

  if (user == null) {
    return Stream.value(null);
  }

  final key = currentMonthKey();
  return firestore
      .collection('ledger')
      .doc(user.ledgerId)
      .snapshots()
      .map((snapshot) {
    final status = snapshot.data()?['rolloverStatus'];
    if (status is! Map) return null;
    return normalizeRolloverRecord(status[key]);
  });
});

/// The signed-in user's id, or null. Lets the modal tell its own claim landing
/// on the status stream apart from the paired user's.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(userProvider).valueOrNull?.id;
});

/// "I'll do it later", held in memory only: persisting it would make the
/// dismissal effectively permanent for the device, which is stronger than the
/// user asked for. Holds the month key that was deferred.
final rolloverDeferredProvider = StateProvider<String?>((ref) => null);

enum RolloverSubmitResult {
  /// The rollover was recorded for the ledger.
  completed,

  /// Another user claimed the month first; nothing was written.
  lostClaim,

  /// The claim was won but writing failed; the claim has been released.
  failed,
}

/// Claims, writes, and completes the monthly rollover.
///
/// Submission is claim-then-write: the month is claimed in a transaction over
/// the ledger document alone before any expense is written, so two users
/// submitting at once cannot both produce rollover expenses. The expense
/// writes stay outside that transaction — it exists only to arbitrate.
class RolloverNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  ExpenseUser get _user => ref.read(userProvider).value!;
  FirebaseFirestore get _firestore => ref.read(backendProvider);
  DocumentReference<Map<String, dynamic>> get _ledgerRef =>
      _firestore.collection('ledger').doc(_user.ledgerId);

  /// Attempts to claim the month. Returns whether this client may proceed.
  ///
  /// A live record — a completion, or a pending claim under two minutes old —
  /// means someone else owns the month and this client must not write.
  Future<bool> claimRollover({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final key = currentMonthKey(at);

    try {
      return await _firestore.runTransaction<bool>((txn) async {
        final snapshot = await txn.get(_ledgerRef);
        final status = snapshot.data()?['rolloverStatus'];
        final existing =
            status is Map ? normalizeRolloverRecord(status[key]) : null;

        if (isLiveRolloverRecord(existing, at)) return false;

        // A dotted field path writes this month's key alone, leaving sibling
        // months — and the rest of the ledger document — untouched.
        txn.update(_ledgerRef, {
          'rolloverStatus.$key': {
            'status': kRolloverPending,
            'claimedBy': _user.id,
            'claimedAt': FieldValue.serverTimestamp(),
            'sourceMonth': formatMonth(sourceRolloverMonth(at)),
          },
        });
        return true;
      });
    } catch (e) {
      debugPrint('Rollover claim failed: $e');
      return false;
    }
  }

  /// Turns the pending claim into a completion, storing the month's budget
  /// adjustments alongside it.
  ///
  /// Written field-by-field so the claim's `claimedBy`, `claimedAt`, and
  /// `sourceMonth` survive the transition. Overridable so tests can exercise
  /// the claim-release path without a fake that fails mid-write.
  @protected
  @visibleForTesting
  Future<void> recordCompletion({
    required String monthKey,
    required double total,
    required Map<String, double> allocations,
  }) {
    return _ledgerRef.update({
      'rolloverStatus.$monthKey.status': kRolloverComplete,
      'rolloverStatus.$monthKey.completedAt': FieldValue.serverTimestamp(),
      'rolloverStatus.$monthKey.total': total,
      'rolloverStatus.$monthKey.allocations': allocations,
    });
  }

  /// Releases a won claim so the month can be attempted again.
  Future<void> _releaseClaim(String key) async {
    try {
      await _ledgerRef.update({'rolloverStatus.$key': FieldValue.delete()});
    } catch (e) {
      debugPrint('Rollover claim release failed: $e');
    }
  }

  /// Records the allocations as budget adjustments for the month and completes.
  ///
  /// No expense is written and no spend summary is touched: a rollover is not
  /// a purchase, so the ledger must keep reporting only what was really spent.
  /// The allocations reduce this month's budgets instead.
  ///
  /// A zero total still completes: the user has consciously decided to carry
  /// nothing forward, and the month should not keep prompting.
  Future<RolloverSubmitResult> submitRollover(
    Map<String, double> allocations, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final key = currentMonthKey(at);

    if (!await claimRollover(now: at)) {
      return RolloverSubmitResult.lostClaim;
    }

    state = true;
    final applied = <String, double>{
      for (final entry in allocations.entries)
        if (entry.value > 0) entry.key: roundMoney(entry.value),
    };
    final total = roundMoney(
      applied.values.fold<double>(0, (running, value) => running + value),
    );

    try {
      await recordCompletion(monthKey: key, total: total, allocations: applied);
    } catch (e) {
      debugPrint('Rollover submission failed: $e');
      await _releaseClaim(key);
      return RolloverSubmitResult.failed;
    } finally {
      state = false;
    }

    if (total > 0) {
      await _notifyLinkedUsers(monthKey: key, total: total);
    }

    return RolloverSubmitResult.completed;
  }

  /// Best-effort: a notification failure must not fail a submission whose
  /// expenses and completion record are already written.
  Future<void> _notifyLinkedUsers({
    required String monthKey,
    required double total,
  }) async {
    try {
      await ref
          .read(functionsProvider)
          .httpsCallable('sendRolloverNotification')
          .call({
        'ledgerId': _user.ledgerId,
        'monthKey': monthKey,
        'total': total,
      });
    } catch (e) {
      debugPrint('Rollover notification failed: $e');
    }
  }
}

final rolloverNotifierProvider =
    NotifierProvider<RolloverNotifier, bool>(RolloverNotifier.new);

/// Everything needed to present the modal, or null if it should not be shown.
class RolloverPrompt {
  const RolloverPrompt({required this.pool, required this.candidates});

  /// The net amount to carry forward.
  final double pool;
  final List<RolloverCandidate> candidates;
}

/// Non-null only once the user is eligible *and* every input has resolved.
///
/// Must be listened to rather than read once: the summary and ledger streams
/// it depends on are cold — nothing else in the app subscribes to them — so a
/// single read creates them and sees `AsyncLoading`, never the data that
/// arrives a moment later.
final rolloverPromptProvider = Provider<RolloverPrompt?>((ref) {
  if (!ref.watch(rolloverEligibilityProvider)) return null;

  final pool = ref.watch(rolloverPoolProvider).valueOrNull;
  if (pool == null || pool <= 0) return null;

  final candidates = ref.watch(rolloverCandidatesProvider).valueOrNull;
  if (candidates == null || candidates.isEmpty) return null;

  return RolloverPrompt(pool: pool, candidates: candidates);
});

/// Whether to offer the modal on this launch.
final rolloverEligibilityProvider = Provider<bool>((ref) {
  final user = ref.watch(userProvider).value;
  final pool = ref.watch(rolloverPoolProvider).valueOrNull;
  final record = ref.watch(rolloverStatusProvider).valueOrNull;
  final deferred = ref.watch(rolloverDeferredProvider);

  if (user == null || pool == null) return false;

  return isEligible(
    now: DateTime.now(),
    accountInitialized: user.initialized,
    poolTotal: pool,
    rolloverRecord: record,
    currentMonthKey: currentMonthKey(),
    deferredMonthKey: deferred,
  );
});
