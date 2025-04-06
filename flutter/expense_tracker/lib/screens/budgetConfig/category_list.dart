import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryList extends ConsumerWidget {
  const CategoryList({
    super.key,
    required this.categoryList,
    required this.onEdit,
  });

  final List<CategoryDataWithId> categoryList;
  final void Function(CategoryDataWithId) onEdit;

  @override
  Widget build(Object context, WidgetRef ref) {
    final user = ref.watch(userProvider).valueOrNull;
    return SingleChildScrollView(
      child: Column(
        children: categoryList
            .map((category) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(category.iconData),
                              ),
                              Text(category.label),
                            ],
                          ),
                        ),
                        Text(
                          'Budget: ${currency.format(category.budget)}',
                          textAlign: TextAlign.end,
                        ),
                        if (user!.role == 'primary')
                          Row(
                            children: [
                              TextButton(
                                  onPressed: () => onEdit(category), child: const Icon(Icons.edit)),
                            ],
                          )
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
