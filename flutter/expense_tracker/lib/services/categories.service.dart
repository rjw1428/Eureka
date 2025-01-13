import 'package:expense_tracker/models/category.dart';
import 'package:flutter/material.dart';

typedef CategoryConfig = List<CategoryDataWithId>;

final Map<String, CategoryData> defaultCategories = {
  'EATING_OUT': CategoryData(
    label: 'Eating Out',
    icon: Icons.lunch_dining_outlined,
    budget: 500.0,
  ),
  'SNACKS': CategoryData(
    label: 'Snacks',
    icon: Icons.icecream_outlined,
    budget: 100.0,
  ),
  'GAS': CategoryData(
    label: 'Gas',
    icon: Icons.local_gas_station_outlined,
    budget: 200.0,
  ),
  'SHOPPING': CategoryData(
    label: 'Shopping',
    icon: Icons.shopping_basket_outlined,
    budget: 100.0,
  ),
  'HOME_RENO': CategoryData(
    label: 'Home Reno',
    icon: Icons.construction_outlined,
    budget: 100.0,
  ),
};

class CategoriesService {
  List<CategoryDataWithId> getCategories({withDeleted = true}) {
    return defaultCategories.entries
        .where((el) => withDeleted ? true : !el.value.deleted)
        .map(
          (entry) => CategoryDataWithId(
            label: entry.value.label,
            icon: entry.value.icon,
            budget: entry.value.budget,
            deleted: entry.value.deleted,
            id: entry.key,
          ),
        )
        .toList();
  }

  void updateCategory(CategoryDataWithId category) {
    defaultCategories[category.id] = CategoryData(
      label: category.label,
      icon: category.icon,
      budget: category.budget,
    );
  }

  void remove(CategoryDataWithId category) {
    category.deleted = true;
    defaultCategories[category.id] = category;
  }

  void addCategory(CategoryDataWithId category, [index = 0]) {
    defaultCategories.putIfAbsent(
      category.id,
      () => CategoryData(
        label: category.label,
        icon: category.icon,
        budget: category.budget,
      ),
    );
  }
}
