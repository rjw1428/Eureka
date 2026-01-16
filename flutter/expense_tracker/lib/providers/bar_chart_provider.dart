import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final barColumnProvider = Provider<AsyncValue<List<ExpenseBucket>>>((ref) {
  final expenses$ = ref.watch(expenseProvider);
  final budgetConfigs$ = ref.watch(activeBudgetCategoryProvider);

  return budgetConfigs$.when(
      loading: () => const AsyncValue.loading(),
      error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
      data: (configs) {
        return expenses$.when(
          loading: () => const AsyncValue.loading(),
          error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
          data: (expenses) {
            return AsyncValue.data(configs
                .where((config) => config.deleted == false)
                .map((config) => ExpenseBucket(
                    expenses: expenses
                        .where((expense) => expense.categoryId == config.id)
                        .toList(),
                    category: config))
                .toList());
          },
        );
      });
});
