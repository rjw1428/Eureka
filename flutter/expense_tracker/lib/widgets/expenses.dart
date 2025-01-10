import 'package:expense_tracker/constants/categories.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/widgets/chart.dart';
import 'package:expense_tracker/widgets/expense_form.dart';
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
  ];

  void _openAddExpenseOverlay([Expense? expense]) {
    showModalBottomSheet(
        useSafeArea: true,
        isScrollControlled: true,
        context: context,
        builder: (ctx) {
          return ExpenseForm(
            onSubmit: expense == null ? _addExpense : _updateExpense,
            initialExpense: expense,
            onRemove: _removeExpense,
          );
        });
  }

  void _addExpense(Expense expense) {
    setState(() => _registeredExpenses.insert(0, expense));
  }

  void _updateExpense(Expense expense) {
    final index = _registeredExpenses.map((e) => e.id).toList().indexOf(expense.id);
    setState(() => _registeredExpenses[index] = expense);
  }

  void _removeExpense(Expense expense) {
    ScaffoldMessenger.of(context).clearSnackBars();

    final index = _registeredExpenses.indexOf(expense);
    setState(() => _registeredExpenses.remove(expense));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('Expense for ${expense.title}  deleted!'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _registeredExpenses.insert(index, expense));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget listContent = _registeredExpenses.isEmpty
        ? const Center(child: Text('No expenses found 💩'))
        : ExpenseList(
            list: _registeredExpenses,
            onRemove: _removeExpense,
            onEdit: _openAddExpenseOverlay,
          );

    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(title: const Text('Expense Tracker'), actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddExpenseOverlay,
          ),
        ]),
        body: LayoutBuilder(builder: (ctx, constraints) {
          return constraints.maxWidth < 600
              ? Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: Chart(expenses: _registeredExpenses),
                    ),
                    Expanded(child: listContent)
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: Chart(expenses: _registeredExpenses)),
                    Expanded(child: listContent)
                  ],
                );
        }));
  }
}

class ExpenseList extends StatelessWidget {
  const ExpenseList({
    super.key,
    required this.list,
    required this.onRemove,
    required this.onEdit,
  });

  final List<Expense> list;
  final void Function(Expense) onRemove;
  final void Function(Expense) onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        return kIsWeb
            ? ExpenseItem(
                expense: list[i],
                onEdit: onEdit,
              )
            : GestureDetector(
                onLongPress: () => onEdit(list[i]),
                child: ExpenseItem(
                  expense: list[i],
                  onEdit: (e) => {},
                ),
              );
        // return Dismissible(
        //   key: ValueKey(list[i].id),
        //   onDismissed: (direction) => onRemove(list[i]),
        //   child: ExpenseItem(expense: list[i]),
        // );
      },
    );
  }
}

class ExpenseItem extends StatelessWidget {
  const ExpenseItem({
    super.key,
    required this.expense,
    required this.onEdit,
  });

  final Expense expense;
  final void Function(Expense) onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (kIsWeb)
                    IconButton(onPressed: () => onEdit(expense), icon: const Icon(Icons.edit)),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(expense.icon),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(expense.formattedDate, style: Theme.of(context).textTheme.titleSmall),
                      Text(expense.title),
                    ],
                  ),
                ],
              ),
              Text(
                'Amount: \$${expense.amount.toStringAsFixed(2)}',
              ),
            ],
          )),
    );
  }
}
