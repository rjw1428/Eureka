import 'dart:async';

import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/screens/login.dart';
import 'package:expense_tracker/services/account_link.service.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/services/expense.service.dart';
import 'package:expense_tracker/widgets/app_bar_action_menu.dart';
import 'package:expense_tracker/widgets/bar_chart.dart';
import 'package:expense_tracker/widgets/expense_form.dart';
import 'package:expense_tracker/widgets/expenses_list.dart';
import 'package:expense_tracker/widgets/filter_row.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:expense_tracker/widgets/time_row.dart';
import 'package:expense_tracker/widgets/total_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: AuthService().hasUser$,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Loading();
        } else if (snapshot.hasError) {
          return Center(
            child: Column(children: [
              const Text('ERROR'),
              Text(
                snapshot.error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          );
        } else if (snapshot.hasData && snapshot.data!) {
          return const TransactionScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _TransactionScreenState();
  }
}

class _TransactionScreenState extends State<TransactionScreen> {
  List<ExpenseWithCategoryData> _expenses = [];
  List<CategoryDataWithId> _categoryConfigs = []; // All configs
  List<CategoryDataWithId> _categoryOptions = []; // filtered list of configs by what's being using
  List<String> _filterList = []; // All available category ids for given expense list
  final _selectedFilters =
      StreamController<List<String>?>.broadcast(); // Only selected category ids
  DateTime _selectedDate = DateTime.now();

  void _openAddExpenseOverlay([ExpenseWithCategoryData? expense]) {
    HapticFeedback.selectionClick();
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

  void _addExpense(Expense expense) async {
    final resp = await ExpenseService().addExpense(expense);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(resp == null ? 'An error occurred while adding expense' : 'Expense added!'),
        ),
      );
    }
  }

  void _updateExpense(Expense expense) {
    final previousExpense = _expenses.firstWhere((e) => e.id == expense.id);

    ExpenseService().updateExpense(expense, previousExpense);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 3),
        content: Text('Expense updated!'),
      ),
    );
  }

  void _removeExpense(ExpenseWithCategoryData expense) async {
    ScaffoldMessenger.of(context).clearSnackBars();

    ExpenseService().remove(expense);

    final title = expense.title;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('Expense for $title deleted!'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _addExpense(expense),
          ),
        ),
      );
    }
  }

  void _filterExpenses(List<String> selection) {
    _selectedFilters.sink.add(selection);
  }

  void _setTimeRange(DateTime date) {
    setState(() => _selectedDate = date);
  }

  void linkRequestNotification() {
    AuthService()
        .expenseUser$
        .where((user) => user != null && user.notification != null)
        .doOnDone(() => print('notification listener closed'))
        .doOnError((e, s) => print('ohShit: notification listener errored ${e.toString()}'))
        .listen((user) async {
      final notification = user.notification!;
      if (notification.type == 'pendingRequest') {
        final request =
            await AccountLinkService().getPendingRequest(notification.data!['requestId']);
        showDialogNotification(
          'Link Account',
          Text(
              '''User ${request.requestingUserEmail} is requesting to link accounts. This will mean that both your expenses and their expenses will appear on your tracker. It also means that by accepting their request, they will hold a primary account will set budgeting rules for both your accounts.'''),
          context,
          TextButton(
            onPressed: () async {
              await AccountLinkService().acceptLinkRequest(request, user.id);
              Navigator.pop(context);
              // Accepting requeries the ledger with the new ID,
              // but permissions are not valid yet,
              // Call this and to reload the data

              // UPDATE: now that this is async and we await
              // the acceptLinkRequest change, maybe this isn't needed
              _setTimeRange(_selectedDate);
            },
            child: const Text('Accept'),
          ),
          TextButton(
            onPressed: () {
              AccountLinkService().rejectLinRequest(request);
              Navigator.pop(context);
            },
            child: const Text('Reject'),
          ),
        );
        return;
      }
      // If a secondary user unlinks from a primary user
      if (notification.type == 'primaryUnlink') {
        final String sourceEmail = notification.data!['email'];

        showDialogNotification(
          'Account Unlinked',
          Text('$sourceEmail has unlinked there account from your ledger.'),
          context,
        );
        await AccountLinkService().clearNotification(user.id);
        return;
      }

      // If a secondary user unlinks from a primary user
      if (notification.type == 'secondaryUnlink') {
        final String sourceEmail = notification.data!['email'];

        showDialogNotification(
          'Account Unlinked',
          Text('$sourceEmail has unlinked you account from there ledger.'),
          context,
        );
        await AccountLinkService().clearNotification(user.id);
        return;
      }
    });
  }

  @override
  void initState() {
    linkRequestNotification();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(APP_TITLE),
        actions: const [
          AppBarActionMenu(),
        ],
      ),
      body: StreamBuilder<Map<String, List<dynamic>>>(
        stream:
            AuthService().expenseUser$.takeUntil(AuthService().userLoggedOut$).exhaustMap((user) {
          print("LEDGER ID: ${user.ledgerId}");
          return CombineLatestStream.combine3(
              ExpenseService().getExpenseStream(user.ledgerId, _selectedDate),
              CategoriesService().categoryStream$,
              _selectedFilters.stream.startWith(null), (expenses, categories, selection) {
            final List distinctCategoryIds = Set.from(expenses.map((el) => el.categoryId)).toList();
            return Map.from({
              'expenses': expenses,
              'categories': categories,
              'selection': selection ?? distinctCategoryIds,
              'user': [user],
            });
          });
        }),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Loading();
          }

          _categoryConfigs = snapshot.data!['categories']!.map((el) {
            return el as CategoryDataWithId;
          }).toList();

          final ExpenseUser _user = snapshot.data!['user']![0];
          _expenses = snapshot.data!['expenses']!.map((exp) {
            final e = exp as Expense;
            final CategoryDataWithId category = _categoryConfigs.firstWhere((cat) {
              return cat.id == e.categoryId;
            });
            // print(_user.id);
            // print(_user.linkedAccounts);
            // print(_user.archivedLinkedAccounts);
            return ExpenseWithCategoryData.fromJson({...e.toJson(), 'category': category.toJson()});
          }).toList();

          final Set<String> distinctCategoryIds = Set.from(
            _expenses.map((el) => el.categoryId),
          );

          _categoryOptions =
              _categoryConfigs.where((config) => distinctCategoryIds.contains(config.id)).toList();

          final selectedIds = snapshot.data!['selection'];

          _filterList = selectedIds == null
              ? distinctCategoryIds.toList()
              : distinctCategoryIds.toList().where((id) => selectedIds.contains(id)).toList();

          final isAllSelected = (selectedIds?.length ?? 0) == distinctCategoryIds.length;

          final double totalExpenses = _expenses
              .where((expense) => _filterList.contains(expense.categoryId))
              .fold(0, (sum, exp) => exp.amount + sum);

          final double? totalBudget = isAllSelected
              ? _categoryConfigs
                  .where((config) => !config.deleted)
                  .fold(0, (sum, config) => sum! + config.budget)
              : null;

          Widget listContent(List<ExpenseWithCategoryData> expenses) {
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
            child: TimeRow(
              onTimeSelect: _setTimeRange,
              initialTime: _user.initialized,
            ),
          );

          Widget columnOrientationLayout(List<ExpenseWithCategoryData> expenses) {
            return Column(
              children: [
                timeFilter,
                categoryFilter,
                TotalRow(
                  sum: totalExpenses,
                  totalBudget: totalBudget,
                ),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    screenWidth: MediaQuery.of(context).size.width,
                    expenses: expenses,
                    selectedFilters: _filterList,
                    budgetConfigs: _categoryConfigs,
                  ),
                ),
                Expanded(child: listContent(expenses))
              ],
            );
          }

          Widget rowOrientationLayout(List<ExpenseWithCategoryData> expenses) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TotalRow(
                        sum: totalExpenses,
                        totalBudget: totalBudget,
                      ),
                      Expanded(
                        child: BarChart(
                          screenWidth: MediaQuery.of(context).size.width / 2,
                          expenses: expenses,
                          selectedFilters: _filterList,
                          budgetConfigs: _categoryConfigs,
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
                  ? columnOrientationLayout(_expenses)
                  : rowOrientationLayout(_expenses);
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
