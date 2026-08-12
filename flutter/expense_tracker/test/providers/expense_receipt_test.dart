import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/receipt.service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReceiptService extends Mock implements ReceiptService {}

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}

const testUserId = 'user-1';
const testLedgerId = 'ledger-1';

final bytes = Uint8List.fromList([1, 2, 3, 4]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late MockReceiptService receipts;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    receipts = MockReceiptService();

    when(() => receipts.upload(
          ledgerId: any(named: 'ledgerId'),
          bytes: any(named: 'bytes'),
        )).thenAnswer((_) async => const UploadedReceipt(
          receiptId: 'new-receipt',
          imageUrl: 'https://example.com/new-receipt',
        ));
    when(() => receipts.release(
          ledgerId: any(named: 'ledgerId'),
          receiptId: any(named: 'receiptId'),
        )).thenAnswer((_) async {});
    when(() => receipts.commitDeletion(
          ledgerId: any(named: 'ledgerId'),
          receiptId: any(named: 'receiptId'),
        )).thenAnswer((_) async {});
    when(() => receipts.deleteUnreferenced(
          ledgerId: any(named: 'ledgerId'),
          receiptId: any(named: 'receiptId'),
        )).thenAnswer((_) async {});
    when(() => receipts.clearMarker(any())).thenAnswer((_) async {});
  });

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
      });

  Future<ProviderContainer> buildContainer() async {
    final container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(db),
        receiptServiceProvider.overrideWithValue(receipts),
        userProvider.overrideWith((ref) => Stream.value(buildUser())),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(userProvider, (_, __) {}, fireImmediately: true);
    addTearDown(sub.close);
    await container.read(userProvider.future);
    return container;
  }

  Expense buildExpense({
    DateTime? date,
    String? receiptId,
    String? imageUrl,
    String? id,
    double amount = 25,
  }) =>
      Expense(
        amount: amount,
        date: date ?? DateTime(2026, 3, 10),
        categoryId: 'groceries',
        id: id,
        receiptId: receiptId,
        imageUrl: imageUrl,
      );

  String monthOf(DateTime d) =>
      '${d.year}_${['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][d.month - 1]}';

  Future<List<Map<String, dynamic>>> docsIn(DateTime date) async {
    final snap = await db
        .collection('ledger')
        .doc(testLedgerId)
        .collection(monthOf(date))
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  group('create', () {
    test('without a receipt writes no receipt fields and uploads nothing',
        () async {
      final container = await buildContainer();

      final id = await container
          .read(expenseModifierProvider.notifier)
          .addExpense(buildExpense());

      expect(id, isNotNull);
      final docs = await docsIn(DateTime(2026, 3, 10));
      expect(docs.single['receiptId'], isNull);
      expect(docs.single['imageUrl'], isNull);
      verifyNever(() => receipts.upload(
          ledgerId: any(named: 'ledgerId'), bytes: any(named: 'bytes')));
    });

    test('with a receipt uploads first, then records both fields', () async {
      final container = await buildContainer();

      final id = await container
          .read(expenseModifierProvider.notifier)
          .addExpense(buildExpense(), receiptBytes: bytes);

      expect(id, isNotNull);
      final docs = await docsIn(DateTime(2026, 3, 10));
      expect(docs.single['receiptId'], 'new-receipt');
      expect(docs.single['imageUrl'], 'https://example.com/new-receipt');
    });

    test('an upload failure writes no expense at all', () async {
      when(() => receipts.upload(
                ledgerId: any(named: 'ledgerId'),
                bytes: any(named: 'bytes'),
              ))
          .thenThrow(ReceiptException(ReceiptFailure.permissionDenied));
      final container = await buildContainer();

      await expectLater(
        container
            .read(expenseModifierProvider.notifier)
            .addExpense(buildExpense(), receiptBytes: bytes),
        throwsA(isA<ReceiptException>()),
      );

      expect(await docsIn(DateTime(2026, 3, 10)), isEmpty);
    });

    test('a failed document write reclaims the object it just uploaded',
        () async {
      // The rollback contract from D3: the document is the commit point, so an
      // upload that never gets referenced must not be left behind.
      final failing = MockFirestore();
      final ledgerCollection = MockCollection();
      final ledgerDoc = MockDoc();
      final monthCollection = MockCollection();

      when(() => failing.collection('ledger')).thenReturn(ledgerCollection);
      when(() => ledgerCollection.doc(any())).thenReturn(ledgerDoc);
      when(() => ledgerDoc.collection(any())).thenReturn(monthCollection);
      when(() => monthCollection.add(any()))
          .thenThrow(Exception('firestore write rejected'));

      final container = ProviderContainer(overrides: [
        backendProvider.overrideWithValue(failing),
        receiptServiceProvider.overrideWithValue(receipts),
        userProvider.overrideWith((ref) => Stream.value(buildUser())),
      ]);
      addTearDown(container.dispose);
      final sub =
          container.listen(userProvider, (_, __) {}, fireImmediately: true);
      addTearDown(sub.close);
      await container.read(userProvider.future);

      final id = await container
          .read(expenseModifierProvider.notifier)
          .addExpense(buildExpense(), receiptBytes: bytes);

      expect(id, isNull, reason: 'the save must be reported as failed');
      verify(() => receipts.deleteUnreferenced(
            ledgerId: testLedgerId,
            receiptId: 'new-receipt',
          )).called(1);
    });

    test('re-adding an expense that already has a receipt does not re-upload '
        'and clears its deletion marker', () async {
      // This is the undo-restore path: the object already exists, and the
      // pending deletion has to be cancelled rather than a new copy uploaded.
      final container = await buildContainer();

      await container.read(expenseModifierProvider.notifier).addExpense(
            buildExpense(receiptId: 'old', imageUrl: 'https://example.com/old'),
          );

      verifyNever(() => receipts.upload(
          ledgerId: any(named: 'ledgerId'), bytes: any(named: 'bytes')));
      verify(() => receipts.clearMarker('old')).called(1);

      final docs = await docsIn(DateTime(2026, 3, 10));
      expect(docs.single['receiptId'], 'old');
    });
  });

  group('replace', () {
    test('a replacement on an expense that already has a receipt is uploaded '
        'and persisted', () async {
      // The specific prototype regression: the upload was gated on
      // `imageUrl == null`, so replacements were silently discarded.
      final container = await buildContainer();
      final previous = buildExpense(
        id: 'e1',
        receiptId: 'old',
        imageUrl: 'https://example.com/old',
      );
      await db
          .collection('ledger')
          .doc(testLedgerId)
          .collection(monthOf(previous.date))
          .doc('e1')
          .set(previous.toJson()..remove('id'));

      final ok = await container
          .read(expenseModifierProvider.notifier)
          .updateExpense(
            buildExpense(id: 'e1', amount: 30),
            previous,
            receipt: ReceiptReplaced(bytes),
          );

      expect(ok, isTrue);
      verify(() => receipts.upload(
          ledgerId: testLedgerId, bytes: any(named: 'bytes'))).called(1);

      final docs = await docsIn(previous.date);
      expect(docs.single['receiptId'], 'new-receipt');
      // Only the superseded object is released, and only after the write.
      verify(() => receipts.release(
          ledgerId: testLedgerId, receiptId: 'old')).called(1);
    });

    test('an unchanged intent carries the existing receipt forward without '
        'uploading or releasing', () async {
      final container = await buildContainer();
      final previous = buildExpense(
        id: 'e1',
        receiptId: 'old',
        imageUrl: 'https://example.com/old',
      );
      await db
          .collection('ledger')
          .doc(testLedgerId)
          .collection(monthOf(previous.date))
          .doc('e1')
          .set(previous.toJson()..remove('id'));

      await container.read(expenseModifierProvider.notifier).updateExpense(
            buildExpense(id: 'e1', amount: 31),
            previous,
          );

      final docs = await docsIn(previous.date);
      expect(docs.single['receiptId'], 'old');
      verifyNever(() => receipts.upload(
          ledgerId: any(named: 'ledgerId'), bytes: any(named: 'bytes')));
      verifyNever(() => receipts.release(
          ledgerId: any(named: 'ledgerId'), receiptId: any(named: 'receiptId')));
    });
  });

  group('remove', () {
    test('clears both fields and releases the object', () async {
      final container = await buildContainer();
      final previous = buildExpense(
        id: 'e1',
        receiptId: 'old',
        imageUrl: 'https://example.com/old',
      );
      await db
          .collection('ledger')
          .doc(testLedgerId)
          .collection(monthOf(previous.date))
          .doc('e1')
          .set(previous.toJson()..remove('id'));

      await container.read(expenseModifierProvider.notifier).updateExpense(
            buildExpense(id: 'e1'),
            previous,
            receipt: const ReceiptRemoved(),
          );

      final docs = await docsIn(previous.date);
      expect(docs.single['receiptId'], isNull);
      expect(docs.single['imageUrl'], isNull);
      verify(() => receipts.release(
          ledgerId: testLedgerId, receiptId: 'old')).called(1);
    });
  });

  group('cross-month move', () {
    test('preserves the receipt and issues no Storage operations', () async {
      // The prototype deleted the object here while keeping the URL, leaving a
      // permanently broken image.
      final container = await buildContainer();
      final previous = buildExpense(
        id: 'e1',
        receiptId: 'keep-me',
        imageUrl: 'https://example.com/keep-me',
      );
      await db
          .collection('ledger')
          .doc(testLedgerId)
          .collection(monthOf(previous.date))
          .doc('e1')
          .set(previous.toJson()..remove('id'));

      final moved = buildExpense(id: 'e1', date: DateTime(2026, 5, 10));
      final ok = await container
          .read(expenseModifierProvider.notifier)
          .updateExpense(moved, previous);

      expect(ok, isTrue);
      // Gone from March, present in May, receipt intact.
      expect(await docsIn(DateTime(2026, 3, 10)), isEmpty);
      final movedDocs = await docsIn(DateTime(2026, 5, 10));
      expect(movedDocs.single['receiptId'], 'keep-me');
      expect(movedDocs.single['imageUrl'], 'https://example.com/keep-me');

      // Storage must not be touched: no upload, and crucially no release of an
      // object the surviving document still points at.
      verifyNever(() => receipts.upload(
          ledgerId: any(named: 'ledgerId'), bytes: any(named: 'bytes')));
      verifyNever(() => receipts.release(
          ledgerId: any(named: 'ledgerId'), receiptId: any(named: 'receiptId')));
    });

    test('combined with a replacement uploads once and releases only the old '
        'object', () async {
      final container = await buildContainer();
      final previous = buildExpense(
        id: 'e1',
        receiptId: 'old',
        imageUrl: 'https://example.com/old',
      );
      await db
          .collection('ledger')
          .doc(testLedgerId)
          .collection(monthOf(previous.date))
          .doc('e1')
          .set(previous.toJson()..remove('id'));

      await container.read(expenseModifierProvider.notifier).updateExpense(
            buildExpense(id: 'e1', date: DateTime(2026, 5, 10)),
            previous,
            receipt: ReceiptReplaced(bytes),
          );

      verify(() => receipts.upload(
          ledgerId: testLedgerId, bytes: any(named: 'bytes'))).called(1);
      verify(() => receipts.release(
          ledgerId: testLedgerId, receiptId: 'old')).called(1);
      verifyNever(() => receipts.release(
          ledgerId: testLedgerId, receiptId: 'new-receipt'));

      final movedDocs = await docsIn(DateTime(2026, 5, 10));
      expect(movedDocs.single['receiptId'], 'new-receipt');
    });
  });

  group('delete', () {
    test('releases rather than deletes, so undo can still restore it',
        () async {
      final container = await buildContainer();
      final expense = buildExpense(
        id: 'e1',
        receiptId: 'old',
        imageUrl: 'https://example.com/old',
      );
      await db
          .collection('ledger')
          .doc(testLedgerId)
          .collection(monthOf(expense.date))
          .doc('e1')
          .set(expense.toJson()..remove('id'));

      await container
          .read(expenseModifierProvider.notifier)
          .removeExpense(expense);

      expect(await docsIn(expense.date), isEmpty);
      verify(() => receipts.release(
          ledgerId: testLedgerId, receiptId: 'old')).called(1);
      // Committing is the UI's job once the undo window closes.
      verifyNever(() => receipts.commitDeletion(
          ledgerId: any(named: 'ledgerId'), receiptId: any(named: 'receiptId')));
    });

    test('a failed marker write does not prevent the expense deletion',
        () async {
      when(() => receipts.release(
            ledgerId: any(named: 'ledgerId'),
            receiptId: any(named: 'receiptId'),
          )).thenThrow(Exception('firestore down'));
      final container = await buildContainer();
      final expense = buildExpense(
        id: 'e1',
        receiptId: 'old',
        imageUrl: 'https://example.com/old',
      );
      await db
          .collection('ledger')
          .doc(testLedgerId)
          .collection(monthOf(expense.date))
          .doc('e1')
          .set(expense.toJson()..remove('id'));

      await container
          .read(expenseModifierProvider.notifier)
          .removeExpense(expense);

      expect(await docsIn(expense.date), isEmpty);
    });

    test('an expense without a receipt touches Storage not at all', () async {
      final container = await buildContainer();
      final expense = buildExpense(id: 'e1');
      await db
          .collection('ledger')
          .doc(testLedgerId)
          .collection(monthOf(expense.date))
          .doc('e1')
          .set(expense.toJson()..remove('id'));

      await container
          .read(expenseModifierProvider.notifier)
          .removeExpense(expense);

      verifyNever(() => receipts.release(
          ledgerId: any(named: 'ledgerId'), receiptId: any(named: 'receiptId')));
    });
  });

  group('marker safety', () {
    test('no marker is ever written for an object a live expense still '
        'references', () async {
      // The invariant the sweep depends on. Exercised across the edit paths
      // that keep a receipt: unchanged same-month, and a cross-month move.
      final container = await buildContainer();
      final notifier = container.read(expenseModifierProvider.notifier);

      final previous = buildExpense(
        id: 'e1',
        receiptId: 'keep-me',
        imageUrl: 'https://example.com/keep-me',
      );
      await db
          .collection('ledger')
          .doc(testLedgerId)
          .collection(monthOf(previous.date))
          .doc('e1')
          .set(previous.toJson()..remove('id'));

      await notifier.updateExpense(buildExpense(id: 'e1', amount: 40), previous);
      await notifier.updateExpense(
        buildExpense(id: 'e1', date: DateTime(2026, 7, 2)),
        previous,
      );

      verifyNever(() => receipts.release(
          ledgerId: any(named: 'ledgerId'), receiptId: 'keep-me'));
    });
  });
}
