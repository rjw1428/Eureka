import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/providers/note_suggestion_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryList extends ConsumerWidget {
  const CategoryList({
    super.key,
    required this.categoryList,
    required this.onEdit,
    required this.onAddShortcut,
    this.isEditable = false,
  });

  final List<CategoryDataWithId> categoryList;
  final void Function(CategoryDataWithId) onEdit;
  final void Function(String) onAddShortcut;
  final bool isEditable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).valueOrNull;
    final noteShortcuts = ref.watch(noteSuggestionProvider);

    return SingleChildScrollView(
      key: const PageStorageKey('categoryListScrollPosition'),
      child: Column(
        children: categoryList.map((category) {
          final shortcuts = noteShortcuts[category.id] ?? [];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
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
                      if (user?.role == 'primary' || isEditable)
                        Row(
                          children: [
                            TextButton(onPressed: () => onEdit(category), child: const Icon(Icons.edit)),
                          ],
                        )
                    ],
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Description Shortcuts:',
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton.outlined(
                        icon: const Icon(Icons.add),
                        onPressed: () => onAddShortcut(category.id),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 4.0,
                          runSpacing: -10.0,
                          children: shortcuts
                              .map((shortcut) => Chip(
                                    label: Text(shortcut),
                                    deleteIcon: const Icon(Icons.clear),
                                    onDeleted: () => ref
                                        .read(noteSuggestionProvider.notifier)
                                        .removeSuggestion(shortcut, category.id),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
