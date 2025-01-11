import 'package:expense_tracker/constants/categories.dart';
import 'package:expense_tracker/models/expense.dart';

class ExpenseService {
  List<Expense> getExpenses() {
    return [
      Expense(
        note: 'Grocery Shopping',
        amount: 30.82,
        date: DateTime.now(),
        category: Category.SHOPPING,
      ),
      Expense(
        note: 'Truck',
        amount: 89.12,
        date: DateTime.now().add(const Duration(hours: -1)),
        category: Category.GAS,
      ),
      Expense(
        amount: 45.00,
        date: DateTime.now().add(const Duration(hours: -2)),
        category: Category.HOME_RENO,
      ),
      Expense(
          amount: 45.00,
          date: DateTime.now().add(const Duration(hours: -2)),
          category: Category.HOME_RENO,
          note: 'Here is one with a very long title just to see how it renders'),
    ];
  }
}
