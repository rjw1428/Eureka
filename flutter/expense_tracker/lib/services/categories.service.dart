import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:rxdart/rxdart.dart';

typedef CategoryConfig = List<CategoryDataWithId>;

final Map<String, CategoryData> defaultCategories = {
  'EATING_OUT': CategoryData(
    label: 'Eating Out',
    icon: 'lunch_dining_outlined',
    budget: 500.0,
  ),
  'SNACKS': CategoryData(
    label: 'Snacks',
    icon: 'icecream_outlined',
    budget: 100.0,
  ),
  'GAS': CategoryData(
    label: 'Gas',
    icon: 'local_gas_station_outlined',
    budget: 200.0,
  ),
  'SHOPPING': CategoryData(
    label: 'Shopping',
    icon: 'shopping_basket_outlined',
    budget: 100.0,
  ),
  'HOME_RENO': CategoryData(
    label: 'Home Reno',
    icon: 'construction_outlined',
    budget: 100.0,
  ),
};

class CategoriesService {
  CategoriesService._internal();

  final _db = FirebaseFirestore.instance;
  static final CategoriesService _instance = CategoriesService._internal();
  factory CategoriesService() {
    return _instance;
  }

  Future<DocumentReference<Map<String, dynamic>>> budgetCategoryCollection() async {
    final ledgerId = await AuthService().getCurrentUserLedgerId().first;
    return _db.collection('ledger').doc(ledgerId);
  }

  Stream<List<CategoryDataWithId>> getCategoriesStream(String ledgerId, {withDeleted = true}) {
    return _db
        .collection('ledger')
        .doc(ledgerId)
        .snapshots()
        .map(
          (snapshot) {
            final data = snapshot.get('budgetConfig') as LinkedHashMap<String, dynamic>;
            List<CategoryDataWithId> configs = data.entries.map((element) {
              return CategoryDataWithId.fromJson({...element.value, 'id': element.key});
            }).toList();

            if (!withDeleted) {
              configs = configs.where((config) => !config.deleted).toList();
            }

            configs.sort((a, b) => a.label.compareTo(b.label));
            return configs;
          },
        )
        .handleError((err) => print('Category Stream: ${err.toString()}'))
        .shareReplay(maxSize: 1);
  }

  Future<List<CategoryDataWithId>> getCategories(String ledgerId, {withDeleted = true}) async {
    return getCategoriesStream(ledgerId).first;
  }

  Future<void> updateCategory(CategoryDataWithId category) async {
    try {
      final docRef = await budgetCategoryCollection();
      var categoryUpdate = category.toJson();
      categoryUpdate.remove('id');
      return docRef.update({"budgetConfig.${category.id}": categoryUpdate});
    } catch (e) {
      return;
    }
  }

  Future<void> remove(CategoryDataWithId category) async {
    category.deleted = true;
    defaultCategories[category.id] = category;

    final doc = await budgetCategoryCollection();
    doc.update({"budgetConfig.${category.id}.deleted": true});
  }

  Future<void> addCategory(CategoryDataWithId category) async {
    try {
      final docRef = await budgetCategoryCollection();
      var categoryUpdate = category.toJson();
      categoryUpdate.remove('id');
      return docRef.update({"budgetConfig.${category.id}": categoryUpdate});
    } catch (e) {
      return;
    }
  }
}
