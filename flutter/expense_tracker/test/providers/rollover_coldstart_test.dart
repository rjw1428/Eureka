import 'dart:async';

import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/rollover_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/rollover_calculator.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/rollover_fixtures.dart';

/// Regression coverage for the launch trigger starting cold.
///
/// The providers behind the prompt — the previous month's summaries and the
/// ledger's rollover record — are subscribed by nothing else in the app. A
/// one-shot read therefore creates them and sees `AsyncLoading`, so the modal
/// never appeared however long the trigger waited beforehand. The prompt must
/// be *listened* to, so it fires when the data lands.
void main() {
  late FakeFirebaseFirestore db;

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [
      backendProvider.overrideWithValue(db),
      userProvider.overrideWith((ref) => Stream.value(ExpenseUser.fromJson({
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
          }))),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    final now = DateTime.now();
    await seedLedger(
      firestore: db,
      categories: [
        category('groceries', budget: 6000, label: 'Groceries'),
        category('travel', budget: 3000, label: 'Travel'),
      ],
      summaries: [
        // $9,785.38 spent against a $9,000 budget: $785.38 net over.
        summary('groceries',
            total: 7000, month: DateTime(now.year, now.month - 1)),
        summary('travel',
            total: 2785.38, month: DateTime(now.year, now.month - 1)),
      ],
    );
  });

  test('the prompt arrives once the cold streams resolve', () async {
    final container = buildContainer();
    final prompts = <RolloverPrompt?>[];

    // Exactly what the launch trigger does: subscribe, having read nothing.
    final sub = container.listen<RolloverPrompt?>(
      rolloverPromptProvider,
      (previous, next) => prompts.add(next),
      fireImmediately: true,
    );
    addTearDown(sub.close);

    expect(prompts.single, isNull, reason: 'nothing has loaded yet');

    await Future<void>.delayed(const Duration(milliseconds: 300));

    final prompt = container.read(rolloverPromptProvider);
    expect(prompt, isNotNull, reason: 'the modal must be offered');
    expect(prompt!.pool, 785.38);
    expect(prompt.candidates, hasLength(2));
    expect(prompts.whereType<RolloverPrompt>(), isNotEmpty,
        reason: 'the listener has to be notified, not just the later read');
  });

  test('no prompt when the previous month stayed within budget', () async {
    db = FakeFirebaseFirestore();
    final now = DateTime.now();
    await seedLedger(
      firestore: db,
      categories: [category('groceries', budget: 9000)],
      summaries: [
        summary('groceries',
            total: 100, month: DateTime(now.year, now.month - 1)),
      ],
    );
    final container = buildContainer();

    final sub = container.listen<RolloverPrompt?>(
        rolloverPromptProvider, (_, __) {},
        fireImmediately: true);
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(container.read(rolloverPromptProvider), isNull);
  });

  test('no prompt once the month is already complete', () async {
    await db.collection('ledger').doc(testLedgerId).update({
      'rolloverStatus.${currentMonthKey()}':
          rolloverRecord(status: kRolloverComplete, claimedBy: testPartnerId),
    });
    final container = buildContainer();

    final sub = container.listen<RolloverPrompt?>(
        rolloverPromptProvider, (_, __) {},
        fireImmediately: true);
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(container.read(rolloverPromptProvider), isNull);
  });
}
