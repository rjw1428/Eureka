import 'package:expense_tracker/constants/categories.dart';
import 'package:expense_tracker/models/expense.dart';

class ExpenseService {
  List<Expense> getExpenses(int year, int month) {
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
        amount: 10.88,
        date: DateTime.now().add(const Duration(days: -2)),
        category: Category.GAS,
        note: 'Here is one with a very long title just to see how it renders',
      ),
      Expense(
          amount: 112.00,
          date: DateTime(2024, 12, 12),
          category: Category.EATING_OUT,
          note: 'December Dinner'),
      Expense(
          amount: 45.00,
          date: DateTime(2024, 12, 10),
          category: Category.GAS,
          note: 'December Gas'),
      Expense(
          amount: 111.00,
          date: DateTime(2024, 11, 29),
          category: Category.EATING_OUT,
          note: 'November Dinner'),
      Expense(
        amount: 45.00,
        date: DateTime(2024, 11, 29),
        category: Category.GAS,
        note: 'November Gas',
      ),
    ].where((expense) => expense.date.year == year && expense.date.month == month).toList();
  }
}
