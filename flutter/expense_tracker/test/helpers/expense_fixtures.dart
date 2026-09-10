// Mocking Firestore's sealed reference types is the established pattern in
// this suite; the analyzer's sealed-class warning is expected here.
// ignore_for_file: subtype_of_sealed_class

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

/// Shared scaffolding for tests that drive [ExpenseNotifier]. Keeping the
/// container wiring, the Cloud Functions double and the Firestore readers in
/// one place means a new suite states the situation it cares about rather than
/// rebuilding the harness.
const String testUserId = 'user-1';
const String testLedgerId = 'ledger-1';

final Uint8List receiptBytes = Uint8List.fromList([1, 2, 3, 4]);

const List<String> monthAbbreviations = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// Mirrors `formatMonth` in lib/providers/expense_provider.dart deliberately
/// rather than importing it, so a change to the sharding scheme shows up as a
/// failing test instead of being silently tracked.
String monthKeyFor(DateTime date) =>
    '${date.year}_${monthAbbreviations[date.month - 1]}';

class MockReceiptService extends Mock implements ReceiptService {}

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}

/// One recorded `httpsCallable(name).call(payload)`.
typedef CallableInvocation = ({String name, Map<String, dynamic> payload});

/// A [FirebaseFunctions] stand-in that records calls instead of making them.
///
/// The production amortization paths hand months 2..N to a Cloud Function, so
/// without this the only observable behaviour would be the first installment.
/// Recording the payload lets a test assert the whole contract: what the
/// function was asked to build, and from which template.
class FakeFunctions implements FirebaseFunctions {
  FakeFunctions();

  final List<CallableInvocation> invocations = [];

  /// Names that should throw when called, simulating a backend failure.
  final Set<String> failing = {};

  List<CallableInvocation> callsTo(String name) =>
      invocations.where((i) => i.name == name).toList();

  CallableInvocation? lastCallTo(String name) {
    final calls = callsTo(name);
    return calls.isEmpty ? null : calls.last;
  }

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FakeCallable(this, name);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  _FakeCallable(this._functions, this._name);

  final FakeFunctions _functions;
  final String _name;

  @override
  Future<HttpsCallableResult<T>> call<T>([Object? parameters]) async {
    _functions.invocations.add((
      name: _name,
      payload: Map<String, dynamic>.from(parameters as Map? ?? const {}),
    ));
    if (_functions.failing.contains(_name)) {
      throw FirebaseFunctionsException(
        message: 'simulated failure of $_name',
        code: 'internal',
      );
    }
    return _FakeCallableResult<T>(null as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallableResult<T> implements HttpsCallableResult<T> {
  _FakeCallableResult(this.data);

  @override
  final T data;
}

/// The pieces a test needs to drive and inspect the notifier.
class ExpenseHarness {
  ExpenseHarness({
    required this.container,
    required this.db,
    required this.receipts,
    required this.functions,
  });

  final ProviderContainer container;
  final FakeFirebaseFirestore db;
  final MockReceiptService receipts;
  final FakeFunctions functions;

  ExpenseNotifier get notifier =>
      container.read(expenseModifierProvider.notifier);

  CollectionReference<Map<String, dynamic>> monthCollection(DateTime date) =>
      db.collection('ledger').doc(testLedgerId).collection(monthKeyFor(date));

  /// Every expense document in [date]'s month bucket, each carrying its id.
  Future<List<Map<String, dynamic>>> expensesIn(DateTime date) async {
    final snap = await monthCollection(date).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<Map<String, dynamic>?> expenseAt(DateTime date, String id) async {
    final doc = await monthCollection(date).doc(id).get();
    return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
  }

  /// The category-month roll-up, or null when no summary has been written.
  Future<Map<String, dynamic>?> summaryFor(
    String categoryId,
    DateTime date,
  ) async {
    final doc = await db
        .collection('ledger')
        .doc(testLedgerId)
        .collection('summaries')
        .doc('${monthKeyFor(date)}_$categoryId')
        .get();
    return doc.exists ? doc.data() : null;
  }

  Future<double> summaryTotal(String categoryId, DateTime date) async =>
      ((await summaryFor(categoryId, date))?['total'] as num?)?.toDouble() ?? 0;

  Future<int> summaryCount(String categoryId, DateTime date) async =>
      ((await summaryFor(categoryId, date))?['count'] as num?)?.toInt() ?? 0;
}

ExpenseUser buildUser({String ledgerId = testLedgerId}) =>
    ExpenseUser.fromJson({
      'id': testUserId,
      'firstName': 'Test',
      'lastName': 'User',
      'email': 'test@example.com',
      'ledgerId': ledgerId,
      'role': 'primary',
      'initialized': DateTime(2025, 1, 1).toIso8601String(),
      'userSettings': <String, String>{},
      'noteSuggestions': <String, dynamic>{},
      'linkedAccounts': <dynamic>[],
    });

/// A receipt service double whose every operation succeeds quietly. Tests that
/// care about a failure re-stub the one method they are exercising.
MockReceiptService buildReceiptService() {
  // Registered here rather than in each suite's setUpAll so callers cannot
  // forget it; mocktail needs a concrete value behind `any(named: 'bytes')`.
  registerFallbackValue(Uint8List(0));
  final receipts = MockReceiptService();
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
  return receipts;
}

/// Builds a container wired to fakes and waits for the user stream to resolve,
/// which is what [ExpenseNotifier.build] reads synchronously.
Future<ExpenseHarness> buildExpenseHarness({
  FakeFirebaseFirestore? db,
  MockReceiptService? receipts,
  FakeFunctions? functions,
  FirebaseFirestore? backendOverride,
}) async {
  final database = db ?? FakeFirebaseFirestore();
  final receiptService = receipts ?? buildReceiptService();
  final fakeFunctions = functions ?? FakeFunctions();

  final container = ProviderContainer(
    overrides: [
      backendProvider.overrideWithValue(backendOverride ?? database),
      receiptServiceProvider.overrideWithValue(receiptService),
      functionsProvider.overrideWithValue(fakeFunctions),
      userProvider.overrideWith((ref) => Stream.value(buildUser())),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(userProvider, (_, __) {}, fireImmediately: true);
  addTearDown(sub.close);
  await container.read(userProvider.future);

  return ExpenseHarness(
    container: container,
    db: database,
    receipts: receiptService,
    functions: fakeFunctions,
  );
}

/// A plain expense. Amortization is opted into explicitly by [amortizedOver],
/// which mirrors what the form submits when the toggle is on: a total amount
/// plus a placeholder group id the provider replaces.
Expense buildExpense({
  double amount = 25,
  DateTime? date,
  String categoryId = 'groceries',
  String? id,
  String? note,
  String? receiptId,
  String? imageUrl,
  DateTime? hideUntil,
  String? submittedBy,
  int? amortizedOver,
  AmortizationDetails? amortized,
}) =>
    Expense(
      amount: amount,
      date: date ?? DateTime(2026, 3, 10),
      categoryId: categoryId,
      id: id,
      note: note,
      receiptId: receiptId,
      imageUrl: imageUrl,
      hideUntil: hideUntil,
      submittedBy: submittedBy,
      amortized: amortized ??
          (amortizedOver == null
              ? null
              : AmortizationDetails(
                  groupId: '',
                  index: 0,
                  over: amortizedOver,
                )),
    );
