import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

const uuid = Uuid();
final dateFormatter = DateFormat.yMd();

enum Category { EATING_OUT, SNACKS, GAS, SHOPPING, HOME_RENO }

class CategoryData {
  final String label;
  final IconData icon;

  const CategoryData({required this.label, required this.icon});
}

const Map<Category, CategoryData> categories = {
  Category.EATING_OUT: CategoryData(label: 'Eating Out', icon: Icons.lunch_dining_outlined),
  Category.SNACKS: CategoryData(label: 'Snacks', icon: Icons.icecream_outlined),
  Category.GAS: CategoryData(label: 'Gas', icon: Icons.local_gas_station_outlined),
  Category.SHOPPING: CategoryData(label: 'Shopping', icon: Icons.shopping_basket_outlined),
  Category.HOME_RENO: CategoryData(label: 'Home Reno', icon: Icons.construction_outlined),
};

class Expense {
  Expense({required this.amount, required this.date, required this.category, this.note})
      : id = uuid.v4();

  final String id;
  final Category category;
  final String? note;
  final double amount;
  final DateTime date;

  String get formattedDate {
    return dateFormatter.format(date);
  }

  IconData get icon {
    return categories.containsKey(category) ? categories[category]!.icon : Icons.attach_money;
  }
}

class ExpenseBucket {
  const ExpenseBucket({required this.category, required this.expenses});

  ExpenseBucket.forCategory(List<Expense> allExpenses, this.category)
      : expenses = allExpenses.where((expense) => expense.category == category).toList();

  final Category category;
  final List<Expense> expenses;

  double get totalExpenses {
    return expenses.fold(0, (sum, val) => sum + val.amount);
  }
}
