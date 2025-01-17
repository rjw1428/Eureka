import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/screens/login.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/services/expense.service.dart';
import 'package:expense_tracker/widgets/app_bar_action_menu.dart';
import 'package:expense_tracker/widgets/chart.dart';
import 'package:expense_tracker/widgets/expense_form.dart';
import 'package:expense_tracker/widgets/expenses_list.dart';
import 'package:expense_tracker/widgets/filter_row.dart';
import 'package:expense_tracker/widgets/time_row.dart';
import 'package:expense_tracker/widgets/total_row.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('PENDING');
        } else if (snapshot.hasError) {
          return const Center(child: Text('ERROR'));
        } else if (snapshot.hasData) {
          return TransactionScreen(userId: snapshot.data!.uid);
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key, required this.userId});

  final String userId;

  @override
  State<StatefulWidget> createState() {
    return _TransactionScreenState();
  }
}

class _TransactionScreenState extends State<TransactionScreen> {
  CategoryConfig categoryConfigs = [];
  List<Expense> _registeredExpenses = [];
  List<CategoryDataWithId> _categoryOptions = [];
  List<String> _filterList = [];
  DateTime _selectedDate = DateTime.now();

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
      },
    );
  }

  void _addExpense(Expense expense, [int index = 0]) async {
    // setState(() {
    //   if (!_filterList.contains(expense.category)) {
    //     _filterList.add(expense.category);
    //   }
    //   _registeredExpenses.insert(index, expense);
    //   ExpenseService().addExpense(expense, index);
    // });

    final resp = await ExpenseService().addExpense(expense, index);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(resp == null ? 'An error occurred while adding expense' : 'Expense added!'),
      ),
    );
  }

  void _updateExpense(Expense expense) {
    final previousExpense = _registeredExpenses.firstWhere((e) => e.id == expense.id);
    // setState(() {
    //   ExpenseService().updateExpense(expense);

    //   final stillHasCategory = Set.from(_registeredExpenses.map((exp) => exp.category))
    //       .contains(previousExpense.category);

    //   if (!stillHasCategory) {
    //     _filterList.remove(previousExpense.category);
    //   }

    //   if (!_filterList.contains(expense.category)) {
    //     _filterList.add(expense.category);
    //   }
    // });

    ExpenseService().updateExpense(expense, previousExpense);

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
    ExpenseService().remove(expense);

    setState(() {
      // if (!Set.from(_registeredExpenses.map((exp) => exp.category)).contains(expense.category)) {
      //   _filterList.remove(expense.category);
      // }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('Expense for ${expense.title} deleted!'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _addExpense(expense, index),
        ),
      ),
    );
  }

  void _filterExpenses(List<String> selection) {
    setState(() => _filterList = selection);
  }

  void _setTimeRange(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: const [
          AppBarActionMenu(),
        ],
      ),
      body: StreamBuilder<List<Expense>>(
        stream: ExpenseService().getExpenseStream(_selectedDate),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Text('Loading...');
          }
          print('UserId: ${widget.userId} - ${snapshot.data!.length}');

          categoryConfigs = CategoriesService().getCategories();

          _registeredExpenses = snapshot.data ?? [];

          final Set<String> distinctCategoryIds = Set.from(
            _registeredExpenses.map((el) => el.category),
          );
          _categoryOptions = distinctCategoryIds.map((c) {
            final config = categoryConfigs.firstWhere((con) => con.id == c);
            return CategoryDataWithId(
              budget: config.budget,
              icon: config.icon,
              label: config.label,
              id: c,
            );
          }).toList();
          _filterList = distinctCategoryIds.toList();

          final double totalExpenses = _registeredExpenses
              .where((expense) => _filterList.contains(expense.category))
              .fold(0, (sum, exp) => exp.amount + sum);
          print('TOTAL: $totalExpenses');

          Widget listContent(List<Expense> expenses) {
            return ExpenseList(
              list: expenses,
              onRemove: _removeExpense,
              onEdit: _openAddExpenseOverlay,
              filters: _filterList,
            );
          }

          Widget categoryFilter = FilterRow(
            options: _categoryOptions,
            onFilter: _filterExpenses,
            selectedFilters: _filterList,
          );

          Widget timeFilter = Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: TimeRow(onTimeSelect: _setTimeRange),
          );

          Widget columnOrientationLayout(List<Expense> expenses) {
            return Column(
              children: [
                timeFilter,
                categoryFilter,
                TotalRow(sum: totalExpenses),
                SizedBox(
                  height: 200,
                  child: Chart(
                    expenses: expenses,
                    selectedFilters: _filterList,
                  ),
                ),
                Expanded(child: listContent(expenses))
              ],
            );
          }

          Widget rowOrientationLayout(List<Expense> expenses) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TotalRow(sum: totalExpenses),
                      Expanded(
                        child: Chart(
                          expenses: expenses,
                          selectedFilters: _filterList,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      timeFilter,
                      categoryFilter,
                      Expanded(child: listContent(expenses)),
                    ],
                  ),
                )
              ],
            );
          }

          return LayoutBuilder(
            builder: (ctx, constraints) {
              return constraints.maxWidth < 600
                  ? columnOrientationLayout(snapshot.data ?? [])
                  : rowOrientationLayout(snapshot.data ?? []);
            },
          );
        },
      ),
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
