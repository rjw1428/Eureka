import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedTimeNotifier extends StateNotifier<DateTime> {
  SelectedTimeNotifier() : super(DateTime.now());

  void setSelectedTime(DateTime month) {
    state = month;
  }
}

final selectedTimeProvider = StateNotifierProvider<SelectedTimeNotifier, DateTime>(
  (ref) => SelectedTimeNotifier(),
);

class SelectedFiltersNotifier extends StateNotifier<List<String>?> {
  SelectedFiltersNotifier() : super(null);
  // Initialize with null
  // if null, show all expenses
  // otherwise value will be an array in which we show the corresponding selection

  void setSelectedFilters(List<String>? selection) {
    state = selection;
  }
}

final selectedFiltersProvider = StateNotifierProvider<SelectedFiltersNotifier, List<String>?>(
    (ref) => SelectedFiltersNotifier());

final defaultFilterOptions = Provider<List<CategoryDataWithId>>((ref) {
  final budgetConfigs = ref.watch(budgetProvider).valueOrNull ?? [];
  final usedCategoryIds = ref.watch(expenseProvider.select(
      (expenses) => (expenses.valueOrNull ?? []).map((expense) => expense.categoryId).toSet()));

  final filterList = usedCategoryIds
      .toList()
      .map((id) => budgetConfigs.firstWhere((config) => config.id == id))
      .toList();

  return filterList;
});

final usedCategoryIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(expenseProvider).maybeWhen(
        data: (expenses) {
          if (expenses.isEmpty) {
            return <String>[];
          }
          return expenses.map((expense) => expense.categoryId).toSet().toList();
        },
        orElse: () => <String>[],
      );
});

final areAllCategoriesSelectedProvider = Provider<bool>((ref) {
  final usedCategories = ref.watch(usedCategoryIdsProvider);
  final selectedFilters = ref.watch(selectedFiltersProvider);

  return selectedFilters == null ||
      usedCategories.isEmpty ||
      selectedFilters.length == usedCategories.length;
});
