import 'package:expense_tracker/models/expense.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/expense_fixtures.dart';

/// Amortization is split across two systems: the client writes installment 1
/// and updates its summary, and `createAmortizedExpenses` builds months 2..N
/// from a template. These tests pin down the client's half and the exact
/// payload handed across that boundary, since a template that is wrong or
/// never sent is invisible until the following month arrives.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final march = DateTime(2026, 3, 10);
  final april = DateTime(2026, 4, 10);

  setUpAll(() => registerFallbackValue(receiptBytes));

  group('creating a series', () {
    test('the current month is charged one installment, not the total',
        () async {
      final h = await buildExpenseHarness();

      await h.notifier.addAmortizedExpense(buildExpense(amount: 300), 3);

      final docs = await h.expensesIn(march);
      expect(docs.single['amount'], 100);
      expect(await h.summaryTotal('groceries', march), 100);
      expect(await h.summaryCount('groceries', march), 1);
    });

    test('installment 1 records its position in the series', () async {
      final h = await buildExpenseHarness();

      await h.notifier.addAmortizedExpense(buildExpense(amount: 300), 3);

      final amortized =
          (await h.expensesIn(march)).single['amortized'] as Map<String, dynamic>;
      expect(amortized['index'], 1);
      expect(amortized['over'], 3);
      expect(amortized['groupId'], isNotEmpty);
    });

    test('the Cloud Function is handed the full total to divide, not the '
        'installment', () async {
      // The function re-derives `amount / months` itself. Sending it the
      // already-divided figure would shrink every later month by a factor of N.
      final h = await buildExpenseHarness();

      await h.notifier.addAmortizedExpense(buildExpense(amount: 300), 3);

      final call = h.functions.lastCallTo('createAmortizedExpenses')!;
      expect((call.payload['template'] as Map)['amount'], 300);
      expect(call.payload['months'], 3);
      expect(call.payload['ledgerId'], testLedgerId);
    });

    test('the function is told which document is installment 1, under the same '
        'group id', () async {
      final h = await buildExpenseHarness();

      final id = await h.notifier.addAmortizedExpense(buildExpense(amount: 300), 3);

      final call = h.functions.lastCallTo('createAmortizedExpenses')!;
      expect(call.payload['firstExpenseId'], id);
      final stored =
          (await h.expenseAt(march, id!))!['amortized'] as Map<String, dynamic>;
      expect(call.payload['groupId'], stored['groupId']);
    });

    test('addExpense routes an amortized expense into the series path',
        () async {
      final h = await buildExpenseHarness();

      await h.notifier.addExpense(buildExpense(amount: 300, amortizedOver: 3));

      expect((await h.expensesIn(march)).single['amount'], 100);
      expect(h.functions.callsTo('createAmortizedExpenses'), hasLength(1));
    });

    test('a receipt is uploaded once and referenced by the whole series',
        () async {
      final h = await buildExpenseHarness();

      await h.notifier.addAmortizedExpense(
        buildExpense(amount: 300),
        3,
        null,
        receiptBytes,
      );

      final docs = await h.expensesIn(march);
      expect(docs.single['receiptId'], 'new-receipt');
      // Months 2..N inherit the reference through the template rather than
      // uploading their own copy.
      final template =
          h.functions.lastCallTo('createAmortizedExpenses')!.payload['template']
              as Map;
      expect(template['receiptId'], 'new-receipt');
      verify(() => h.receipts.upload(
            ledgerId: any(named: 'ledgerId'),
            bytes: any(named: 'bytes'),
          )).called(1);
    });

    test('the document id is never written into the payload', () async {
      // The id belongs to the path. A stale copy in the body would survive a
      // move between month buckets and disagree with the real document id.
      final h = await buildExpenseHarness();

      await h.notifier
          .addAmortizedExpense(buildExpense(amount: 300, id: 'stale-id'), 3);

      final doc = await h.monthCollection(march).get();
      expect(doc.docs.single.data().containsKey('id'), isFalse);
    });
  });

  group('converting a plain expense into a series', () {
    /// The regression this suite exists for: the edit form used to drop the
    /// amortization details, so the update looked ordinary, the month's amount
    /// never changed and no later months were ever created.
    Future<({dynamic h, String id, Expense previous})> existingPlainExpense({
      double amount = 90,
    }) async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addExpense(buildExpense(amount: amount));
      final previous = buildExpense(amount: amount, id: id);
      return (h: h, id: id!, previous: previous);
    }

    test('the month is re-charged at one installment', () async {
      final ctx = await existingPlainExpense(amount: 90);
      final h = ctx.h as ExpenseHarness;

      final ok = await h.notifier.updateExpense(
        buildExpense(amount: 90, id: ctx.id, amortizedOver: 3),
        ctx.previous,
      );

      expect(ok, isTrue);
      expect((await h.expensesIn(march)).single['amount'], 30);
      expect(await h.summaryTotal('groceries', march), 30);
      expect(await h.summaryCount('groceries', march), 1,
          reason: 'the expense moved into a series, it was not duplicated');
    });

    test('the later months are requested from the Cloud Function', () async {
      final ctx = await existingPlainExpense(amount: 90);
      final h = ctx.h as ExpenseHarness;

      await h.notifier.updateExpense(
        buildExpense(amount: 90, id: ctx.id, amortizedOver: 3),
        ctx.previous,
      );

      final call = h.functions.lastCallTo('createAmortizedExpenses');
      expect(call, isNotNull,
          reason: 'without this call no future month is ever created');
      expect((call!.payload['template'] as Map)['amount'], 90);
      expect(call.payload['months'], 3);
    });

    test('installment 1 keeps the original document id', () async {
      final ctx = await existingPlainExpense();
      final h = ctx.h as ExpenseHarness;

      await h.notifier.updateExpense(
        buildExpense(amount: 90, id: ctx.id, amortizedOver: 3),
        ctx.previous,
      );

      final docs = await h.expensesIn(march);
      expect(docs, hasLength(1), reason: 'the plain document is reused');
      expect(docs.single['id'], ctx.id);
      expect((docs.single['amortized'] as Map)['index'], 1);
    });

    test('edits made in the same submission are carried into the series',
        () async {
      final ctx = await existingPlainExpense();
      final h = ctx.h as ExpenseHarness;

      await h.notifier.updateExpense(
        buildExpense(
          amount: 90,
          id: ctx.id,
          amortizedOver: 3,
          categoryId: 'travel',
          note: 'annual pass',
        ),
        ctx.previous,
      );

      final doc = (await h.expensesIn(march)).single;
      expect(doc['categoryId'], 'travel');
      expect(doc['note'], 'annual pass');
      expect(await h.summaryTotal('travel', march), 30);
      expect(await h.summaryTotal('groceries', march), 0,
          reason: 'the old category gives the whole original amount back');
    });

    test('a series that cannot be written reports failure', () async {
      final ctx = await existingPlainExpense();
      final h = ctx.h as ExpenseHarness;
      h.functions.failing.add('createAmortizedExpenses');

      final ok = await h.notifier.updateExpense(
        buildExpense(amount: 90, id: ctx.id, amortizedOver: 3),
        ctx.previous,
      );

      expect(ok, isFalse,
          reason: 'reporting success here would hide a lost expense');
    });
  });

  group('editing an existing series', () {
    test('the series is torn down and rebuilt from the new values', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addAmortizedExpense(buildExpense(amount: 300), 3);
      final previous = (await h.expenseAt(march, id!))!;
      final previousExpense =
          Expense.fromJson({...previous, 'id': id});
      h.functions.invocations.clear();

      final ok = await h.notifier.updateExpense(
        buildExpense(
          amount: 300,
          id: id,
          amortized: AmortizationDetails(groupId: '', index: 0, over: 3),
          note: 'revised',
        ),
        previousExpense,
      );

      expect(ok, isTrue);
      expect(h.functions.callsTo('deleteAmortizedSeries'), hasLength(1));
      expect(h.functions.callsTo('createAmortizedExpenses'), hasLength(1));
      expect((await h.expensesIn(march)).single['note'], 'revised');
    });

    test('the teardown targets the old group and spares installment 1',
        () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addAmortizedExpense(buildExpense(amount: 300), 3);
      final stored = (await h.expenseAt(march, id!))!;
      final oldGroupId = (stored['amortized'] as Map)['groupId'];

      await h.notifier.updateExpense(
        buildExpense(
          amount: 300,
          id: id,
          amortized: AmortizationDetails(groupId: '', index: 0, over: 3),
        ),
        Expense.fromJson({...stored, 'id': id}),
      );

      final teardown = h.functions.lastCallTo('deleteAmortizedSeries')!;
      expect(teardown.payload['groupId'], oldGroupId);
      expect(teardown.payload['updateId'], id,
          reason: 'installment 1 is rewritten in place, not deleted');
    });

    test('the month is left with exactly one document', () async {
      // Regression: the screen used to run an update *and* a manual
      // remove-and-re-add, so the plain document written by the update stayed
      // behind as a duplicate and the month counted the expense twice.
      final h = await buildExpenseHarness();
      final id = await h.notifier.addAmortizedExpense(buildExpense(amount: 300), 3);
      final stored = (await h.expenseAt(march, id!))!;

      await h.notifier.updateExpense(
        buildExpense(
          amount: 360,
          id: id,
          amortized: AmortizationDetails(groupId: '', index: 0, over: 3),
        ),
        Expense.fromJson({...stored, 'id': id}),
      );

      final docs = await h.expensesIn(march);
      expect(docs, hasLength(1));
      expect(docs.single['id'], id);
      expect(docs.single['amount'], 120);
      expect(docs.single['amortized'], isNotNull);
    });

    test('converting a series back to a plain expense charges the full amount',
        () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addAmortizedExpense(buildExpense(amount: 300), 3);
      final stored = (await h.expenseAt(march, id!))!;

      final ok = await h.notifier.updateExpense(
        buildExpense(amount: 100, id: id),
        Expense.fromJson({...stored, 'id': id}),
      );

      expect(ok, isTrue);
      expect(h.functions.callsTo('deleteAmortizedSeries'), hasLength(1));
      expect(h.functions.callsTo('createAmortizedExpenses'), hasLength(1),
          reason: 'only the original creation; no series is rebuilt');
      final doc = (await h.expensesIn(march)).single;
      expect(doc['amortized'], isNull);
      expect(doc['amount'], 100);
    });
  });

  group('deleting a series', () {
    test('the whole series is torn down, not just the visible month', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addAmortizedExpense(buildExpense(amount: 300), 3);
      final stored = (await h.expenseAt(march, id!))!;

      await h.notifier.removeExpense(Expense.fromJson({...stored, 'id': id}));

      expect(await h.expensesIn(march), isEmpty);
      final teardown = h.functions.lastCallTo('deleteAmortizedSeries')!;
      expect(teardown.payload['groupId'], (stored['amortized'] as Map)['groupId']);
      expect(teardown.payload['ledgerId'], testLedgerId);
    });

    test('the receipt is released once for the series', () async {
      final h = await buildExpenseHarness();
      final id = await h.notifier.addAmortizedExpense(
        buildExpense(amount: 300),
        3,
        null,
        receiptBytes,
      );
      final stored = (await h.expenseAt(march, id!))!;

      await h.notifier.removeExpense(Expense.fromJson({...stored, 'id': id}));

      verify(() => h.receipts.release(
            ledgerId: testLedgerId,
            receiptId: 'new-receipt',
          )).called(1);
    });
  });

  group('the month bucket a series starts in', () {
    test('a series dated next month starts there, not in the current one',
        () async {
      final h = await buildExpenseHarness();

      await h.notifier
          .addAmortizedExpense(buildExpense(amount: 300, date: april), 3);

      expect(await h.expensesIn(march), isEmpty);
      expect((await h.expensesIn(april)).single['amount'], 100);
      expect(await h.summaryTotal('groceries', april), 100);
    });
  });
}
