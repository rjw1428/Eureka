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
      date: DateTime.now().add(const Duration(hours: -1)),
      category: Category.HOME_RENO,
    ),
  ];

  void _openAddExpenseOverlay() {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (ctx) {
          return ExpenseForm(onSubmit: _addExpense);
        });
  }

  void _addExpense(Expense expense) {
    setState(() {
      _registeredExpenses.add(expense);
    });
  }

  void _removeExpense(Expense expense) {
    ScaffoldMessenger.of(context).clearSnackBars();

    final index = _registeredExpenses.indexOf(expense);
    setState(() {
      _registeredExpenses.remove(expense);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('${expense.category} deleted!'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() {
                _registeredExpenses.insert(index, expense);
              });
            },
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget listContent = _registeredExpenses.isEmpty
        ? const Center(child: Text('No expenses found 💩'))
        : ExpenseList(list: _registeredExpenses, onRemove: _removeExpense);

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Tracker'), actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _openAddExpenseOverlay,
        ),
      ]),
      body: Column(
        children: [
          Chart(expenses: _registeredExpenses),
          Expanded(
            child: listContent,
          ),
        ],
      ),
    );
  }
}

class ExpenseList extends StatelessWidget {
  const ExpenseList({super.key, required this.list, required this.onRemove});

  final List<Expense> list;
  final void Function(Expense) onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (ctx, i) => Dismissible(
        key: ValueKey(list[i].id),
        onDismissed: (direction) => onRemove(list[i]),
        // background: Container(color: Theme.of(context).colorScheme.onError),
        child: ExpenseItem(expense: list[i]),
      ),
    );
  }
}

class ExpenseItem extends StatelessWidget {
  const ExpenseItem({super.key, required this.expense});

  final Expense expense;

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(expense.formattedDate, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                      '${categories[expense.category]!.label}${expense.note == null ? '' : ':'} ${expense.note ?? ''}'),
                ],
              ),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(expense.icon),
                  ),
                  Text(
                    'Amount: \$${expense.amount.toString()}',
                  ),
                ],
              )
            ],
          )),
    );
  }
}
