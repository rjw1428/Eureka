import 'package:expense_tracker/constants/categories.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

const uuid = Uuid();
final dateFormatter = DateFormat.yMd();
final CategoryConfig categories = CategoriesService().getCategories();

class Expense {
  Expense({required this.amount, required this.date, required this.category, this.note})
      : id = uuid.v4();

  final String id;
  Category category;
  String? note;
  double amount;
  DateTime date;

  String get formattedDate {
    return dateFormatter.format(date);
  }

  IconData get icon {
    return categories.containsKey(category) ? categories[category]!.icon : Icons.attach_money;
  }

  String get title {
    return '${categories[category]!.label}${note == null ? '' : ':'} ${note ?? ''}';
  }

  update({
    required double amount,
    required DateTime date,
    required Category category,
    required String? note,
  }) {
    this.amount = amount;
    this.date = date;
    this.category = category;
    this.note = note;
    return this;
  }
}

class ExpenseBucket {
  const ExpenseBucket({required this.category, required this.expenses, required this.budgetLimit});

  ExpenseBucket.forCategory(List<Expense> allExpenses, this.category)
      : expenses = allExpenses.where((expense) => expense.category == category).toList(),
        budgetLimit = categories[category]!.budget;

  final Category category;
  final List<Expense> expenses;
  final double budgetLimit;

  double get totalExpenses {
    return expenses.fold(0, (sum, val) => sum + val.amount);
  }
}
