import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/services/category_form.provider.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({
    super.key,
    required this.onSubmit,
    required this.onRemove,
    this.initialExpense,
  });

  final void Function(Expense) onSubmit;
  final void Function(ExpenseWithCategoryData) onRemove;
  final ExpenseWithCategoryData? initialExpense;

  @override
  State<StatefulWidget> createState() {
    return _ExpenseFormState();
  }
}

class _ExpenseFormState extends State<ExpenseForm> {
  String formTitle = 'Add Expense';
  String actionButtonLabel = 'Save';
  final _note = TextEditingController();
  final _amount = TextEditingController();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  void _showDatePicker() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365));
    final date = await showDatePicker(context: context, firstDate: firstDate, lastDate: now);
    setState(() => _selectedDate = date ?? _selectedDate);
  }

  void _submit() {
    HapticFeedback.selectionClick();
    final enteredAmount = double.tryParse(_amount.text);
    if (enteredAmount == null || enteredAmount == 0) {
      showDialogNotification(
          'Invalid Amount',
          Text(enteredAmount == 0
              ? 'Make sure the amount is not 0'
              : 'Make sure the amount is a number'),
          context);
      return;
    }

    if (_selectedCategory == null) {
      showDialogNotification(
        'Invalid Category',
        const Text('Make sure to select a category'),
        context,
      );
      return;
    }

    final newExpense = Expense(
      amount: enteredAmount,
      note: _note.text.trim().isNotEmpty ? _note.text : null,
      date: _selectedDate,
      categoryId: _selectedCategory!,
    );

    if (widget.initialExpense != null) {
      newExpense.updateId(widget.initialExpense!.id!);
      widget.onSubmit(newExpense);
    } else {
      widget.onSubmit(newExpense);
    }

    Navigator.pop(context);
    return;
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  void initState() {
    if (widget.initialExpense != null) {
      _selectedCategory = widget.initialExpense!.categoryId;
      _amount.text = widget.initialExpense!.amount.toString();
      _note.text = widget.initialExpense!.note ?? '';
      _selectedDate = widget.initialExpense!.date;
      formTitle = 'Edit Expense';
      actionButtonLabel = 'Update';
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;

    return StreamBuilder(
        stream: CategoriesService().categoryStream$,
        builder: (context, snapshot) {
          final categoryConfig = snapshot.data ?? [];
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardSpace + 16),
              child: Column(
                children: [
                  Text(
                    formTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (categoryConfig.isEmpty)
                    const Text(
                      'No budget categories found. Navigate to the Settings menu in the upper right corner and configure your budget categories.',
                    ),
                  Row(children: [
                    Expanded(
                      child: DropdownButton(
                        hint: const Text('Category'),
                        isExpanded: true,
                        value: _selectedCategory,
                        items: categoryConfig
                            .where(
                                (category) => !category.deleted || category.id == _selectedCategory)
                            .map((category) => DropdownMenuItem(
                                value: category.id,
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Icon(category.iconData),
                                    ),
                                    Text(category.label),
                                  ],
                                )))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedCategory = value),
                      ),
                    ),
                    IconButton(
                      onPressed: () => openAddCategoryOverlay(context),
                      icon: const Icon(
                        Icons.playlist_add,
                      ),
                    )
                  ]),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _amount,
                          decoration: const InputDecoration(
                            prefixText: '\$',
                            label: Text('Amount'),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(signed: true, decimal: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextButton.icon(
                          onPressed: _showDatePicker,
                          icon: const Icon(Icons.calendar_month),
                          iconAlignment: IconAlignment.start,
                          label: Text(
                            'Date Occurred: ${dateFormatter.format(_selectedDate)}',
                          ),
                        ),
                      )
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: _note,
                            maxLength: 50,
                            decoration: const InputDecoration(
                              label: Text('Notes'),
                              helperText: 'Optional',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (categoryConfig.isNotEmpty)
                        ElevatedButton(
                          onPressed: _submit,
                          child: Text(actionButtonLabel),
                        ),
                      if (widget.initialExpense != null)
                        TextButton(
                          onPressed: () {
                            widget.onRemove(widget.initialExpense!);
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                          },
                          child: const Text('Remove'),
                        ),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
  }
}
