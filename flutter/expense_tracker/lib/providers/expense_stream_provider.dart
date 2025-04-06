import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

final expenseProvider = StreamProvider<List<ExpenseWithCategoryData>>((ref) {
  final firestore = ref.read(backendProvider);
  final user = ref.watch(userProvider).valueOrNull;
  final budgetCategories = ref.watch(budgetProvider).value ?? [];
  // final lastDoc = ref.watch(paginationProvider.select((state) => state.lastDoc));

  if (user == null) {
    return Stream.value([]);
  }

  final month = formatMonth(DateTime.now());

  return firestore
      .collection('ledger')
      .doc(user.ledgerId)
      .collection(month)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Expense.fromJson({...doc.data(), "id": doc.id})).toList())
      .doOnData((d) => print('-- Returning expense data: ${d.length}'))
      .handleError((err) => print('Expense Stream: ${err.toString()}'))
      .shareReplay(maxSize: 1)
      .map((expenses) => expenses.map((expense) {
            final CategoryDataWithId category =
                budgetCategories.firstWhere((cat) => cat.id == expense.categoryId);
            return ExpenseWithCategoryData.fromJson(
                {...expense.toJson(), 'category': category.toJson()});
          }).toList());
});
