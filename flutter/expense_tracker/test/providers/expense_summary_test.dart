import 'package:flutter_test/flutter_test.dart';

import '../helpers/expense_fixtures.dart';

/// Category-month summaries are what the budget, the spending report and the
/// rollover prompt all read. Nothing recomputes them from the raw expenses, so
/// a delta that is applied twice, dropped, or aimed at the wrong bucket is
/// silent until the numbers are visibly wrong.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final march = DateTime(2026, 3, 10);
  final april = DateTime(2026, 4, 12);

  group('adding', () {
    test('an expense adds its amount and one to the count', () async {
      final h = await buildExpenseHarness();

      await h.notifier.addExpense(buildExpense(amount: 25));

      expect(await h.summaryTotal('groceries', march), 25);
      expect(await h.summaryCount('groceries', march), 1);
    });

    test('expenses accumulate rather than overwrite', () async {
      final h = await buildExpenseHarness();

      await h.notifier.addExpense(buildExpense(amount: 25));
      await h.notifier.addExpense(buildExpense(amount: 10));

      expect(await h.summaryTotal('groceries', march), 35);
      expect(await h.summaryCount('groceries', march), 2);
    });

    test('categories are totalled independently', () async {
      final h = await buildExpenseHarness();

      await h.notifier.addExpense(buildExpense(amount: 25));
      await h.notifier.addExpense(buildExpense(amount: 40, categoryId: 'travel'));

      expect(await h.summaryTotal('groceries', march), 25);
      expect(await h.summaryTotal('travel', march), 40);
    });

    test('months are totalled independently', () async {
      final h = await buildExpenseHarness();

      await h.notifier.addExpense(buildExpense(amount: 25));
      await h.notifier.addExpense(buildExpense(amount: 40, date: april));

      expect(await h.summaryTotal('groceries', march), 25);
      expect(await h.summaryTotal('groceries', april), 40);
    });

    test('the summary records the month it belongs to', () async {
      final h = await buildExpenseHarness();

      await h.notifier.addExpense(buildExpense(amount: 25));

      final summary = (await h.summaryFor('groceries', march))!;
      expect(summary['categoryId'], 'groceries');
      expect((summary['startDate'] as dynamic).toDate(), DateTime(2026, 3));
    });
  });

  group('updating within a month', () {
    test('a changed amount moves the total by the difference only', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.updateExpense(
        buildExpense(amount: 40, id: id),
        buildExpense(amount: 25, id: id),
      );

      expect(await h.summaryTotal('groceries', march), 40);
      expect(await h.summaryCount('groceries', march), 1,
          reason: 'an edit is not a second transaction');
    });

    test('an unchanged amount leaves the total alone', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.updateExpense(
        buildExpense(amount: 25, id: id, note: 'renamed'),
        buildExpense(amount: 25, id: id),
      );

      expect(await h.summaryTotal('groceries', march), 25);
      expect((await h.expensesIn(march)).single['note'], 'renamed');
    });

    test('a changed category moves the whole transaction between buckets',
        () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.updateExpense(
        buildExpense(amount: 25, id: id, categoryId: 'travel'),
        buildExpense(amount: 25, id: id),
      );

      expect(await h.summaryTotal('groceries', march), 0);
      expect(await h.summaryCount('groceries', march), 0);
      expect(await h.summaryTotal('travel', march), 25);
      expect(await h.summaryCount('travel', march), 1);
    });

    test('a category and amount change in one edit lands both', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.updateExpense(
        buildExpense(amount: 60, id: id, categoryId: 'travel'),
        buildExpense(amount: 25, id: id),
      );

      expect(await h.summaryTotal('groceries', march), 0);
      expect(await h.summaryTotal('travel', march), 60);
    });

    test('the expense keeps its document id', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.updateExpense(
        buildExpense(amount: 40, id: id),
        buildExpense(amount: 25, id: id),
      );

      final docs = await h.expensesIn(march);
      expect(docs, hasLength(1));
      expect(docs.single['id'], id);
    });
  });

  group('moving to another month', () {
    test('the amount leaves the old bucket and lands in the new one', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.updateExpense(
        buildExpense(amount: 25, id: id, date: april),
        buildExpense(amount: 25, id: id),
      );

      expect(await h.summaryTotal('groceries', march), 0);
      expect(await h.summaryCount('groceries', march), 0);
      expect(await h.summaryTotal('groceries', april), 25);
      expect(await h.summaryCount('groceries', april), 1);
    });

    test('the document moves buckets rather than being copied', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.updateExpense(
        buildExpense(amount: 25, id: id, date: april),
        buildExpense(amount: 25, id: id),
      );

      expect(await h.expensesIn(march), isEmpty);
      expect(await h.expensesIn(april), hasLength(1));
    });

    test('a move that also changes the amount carries the new figure',
        () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.updateExpense(
        buildExpense(amount: 80, id: id, date: april),
        buildExpense(amount: 25, id: id),
      );

      expect(await h.summaryTotal('groceries', march), 0);
      expect(await h.summaryTotal('groceries', april), 80);
    });
  });

  group('deleting', () {
    test('the amount and the count are both given back', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.removeExpense(buildExpense(amount: 25, id: id));

      expect(await h.summaryTotal('groceries', march), 0);
      expect(await h.summaryCount('groceries', march), 0);
      expect(await h.expensesIn(march), isEmpty);
    });

    test('only the deleted expense is given back', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));
      await h.notifier.addExpense(buildExpense(amount: 10));

      await h.notifier.removeExpense(buildExpense(amount: 25, id: id));

      expect(await h.summaryTotal('groceries', march), 10);
      expect(await h.summaryCount('groceries', march), 1);
    });

    test('a delete against a month with no summary does not throw', () async {
      // `set(merge:true)` with an increment tolerates a missing document; an
      // `update` would throw and abandon the document deletion.
      final h = await buildExpenseHarness();
      final ref = await h.monthCollection(march).add({
        'amount': 25,
        'date': march.toIso8601String(),
        'categoryId': 'groceries',
        'reactions': <String>[],
      });

      await expectLater(
        h.notifier.removeExpense(buildExpense(amount: 25, id: ref.id)),
        completes,
      );
      expect(await h.expensesIn(march), isEmpty);
    });
  });

  group('expenses hidden from a partner', () {
    final future = DateTime(2026, 12, 31);

    test('someone else\'s hidden expense cannot be updated', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));
      final hidden = buildExpense(
        amount: 25,
        id: id,
        hideUntil: future,
        submittedBy: 'partner',
      );

      final ok = await h.notifier
          .updateExpense(buildExpense(amount: 999, id: id), hidden);

      expect(ok, isFalse);
      expect(await h.summaryTotal('groceries', march), 25);
      expect((await h.expensesIn(march)).single['amount'], 25);
    });

    test('someone else\'s hidden expense cannot be deleted', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));

      await h.notifier.removeExpense(buildExpense(
        amount: 25,
        id: id,
        hideUntil: future,
        submittedBy: 'partner',
      ));

      expect(await h.expensesIn(march), hasLength(1));
      expect(await h.summaryTotal('groceries', march), 25);
    });

    test('the submitter may still edit their own hidden expense', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));
      final mine = buildExpense(
        amount: 25,
        id: id,
        hideUntil: future,
        submittedBy: testUserId,
      );

      final ok = await h.notifier.updateExpense(
        buildExpense(amount: 40, id: id, hideUntil: future),
        mine,
      );

      expect(ok, isTrue);
      expect(await h.summaryTotal('groceries', march), 40);
    });

    test('a hidden expense whose date has passed is editable by anyone',
        () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: 25));
      final expired = buildExpense(
        amount: 25,
        id: id,
        hideUntil: DateTime(2020, 1, 1),
        submittedBy: 'partner',
      );

      final ok = await h.notifier
          .updateExpense(buildExpense(amount: 40, id: id), expired);

      expect(ok, isTrue);
      expect(await h.summaryTotal('groceries', march), 40);
    });
  });
}
