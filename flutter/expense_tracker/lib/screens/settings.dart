import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/widgets/category_form.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _SettingsScreenState();
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<CategoryDataWithId> categoryList = CategoriesService().getCategories(withDeleted: false);

  void _openAddCategoryOverlay([CategoryDataWithId? category]) {
    showModalBottomSheet(
      useSafeArea: true,
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        return CategoryForm(
          onSubmit: category == null ? _addCategory : _updateCategory,
          initialCategory: category,
          onRemove: _removeCategory,
        );
      },
    );
  }

  void _addCategory(CategoryDataWithId category) {
    CategoriesService().addCategory(category);
    setState(() {
      categoryList = CategoriesService().getCategories(withDeleted: false);
    });
  }

  void _updateCategory(CategoryDataWithId category) {
    CategoriesService().updateCategory(category);
    setState(() {
      categoryList = CategoriesService().getCategories(withDeleted: false);
    });
  }

  void _removeCategory(CategoryDataWithId category) {
    CategoriesService().remove(category);
    setState(() {
      categoryList = CategoriesService().getCategories(withDeleted: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 64, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Spending Categories:',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.start,
          ),
          CategoryList(
            categoryList: categoryList,
            onEdit: _openAddCategoryOverlay,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: OutlinedButton.icon(
                onPressed: _openAddCategoryOverlay,
                label: const Text('Add a spending category'),
                icon: const Icon(Icons.playlist_add),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Link your spending',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.start,
          ),
          Text(
            'Send a request to another user. When they accept, all transactions will appear on each others accounts.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }
}

class CategoryList extends StatelessWidget {
  const CategoryList({super.key, required this.categoryList, required this.onEdit});

  final List<CategoryDataWithId> categoryList;
  final void Function(CategoryDataWithId) onEdit;

  @override
  Widget build(Object context) {
    return Column(
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
                                child: Icon(category.icon),
                              ),
                              Text(category.label),
                            ],
                          ),
                        ),
                        Text(
                          'Budget: \$${category.budget.toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                        ),
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
            .toList());
  }
}
