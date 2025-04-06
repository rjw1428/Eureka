import 'package:expense_tracker/models/expense.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ExpenseItem extends StatelessWidget {
  const ExpenseItem({
    super.key,
    required this.expense,
    required this.onEdit,
    required this.onRemove,
    this.onReact,
  });

  final ExpenseWithCategoryData expense;
  final void Function(ExpenseWithCategoryData) onEdit;
  final void Function(ExpenseWithCategoryData) onRemove;
  final void Function(ExpenseWithCategoryData, BuildContext)? onReact;

  @override
  Widget build(BuildContext context) {
    expense.submittedBy;
    if (expense.reactionData != null) {
      print(expense.reactionData);
    }
    return LayoutBuilder(
      builder: (ctx, constraints) => Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            clipBehavior: Clip.none,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(expense.icon),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(expense.formattedDate, style: Theme.of(context).textTheme.titleSmall),
                        Text(expense.title),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${expense.amount.toStringAsFixed(2)}',
                  ),
                  actionButtons(expense, onEdit, onRemove, onReact, context),
                ],
              ),
            ),
          ),
          if (expense.reactionData != null)
            Positioned(
              right: 50,
              bottom: -5,
              child: Row(
                  children: expense.reactionData!.entries
                      .map(
                        (entry) => entry.value > 1
                            ? Stack(clipBehavior: Clip.none, children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(entry.key),
                                ),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Text(
                                    entry.value.toString(),
                                    style: Theme.of(context).textTheme.labelMedium,
                                  ),
                                )
                              ])
                            : Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Text(entry.key),
                              ),
                      )
                      .toList()),
            ),
        ],
      ),
    );
  }

  Widget actionButtons(
      ExpenseWithCategoryData expense,
      void Function(ExpenseWithCategoryData) onEdit,
      void Function(ExpenseWithCategoryData) onRemove,
      void Function(ExpenseWithCategoryData, BuildContext)? onReact,
      BuildContext ctx) {
    return PopupMenuButton(
        tooltip: 'Actions',
        onSelected: (value) {
          if (value == "EDIT") {
            onEdit(expense);
          } else if (value == "REMOVE") {
            onRemove(expense);
          } else if (value == "REACT" && onReact != null) {
            onReact(expense, ctx);
          }
        },
        itemBuilder: (context) => [
              const PopupMenuItem(
                  value: "EDIT",
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      Padding(padding: EdgeInsets.only(left: 8), child: Text('Edit'))
                    ],
                  )),
              if (kIsWeb)
                const PopupMenuItem(
                    value: "REACT",
                    child: Row(
                      children: [
                        Icon(Icons.emoji_emotions),
                        Padding(padding: EdgeInsets.only(left: 8), child: Text('React'))
                      ],
                    )),
              // // ON PUSH TASK
              const PopupMenuItem(
                  value: "REMOVE",
                  child: Row(
                    children: [
                      Icon(Icons.delete),
                      Padding(padding: EdgeInsets.only(left: 8), child: Text('Remove'))
                    ],
                  ))
            ]);
  }
}
