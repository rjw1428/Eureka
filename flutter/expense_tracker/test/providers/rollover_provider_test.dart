import 'dart:async';

import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/rollover_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/rollover_calculator.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/rollover_fixtures.dart';

void main() {
  late FakeFirebaseFirestore db;

  ExpenseUser buildUser({DateTime? initialized}) {
    return ExpenseUser.fromJson({
      'id': testUserId,
      'firstName': 'Test',
      'lastName': 'User',
      'email': 'test@example.com',
      'ledgerId': testLedgerId,
      'role': 'primary',
      'initialized': (initialized ?? DateTime(2025, 1, 1)).toIso8601String(),
      'userSettings': <String, String>{},
      'noteSuggestions': <String, dynamic>{},
      'linkedAccounts': <dynamic>[],
      'archivedLinkedAccounts': <dynamic>[],
    });
  }

  ProviderContainer buildContainer({ExpenseUser? user}) {
    final container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(db),
        userProvider.overrideWith((ref) => Stream.value(user ?? buildUser())),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Waits for a stream provider to produce its first value.
  Future<T> firstValue<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
  ) async {
    final completer = Completer<T>();
    final sub = container.listen<AsyncValue<T>>(provider, (previous, next) {
      if (next.hasValue && !completer.isCompleted) {
        completer.complete(next.value as T);
      }
    }, fireImmediately: true);
    addTearDown(sub.close);
    return completer.future.timeout(const Duration(seconds: 5));
  }

  setUp(() {
    db = FakeFirebaseFirestore();
  });

  group('month helpers', () {
    test('January rolls over from the previous December', () {
      final january = DateTime(2027, 1, 1, 9);

      expect(sourceRolloverMonth(january), DateTime(2026, 12));
      expect(currentRolloverMonth(january), DateTime(2027, 1));
      expect(currentMonthKey(january), '2027_JAN');
      expect(sourceMonthLabel(january), 'Dec 2026');
    });

    test('mid-year months resolve to the immediately preceding month', () {
      final september = DateTime(2026, 9, 4, 18);

      expect(sourceRolloverMonth(september), DateTime(2026, 8));
      expect(currentMonthKey(september), '2026_SEP');
      expect(sourceMonthLabel(september), 'Aug 2026');
    });
  });

  group('monthSummaryProvider', () {
    test('returns only the requested month', () async {
      await seedLedger(
        firestore: db,
        categories: [category('groceries', budget: 500)],
        summaries: [
          summary('groceries', total: 620, month: DateTime(2026, 8)),
          summary('groceries', total: 90, month: DateTime(2026, 9)),
        ],
      );
      final container = buildContainer();

      final august = await firstValue(
        container,
        monthSummaryProvider(DateTime(2026, 8)),
      );

      expect(august, hasLength(1));
      expect(august.single.total, 620);
    });

    test('an adjacent month written at local midnight does not leak in',
        () async {
      // The regression the ±24h bounds exist for: startDate is written as local
      // midnight of the 1st and stored as a UTC instant, so a naive range query
      // pulls in the neighbouring month.
      await seedLedger(
        firestore: db,
        categories: [category('groceries', budget: 500)],
        summaries: [
          summary('groceries', total: 620, month: DateTime(2026, 8)),
          summary('groceries', total: 50, month: DateTime(2026, 9)),
          summary('groceries', total: 75, month: DateTime(2026, 10)),
        ],
      );
      final container = buildContainer();

      final september = await firstValue(
        container,
        monthSummaryProvider(DateTime(2026, 9)),
      );

      expect(september, hasLength(1));
      expect(september.single.total, 50,
          reason: 'August and October must not leak into September');
    });

    test('an empty month yields an empty list', () async {
      await seedLedger(
        firestore: db,
        categories: [category('groceries', budget: 500)],
      );
      final container = buildContainer();

      expect(
        await firstValue(container, monthSummaryProvider(DateTime(2026, 8))),
        isEmpty,
      );
    });
  });

  group('rolloverPoolProvider', () {
    test('derives the net pool from the previous month', () async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1);

      await seedLedger(
        firestore: db,
        categories: [
          category('groceries', budget: 500),
          category('dining', budget: 200),
        ],
        summaries: [
          summary('groceries', total: 620, month: lastMonth),
          summary('dining', total: 245, month: lastMonth),
        ],
      );
      final container = buildContainer();

      final pool = await firstValue(container, rolloverPoolProvider);

      expect(pool, 165);
    });

    test('is empty when the previous month stayed within budget', () async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1);

      await seedLedger(
        firestore: db,
        categories: [category('groceries', budget: 500)],
        summaries: [summary('groceries', total: 300, month: lastMonth)],
      );
      final container = buildContainer();

      expect(await firstValue(container, rolloverPoolProvider), 0);
    });

    test('is empty when underspend elsewhere absorbs the overage', () async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1);

      await seedLedger(
        firestore: db,
        categories: [
          category('groceries', budget: 500),
          category('travel', budget: 400),
        ],
        summaries: [
          summary('groceries', total: 620, month: lastMonth),
          summary('travel', total: 250, month: lastMonth),
        ],
      );
      final container = buildContainer();

      expect(await firstValue(container, rolloverPoolProvider), 0,
          reason: 'the ledger came in under budget overall');
    });
  });

  group('rolloverCandidatesProvider', () {
    test('offers active categories with this month committed spend', () async {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month);

      await seedLedger(
        firestore: db,
        categories: [
          category('groceries', budget: 500),
          category('dining', budget: 200),
        ],
        summaries: [
          // An amortized installment already landed for this month.
          summary('groceries', total: 50, month: thisMonth),
        ],
      );
      final container = buildContainer();

      final candidates = await firstValue(container, rolloverCandidatesProvider);
      final byId = {for (final c in candidates) c.id: c};

      expect(byId.keys, containsAll(['groceries', 'dining']));
      expect(byId['groceries']!.committed, 50);
      expect(byId['dining']!.committed, 0,
          reason: 'an unspent category has no summary yet');
    });

    test('excludes deleted categories', () async {
      await seedLedger(
        firestore: db,
        categories: [
          category('groceries', budget: 500),
          category('subscriptions', budget: 50, deleted: true),
        ],
      );
      final container = buildContainer();

      final candidates = await firstValue(container, rolloverCandidatesProvider);

      expect(candidates.map((c) => c.id), ['groceries']);
    });
  });

  group('rolloverStatusProvider', () {
    test('emits null when the ledger has no rolloverStatus field', () async {
      await seedLedger(
        firestore: db,
        categories: [category('groceries', budget: 500)],
      );
      final container = buildContainer();

      final sub = container.listen(rolloverStatusProvider, (_, __) {},
          fireImmediately: true);
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(rolloverStatusProvider).valueOrNull, isNull);
    });

    test('exposes the record for the month in progress with dates decoded',
        () async {
      final claimedAt = DateTime(2026, 9, 1, 8, 30);
      await seedLedger(
        firestore: db,
        categories: [category('groceries', budget: 500)],
        rolloverStatus: {
          currentMonthKey(): rolloverRecord(
            status: kRolloverPending,
            claimedBy: testPartnerId,
            claimedAt: claimedAt,
          ),
        },
      );
      final container = buildContainer();

      final record = await firstValue(
        container,
        rolloverStatusProvider.select((v) => v),
      );

      expect(record!['status'], kRolloverPending);
      expect(record['claimedBy'], testPartnerId);
      expect(record['claimedAt'], isA<DateTime>(),
          reason: 'Timestamps are normalised for the pure calculator');
      expect(record['claimedAt'], claimedAt);
    });

    test('ignores a record belonging to a different month', () async {
      await seedLedger(
        firestore: db,
        categories: [category('groceries', budget: 500)],
        rolloverStatus: {
          '1999_JAN': rolloverRecord(status: kRolloverComplete),
        },
      );
      final container = buildContainer();

      final sub = container.listen(rolloverStatusProvider, (_, __) {},
          fireImmediately: true);
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(rolloverStatusProvider).valueOrNull, isNull);
    });
  });

  group('effective budgets', () {
    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final nextMonth = DateTime(thisMonth.year, thisMonth.month + 1);

    Future<ProviderContainer> seedWithAllocations(
      Map<String, dynamic> allocations,
    ) async {
      await seedLedger(
        firestore: db,
        categories: [
          category('travel', budget: 400),
          category('gifts', budget: 300),
          category('groceries', budget: 500),
        ],
        rolloverStatus: {
          if (allocations.isNotEmpty)
            monthKeyFor(thisMonth): {
              ...rolloverRecord(status: kRolloverComplete),
              'allocations': allocations,
            },
        },
      );
      final container = buildContainer();
      // Both upstream streams have to have emitted before the derived budgets
      // mean anything: the configured categories and the ledger's allocations.
      final sub = container.listen(rolloverStatusesProvider, (_, __) {},
          fireImmediately: true);
      addTearDown(sub.close);
      await firstValue(container, budgetProvider);
      await firstValue(container, rolloverStatusesProvider);
      return container;
    }

    Map<String, double> budgetsOf(
      ProviderContainer container,
      DateTime month,
    ) {
      final categories =
          container.read(adjustedCategoriesProvider(month)).valueOrNull ?? [];
      return {for (final c in categories) c.id: c.budget};
    }

    test('allocations reduce that month\'s budgets', () async {
      final container =
          await seedWithAllocations({'travel': 250.0, 'gifts': 250.0});

      expect(budgetsOf(container, thisMonth), {
        'travel': 150,
        'gifts': 50,
        'groceries': 500,
      });
    });

    test('later months keep the configured budgets', () async {
      final container =
          await seedWithAllocations({'travel': 250.0, 'gifts': 250.0});

      expect(budgetsOf(container, nextMonth), {
        'travel': 400,
        'gifts': 300,
        'groceries': 500,
      });
    });

    test('a month with no allocations is unchanged', () async {
      final container = await seedWithAllocations(const {});

      expect(budgetsOf(container, thisMonth), {
        'travel': 400,
        'gifts': 300,
        'groceries': 500,
      });
    });

    test('an allocation larger than the budget goes negative', () async {
      final container = await seedWithAllocations({'gifts': 400.0});

      expect(budgetsOf(container, thisMonth)['gifts'], -100);
    });

    test('the configured budgets are left untouched', () async {
      final container =
          await seedWithAllocations({'travel': 250.0, 'gifts': 250.0});

      final configured = container.read(budgetProvider).valueOrNull ?? [];
      expect(
        {for (final c in configured) c.id: c.budget},
        {'travel': 400, 'gifts': 300, 'groceries': 500},
        reason: 'the budget config screen must still show what was configured',
      );
    });
  });

  group('rolloverEligibilityProvider', () {
    Future<bool> eligibility({
      required Map<String, dynamic> status,
      DateTime? initialized,
      double previousSpend = 620,
      String? deferred,
    }) async {
      final now = DateTime.now();
      await seedLedger(
        firestore: db,
        categories: [category('groceries', budget: 500)],
        summaries: [
          summary('groceries',
              total: previousSpend, month: DateTime(now.year, now.month - 1)),
        ],
        rolloverStatus: status,
      );
      final container = buildContainer(user: buildUser(initialized: initialized));

      // Keep the predicate subscribed, then let both upstream streams emit
      // before reading it — otherwise the status stream is still loading and
      // the record under test has not been seen yet.
      final sub = container.listen(rolloverEligibilityProvider, (_, __) {},
          fireImmediately: true);
      addTearDown(sub.close);
      await firstValue(container, rolloverPoolProvider);
      await firstValue(container, rolloverStatusProvider);

      if (deferred != null) {
        container.read(rolloverDeferredProvider.notifier).state = deferred;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      return container.read(rolloverEligibilityProvider);
    }

    test('prompts when the previous month overspent and nothing blocks it',
        () async {
      expect(await eligibility(status: const {}), isTrue);
    });

    test('does not prompt when the previous month stayed in budget', () async {
      expect(
        await eligibility(status: const {}, previousSpend: 300),
        isFalse,
      );
    });

    test('does not prompt once the ledger records completion', () async {
      expect(
        await eligibility(status: {
          currentMonthKey(): rolloverRecord(
            status: kRolloverComplete,
            claimedBy: testPartnerId,
          ),
        }),
        isFalse,
      );
    });

    test('does not prompt while a fresh claim is held', () async {
      expect(
        await eligibility(status: {
          currentMonthKey(): rolloverRecord(
            status: kRolloverPending,
            claimedBy: testPartnerId,
            claimedAt: DateTime.now().subtract(const Duration(seconds: 20)),
          ),
        }),
        isFalse,
      );
    });

    test('prompts again once a claim goes stale', () async {
      expect(
        await eligibility(status: {
          currentMonthKey(): rolloverRecord(
            status: kRolloverPending,
            claimedBy: testPartnerId,
            claimedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        }),
        isTrue,
      );
    });

    test('does not prompt an account created this month', () async {
      final now = DateTime.now();
      expect(
        await eligibility(
          status: const {},
          initialized: DateTime(now.year, now.month, 1),
        ),
        isFalse,
      );
    });

    test('does not prompt after deferring this session', () async {
      expect(
        await eligibility(status: const {}, deferred: currentMonthKey()),
        isFalse,
      );
    });
  });
}
