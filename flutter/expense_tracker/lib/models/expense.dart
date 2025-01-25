import 'package:expense_tracker/constants/icons.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:json_annotation/json_annotation.dart';
part 'expense.g.dart';

final dateFormatter = DateFormat.yMd();

@JsonSerializable()
class Expense {
  Expense({
    required this.amount,
    required this.date,
    required this.categoryId,
    this.submittedBy,
    this.note,
    this.id,
  });

  String categoryId;
  String? id;
  String? note;
  String? submittedBy;
  double amount;
  DateTime date;

  factory Expense.fromJson(Map<String, dynamic> json) => _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);

  String get formattedDate {
    return dateFormatter.format(date);
  }

  updateId(String oldId) {
    id = oldId;
  }
}

@JsonSerializable()
class ExpenseWithCategoryData extends Expense {
  CategoryDataWithId category;

  ExpenseWithCategoryData({
    required super.amount,
    required super.date,
    required super.categoryId,
    required super.submittedBy,
    required this.category,
  });

  factory ExpenseWithCategoryData.fromJson(Map<String, dynamic> json) =>
      _$ExpenseWithCategoryDataFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseWithCategoryDataToJson(this);

  String get title {
    return '${category.label}${note == null ? '' : ':'} ${note ?? ''}';
  }

  IconData get icon {
    return categoryIcons[category.icon]!;
  }
}

class ExpenseBucket {
  ExpenseBucket({
    required this.category,
    required this.expenses,
    required this.budgetLimit,
  });

  ExpenseBucket.forCategory(
    List<Expense> allExpenses,
    List<CategoryDataWithId> categoryList,
    this.category,
  )   : expenses = allExpenses.where((expense) => expense.categoryId == category).toList(),
        budgetLimit = categoryList.firstWhere((cat) => cat.id == category).budget;

  final String category;
  final List<Expense> expenses;
  final double budgetLimit;

  double get totalExpenses {
    return expenses.fold(0, (sum, val) => sum + val.amount);
  }
}
