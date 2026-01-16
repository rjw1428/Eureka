import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/category_form.provider.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:expense_tracker/widgets/suggestions_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseForm extends ConsumerStatefulWidget {
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
  ConsumerState<ExpenseForm> createState() {
    return _ExpenseFormState();
  }
}

class _ExpenseFormState extends ConsumerState<ExpenseForm> {
  String formTitle = 'Add Expense';
  String actionButtonLabel = 'Save';
  final _note = TextEditingController();
  final _amount = TextEditingController();
  final _amountFocusNode = FocusNode();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  DateTime? _hideUntilDate;
  bool _isAmortized = false;
  final _amortizationMonthsController = TextEditingController(text: '2');
  bool _isEditingAmortized = false;
  bool _notify = false;
  bool _isHidingExpense = false;

  void _showDatePicker() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365));
    final date = await showDatePicker(context: context, firstDate: firstDate, lastDate: now);

    if (date == null) {
      return;
    }
    // If user selects current date, then make sure the time part of the date is no
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      setState(() => _selectedDate = now);
      return;
    }

    final endOfDayDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
    // Otherwise, set the time part to the ned of the day
    setState(() => _selectedDate = endOfDayDate);
  }

  void _showHideUntilDatePicker() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365));
    final date = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date == null) {
      return;
    }

    final endOfDayDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
    // Otherwise, set the time part to the ned of the day
    setState(() => _hideUntilDate = endOfDayDate);
  }

  void _submit(ExpenseUser user, CategoryDataWithIdAndDelta? spendCategory) {
    HapticFeedback.selectionClick();
    _evaluateAmountExpression();
    final enteredAmount = double.tryParse(_amount.text);
    if (enteredAmount == null || enteredAmount == 0) {
      showDialogNotification('Invalid Amount',
          Text(enteredAmount == 0 ? 'Make sure the amount is not 0' : 'Make sure the amount is a number'), context);
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
      hideUntil: _hideUntilDate,
      notify: _notify,
    );

    // Case 1: Updating an existing expense. Amortization settings are locked.
    if (widget.initialExpense != null) {
      newExpense.updateId(widget.initialExpense!.id!);
      widget.onSubmit(newExpense);
    }
    // Case 2: Adding a new amortized expense.
    else if (_isAmortized) {
      final months = int.tryParse(_amortizationMonthsController.text);
      if (months == null || months < 2 || months > 24) {
        showDialogNotification(
          'Invalid Amortization Months',
          const Text('Amortization must be between 2 and 24 months.'),
          context,
        );
        return;
      }
      final tempAmortization = AmortizationDetails(
        groupId: "",
        over: months,
        index: 0,
      );
      widget.onSubmit(newExpense.copyWith(amortized: tempAmortization));
    }
    // Case 3: Adding a new regular expense.
    else {
      widget.onSubmit(newExpense);
    }

    if (spendCategory != null) {
      final newDelta = spendCategory.delta - newExpense.amount;
      // If we go from underspent to overspent, notify
      if (spendCategory.delta >= 0 && newDelta < 0) {
        FirebaseFunctions.instance.httpsCallable("sendBudgetNotification").call({
          'userIds': user.linkedAccounts.map((account) => account.id).toList(),
          'amount': newExpense.amount,
          'categoryLabel': spendCategory.label,
          'notificationType': 'overspendingIndividualBudget'
        });
      }
    }

    Navigator.pop(context);
    return;
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    _amountFocusNode.dispose();
    _amortizationMonthsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    if (widget.initialExpense != null) {
      _selectedCategory = widget.initialExpense!.categoryId;
      _amount.text = widget.initialExpense!.amount.toStringAsFixed(2);
      _note.text = widget.initialExpense!.note ?? '';
      _selectedDate = widget.initialExpense!.date;
      _hideUntilDate = widget.initialExpense!.hideUntil;
      formTitle = 'Edit Expense';
      actionButtonLabel = 'Update';

      if (widget.initialExpense!.amortized != null) {
        _isAmortized = true;
        _isEditingAmortized = true;
        _amortizationMonthsController.text = widget.initialExpense!.amortized!.over.toString();
      }
      _isHidingExpense = widget.initialExpense!.hideUntil != null;
    }
    super.initState();
    _amountFocusNode.addListener(_evaluateAmountExpression);
  }

  void _evaluateAmountExpression() {
    String text = _amount.text;
    if (text.contains('-')) {
      var parts = text.split('-');
      var nums = parts.map((el) => double.tryParse(el)).toList();
      var result = nums.slice(1).fold(nums[0] ?? 0, (result, double? num) => result - (num ?? 0));
      _amount.text = result.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final categoryConfig = ref.watch(activeBudgetCategoriesWithSpend).valueOrNull ?? [];
    final user = ref.read(userProvider).valueOrNull!;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardSpace + 16),
        child: Column(
          children: [
            Text(
              formTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            // Need to improve, as initial load would be empty and this shouldn't show unless there are actually no categories
            // if (categoryConfig.isEmpty)
            //   const Text(
            //     'No budget categories found. Navigate to the Settings menu in the upper right corner and configure your budget categories.',
            //   ),
            Row(children: [
              Expanded(
                child: DropdownButton(
                  hint: const Text('Category'),
                  isExpanded: true,
                  value: _selectedCategory,
                  items: categoryConfig
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
                              Text(
                                "${category.delta >= 0 ? 'Remaining' : 'Over'} ${currency.format(category.delta)}",
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          )))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value),
                ),
              ),
              IconButton(
                onPressed: () => openAddCategoryOverlay(context, user.ledgerId),
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
                    focusNode: _amountFocusNode,
                    decoration: const InputDecoration(
                      prefixText: '\$',
                      label: Text('Amount'),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      TextButton.icon(
                        onPressed: _showDatePicker,
                        icon: const Icon(Icons.calendar_month),
                        iconAlignment: IconAlignment.start,
                        label: Text(
                          'Date Occurred: ${dateFormatter.format(_selectedDate)}',
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
            if (_selectedCategory != null)
              Align(
                alignment: Alignment.centerLeft,
                child: SuggestionsRow(
                  onClick: (suggestion) => _note.text = '${_note.text} $suggestion',
                  categoryId: _selectedCategory!,
                ),
              ),
            ExpansionTile(
              title: const Text('Advanced'),
              controlAffinity: ListTileControlAffinity.leading,
              children: [
                SwitchListTile(
                  title: const Text('Notify linked users'),
                  subtitle: const Text('Send a push notification to linked users about this expense.'),
                  value: _notify,
                  onChanged: (bool value) {
                    setState(() {
                      _notify = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Amortize expense'),
                  subtitle: const Text('Split this expense over multiple months.'),
                  value: _isAmortized,
                  onChanged: _isEditingAmortized
                      ? null
                      : (bool value) {
                          setState(() {
                            _isAmortized = value;
                          });
                        },
                ),
                if (_isAmortized)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      controller: _amortizationMonthsController,
                      decoration: const InputDecoration(
                        label: Text('Number of Months (2-24)'),
                        helperText: 'The total amount will be divided over these months.',
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !_isEditingAmortized,
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Hide until date'),
                  subtitle: const Text('Hide this expense from the main list until a specific date.'),
                  value: _isHidingExpense,
                  onChanged: (bool value) {
                    setState(() {
                      _isHidingExpense = value;
                      if (!value) {
                        _hideUntilDate = null; // Clear date if hiding is turned off
                      }
                    });
                  },
                ),
                if (_isHidingExpense) // Conditionally show the date picker and clear button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _showHideUntilDatePicker,
                            icon: const Icon(Icons.calendar_month),
                            iconAlignment: IconAlignment.start,
                            label: Text(
                              'Date: ${_hideUntilDate != null ? dateFormatter.format(_hideUntilDate!) : 'Select Date'}',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _hideUntilDate = null),
                        ),
                        IconButton(
                          icon: const Icon(Icons.help_outline_rounded),
                          onPressed: () => showDialog<String>(
                            context: context,
                            builder: (BuildContext context) => Dialog(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Center(
                                        child: Text(
                                      'Hide Until',
                                      style: Theme.of(context).textTheme.headlineMedium,
                                    )),
                                    const SizedBox(height: 15),
                                    const Text(
                                        'Let\'s say it\'s your significant other\'s birthday and you want to get them a gift, and actually be ahead of the game for once.'),
                                    const SizedBox(height: 15),
                                    const Text(
                                        'This option allows you to set when it will actually show up in the expense list. The total and summary will still update to reflect the amout spent, but the surprise won\'t be ruined!'),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Center(
                                      child: TextButton(
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Close'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (categoryConfig.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => _submit(user, categoryConfig.firstWhereOrNull((c) => c.id == _selectedCategory)),
                    child: Text(actionButtonLabel),
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
  }
}
