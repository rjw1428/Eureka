import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:expense_tracker/providers/filtered_expenses_provider.dart';
import 'package:expense_tracker/services/local_storage.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const maskCharacter = '-';

class TotalRow extends ConsumerStatefulWidget {
  const TotalRow({super.key});

  @override
  ConsumerState<TotalRow> createState() => _TotalRowState();
}

class _TotalRowState extends ConsumerState<TotalRow> {
  bool showValues = LocalStorageService().showTotal;

  @override
  Widget build(BuildContext context) {
    final categoryConfigs = ref.watch(activeBudgetCategoryProvider).valueOrNull ?? [];
    final expenses = ref.watch(filteredExpensesProvider).valueOrNull ?? [];
    final List<String> usedCategoryIds = ref.watch(usedCategoryIdsProvider);
    final selectedCategories = ref.watch(selectedFiltersProvider) ?? usedCategoryIds.toList();

    print(usedCategoryIds.length);
    print(selectedCategories.length);
    final isAllSelected = ref.watch(areAllCategoriesSelectedProvider);

    final double totalExpenses = expenses
        .where((expense) => selectedCategories.contains(expense.categoryId))
        .fold(0, (sum, exp) => exp.amount + sum);

    final double? totalBudget = isAllSelected
        ? categoryConfigs
            .where((config) => !config.deleted)
            .fold(0, (sum, config) => sum! + config.budget)
        : null;

    final double? delta = totalBudget == null ? totalBudget : totalBudget - totalExpenses;

    return GestureDetector(
      onLongPress: () => setState(() {
        final nextState = !showValues;
        showValues = nextState;
        LocalStorageService().setShowTotal(nextState);
        HapticFeedback.mediumImpact();
      }),
      child: Column(
        children: [
          Text(
            showValues
                ? currency.format(totalExpenses)
                : currency.format(totalExpenses).replaceAll(RegExp(r'[0-9]'), maskCharacter),
            style: TextStyle(fontSize: 24, color: Theme.of(context).textTheme.titleLarge?.color),
            textAlign: TextAlign.center,
          ),
          if (delta != null)
            Text(
              '${delta >= 0 ? '+' : ''} ${showValues ? currency.format(delta) : currency.format(delta).replaceAll(RegExp(r'[0-9]'), maskCharacter)}',
              style: TextStyle(fontSize: 16, color: delta >= 0 ? Colors.green : Colors.red),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
