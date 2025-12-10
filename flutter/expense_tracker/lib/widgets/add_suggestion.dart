import 'dart:io';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuggestionFom extends ConsumerStatefulWidget {
  const SuggestionFom({
    super.key,
    required this.onSubmit,
  });

  final void Function(String, String) onSubmit;

  @override
  ConsumerState<SuggestionFom> createState() {
    return _SuggestionFormState();
  }
}

class _SuggestionFormState extends ConsumerState<SuggestionFom> {
  String formTitle = 'Add Note Shortcut';
  String actionButtonLabel = 'Save';
  final _label = TextEditingController();
  String? _selectedCategory;

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
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))],
              ));
    } else {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))],
              ));
    }
  }

  void _submit() {
    final enteredText = _label.text.trim();

    if (_selectedCategory == null) {
      _showDialog(
        "Invalid Shortcut text",
        "A category is required",
      );
    }
    if (enteredText.isEmpty) {
      _showDialog(
        'Invalid Shortcut text',
        'Value is required',
      );
      return;
    }

    widget.onSubmit(enteredText, _selectedCategory!);

    Navigator.pop(context);
    return;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(activeBudgetCategoriesWithSpend).valueOrNull ?? [];
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
            DropdownButton(
              hint: const Text('Category'),
              isExpanded: true,
              value: _selectedCategory,
              items: categories
                  .map((category) => DropdownMenuItem(
                      value: category.id,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(category.iconData),
                              ),
                              Text(category.label),
                            ],
                          ),
                        ],
                      )))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              textCapitalization: TextCapitalization.words,
              controller: _label,
              decoration: const InputDecoration(
                label: Text('Note Shortcut'),
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
