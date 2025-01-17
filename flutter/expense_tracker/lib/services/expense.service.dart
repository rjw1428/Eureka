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

  Future<CollectionReference<Map<String, dynamic>>> expenseCollection(DateTime date) async {
    final ledgerId = await AuthService().getCurrentUserLedgerId().first;
    final month = formatMonth(date);
    return _db.collection('ledger').doc(ledgerId).collection(month);
  }

  Stream<List<Expense>> getExpenseStream(DateTime date) {
    final ledgerId$ = AuthService().getCurrentUserLedgerId();
    final month = formatMonth(date);
    return ledgerId$
        .switchMap(
            (ledgerId) => _db.collection('ledger').doc(ledgerId).collection(month).snapshots())
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Expense.fromJson({...doc.data(), "id": doc.id});
      }).toList();
    });
  }

  Future<void> updateExpense(Expense expense, Expense previousExpense) async {
    if (expense.date.month == previousExpense.date.month &&
        expense.date.year == previousExpense.date.year) {
      final collectionRef = await expenseCollection(previousExpense.date);
      return collectionRef.doc(previousExpense.id).set(expense.toJson());
    }
    await remove(previousExpense);
    await addExpense(expense);
    return;
  }

  Future<void> remove(Expense expense) async {
    final collectionRef = await expenseCollection(expense.date);
    return collectionRef.doc(expense.id!).delete();
  }

  Future<DocumentReference<Map<String, dynamic>>?> addExpense(Expense expense, [index = 0]) async {
    try {
      final collectionRef = await expenseCollection(expense.date);
      var newExpenseData = expense.toJson();
      newExpenseData.remove('id');
      return collectionRef.add(newExpenseData);
    } catch (e) {
      return null;
    }
  }

  String formatMonth(DateTime date) {
    return "${date.year}_${formatter.format(date).toUpperCase()}";
  }
}
