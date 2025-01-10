import 'package:expense_tracker/constants/categories.dart';
import 'package:expense_tracker/models/category.dart';

typedef CategoryConfig = Map<Category, CategoryData>;

class CategoriesService {
  CategoryConfig getCategories() {
    return categories;
  }
}
