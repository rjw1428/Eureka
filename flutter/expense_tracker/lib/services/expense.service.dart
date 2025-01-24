import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

final formatter = DateFormat('MMM');

class ExpenseService {
  ExpenseService._internal();

  final _db = FirebaseFirestore.instance;
  static final ExpenseService _instance = ExpenseService._internal();

  factory ExpenseService() {
    return _instance;
  }

  Stream<List<Expense>> getExpenseStream(String ledgerId, DateTime date) {
    final month = formatMonth(date);

    return _db
        .collection('ledger')
        .doc(ledgerId)
        .collection(month)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Expense.fromJson({...doc.data(), "id": doc.id})).toList())
        .handleError((err) => print('Expense Stream: ${err.toString()}'))
        .shareReplay(maxSize: 1);
  }

  Future<void> getSummary(DateTime start, DateTime? end) async {
    DateTime queryEnd = end ?? DateTime.now();
    final ledgerId = await AuthService().getCurrentUserLedgerId().first;
    final snapshot = await _db
        .collection('ledger')
        .doc(ledgerId)
        .collection('summaries')
        .where('startDate', isGreaterThanOrEqualTo: start)
        .where('startDate', isLessThanOrEqualTo: queryEnd)
        .get();

    snapshot.docs.forEach((doc) => print(doc.data()));
  }

  Future<CollectionReference<Map<String, dynamic>>> expenseCollection(DateTime date) async {
    final ledgerId = await AuthService().getCurrentUserLedgerId().first;
    final month = formatMonth(date);
    return _db.collection('ledger').doc(ledgerId).collection(month);
  }

  Future<DocumentReference<Map<String, dynamic>>> summaryCollection(Expense expense) async {
    final ledgerId = await AuthService().getCurrentUserLedgerId().first;
    final docId = summaryId(expense);
    return _db.collection('ledger').doc(ledgerId).collection('summaries').doc(docId);
  }

  Future checkSummaryCollection(Expense expense) async {
    final ledgerId = await AuthService().getCurrentUserLedgerId().first;
    final ref = _db.collection('ledger').doc(ledgerId).collection('summaries');
    final docId = summaryId(expense);

    final summaryDoc = await ref.doc(docId).get();
    if (!summaryDoc.exists) {
      ref.doc(docId).set({
        'startDate': DateTime(expense.date.year, expense.date.month),
      });
    }
  }

  Future<void> updateExpense(Expense expense, Expense previousExpense) async {
    final isSameDate = expense.date.month == previousExpense.date.month &&
        expense.date.year == previousExpense.date.year;
    if (isSameDate) {
      List<Future> actions = [
        expenseCollection(previousExpense.date)
            .then((ref) => ref.doc(previousExpense.id).set(expense.toJson())),
      ];
      // Skip updating summary if the amount hasn't changed
      if (expense.amount - previousExpense.amount != 0) {
        actions.add(
          summaryCollection(expense).then(
            (ref) => ref.update({
              'lastUpdate': FieldValue.serverTimestamp(),
              'total': FieldValue.increment(expense.amount - previousExpense.amount),
            }),
          ),
        );
      }
      await Future.wait(actions);
    }
    await remove(previousExpense);
    await addExpense(expense);
    return;
  }

  Future<void> remove(Expense expense) async {
    await Future.wait([
      summaryCollection(expense).then((ref) => ref.update({
            'lastUpdate': FieldValue.serverTimestamp(),
            'total': FieldValue.increment(-1 * expense.amount),
            'count': FieldValue.increment(-1),
          })),
      expenseCollection(expense.date).then((ref) => ref.doc(expense.id!).delete()),
    ]);
  }

  Future addExpense(Expense expense) async {
    await checkSummaryCollection(expense);
    try {
      return Future.wait([
        summaryCollection(expense).then(
          (summaryDocRef) => summaryDocRef.update({
            'lastUpdate': FieldValue.serverTimestamp(),
            'total': FieldValue.increment(expense.amount),
            'count': FieldValue.increment(1)
          }),
        ),
        expenseCollection(expense.date).then((collectionRef) {
          var newExpenseData = expense.toJson();
          newExpenseData.remove('id');
          collectionRef.add(newExpenseData);
        })
      ]);
    } catch (e) {
      return null;
    }
  }

  String formatMonth(DateTime date) {
    return "${date.year}_${formatter.format(date).toUpperCase()}";
  }

  String summaryId(Expense expense) {
    final yearMonth = formatMonth(expense.date);
    return "${yearMonth}_${expense.categoryId}";
  }
}
