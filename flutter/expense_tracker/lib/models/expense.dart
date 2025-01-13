import 'package:expense_tracker/services/categories.service.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

const uuid = Uuid();
final dateFormatter = DateFormat.yMd();

class Expense {
  Expense({
    required this.amount,
    required this.date,
    required this.category,
    this.note,
  }) : id = uuid.v4();

  String id;
  String category;
  String? note;
  double amount;
  DateTime date;

  String get formattedDate {
    return dateFormatter.format(date);
  }

  IconData get icon {
    final CategoryConfig categories = CategoriesService().getCategories();
    return categories.firstWhere((cat) => cat.id == category).icon;
  }

  String get title {
    final CategoryConfig categories = CategoriesService().getCategories();
    return '${categories.firstWhere((cat) => cat.id == category).label}${note == null ? '' : ':'} ${note ?? ''}';
  }

  updateId(String oldId) {
    id = oldId;
  }
}

class ExpenseBucket {
  ExpenseBucket({
    required this.category,
    required this.expenses,
    required this.budgetLimit,
  });

  ExpenseBucket.forCategory(List<Expense> allExpenses, CategoryConfig categoryList, this.category)
      : expenses = allExpenses.where((expense) => expense.category == category).toList(),
        budgetLimit = categoryList.firstWhere((cat) => cat.id == category).budget;

  final String category;
  final List<Expense> expenses;
  final double budgetLimit;

  double get totalExpenses {
    return expenses.fold(0, (sum, val) => sum + val.amount);
  }
}
