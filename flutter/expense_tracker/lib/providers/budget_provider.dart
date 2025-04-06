import 'dart:collection';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

final budgetProvider = StreamProvider<List<CategoryDataWithId>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final firestore = ref.read(backendProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return firestore
      .collection('ledger')
      .doc(user.ledgerId)
      .snapshots()
      .map(
        (snapshot) {
          final data = snapshot.get('budgetConfig') as LinkedHashMap<String, dynamic>;
          List<CategoryDataWithId> configs = data.entries.map((element) {
            return CategoryDataWithId.fromJson({...element.value, 'id': element.key});
          }).toList();
          configs.sort((a, b) => a.label.compareTo(b.label));
          return configs;
        },
      )
      .doOnData((d) => print('-- Returning budget data: ${d.length}'))
      .handleError((err) => print('Category Stream: ${err.toString()}'))
      .shareReplay(maxSize: 1);
});

final activeBudgetCategoryProvider = Provider<AsyncValue<List<CategoryDataWithId>>>((ref) {
  return ref.watch(budgetProvider).when(
      data: (categories) => AsyncData(
            categories.where((category) => category.deleted == false).toList(),
          ),
      error: (err, stack) => AsyncError(err, stack),
      loading: () => const AsyncLoading());
});
