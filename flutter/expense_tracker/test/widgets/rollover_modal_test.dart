import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/rollover_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/rollover_calculator.dart';
import 'package:expense_tracker/widgets/rollover_modal.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/rollover_fixtures.dart';

class _StubFunctions extends Mock implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _StubCallable();
}

class _StubCallable extends Mock implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([Object? parameters]) async =>
      _StubResult<T>();
}

class _StubResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  late FakeFirebaseFirestore db;

  // The modal watches rolloverStatusProvider, which keys off the real clock,
  // so the widget's injected clock has to agree with it. Submission-level date
  // behaviour is pinned to a fixed date in rollover_submission_test.dart.
  final now = DateTime.now();
  final monthKey = currentMonthKey(now);

  ExpenseUser buildUser() => ExpenseUser.fromJson({
        'id': testUserId,
        'firstName': 'Test',
        'lastName': 'User',
        'email': 'test@example.com',
        'ledgerId': testLedgerId,
        'role': 'primary',
        'initialized': DateTime(2025, 1, 1).toIso8601String(),
        'userSettings': <String, String>{},
        'noteSuggestions': <String, dynamic>{},
        'linkedAccounts': <dynamic>[],
        'archivedLinkedAccounts': <dynamic>[],
      });

  /// Pumps the modal the way the app presents it — pushed as a bottom sheet
  /// route, so `Navigator.pop` genuinely closes something and the snackbars
  /// land on a real messenger.
  Future<WidgetRef> pumpModal(
    WidgetTester tester, {
    required double pool,
    required List<RolloverCandidate> candidates,
  }) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        backendProvider.overrideWithValue(db),
        functionsProvider.overrideWithValue(_StubFunctions()),
        userProvider.overrideWith((ref) => Stream.value(buildUser())),
      ],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          capturedRef = ref;
          return Scaffold(
            body: Builder(
              builder: (inner) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: inner,
                  isScrollControlled: true,
                  builder: (_) => RolloverModal(
                    pool: pool,
                    candidates: candidates,
                    now: now,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          );
        }),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return capturedRef;
  }

  /// Drives a category's slider directly. Pixel drags on a Slider depend on
  /// track geometry and the thumb jumping to the touch point; calling the
  /// callback tests the clamping behaviour that actually matters.
  Future<void> setSlider(
    WidgetTester tester,
    String categoryId,
    double value,
  ) async {
    final slider = tester.widget<Slider>(
      find.byKey(Key('rollover-slider-$categoryId')),
    );
    slider.onChanged!(value);
    await tester.pump();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  RolloverCandidate candidate(
    String id, {
    required double budget,
    double committed = 0,
    String? label,
  }) {
    return RolloverCandidate(
      category: category(id, budget: budget, label: label ?? id),
      committed: committed,
    );
  }

  // The net amount carried out of last month.
  const pool = 165.0;

  final candidates = [
    candidate('groceries', budget: 500, committed: 50, label: 'Groceries'),
    candidate('dining', budget: 200, label: 'Dining'),
  ];

  setUp(() async {
    db = FakeFirebaseFirestore();
    await seedLedger(
      firestore: db,
      categories: [
        category('groceries', budget: 500, label: 'Groceries'),
        category('dining', budget: 200, label: 'Dining'),
      ],
    );
  });

  Future<Map<String, dynamic>?> storedRecord() async {
    final doc = await db.collection('ledger').doc(testLedgerId).get();
    final status = doc.data()?['rolloverStatus'];
    if (status is! Map) return null;
    return normalizeRolloverRecord(status[monthKey]);
  }

  Future<int> expenseCount() async {
    final snapshot =
        await db.collection('ledger').doc(testLedgerId).collection(monthKey).get();
    return snapshot.docs.length;
  }

  /// Budget adjustments recorded for the month under test.
  Future<Map<String, double>> recordedAllocations() async {
    final raw = (await storedRecord())?['allocations'];
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): (entry.value as num).toDouble(),
    };
  }


  testWidgets('renders one row per active category', (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Dining'), findsOneWidget);
    expect(find.byKey(const Key('rollover-slider-groceries')), findsOneWidget);
    expect(find.byKey(const Key('rollover-slider-dining')), findsOneWidget);
  });

  testWidgets('shows committed spend, budget, and left to spend',
      (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    // $500 budget, $50 already committed, nothing allocated yet. The budget
    // itself is the row's headline figure, so it is not repeated below.
    expect(textOf(tester, 'rollover-budget-groceries'), '\$500.00');
    final groceries = textOf(tester, 'rollover-left-groceries');
    expect(groceries, contains('Spent \$50.00'));
    expect(groceries, contains('Remaining \$450.00'));
  });

  testWidgets('renders no row for a category that is not a candidate',
      (tester) async {
    await pumpModal(tester, pool: pool, candidates: [candidates.first]);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Dining'), findsNothing);
  });

  testWidgets('starts with nothing allocated and the full pool free',
      (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    expect(textOf(tester, 'rollover-budget-groceries'), '\$500.00',
        reason: 'the budget starts at its configured value');
    expect(textOf(tester, 'rollover-allocation-groceries'), 'No rollover added');
    expect(textOf(tester, 'rollover-unallocated'), 'Unallocated \$165.00',
        reason: 'the user chooses which budgets absorb the net overspend');
    expect(find.byKey(const Key('rollover-original-groceries')), findsNothing,
        reason: 'nothing to strike through until something is allocated');
  });

  testWidgets('the pool may be allocated to a category that did not overspend',
      (tester) async {
    // Dining did not overspend — it is absent from overspendByCategory — but
    // is still a legitimate place to give the money back.
    await pumpModal(tester, pool: pool, candidates: candidates);
    // Dining has a $200 budget, so its slider reaches $165.
    await setSlider(tester, 'dining', 165);

    expect(textOf(tester, 'rollover-allocation-dining'),
        'Adding \$165.00 rollover');
    expect(textOf(tester, 'rollover-budget-dining'), '\$35.00');
  });

  testWidgets('raising a slider updates left-to-spend and the remainder',
      (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    expect(
      textOf(tester, 'rollover-left-groceries'),
      contains('Remaining \$450.00'),
      reason: '\$500 budget less \$50 committed, nothing rolled over yet',
    );

    await setSlider(tester, 'groceries', 120);

    expect(textOf(tester, 'rollover-allocation-groceries'),
        'Adding \$120.00 rollover');
    expect(textOf(tester, 'rollover-budget-groceries'), '\$380.00',
        reason: 'the budget counts down as the slider moves');
    expect(textOf(tester, 'rollover-original-groceries'), '\$500.00',
        reason: 'the original is struck through beside it');
    expect(
      textOf(tester, 'rollover-left-groceries'),
      contains('Remaining \$330.00'),
    );
    expect(textOf(tester, 'rollover-unallocated'), 'Unallocated \$45.00');
  });

  testWidgets('an allocation past the budget is shown as Over', (tester) async {
    // A small category, so the pool can genuinely overshoot its budget.
    await pumpModal(tester, pool: pool, candidates: [
      candidate('coffee', budget: 100, committed: 20, label: 'Coffee'),
    ]);

    await setSlider(tester, 'coffee', 100);


    // The slider tops out at the $100 budget, taking it to exactly zero.
    expect(textOf(tester, 'rollover-budget-coffee'), '\$0.00');
    // $100 budget - $20 committed - $100 allocated.
    expect(textOf(tester, 'rollover-left-coffee'), contains('Over \$20.00'));
  });

  testWidgets('a slider cannot push the total past the pool', (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    await setSlider(tester, 'groceries', 120);
    // $45 is all that remains; asking for more is blocked at the pool limit.
    await setSlider(tester, 'dining', 200);

    expect(textOf(tester, 'rollover-allocation-dining'),
        'Adding \$45.00 rollover');
    expect(textOf(tester, 'rollover-allocation-groceries'),
        'Adding \$120.00 rollover',
        reason: 'other rows are not silently shrunk');
    expect(textOf(tester, 'rollover-unallocated'), 'Unallocated \$0.00');
  });

  testWidgets("'I'll do it later' writes nothing and defers the month",
      (tester) async {
    final ref = await pumpModal(tester, pool: pool, candidates: candidates);

    await tester.tap(find.text("I'll do it later"));
    await tester.pumpAndSettle();

    expect(find.text('Submit'), findsNothing, reason: 'the modal closed');
    expect(ref.read(rolloverDeferredProvider), monthKey);
    expect(await expenseCount(), 0);
    expect(await storedRecord(), isNull);
  });

  testWidgets('submitting records the adjustments and completes the month',
      (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    await setSlider(tester, 'groceries', 120);
    await setSlider(tester, 'dining', 45);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(await recordedAllocations(), {'groceries': 120, 'dining': 45});
    expect(await expenseCount(), 0, reason: 'a rollover is not an expense');
    final record = await storedRecord();
    expect(record!['status'], kRolloverComplete);
    expect(record['total'], 165);
    expect(find.text('Rolled over \$165.00 into this month'), findsOneWidget);
  });

  testWidgets('submitting records only the non-zero rows', (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    await setSlider(tester, 'groceries', 120);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(await recordedAllocations(), {'groceries': 120});
    expect((await storedRecord())!['total'], 120);
  });

  testWidgets('each slider runs to its own budget, not the pool',
      (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    expect(
      tester.widget<Slider>(find.byKey(const Key('rollover-slider-groceries'))).max,
      500,
    );
    expect(
      tester.widget<Slider>(find.byKey(const Key('rollover-slider-dining'))).max,
      200,
      reason: 'a fixed scale per row, independent of other allocations',
    );

    // Allocating elsewhere must not rescale a row's track.
    await setSlider(tester, 'groceries', 120);
    expect(
      tester.widget<Slider>(find.byKey(const Key('rollover-slider-dining'))).max,
      200,
    );
  });

  testWidgets('submitting with everything at zero completes without adjustments',
      (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(await recordedAllocations(), isEmpty);
    expect(await expenseCount(), 0);
    expect((await storedRecord())!['status'], kRolloverComplete);
    expect(find.text('Nothing carried over this month'), findsOneWidget);
  });

  testWidgets('closes when the partner completes the rollover', (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    expect(find.text('Submit'), findsOneWidget);

    // The partner's completion lands on the ledger doc the modal is watching.
    await db.collection('ledger').doc(testLedgerId).update({
      'rolloverStatus.$monthKey': rolloverRecord(
        status: kRolloverComplete,
        claimedBy: testPartnerId,
      ),
    });
    await tester.pumpAndSettle();

    expect(find.text('Submit'), findsNothing, reason: 'the modal closed');
    expect(
      find.text('Your partner just completed the rollover'),
      findsOneWidget,
    );
    expect(await expenseCount(), 0);
  });

  testWidgets('closes when the partner claims the month', (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    await db.collection('ledger').doc(testLedgerId).update({
      'rolloverStatus.$monthKey': rolloverRecord(
        status: kRolloverPending,
        claimedBy: testPartnerId,
        claimedAt: now,
      ),
    });
    await tester.pumpAndSettle();

    expect(find.text('Submit'), findsNothing);
    expect(find.text('Your partner is handling the rollover'), findsOneWidget);
  });

  testWidgets("stays open for this user's own claim landing", (tester) async {
    await pumpModal(tester, pool: pool, candidates: candidates);

    await db.collection('ledger').doc(testLedgerId).update({
      'rolloverStatus.$monthKey': rolloverRecord(
        status: kRolloverPending,
        claimedBy: testUserId,
        claimedAt: now,
      ),
    });
    await tester.pumpAndSettle();

    expect(find.text('Submit'), findsOneWidget,
        reason: 'our own claim must not close our own modal');
  });
}
