import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:expense_tracker/models/expense.dart';
import 'package:flutter/material.dart';

class ExpenseList extends StatelessWidget {
  const ExpenseList({
    super.key,
    required this.list,
    required this.onRemove,
    required this.onEdit,
    required this.filters,
  });

  final List<Expense> list;
  final void Function(Expense) onRemove;
  final void Function(Expense) onEdit;
  final List<String> filters;

  @override
  Widget build(BuildContext context) {
    final List<Expense> filteredList =
        list.where((expense) => filters.contains(expense.category)).toList();

    return filteredList.isEmpty
        ? const Center(child: Text('No expenses found 💩'))
        : ListView.builder(
            itemCount: filteredList.length,
            itemBuilder: (ctx, i) {
              return kIsWeb
                  ? ExpenseItem(
                      expense: filteredList[i],
                      onEdit: onEdit,
                    )
                  : GestureDetector(
                      key: ValueKey(list[i].id),
                      onLongPress: () => onEdit(filteredList[i]),
                      child: ExpenseItem(
                        expense: filteredList[i],
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
    return LayoutBuilder(
      builder: (ctx, constraints) => Card(
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
                      SizedBox(
                        width: constraints.maxWidth - 200,
                        child: Text(expense.title),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '\$${expense.amount.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
