import 'package:expense_tracker/models/expense.dart';
import 'package:flutter/material.dart';

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key, required this.onSubmit});

  final void Function(Expense) onSubmit;

  @override
  State<StatefulWidget> createState() {
    return _ExpenseFormState();
  }
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _note = TextEditingController();
  final _amount = TextEditingController();
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  void _showDatePicker() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365));
    final date = await showDatePicker(context: context, firstDate: firstDate, lastDate: now);
    setState(() => _selectedDate = date ?? _selectedDate);
  }

  void _submit() {
    final enteredAmount = double.tryParse(_amount.text);
    if (enteredAmount == null || enteredAmount == 0) {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Invalid Amount'),
            content: Text(enteredAmount == 0
                ? 'Make sure the amount is not 0'
                : 'Make sure the amount is a number'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))],
          );
        },
      );
      return;
    }

    if (_selectedCategory == null) {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Invalid Category'),
            content: const Text('Make sure to select a category'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))],
          );
        },
      );
      return;
    }

    final newExpense = Expense(
        amount: enteredAmount,
        note: _note.text.trim().isNotEmpty ? _note.text : null,
        date: _selectedDate,
        category: _selectedCategory!);

    widget.onSubmit(newExpense);
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Column(
        children: [
          Text('Add Expense', style: Theme.of(context).textTheme.titleLarge),
          Row(children: [
            Expanded(
              child: DropdownButton(
                hint: const Text('Category'),
                isExpanded: true,
                value: _selectedCategory,
                items: categories.entries
                    .map((category) => DropdownMenuItem(
                          value: category.key,
                          child: Text(category.value.label),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
            ),
          ]),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  decoration: const InputDecoration(
                    prefixText: '\$',
                    label: Text('Amount'),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Date Occurred: ${dateFormatter.format(_selectedDate)}',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: _showDatePicker,
                      ),
                    ),
                  ],
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
                    controller: _note,
                    maxLength: 50,
                    decoration: const InputDecoration(label: Text('Notes'), helperText: 'Optional'),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
