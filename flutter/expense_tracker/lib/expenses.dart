import 'package:expense_tracker/models/expense.dart';
import 'package:flutter/material.dart';

class Expenses extends StatefulWidget {
  const Expenses({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ExpensesState();
  }
}

class _ExpensesState extends State<Expenses> {
  final List<Expense> _registeredExpenses = [
    Expense(
      title: 'Grocery Shopping',
      amount: 30.82,
      date: DateTime.now(),
      category: Category.SHOPPING,
    ),
    Expense(
      title: 'Gas',
      amount: 89.12,
      date: DateTime.now().add(const Duration(hours: -1)),
      category: Category.SHOPPING,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [const Text('Chart'), ExpenseList(list: _registeredExpenses)],
    );
  }
}

class ExpenseList extends StatelessWidget {
  const ExpenseList({super.key, required this.list});

  final List<Expense> list;

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child:
            ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) => Text(list[i].title)));
  }
}
