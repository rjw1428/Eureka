import 'dart:async';

import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/notification.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/home/expense_list/expense_list.dart';
import 'package:expense_tracker/services/account_link.service.dart';
import 'package:expense_tracker/services/expense.service.dart';
import 'package:expense_tracker/widgets/app_bar_action_menu.dart';
import 'package:expense_tracker/widgets/bar_chart.dart';
import 'package:expense_tracker/widgets/expense_form.dart';
import 'package:expense_tracker/widgets/filter_row.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:expense_tracker/widgets/time_row.dart';
import 'package:expense_tracker/widgets/total_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() {
    return _TransactionScreenState();
  }
}

class _TransactionScreenState extends ConsumerState<ExpenseScreen> {
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

  void _handlePendingRequest(String userId, AccountNotification notification) async {
    final request = await AccountLinkService().getPendingRequest(notification.data!['requestId']);
    if (mounted) {
      showDialogNotification(
        'Link Account',
        Text(
            '''User ${request.requestingUserEmail} is requesting to link accounts. This will mean that both your expenses and their expenses will appear on your tracker. It also means that by accepting their request, they will hold a primary account will set budgeting rules for both your accounts.'''),
        context,
        TextButton(
          onPressed: () async {
            await AccountLinkService().acceptLinkRequest(request, userId);
            if (mounted) {
              Navigator.pop(context);
            }
            // Accepting re-queries the ledger with the new ID,
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
    }
    return;
  }

  void _handlePrimaryUnlinkRequest(String userId, AccountNotification notification) async {
    final String sourceEmail = notification.data!['email'];

    showDialogNotification(
      'Account Unlinked',
      Text('$sourceEmail has unlinked there account from your ledger.'),
      context,
    );
    await AccountLinkService().clearNotification(userId);
    return;
  }

  void _handleSecondaryUnlinkRequest(String userId, AccountNotification notification) async {
    final String sourceEmail = notification.data!['email'];

    showDialogNotification(
      'Account Unlinked',
      Text('$sourceEmail has unlinked you account from there ledger.'),
      context,
    );
    await AccountLinkService().clearNotification(userId);
    return;
  }

  void linkRequestNotificationListener(ExpenseUser user) {
    final notification = user.notification;
    if (notification != null) {
      if (notification.type == 'pendingRequest') {
        _handlePendingRequest(user.id, notification);
      }
      // If a secondary user unlinks from a primary user
      if (notification.type == 'primaryUnlink') {
        _handlePrimaryUnlinkRequest(user.id, notification);
      }

      // If a secondary user unlinks from a primary user
      if (notification.type == 'secondaryUnlink') {
        _handleSecondaryUnlinkRequest(user.id, notification);
      }
    }
  }

  Widget listContent(List<ExpenseWithCategoryData> expenses) {
    return ExpenseList(
      list: expenses,
      onRemove: _removeExpense,
      onEdit: _openAddExpenseOverlay,
      filters: _filterList,
    );
  }

  @override
  Widget build(BuildContext context) {
    // final AsyncValue<ExpenseUser?> user$ = ref.watch(userProvider);
    final expenses$ = ref.watch(expenseProvider);
    final Set<String> distinctCategoryIds = Set.from(
      _expenses.map((el) => el.categoryId),
    );

    _categoryOptions =
        _categoryConfigs.where((config) => distinctCategoryIds.contains(config.id)).toList();

    final selectedIds = null; //snapshot.data!['selection'];

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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(APP_TITLE),
        actions: const [
          AppBarActionMenu(),
        ],
      ),
      body: expenses$.when(
        data: (expenses) {
          print("COMPONENT: ${expenses.length}");
          return listContent(expenses);
        },
        loading: () => const Loading(),
        error: (error, stackTrace) => Text('ERROR: ${error.toString()}'),
      ),

      // linkRequestNotificationListener(user);

      // Widget categoryFilter = FilterRow(
      //   options: _categoryOptions,
      //   onFilter: _filterExpenses,
      //   selectedFilters: _filterList,
      // );

      // Widget timeFilter = Padding(
      //   padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      //   child: TimeRow(
      //     onTimeSelect: _setTimeRange,
      //     initialTime: user.initialized,
      //   ),
      // );

      // Widget columnOrientationLayout(List<ExpenseWithCategoryData> expenses) {
      //   return Column(
      //     children: [
      //       timeFilter,
      //       categoryFilter,
      //       TotalRow(
      //         sum: totalExpenses,
      //         totalBudget: totalBudget,
      //       ),
      //       SizedBox(
      //         height: 200,
      //         child: BarChart(
      //           screenWidth: MediaQuery.of(context).size.width,
      //           expenses: expenses,
      //           selectedFilters: _filterList,
      //           budgetConfigs: _categoryConfigs,
      //         ),
      //       ),
      //       Expanded(child: listContent(expenses))
      //     ],
      //   );
      // }

      // Widget rowOrientationLayout(List<ExpenseWithCategoryData> expenses) {
      //   return Row(
      //     children: [
      //       Expanded(
      //         child: Column(
      //           children: [
      //             TotalRow(
      //               sum: totalExpenses,
      //               totalBudget: totalBudget,
      //             ),
      //             Expanded(
      //               child: BarChart(
      //                 screenWidth: MediaQuery.of(context).size.width / 2,
      //                 expenses: expenses,
      //                 selectedFilters: _filterList,
      //                 budgetConfigs: _categoryConfigs,
      //               ),
      //             ),
      //           ],
      //         ),
      //       ),
      //       Expanded(
      //         child: Column(
      //           children: [
      //             timeFilter,
      //             categoryFilter,
      //             Expanded(child: listContent(expenses)),
      //           ],
      //         ),
      //       )
      //     ],
      //   );
      // }

      // return LayoutBuilder(
      //   builder: (ctx, constraints) {
      //     return constraints.maxWidth < 600
      //         ? columnOrientationLayout(_expenses)
      //         : rowOrientationLayout(_expenses);
      //   },
      // );

      floatingActionButton: IconButton.filled(
        color: Theme.of(context).cardTheme.color,
        onPressed: _openAddExpenseOverlay,
        icon: Icon(
          Icons.add,
          color: Theme.of(context).appBarTheme.foregroundColor,
        ),
      ),
    );
    // StreamBuilder<Map<String, List<dynamic>>>(
    //   stream:
    //       AuthService().expenseUser$.takeUntil(AuthService().userLoggedOut$).exhaustMap((user) {
    //     print("LEDGER ID: ${user!.ledgerId}");
    //     return CombineLatestStream.combine3(
    //         ExpenseService().getExpenseStream(user.ledgerId, _selectedDate),
    //         CategoriesService().categoryStream$,
    //         _selectedFilters.stream.startWith(null), (expenses, categories, selection) {
    //       final List distinctCategoryIds = Set.from(expenses.map((el) => el.categoryId)).toList();
    //       return Map.from({
    //         'expenses': expenses,
    //         'categories': categories,
    //         'selection': selection ?? distinctCategoryIds,
    //         'user': [user],
    //       });
    //     });
    //   }),
    //   builder: (context, snapshot) {
    //     if (snapshot.hasError) {
    //       return Text(snapshot.error.toString());
    //     }
    //     if (!snapshot.hasData) {
    //       return const Loading();
    //     }

    //     _categoryConfigs = snapshot.data!['categories']!.map((el) {
    //       return el as CategoryDataWithId;
    //     }).toList();

    //     final ExpenseUser _user = snapshot.data!['user']![0];
    //     _expenses = snapshot.data!['expenses']!.map((exp) {
    //       final e = exp as Expense;
    //       final CategoryDataWithId category = _categoryConfigs.firstWhere((cat) {
    //         return cat.id == e.categoryId;
    //       });
    //       // print(_user.id);
    //       // print(_user.linkedAccounts);
    //       // print(_user.archivedLinkedAccounts);
    //       return ExpenseWithCategoryData.fromJson({...e.toJson(), 'category': category.toJson()});
    //     }).toList();

    // ),
  }
}
