import 'dart:io';
import 'package:expense_tracker/constants/icons.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

class CategoryForm extends StatefulWidget {
  const CategoryForm({
    super.key,
    required this.onSubmit,
    required this.onRemove,
    this.initialCategory,
  });

  final void Function(CategoryDataWithId) onSubmit;
  final void Function(CategoryDataWithId) onRemove;
  final CategoryDataWithId? initialCategory;

  @override
  State<StatefulWidget> createState() {
    return _CategoryFormState();
  }
}

class _CategoryFormState extends State<CategoryForm> {
  String formTitle = 'Add Category';
  String actionButtonLabel = 'Save';
  String _selectedIcon = 'access_time_outlined';
  final _label = TextEditingController();
  final _budget = TextEditingController();

  void _showDialog(String title, String content) {
    bool isIos = false;
    try {
      isIos = Platform.isIOS;
    } catch (e) {
      isIos = false;
    }

    if (isIos) {
      showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Okay'))
                ],
              ));
    } else {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Okay'))
                ],
              ));
    }
  }

  void _submit() {
    // Budget can be 0
    final enteredBudget = double.tryParse(_budget.text);
    final enteredLabel = _label.text.trim();
    if (enteredBudget == null) {
      _showDialog(
        'Invalid Amount',
        'Make sure the amount is a number',
      );
      return;
    }

    if (enteredLabel.isEmpty) {
      _showDialog(
        'Invalid Category Name',
        'Category name is required',
      );
      return;
    }

    final newCategory = CategoryDataWithId(
      budget: enteredBudget,
      label: enteredLabel,
      icon: _selectedIcon,
      id: uuid.v4(),
    );

    if (widget.initialCategory != null) {
      newCategory.updateId(widget.initialCategory!.id);
    }
    widget.onSubmit(newCategory);

    Navigator.pop(context);
    return;
  }

  @override
  void dispose() {
    _label.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  void initState() {
    if (widget.initialCategory != null) {
      formTitle = 'Edit Category';
      actionButtonLabel = 'Update';
      _budget.text = widget.initialCategory!.budget.toString();
      _label.text = widget.initialCategory!.label;
      _selectedIcon = widget.initialCategory!.icon;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardSpace + 16),
        child: Column(
          children: [
            Text(
              formTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 16),
                    child: DropdownButton<String>(
                      onChanged: (el) {
                        setState(() {
                          _selectedIcon = el!;
                        });
                      },
                      value: _selectedIcon,
                      items: categoryIcons.entries
                          .map(
                            (el) => DropdownMenuItem<String>(
                              value: el.key,
                              child: Icon(el.value),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      textCapitalization: TextCapitalization.words,
                      controller: _label,
                      decoration: const InputDecoration(
                        label: Text('Category Name'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _budget,
                      decoration: const InputDecoration(
                        prefixText: '\$',
                        label: Text('Monthly Budget'),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(actionButtonLabel),
                  ),
                  if (widget.initialCategory != null)
                    TextButton(
                      onPressed: () {
                        widget.onRemove(widget.initialCategory!);
                        Navigator.pop(context);
                      },
                      child: const Text('Remove'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
