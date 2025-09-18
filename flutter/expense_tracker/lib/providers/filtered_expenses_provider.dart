import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final filteredExpensesProvider =
    Provider<AsyncValue<List<ExpenseWithCategoryData>>>((ref) {
  final expenses$ = ref.watch(expenseProvider);
  final selectedFilters = ref.watch(selectedFiltersProvider);

  return expenses$.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
    data: (expenses) {
      if (selectedFilters == null || selectedFilters.isEmpty) {
        return AsyncValue.data(expenses);
      }

      final filteredList = expenses
          .where((expense) =>
              (selectedFilters.contains(expense.categoryId)) &&
              (expense.hideUntil == null ||
                  expense.hideUntil!.isBefore(DateTime.now())))
          .toList();
      return AsyncValue.data(filteredList);
    },
  );
});
