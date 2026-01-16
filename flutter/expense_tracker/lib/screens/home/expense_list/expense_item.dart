import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/linked_accounts_provider.dart';
import 'package:expense_tracker/widgets/user_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(linkedUserProvider.select((linkedUsers) {
      if (expense.submittedBy == null) {
        return null;
      }
      return linkedUsers.firstWhereOrNull(
          (linkedUser) => linkedUser.id == expense.submittedBy);
    }));

    final isHidden = expense.hideUntil?.isAfter(DateTime.now()) ?? false;

    createCardContent() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Opacity(
                    opacity: isHidden ? 0.4 : 1.0,
                    child: Icon(
                      expense.icon,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(expense.formattedDate,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        isHidden ? "Lorem ipsum dolor sit amet" : expense.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Text(
                isHidden ? "\$0.00" : '\$${expense.amount.toStringAsFixed(2)}',
              ),
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Opacity(
                    opacity: 0.7,
                    child: UserIcon(
                      user: user,
                      size: 36,
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
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
            color: isHidden
                ? Colors.transparent
                : Theme.of(context).cardTheme.color,
            clipBehavior: Clip.none,
            child: DottedBorder(
              strokeWidth: 2,
              dashPattern: const [6, 3],
              color: isHidden
                  ? Theme.of(context).cardTheme.color!
                  : Colors.transparent,
              borderType: BorderType.RRect,
              radius: const Radius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: isHidden
                          ? ClipRect(
                              child: ImageFiltered(
                                imageFilter:
                                    ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                                child: createCardContent(),
                              ),
                            )
                          : createCardContent(),
                    ),
                    actionButtons(expense, onEdit, onRemove, onReact, context),
                  ],
                ),
              ),
            ),
          ),
          if (expense.reactionData != null) reactionMenu(context),
        ],
      ),
    );
  }

  Widget reactionMenu(BuildContext context) {
    return Positioned(
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
                      Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('Edit'))
                    ],
                  )),
              if (kIsWeb)
                const PopupMenuItem(
                    value: "REACT",
                    child: Row(
                      children: [
                        Icon(Icons.emoji_emotions),
                        Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text('React'))
                      ],
                    )),
              // // ON PUSH TASK
              const PopupMenuItem(
                  value: "REMOVE",
                  child: Row(
                    children: [
                      Icon(Icons.delete),
                      Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('Remove'))
                    ],
                  ))
            ]);
  }
}
