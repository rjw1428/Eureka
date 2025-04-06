import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:rxdart/rxdart.dart';

typedef CategoryConfig = List<CategoryDataWithId>;

class CategoriesService {
  CategoriesService._internal();

  final _db = FirebaseFirestore.instance;
  static final CategoriesService _instance = CategoriesService._internal();
  factory CategoriesService() {
    return _instance;
  }

  // Stream<List<CategoryDataWithId>> get categoryStream$ => AuthService()
  //     .expenseUser$
  //     .takeUntil(AuthService().userLoggedOut$)
  //     .whereNotNull()
  //     .exhaustMap((user) => _db.collection('ledger').doc(user.ledgerId).snapshots().map(
  //           (snapshot) {
  //             final data = snapshot.get('budgetConfig') as LinkedHashMap<String, dynamic>;
  //             List<CategoryDataWithId> configs = data.entries.map((element) {
  //               return CategoryDataWithId.fromJson({...element.value, 'id': element.key});
  //             }).toList();
  //             configs.sort((a, b) => a.label.compareTo(b.label));
  //             return configs;
  //           },
  //         ))
  //     .handleError((err) => print('Category Stream: ${err.toString()}'))
  //     .shareReplay(maxSize: 1);

  // Future<List<CategoryDataWithId>> getCategories(String ledgerId) async {
  //   return categoryStream$.first;
  // }

  Future<void> updateCategory(CategoryDataWithId category, String ledgerId) async {
    final docRef = await _budgetCategoryCollection(ledgerId);
    var categoryUpdate = category.toJson();
    categoryUpdate.remove('id');
    return docRef.update({"budgetConfig.${category.id}": categoryUpdate});
  }

  Future<void> remove(CategoryDataWithId category, String ledgerId) async {
    final doc = await _budgetCategoryCollection(ledgerId);
    doc.update({"budgetConfig.${category.id}.deleted": true});
  }

  Future<void> addCategory(CategoryDataWithId category, String ledgerId) async {
    final docRef = await _budgetCategoryCollection(ledgerId);
    var categoryUpdate = category.toJson();
    categoryUpdate.remove('id');
    return docRef.update({"budgetConfig.${category.id}": categoryUpdate});
  }

  Future<DocumentReference<Map<String, dynamic>>> _budgetCategoryCollection(String ledgerId) async {
    return _db.collection('ledger').doc(ledgerId);
  }
}
