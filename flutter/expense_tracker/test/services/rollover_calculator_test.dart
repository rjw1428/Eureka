import 'dart:math';

import 'package:expense_tracker/services/rollover_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scenario coverage for openspec/changes/monthly-rollover-modal/specs/
/// monthly-rollover/spec.md — the pool, allocation, left-to-spend, liveness,
/// and eligibility requirements.
void main() {
  RolloverCategory cat(String id, double budget, {bool deleted = false}) =>
      RolloverCategory(id: id, budget: budget, deleted: deleted);

  group('computeNetOverspend', () {
    test('nets overspend across multiple categories', () {
      final pool = computeNetOverspend(
        categories: [cat('groceries', 500), cat('dining', 200)],
        previousMonthSpendByCategory: {'groceries': 620, 'dining': 245},
      );

      expect(pool, 165);
    });

    test('a single overspent category with everything else on budget', () {
      final pool = computeNetOverspend(
        categories: [cat('groceries', 500), cat('dining', 200)],
        previousMonthSpendByCategory: {'groceries': 620, 'dining': 200},
      );

      expect(pool, 120);
    });

    test('no overspend yields an empty pool', () {
      final pool = computeNetOverspend(
        categories: [cat('groceries', 500), cat('dining', 200)],
        previousMonthSpendByCategory: {'groceries': 400, 'dining': 100},
      );

      expect(pool, 0);
    });

    test('underspend offsets overspend', () {
      final pool = computeNetOverspend(
        categories: [cat('groceries', 500), cat('travel', 400)],
        previousMonthSpendByCategory: {'groceries': 700, 'travel': 250},
      );

      // $200 over on groceries, $150 under on travel.
      expect(pool, 50);
    });

    test('a month that nets out under budget carries nothing', () {
      final pool = computeNetOverspend(
        categories: [cat('groceries', 500), cat('travel', 400)],
        previousMonthSpendByCategory: {'groceries': 620, 'travel': 250},
      );

      // $120 over on groceries, $150 under on travel.
      expect(pool, 0,
          reason: 'no prompt when the household came in under budget overall');
    });

    test('a month exactly on budget in aggregate carries nothing', () {
      final pool = computeNetOverspend(
        categories: [cat('groceries', 500), cat('travel', 400)],
        previousMonthSpendByCategory: {'groceries': 600, 'travel': 300},
      );

      expect(pool, 0);
    });

    test('a deleted category counts on both sides', () {
      final pool = computeNetOverspend(
        categories: [
          cat('groceries', 500),
          cat('subscriptions', 50, deleted: true),
        ],
        previousMonthSpendByCategory: {'groceries': 620, 'subscriptions': 130},
      );

      // Spend $750 against budget $550.
      expect(pool, 200);
    });

    test("a deleted category's unused budget still absorbs overspend", () {
      final pool = computeNetOverspend(
        categories: [
          cat('groceries', 500),
          cat('subscriptions', 100, deleted: true),
        ],
        previousMonthSpendByCategory: {'groceries': 560, 'subscriptions': 0},
      );

      // $60 over on groceries, absorbed by $100 of unspent subscriptions.
      expect(pool, 0);
    });

    group('edge cases', () {
      test('a category with a zero budget contributes all its spend', () {
        final pool = computeNetOverspend(
          categories: [cat('misc', 0)],
          previousMonthSpendByCategory: {'misc': 75},
        );

        expect(pool, 75);
      });

      test('a category with a budget and no summary contributes nothing', () {
        final pool = computeNetOverspend(
          categories: [cat('groceries', 500)],
          previousMonthSpendByCategory: const {},
        );

        expect(pool, 0);
      });

      test('spend exactly at budget contributes nothing', () {
        final pool = computeNetOverspend(
          categories: [cat('groceries', 500)],
          previousMonthSpendByCategory: {'groceries': 500},
        );

        expect(pool, 0);
      });

      test('a summary for an unknown category is ignored', () {
        final pool = computeNetOverspend(
          categories: [cat('groceries', 500)],
          previousMonthSpendByCategory: {'groceries': 510, 'ghost': 900},
        );

        expect(pool, 10,
            reason: 'a category with no budget has nothing to measure against');
      });

      test('an empty budget configuration yields an empty pool', () {
        final pool = computeNetOverspend(
          categories: const [],
          previousMonthSpendByCategory: {'ghost': 900},
        );

        expect(pool, 0);
      });

      test('fractional amounts round to clean cents', () {
        final pool = computeNetOverspend(
          categories: [cat('a', 0.1), cat('b', 0.1), cat('c', 0.1)],
          previousMonthSpendByCategory: {'a': 0.2, 'b': 0.2, 'c': 0.2},
        );

        // Three lots of 0.1 in binary floating point would otherwise surface
        // as 0.30000000000000004.
        expect(pool, 0.3);
      });
    });
  });

  group('sliderMaxFor', () {
    test("a slider runs to the category's own budget", () {
      expect(sliderMaxFor(500), 500);
      expect(sliderMaxFor(200), 200);
    });

    test('the scale does not depend on what other rows hold', () {
      // The whole point: two calls with the same budget agree regardless of
      // any allocation state elsewhere.
      expect(sliderMaxFor(500), sliderMaxFor(500));
    });

    test('a zero budget yields a zero range', () {
      expect(sliderMaxFor(0), 0);
    });
  });

  group('clampAllocations', () {
    test('accepts a value that fits', () {
      final next = clampAllocations(
        allocations: {'groceries': 100},
        categoryId: 'dining',
        requested: 45,
        pool: 165,
      );

      expect(next, {'groceries': 100, 'dining': 45});
    });

    test('clamps a value that would exceed the pool', () {
      final next = clampAllocations(
        allocations: {'groceries': 145},
        categoryId: 'dining',
        requested: 60,
        pool: 165,
      );

      expect(next['dining'], 20);
      expect(totalAllocated(next), 165);
    });

    test('drops a row set back to zero', () {
      final next = clampAllocations(
        allocations: {'groceries': 100, 'dining': 45},
        categoryId: 'dining',
        requested: 0,
        pool: 165,
      );

      expect(next.containsKey('dining'), isFalse);
      expect(totalAllocated(next), 100);
    });

    test('a negative request is treated as zero', () {
      final next = clampAllocations(
        allocations: {'groceries': 100},
        categoryId: 'groceries',
        requested: -50,
        pool: 165,
      );

      expect(next.containsKey('groceries'), isFalse);
    });

    test('raising one row does not silently shrink another', () {
      final next = clampAllocations(
        allocations: {'groceries': 100, 'dining': 45},
        categoryId: 'groceries',
        requested: 165,
        pool: 165,
      );

      expect(next['dining'], 45, reason: 'other rows are left alone');
      expect(next['groceries'], 120, reason: 'clamped to available headroom');
    });

    test('the total never exceeds the pool across random sequences', () {
      final rng = Random(20260901);
      const pool = 165.0;
      final ids = ['a', 'b', 'c', 'd'];

      for (var trial = 0; trial < 500; trial++) {
        var allocations = <String, double>{};
        for (var step = 0; step < 12; step++) {
          allocations = clampAllocations(
            allocations: allocations,
            categoryId: ids[rng.nextInt(ids.length)],
            // Deliberately over-wide, including values beyond the pool.
            requested: rng.nextDouble() * pool * 1.5,
            pool: pool,
          );

          expect(totalAllocated(allocations), lessThanOrEqualTo(pool));
          expect(unallocated(allocations, pool), greaterThanOrEqualTo(0));
          for (final value in allocations.values) {
            expect(value, greaterThan(0));
            expect(value, value.roundToDouble(), reason: 'whole dollars only');
          }
        }
      }
    });
  });

  group('effectiveBudget', () {
    test('an allocation reduces the month budget', () {
      expect(effectiveBudget(configuredBudget: 400, allocation: 250), 150);
    });

    test('no allocation leaves the configured budget', () {
      expect(effectiveBudget(configuredBudget: 400, allocation: 0), 400);
    });

    test('an allocation larger than the budget goes negative', () {
      expect(effectiveBudget(configuredBudget: 100, allocation: 165), -65);
    });

    test('applies allocations across a set of categories', () {
      final budgets = effectiveBudgets(
        configuredBudgets: {'travel': 400, 'gifts': 300, 'groceries': 500},
        allocations: {'travel': 250, 'gifts': 250},
      );

      expect(budgets, {'travel': 150, 'gifts': 50, 'groceries': 500});
    });

    test('an allocation for an unknown category is ignored', () {
      final budgets = effectiveBudgets(
        configuredBudgets: {'travel': 400},
        allocations: {'ghost': 100},
      );

      expect(budgets, {'travel': 400});
    });

    test('no allocations leaves every budget untouched', () {
      final budgets = effectiveBudgets(
        configuredBudgets: {'travel': 400, 'gifts': 300},
        allocations: const {},
      );

      expect(budgets, {'travel': 400, 'gifts': 300});
    });
  });

  group('leftToSpend', () {
    test('committed amortized spend plus allocation under budget', () {
      // $50 already committed this month, $400 budget, $100 rolled over.
      expect(
        leftToSpend(budget: 400, committed: 50, allocation: 100),
        250,
      );
    });

    test('goes negative when the allocation pushes past the budget', () {
      expect(
        leftToSpend(budget: 100, committed: 60, allocation: 80),
        -40,
      );
    });

    test('a zero allocation leaves the ordinary remaining figure', () {
      expect(
        leftToSpend(budget: 400, committed: 50, allocation: 0),
        350,
      );
    });
  });

  group('isLiveRolloverRecord', () {
    final now = DateTime(2026, 9, 1, 12, 0);

    test('no record is not live', () {
      expect(isLiveRolloverRecord(null, now), isFalse);
    });

    test('a completion is live regardless of age', () {
      final record = {
        'status': kRolloverComplete,
        'claimedAt': DateTime(2026, 9, 1, 8, 0),
        'completedAt': DateTime(2026, 9, 1, 8, 1),
      };

      expect(isLiveRolloverRecord(record, now), isTrue);
      expect(
        isLiveRolloverRecord(record, now.add(const Duration(days: 20))),
        isTrue,
      );
    });

    test('a pending claim under two minutes old is live', () {
      final record = {
        'status': kRolloverPending,
        'claimedAt': now.subtract(const Duration(seconds: 119)),
      };

      expect(isLiveRolloverRecord(record, now), isTrue);
    });

    test('a pending claim over two minutes old is stale', () {
      final record = {
        'status': kRolloverPending,
        'claimedAt': now.subtract(const Duration(seconds: 121)),
      };

      expect(isLiveRolloverRecord(record, now), isFalse);
    });

    test('a pending claim whose timestamp has not resolved is live', () {
      // Firestore surfaces serverTimestamp() as null on the local echo.
      expect(
        isLiveRolloverRecord({'status': kRolloverPending, 'claimedAt': null}, now),
        isTrue,
      );
    });

    test('an unrecognised status is not live', () {
      expect(
        isLiveRolloverRecord({'status': 'something-else'}, now),
        isFalse,
      );
      expect(isLiveRolloverRecord(const {}, now), isFalse);
    });
  });

  group('isEligible', () {
    final now = DateTime(2026, 9, 1, 9, 0);
    const monthKey = '2026_SEP';

    bool eligible({
      DateTime? accountInitialized,
      double poolTotal = 165,
      Map<String, dynamic>? record,
      String? deferred,
      DateTime? at,
    }) {
      return isEligible(
        now: at ?? now,
        accountInitialized: accountInitialized ?? DateTime(2025, 3, 4),
        poolTotal: poolTotal,
        rolloverRecord: record,
        currentMonthKey: monthKey,
        deferredMonthKey: deferred,
      );
    }

    test('prompts when every condition holds', () {
      expect(eligible(), isTrue);
    });

    test('blocked when there is no overspend', () {
      expect(eligible(poolTotal: 0), isFalse);
    });

    test('blocked by a completion record', () {
      expect(eligible(record: {'status': kRolloverComplete}), isFalse);
    });

    test('blocked by a fresh pending claim', () {
      expect(
        eligible(record: {
          'status': kRolloverPending,
          'claimedAt': now.subtract(const Duration(seconds: 30)),
        }),
        isFalse,
      );
    });

    test('not blocked by a stale pending claim', () {
      expect(
        eligible(record: {
          'status': kRolloverPending,
          'claimedAt': now.subtract(const Duration(minutes: 5)),
        }),
        isTrue,
      );
    });

    test('blocked for an account initialized this month', () {
      expect(eligible(accountInitialized: DateTime(2026, 9, 1)), isFalse);
    });

    test('blocked for an account initialized later in this month', () {
      expect(eligible(accountInitialized: DateTime(2026, 9, 20)), isFalse);
    });

    test('allowed for an account initialized the previous month', () {
      expect(eligible(accountInitialized: DateTime(2026, 8, 31)), isTrue);
    });

    test('blocked when deferred this session', () {
      expect(eligible(deferred: monthKey), isFalse);
    });

    test('not blocked by a deferral from a different month', () {
      expect(eligible(deferred: '2026_AUG'), isTrue);
    });

    test('still prompts later in the month', () {
      expect(eligible(at: DateTime(2026, 9, 4, 18, 30)), isTrue);
    });
  });
}
