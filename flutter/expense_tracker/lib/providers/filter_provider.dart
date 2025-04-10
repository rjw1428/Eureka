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

class SelectedFiltersNotifier extends StateNotifier<List<String>> {
  SelectedFiltersNotifier(super.budgetCategories);

  void setSelectedFilters(List<String> selection) {
    state = selection;
  }
}

final selectedFiltersProvider = StateNotifierProvider<SelectedFiltersNotifier, List<String>>((ref) {
  final expenses = ref.watch(expenseProvider).valueOrNull ?? [];
  final Set<String> usedCategoryIds = Set.from(
    expenses.map((el) => el.categoryId),
  );
  return SelectedFiltersNotifier(usedCategoryIds.toList());
});

final defaultFilterOptions = Provider<List<CategoryDataWithId>>((ref) {
  final budgetConfigs = ref.watch(budgetProvider).valueOrNull ?? [];
  final expenses = ref.watch(expenseProvider).valueOrNull ?? [];

  final Set<String> usedCategoryIds = Set.from(
    expenses.map((el) => el.categoryId),
  );
  final filterList = usedCategoryIds
      .toList()
      .map((id) => budgetConfigs.firstWhere((config) => config.id == id))
      .toList();

  return filterList;
});
