import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
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
  SelectedFiltersNotifier(List<CategoryDataWithId> budgetCategories)
      : super(
          budgetCategories.map((category) => category.id).toList(),
        );

  void setSelectedFilters(List<String> selection) {
    state = selection;
  }
}

final selectedFiltersProvider = StateNotifierProvider<SelectedFiltersNotifier, List<String>>((ref) {
  final budgetCategories = ref.watch(budgetProvider).value ?? [];
  return SelectedFiltersNotifier(budgetCategories);
});

                // final _filterList = selectedCategoryIds.isEmpty
                // ? distinctCategoryIds.toList()
                // : distinctCategoryIds
                //     .toList()
                //     .where((id) => selectedCategoryIds.contains(id))
                //     .toList();