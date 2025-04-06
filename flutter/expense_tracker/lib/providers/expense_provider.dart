import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final formatter = DateFormat('MMM');

String formatMonth(DateTime date) {
  return "${date.year}_${formatter.format(date).toUpperCase()}";
}

final expenseProvider = FutureProvider<List<ExpenseWithCategoryData>>((ref) async {
  final firestore = ref.read(backendProvider);
  final user = ref.watch(userProvider).valueOrNull;
  final lastDoc = ref.watch(paginationProvider.select((state) => state.lastDoc));
  final budgetCategories = ref.watch(budgetProvider).value ?? [];

  if (user == null) {
    return Future.value([]);
  }

  final month = formatMonth(DateTime.now());
  final query = firestore
      .collection('ledger')
      .doc(user.ledgerId)
      .collection(month)
      .limit(3)
      .orderBy('date', descending: true);

  final paginationQuery = lastDoc == null ? query : query.startAfterDocument(lastDoc);

  final snapshots = await paginationQuery.get();
  final docs = snapshots.docs as List<DocumentSnapshot>;
  final expenses = docs.map((doc) {
    final data = doc.data()! as Map;
    return Expense.fromJson({...data, "id": doc.id});
  }).toList();

  final newData = expenses.map((expense) {
    final CategoryDataWithId category =
        budgetCategories.firstWhere((cat) => cat.id == expense.categoryId);
    return ExpenseWithCategoryData.fromJson({...expense.toJson(), 'category': category.toJson()});
  }).toList();

  return newData;
});

class PaginationState {
  final List<ExpenseWithCategoryData> expenses;
  final bool isLoading;
  final int limit;
  final bool complete;
  final DocumentSnapshot? lastDoc;

  const PaginationState({
    this.limit = 3,
    this.complete = false,
    this.lastDoc,
    this.expenses = const [],
    this.isLoading = false,
  });

  factory PaginationState.initial() {
    return const PaginationState();
  }

  PaginationState copyWith({
    int? limit,
    DocumentSnapshot? lastDoc,
    bool? complete,
    List<ExpenseWithCategoryData>? expenses,
    bool? isLoading,
  }) {
    return PaginationState(
      limit: limit ?? this.limit,
      complete: complete ?? this.complete,
      lastDoc: lastDoc ?? this.lastDoc,
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PaginationNotifier extends StateNotifier<PaginationState> {
  PaginationNotifier() : super(const PaginationState());

  next(DocumentSnapshot from) {
    state = state.copyWith(lastDoc: from);
  }

  setComplete(bool isComplete) {
    state = state.copyWith(complete: isComplete);
  }

  appendData(List<ExpenseWithCategoryData> expenses) async {
    state = state.copyWith(expenses: [...state.expenses, ...expenses]);
  }
}

final paginationProvider =
    StateNotifierProvider<PaginationNotifier, PaginationState>((ref) => PaginationNotifier());
