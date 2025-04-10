import 'dart:async';
import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/notification.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/home/expense_list/expense_list.dart';
import 'package:expense_tracker/services/account_link.service.dart';
import 'package:expense_tracker/widgets/app_bar_action_menu.dart';
import 'package:expense_tracker/screens/home/expense_list/bar_chart.dart';
import 'package:expense_tracker/widgets/expense_form.dart';
import 'package:expense_tracker/widgets/filter_row.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:expense_tracker/widgets/time_row.dart';
import 'package:expense_tracker/widgets/total_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key, required this.user});
  final ExpenseUser user;

  @override
  ConsumerState<ExpenseScreen> createState() {
    return _TransactionScreenState();
  }
}

class _TransactionScreenState extends ConsumerState<ExpenseScreen> {
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
    final resp = await ref.read(expenseModifierProvider.notifier).addExpense(expense);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(resp == null ? 'An error occurred while adding expense' : 'Expense added!'),
        ),
      );
    }
  }

  void _updateExpense(Expense expense) async {
    final currentExpenses = ref.read(expenseProvider).value ?? [];
    final previousExpense = currentExpenses.firstWhere((e) => e.id == expense.id);

    await ref.read(expenseModifierProvider.notifier).updateExpense(expense, previousExpense);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('Expense updated!'),
        ),
      );
    }
  }

  void _removeExpense(ExpenseWithCategoryData expense) async {
    ScaffoldMessenger.of(context).clearSnackBars();

    await ref.read(expenseModifierProvider.notifier).removeExpense(expense);

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

            // NOTE: THERE WAS AN OPERATION HERE TO REFRESH THE SCREEN
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

  void linkRequestNotificationListener() {
    final notification = widget.user.notification;
    if (notification != null) {
      if (notification.type == 'pendingRequest') {
        _handlePendingRequest(widget.user.id, notification);
      }
      // If a secondary user unlinks from a primary user
      if (notification.type == 'primaryUnlink') {
        _handlePrimaryUnlinkRequest(widget.user.id, notification);
      }

      // If a secondary user unlinks from a primary user
      if (notification.type == 'secondaryUnlink') {
        _handleSecondaryUnlinkRequest(widget.user.id, notification);
      }
    }
  }

  Widget listContent(List<ExpenseWithCategoryData> expenses) {
    return ExpenseList(
      list: expenses,
      onRemove: _removeExpense,
      onEdit: _openAddExpenseOverlay,
    );
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), linkRequestNotificationListener);
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseUser? user = ref.watch(userProvider).valueOrNull;
    List<CategoryDataWithId> categoryConfigs = ref.watch(budgetProvider).value ?? [];
    final selectedCategories = ref.watch(selectedFiltersProvider);
    final defaultCategories = ref.watch(defaultFilterOptions);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(APP_TITLE),
        actions: const [
          AppBarActionMenu(),
        ],
      ),
      body: ref.watch(expenseProvider).when(
          error: (error, stack) => Text('Oh Shit: ${error.toString()}'),
          loading: () => const Loading(),
          data: (expenses) {
            final Set<String> usedCategoryIds = Set.from(
              expenses.map((el) => el.categoryId),
            );

            final isAllSelected = selectedCategories.length == usedCategoryIds.length;

            final double totalExpenses = expenses
                .where((expense) => selectedCategories.contains(expense.categoryId))
                .fold(0, (sum, exp) => exp.amount + sum);

            final double? totalBudget = isAllSelected
                ? categoryConfigs
                    .where((config) => !config.deleted)
                    .fold(0, (sum, config) => sum! + config.budget)
                : null;

            Widget categoryFilter = FilterRow(
              options: defaultCategories,
            );

            Widget timeFilter = Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: TimeRow(
                initialTime: user!.initialized,
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
                      budgetConfigs: categoryConfigs,
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
                            budgetConfigs: categoryConfigs,
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
                    ? columnOrientationLayout(expenses)
                    : rowOrientationLayout(expenses);
              },
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
