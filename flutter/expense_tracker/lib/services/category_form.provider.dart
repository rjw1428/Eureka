import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/widgets/category_form.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:flutter/material.dart';

void openAddCategoryOverlay(BuildContext context, [CategoryDataWithId? category]) {
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
  try {
    CategoriesService().addCategory(category);
  } catch (e) {
    showDialogNotification(
      'Unable to add category',
      const Text('An error has occurred. Please change something and try again.'),
      context,
    );
  }
}

void _updateCategory(BuildContext context, CategoryDataWithId category) {
  try {
    CategoriesService().updateCategory(category);
  } catch (e) {
    showDialogNotification(
      'Unable to update category',
      const Text('An error has occurred. Please change something and try again.'),
      context,
    );
  }
}

void _removeCategory(BuildContext context, CategoryDataWithId category) {
  try {
    CategoriesService().remove(category);
  } catch (e) {
    showDialogNotification(
      'Unable to delete category',
      const Text('An error has occurred. Please change something and try again.'),
      context,
    );
  }
}
