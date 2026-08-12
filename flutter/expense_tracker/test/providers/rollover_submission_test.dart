import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/rollover_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/rollover_calculator.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/rollover_fixtures.dart';

class _MockCallableResult extends Mock implements HttpsCallableResult {}

/// Records the calls made to `sendRolloverNotification`.
class _RecordingFunctions extends Mock implements FirebaseFunctions {
  final List<Map<String, dynamic>> calls = [];
  final List<String> names = [];
  bool shouldThrow = false;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    names.add(name);
    return _RecordingCallable(this);
  }
}

class _RecordingCallable extends Mock implements HttpsCallable {
  _RecordingCallable(this.parent);

  final _RecordingFunctions parent;

  @override
  Future<HttpsCallableResult<T>> call<T>([Object? parameters]) async {
    parent.calls.add(Map<String, dynamic>.from(parameters as Map));
    if (parent.shouldThrow) {
      throw FirebaseFunctionsException(message: 'boom', code: 'internal');
    }
    return _MockCallableResult() as HttpsCallableResult<T>;
  }
}

/// Fails the completion write after the claim has been won, to exercise the
/// claim-release path deterministically.
class _FailingCompletionNotifier extends RolloverNotifier {
  @override
  Future<void> recordCompletion({
    required String monthKey,
    required double total,
    required Map<String, double> allocations,
  }) async {
    throw FirebaseException(plugin: 'test', message: 'update failed');
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late _RecordingFunctions functions;

  final now = DateTime(2026, 9, 3, 10);
  final monthKey = currentMonthKey(now);

  ExpenseUser buildUser({List<String> linked = const []}) {
    return ExpenseUser.fromJson({
      'id': testUserId,
      'firstName': 'Test',
      'lastName': 'User',
      'email': 'test@example.com',
      'ledgerId': testLedgerId,
      'role': 'primary',
      'initialized': DateTime(2025, 1, 1).toIso8601String(),
      'userSettings': <String, String>{},
      'noteSuggestions': <String, dynamic>{},
      'linkedAccounts': [
        for (final id in linked)
          {
            'id': id,
            'firstName': 'Partner',
            'lastName': 'User',
            'email': '$id@example.com',
            'color': '255,0,0,0',
          },
      ],
      'archivedLinkedAccounts': <dynamic>[],
    });
  }

  /// Builds a container whose user stream has already emitted — the notifier
  /// reads the signed-in user synchronously, exactly as it does in the app
  /// once the home screen has rendered.
  Future<ProviderContainer> buildContainer({
    ExpenseUser? user,
    bool failCompletion = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(db),
        functionsProvider.overrideWithValue(functions),
        userProvider.overrideWith((ref) => Stream.value(user ?? buildUser())),
        if (failCompletion)
          rolloverNotifierProvider.overrideWith(_FailingCompletionNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(userProvider, (_, __) {}, fireImmediately: true);
    addTearDown(sub.close);
    await container.read(userProvider.future);

    return container;
  }

  /// The rollover record currently stored for the month under test.
  Future<Map<String, dynamic>?> storedRecord() async {
    final doc = await db.collection('ledger').doc(testLedgerId).get();
    final status = doc.data()?['rolloverStatus'];
    if (status is! Map) return null;
    return normalizeRolloverRecord(status[monthKey]);
  }

  /// Every expense document written into the month under test. A rollover must
  /// never create one — expenses report real spending only.
  Future<List<Map<String, dynamic>>> writtenExpenses() async {
    final snapshot =
        await db.collection('ledger').doc(testLedgerId).collection(monthKey).get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  /// The budget adjustments recorded for the month under test.
  Future<Map<String, double>> recordedAllocations() async {
    final raw = (await storedRecord())?['allocations'];
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): (entry.value as num).toDouble(),
    };
  }

  /// Spend summaries for the month under test, which a rollover must not touch.
  Future<int> summaryCount() async {
    final snapshot = await db
        .collection('ledger')
        .doc(testLedgerId)
        .collection('summaries')
        .get();
    return snapshot.docs.length;
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    functions = _RecordingFunctions();
    await seedLedger(
      firestore: db,
      categories: [
        category('groceries', budget: 500, label: 'Groceries'),
        category('dining', budget: 200, label: 'Dining'),
      ],
    );
  });

  group('claimRollover', () {
    test('succeeds when no record exists and records a pending claim',
        () async {
      final container = await buildContainer();
      final notifier = container.read(rolloverNotifierProvider.notifier);

      expect(await notifier.claimRollover(now: now), isTrue);

      final record = await storedRecord();
      expect(record!['status'], kRolloverPending);
      expect(record['claimedBy'], testUserId);
      expect(record['sourceMonth'], '2026_AUG');
    });

    test('refuses when the month is already complete', () async {
      await db.collection('ledger').doc(testLedgerId).set({
        'rolloverStatus': {
          monthKey: rolloverRecord(
            status: kRolloverComplete,
            claimedBy: testPartnerId,
          ),
        },
      }, SetOptions(merge: true));
      final container = await buildContainer();

      expect(
        await container.read(rolloverNotifierProvider.notifier).claimRollover(now: now),
        isFalse,
      );

      final record = await storedRecord();
      expect(record!['claimedBy'], testPartnerId,
          reason: 'the existing claim must not be overwritten');
    });

    test('refuses while another claim is fresh', () async {
      await db.collection('ledger').doc(testLedgerId).set({
        'rolloverStatus': {
          monthKey: rolloverRecord(
            status: kRolloverPending,
            claimedBy: testPartnerId,
            claimedAt: now.subtract(const Duration(seconds: 30)),
          ),
        },
      }, SetOptions(merge: true));
      final container = await buildContainer();

      expect(
        await container.read(rolloverNotifierProvider.notifier).claimRollover(now: now),
        isFalse,
      );
    });

    test('takes over a stale claim', () async {
      await db.collection('ledger').doc(testLedgerId).set({
        'rolloverStatus': {
          monthKey: rolloverRecord(
            status: kRolloverPending,
            claimedBy: testPartnerId,
            claimedAt: now.subtract(const Duration(minutes: 5)),
          ),
        },
      }, SetOptions(merge: true));
      final container = await buildContainer();

      expect(
        await container.read(rolloverNotifierProvider.notifier).claimRollover(now: now),
        isTrue,
      );
      expect((await storedRecord())!['claimedBy'], testUserId);
    });

    test('leaves other months untouched', () async {
      await db.collection('ledger').doc(testLedgerId).set({
        'rolloverStatus': {
          '2026_AUG': rolloverRecord(status: kRolloverComplete, total: 50),
        },
      }, SetOptions(merge: true));
      final container = await buildContainer();

      await container.read(rolloverNotifierProvider.notifier).claimRollover(now: now);

      final doc = await db.collection('ledger').doc(testLedgerId).get();
      final status = doc.data()!['rolloverStatus'] as Map;
      expect(status.containsKey('2026_AUG'), isTrue);
      expect(status.containsKey(monthKey), isTrue);
    });
  });

  group('submitRollover', () {
    test('records each allocation as a budget adjustment', () async {
      final container = await buildContainer();

      final result = await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 120, 'dining': 45}, now: now);

      expect(result, RolloverSubmitResult.completed);
      expect(await recordedAllocations(), {'groceries': 120, 'dining': 45});
    });

    test('writes no expense', () async {
      final container = await buildContainer();

      await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 120, 'dining': 45}, now: now);

      expect(await writtenExpenses(), isEmpty,
          reason: 'expenses must keep reporting only real spending');
    });

    test('leaves spend summaries untouched', () async {
      final container = await buildContainer();

      await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 120}, now: now);

      expect(await summaryCount(), 0,
          reason: 'a rollover is not a purchase, so nothing was spent');
    });

    test('skips categories allocated zero', () async {
      final container = await buildContainer();

      await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 120, 'dining': 0}, now: now);

      expect(await recordedAllocations(), {'groceries': 120});
    });

    test('transitions the record to complete, preserving the claimant',
        () async {
      final container = await buildContainer();

      await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 120, 'dining': 45}, now: now);

      final record = await storedRecord();
      expect(record!['status'], kRolloverComplete);
      expect(record['total'], 165);
      expect(record['claimedBy'], testUserId);
      expect(record['sourceMonth'], '2026_AUG');
    });

    test('a zero total completes without adjustments or notifying', () async {
      final container = await buildContainer(user: buildUser(linked: [testPartnerId]));

      final result = await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 0}, now: now);

      expect(result, RolloverSubmitResult.completed);
      expect(await recordedAllocations(), isEmpty);
      expect((await storedRecord())!['status'], kRolloverComplete);
      expect(functions.calls, isEmpty,
          reason: 'nothing was carried, so nobody needs telling');
    });

    test('loses the claim to a fresh claim from the paired user', () async {
      await db.collection('ledger').doc(testLedgerId).set({
        'rolloverStatus': {
          monthKey: rolloverRecord(
            status: kRolloverPending,
            claimedBy: testPartnerId,
            claimedAt: now.subtract(const Duration(seconds: 10)),
          ),
        },
      }, SetOptions(merge: true));
      final container = await buildContainer();

      final result = await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 120}, now: now);

      expect(result, RolloverSubmitResult.lostClaim);
      expect(await recordedAllocations(), isEmpty,
          reason: 'the loser must not write anything');
      expect((await storedRecord())!['claimedBy'], testPartnerId);
    });

    test('releases the claim when the completion write fails', () async {
      final container = await buildContainer(failCompletion: true);

      final result = await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 120}, now: now);

      expect(result, RolloverSubmitResult.failed);
      expect(await storedRecord(), isNull,
          reason: 'a released claim leaves the month re-promptable');
    });
  });

  group('notification', () {
    test('calls sendRolloverNotification once with the ledger, month and total',
        () async {
      final container = await buildContainer(user: buildUser(linked: [testPartnerId]));

      await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 120, 'dining': 45}, now: now);

      expect(functions.names, ['sendRolloverNotification']);
      expect(functions.calls, hasLength(1));
      expect(functions.calls.single, {
        'ledgerId': testLedgerId,
        'monthKey': monthKey,
        'total': 165.0,
      });
    });

    test('a failing notification still reports success', () async {
      functions.shouldThrow = true;
      final container = await buildContainer(user: buildUser(linked: [testPartnerId]));

      final result = await container
          .read(rolloverNotifierProvider.notifier)
          .submitRollover({'groceries': 120}, now: now);

      expect(result, RolloverSubmitResult.completed);
      expect(await recordedAllocations(), {'groceries': 120},
          reason: 'the adjustment is already recorded and must stay');
      expect((await storedRecord())!['status'], kRolloverComplete);
    });
  });
}
