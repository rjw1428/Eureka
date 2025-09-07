import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/screens/budgetConfig/category_list.dart';
import 'package:expense_tracker/widgets/category_form.dart';
import 'package:flutter/material.dart';

class CreateInitialBudgetStep extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final Function(List<CategoryDataWithId>) onCreate;
  final Function() onBack;
  final List<CategoryDataWithId> categories;

  const CreateInitialBudgetStep({
    super.key,
    required this.formKey,
    required this.onCreate,
    required this.onBack,
    required this.categories,
  });

  @override
  State<CreateInitialBudgetStep> createState() =>
      _CreateInitialBudgetStepState();
}

class _CreateInitialBudgetStepState extends State<CreateInitialBudgetStep> {
  openAddCategoryOverlay(BuildContext context, [CategoryDataWithId? category]) {
    showModalBottomSheet(
      useSafeArea: true,
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        return CategoryForm(
          onSubmit: (newCategory) => category == null
              ? _addCategory(context, newCategory)
              : _updateCategory(context, newCategory),
          initialCategory: category,
          onRemove: (category) => _removeCategory(context, category),
        );
      },
    );
  }

  void _addCategory(BuildContext context, CategoryDataWithId category) {
    setState(() {
      widget.categories.add(category);
    });
  }

  void _updateCategory(BuildContext context, CategoryDataWithId category) {
    setState(() {
      final index = widget.categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        widget.categories[index] = category;
      }
    });
  }

  void _removeCategory(BuildContext context, CategoryDataWithId category) {
    setState(() {
      widget.categories.removeWhere((c) => c.id == category.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          children: [
            Text(
              'Create Your Budget',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            const Text('Now let\'s setup a budget to get you started.'),
            const SizedBox(height: 20),
            FormField<List<CategoryDataWithId>>(
              validator: (value) => null,
              builder: (FormFieldState<List<CategoryDataWithId>> state) {
                return CategoryList(
                  categoryList: widget.categories,
                  onEdit: (category) =>
                      openAddCategoryOverlay(context, category),
                  isEditable: true,
                );
              },
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: OutlinedButton.icon(
                  onPressed: () => openAddCategoryOverlay(context),
                  label: Text(widget.categories.isEmpty
                      ? 'Add your first budget category'
                      : 'Add another budget category'),
                  icon: const Icon(Icons.playlist_add),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (widget.categories.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Hard to believe you have no expenses! Please add at least one budget category to continue.'),
                    ),
                  );
                  return;
                }

                widget.onCreate(widget.categories);
              },
              child: const Text('Get Started!'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                widget.onBack();
              },
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
