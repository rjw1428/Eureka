import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:intl/intl.dart';

final defaultData = [
  Expense(
    note: 'Grocery Shopping',
    amount: 30.82,
    date: DateTime.now(),
    category: 'SHOPPING',
  ),
  Expense(
    note: 'Truck',
    amount: 89.12,
    date: DateTime.now().add(const Duration(hours: -1)),
    category: 'GAS',
  ),
  Expense(
    amount: 45.00,
    date: DateTime.now().add(const Duration(hours: -2)),
    category: 'HOME_RENO',
  ),
  Expense(
    amount: 10.88,
    date: DateTime.now().add(const Duration(days: -2)),
    category: 'GAS',
    note: 'Here is one with a very long title just to see how it renders',
  ),
  Expense(
      amount: 112.00,
      date: DateTime(2024, 12, 12),
      category: 'EATING_OUT',
      note: 'December Dinner'),
  Expense(
    amount: 45.00,
    date: DateTime(2024, 12, 10),
    category: 'GAS',
    note: 'December Gas',
  ),
  Expense(
      amount: 111.00,
      date: DateTime(2024, 11, 29),
      category: 'EATING_OUT',
      note: 'November Dinner'),
  Expense(
    amount: 45.00,
    date: DateTime(2024, 11, 29),
    category: 'GAS',
    note: 'November Gas',
  ),
];

final formatter = DateFormat('MMM');

class ExpenseService {
  ExpenseService._internal();

  final _db = FirebaseFirestore.instance;
  static final ExpenseService _instance = ExpenseService._internal();
  factory ExpenseService() {
    return _instance;
  }

  CollectionReference<Map<String, dynamic>> expenseCollection(String month) {
    // AuthService().user?.uid
    // TODO: Get the ledger ID here
    // TODO: Validate using security rule
    const ledgerId = '41Rfjjro4zy9Xr3gs557';
    return _db.collection('ledger').doc(ledgerId).collection(month);
  }

  Stream<List<Expense>> getExpenseStream(String userId, String month) {
    return expenseCollection(month).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Expense.fromJson({...doc.data(), "id": doc.id})).toList());
  }

  List<Expense> getExpenses(int year, int month) {
    return defaultData
        .where((expense) => expense.date.year == year && expense.date.month == month)
        .toList();
  }

  void updateExpense(Expense expense) {
    final index = defaultData.map((e) => e.id).toList().indexOf(expense.id);
    defaultData[index] = expense;
  }

  Future<void> remove(Expense expense) {
    // defaultData.remove(expense);
    final month = "${expense.date.year}_${formatter.format(expense.date).toUpperCase()}";
    return expenseCollection(month).doc(expense.id!).delete();
  }

  Future<void> addExpense(Expense expense, [index = 0]) {
    // defaultData.insert(index, expense);
    // TODO: Add without id value
    final month = "${expense.date.year}_${formatter.format(expense.date).toUpperCase()}";
    return expenseCollection(month).add(expense.toJson());
  }
}
