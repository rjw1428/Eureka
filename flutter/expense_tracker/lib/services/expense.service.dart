import 'package:expense_tracker/models/expense.dart';

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

class ExpenseService {
  ExpenseService._internal();

  static final ExpenseService _instance = ExpenseService._internal();
  factory ExpenseService() {
    return _instance;
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

  void remove(Expense expense) {
    defaultData.remove(expense);
  }

  void addExpense(Expense expense, [index = 0]) {
    defaultData.insert(index, expense);
  }
}
