import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:expense_tracker/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';

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

  _loadMoreVertical() {
    print("LOAING MORE");
  }

  @override
  Widget build(BuildContext context) {
    final List<ExpenseWithCategoryData> filteredList =
        list.where((expense) => filters.contains(expense.category.id)).toList();

    if (filteredList.isEmpty) {
      return const Center(child: Text('No expenses found 💩'));
    }

    return LazyLoadScrollView(
      onEndOfPage: () => _loadMoreVertical(),
      child: ListView.builder(
        itemCount: filteredList.length,
        itemBuilder: (ctx, i) {
          return kIsWeb
              ? ExpenseItem(
                  expense: filteredList[i],
                  onEdit: onEdit,
                )
              : GestureDetector(
                  key: ValueKey(list[i].id),
                  onLongPress: () {
                    HapticFeedback.lightImpact();
                    onEdit(filteredList[i]);
                  },
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
      ),
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
            horizontal: 16,
            vertical: 8,
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
