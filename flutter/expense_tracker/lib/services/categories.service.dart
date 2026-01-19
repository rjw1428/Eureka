import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:flutter/foundation.dart';

typedef CategoryConfig = List<CategoryDataWithId>;

class CategoriesService {
  CategoriesService._internal();

  final _db = FirebaseFirestore.instance;
  static final CategoriesService _instance = CategoriesService._internal();
  factory CategoriesService() {
    return _instance;
  }

  Future<void> updateCategory(CategoryDataWithId category, String ledgerId) async {
    final docRef = await _budgetCategoryCollection(ledgerId);
    var categoryUpdate = category.toJson();
    categoryUpdate.remove('id');
    try {
      return docRef.update({"budgetConfig.${category.id}": categoryUpdate});
    } catch (e) {
      debugPrint('Error updating category: $e');
    }
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
