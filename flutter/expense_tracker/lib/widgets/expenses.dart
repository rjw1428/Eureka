import 'package:expense_tracker/constants/categories.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/services/expense.service.dart';
import 'package:expense_tracker/widgets/filter_row.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/widgets/chart.dart';
import 'package:expense_tracker/widgets/expense_form.dart';
import 'package:flutter/material.dart';

class Expenses extends StatefulWidget {
  const Expenses({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ExpensesState();
  }
}

class _ExpensesState extends State<Expenses> {
  final List<Expense> _registeredExpenses = ExpenseService().getExpenses();
  final CategoryConfig categoryConfig = CategoriesService().getCategories();
  List<CategoryDataWithId> _categoryOptions = [];
  List<Category> _filterList = [];

  void _openAddExpenseOverlay([Expense? expense]) {
    showModalBottomSheet(
        useSafeArea: true,
        isScrollControlled: true,
        context: context,
        builder: (ctx) {
          return ExpenseForm(
            onSubmit: expense == null ? _addExpense : _updateExpense,
            initialExpense: expense,
            onRemove: _removeExpense,
          );
        });
  }

  void _addExpense(Expense expense, [int index = 0]) {
    setState(() {
      if (!_filterList.contains(expense.category)) {
        _filterList.add(expense.category);
      }
      _registeredExpenses.insert(index, expense);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 3),
        content: Text('Expense added!'),
      ),
    );
  }

  void _updateExpense(Expense expense) {
    final previousExpense = _registeredExpenses.firstWhere((e) => e.id == expense.id);
    final index = _registeredExpenses.map((e) => e.id).toList().indexOf(expense.id);
    setState(() {
      _registeredExpenses[index] = expense;

      final stillHasCategory = Set.from(_registeredExpenses.map((exp) => exp.category))
          .contains(previousExpense.category);

      if (!stillHasCategory) {
        _filterList.remove(previousExpense.category);
      }

      if (!_filterList.contains(expense.category)) {
        _filterList.add(expense.category);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 3),
        content: Text('Expense updated!'),
      ),
    );
  }

  void _removeExpense(Expense expense) {
    ScaffoldMessenger.of(context).clearSnackBars();

    final index = _registeredExpenses.indexOf(expense);
    setState(() {
      _registeredExpenses.remove(expense);
      if (!Set.from(_registeredExpenses.map((exp) => exp.category)).contains(expense.category)) {
        _filterList.remove(expense.category);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('Expense for ${expense.title}  deleted!'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _addExpense(expense, index),
        ),
      ),
    );
  }

  void _filterExpenses(List<Category> selection) {
    setState(() => _filterList = selection);
  }

  @override
  initState() {
    final Set<Category> distinctCategoryIds = Set.from(
      _registeredExpenses.map((el) => el.category),
    );
    _categoryOptions = distinctCategoryIds.map((c) {
      final config = categoryConfig[c]!;
      return CategoryDataWithId(
        budget: config.budget,
        icon: config.icon,
        label: config.label,
        id: c,
      );
    }).toList();
    _filterList = distinctCategoryIds.toList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Set<Category> distinctCategoryIds = Set.from(
      _registeredExpenses.map((el) => el.category),
    );
    _categoryOptions = distinctCategoryIds.map((c) {
      final config = categoryConfig[c]!;
      return CategoryDataWithId(
        budget: config.budget,
        icon: config.icon,
        label: config.label,
        id: c,
      );
    }).toList();

    Widget listContent = ExpenseList(
      list: _registeredExpenses,
      onRemove: _removeExpense,
      onEdit: _openAddExpenseOverlay,
      filters: _filterList,
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          PopupMenuButton(
            tooltip: 'Menu',
            position: PopupMenuPosition.under,
            onSelected: (value) {
              if (value == "SETTINGS") {
                print(value);
                return;
              }
              if (value == "HELP") {
                print(value);
                return;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: "SETTINGS",
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      Padding(padding: EdgeInsets.only(left: 8), child: Text('Settings'))
                    ],
                  )),
              const PopupMenuItem(
                  value: "HELP",
                  child: Row(
                    children: [
                      Icon(Icons.help),
                      Padding(padding: EdgeInsets.only(left: 8), child: Text('Help'))
                    ],
                  )),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        return constraints.maxWidth < 600
            ? Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Chart(
                      expenses: _registeredExpenses,
                      selectedFilters: _filterList,
                    ),
                  ),
                  FilterRow(
                    options: _categoryOptions,
                    onFilter: _filterExpenses,
                    selectedFilters: _filterList,
                  ),
                  Expanded(child: listContent)
                ],
              )
            : Row(
                children: [
                  Expanded(
                      child: Chart(
                    expenses: _registeredExpenses,
                    selectedFilters: _filterList,
                  )),
                  Expanded(
                      child: Column(
                    children: [
                      FilterRow(
                        options: _categoryOptions,
                        onFilter: _filterExpenses,
                        selectedFilters: _filterList,
                      ),
                      Expanded(child: listContent)
                    ],
                  ))
                ],
              );
      }),
      floatingActionButton: IconButton.filled(
        color: Theme.of(context).cardTheme.color,
        onPressed: _openAddExpenseOverlay,
        icon: Icon(
          Icons.add,
          color: Theme.of(context).appBarTheme.foregroundColor,
        ),
      ),
    );
  }
}

class ExpenseList extends StatelessWidget {
  const ExpenseList({
    super.key,
    required this.list,
    required this.onRemove,
    required this.onEdit,
    required this.filters,
  });

  final List<Expense> list;
  final void Function(Expense) onRemove;
  final void Function(Expense) onEdit;
  final List<Category> filters;

  @override
  Widget build(BuildContext context) {
    final List<Expense> filteredList =
        list.where((expense) => filters.contains(expense.category)).toList();

    return filteredList.isEmpty
        ? const Center(child: Text('No expenses found 💩'))
        : ListView.builder(
            itemCount: filteredList.length,
            itemBuilder: (ctx, i) {
              return kIsWeb
                  ? ExpenseItem(
                      expense: filteredList[i],
                      onEdit: onEdit,
                    )
                  : GestureDetector(
                      onLongPress: () => onEdit(filteredList[i]),
                      child: ExpenseItem(
                        expense: filteredList[i],
                        onEdit: (e) => {},
                      ),
                    );
              // return Dismissible(
              //   key: ValueKey(list[i].id),
              //   onDismissed: (direction) => onRemove(list[i]),
              //   child: ExpenseItem(expense: list[i]),
              // );
            },
          );
  }
}

class ExpenseItem extends StatelessWidget {
  const ExpenseItem({
    super.key,
    required this.expense,
    required this.onEdit,
  });

  final Expense expense;
  final void Function(Expense) onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (kIsWeb)
                    IconButton(onPressed: () => onEdit(expense), icon: const Icon(Icons.edit)),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(expense.icon),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(expense.formattedDate, style: Theme.of(context).textTheme.titleSmall),
                      SizedBox(
                        width: constraints.maxWidth - 200,
                        child: Text(expense.title),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '\$${expense.amount.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
