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

  final List<ExpenseWithCategoryData> list;
  final void Function(ExpenseWithCategoryData) onRemove;
  final void Function(ExpenseWithCategoryData) onEdit;
  final List<String> filters;

  @override
  Widget build(BuildContext context) {
    final List<ExpenseWithCategoryData> filteredList =
        list.where((expense) => filters.contains(expense.category.id)).toList();

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

  final ExpenseWithCategoryData expense;
  final void Function(ExpenseWithCategoryData) onEdit;

  @override
  Widget build(BuildContext context) {
    expense.submittedBy;
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
                        child: SelectableText(expense.title),
                      ),
                    ],
                  ),
                ],
              ),
              SelectableText(
                '\$${expense.amount.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
