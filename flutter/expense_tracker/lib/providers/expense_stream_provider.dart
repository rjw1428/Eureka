import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/linked_accounts_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:collection/collection.dart';

class ExpenseNotifier extends StateNotifier<List<ExpenseWithCategoryData>> {
  ExpenseNotifier({required this.user, required this.firestore}) : super(const []);
  final ExpenseUser user;
  final FirebaseFirestore firestore;

  String _summaryId(Expense expense) {
    final yearMonth = _formatMonth(expense.date);
    return "${yearMonth}_${expense.categoryId}";
  }

  String _formatMonth(DateTime date) {
    return "${date.year}_${formatter.format(date).toUpperCase()}";
  }

  Future<DocumentReference<Map<String, dynamic>>> _summaryCollection(Expense expense) async {
    final docId = _summaryId(expense);
    return firestore.collection('ledger').doc(user.ledgerId).collection('summaries').doc(docId);
  }

  Future<CollectionReference<Map<String, dynamic>>> _expenseCollection(DateTime date) async {
    final month = formatMonth(date);
    return firestore.collection('ledger').doc(user.ledgerId).collection(month);
  }

  Future _checkSummaryCollection(Expense expense) async {
    final collectionRef = firestore.collection('ledger').doc(user.ledgerId).collection('summaries');
    final docId = _summaryId(expense);

    final summaryDoc = await collectionRef.doc(docId).get();
    if (!summaryDoc.exists) {
      collectionRef.doc(docId).set({
        'startDate': DateTime(expense.date.year, expense.date.month),
        'categoryId': expense.categoryId
      });
    }
  }

  Future addExpense(Expense expense) async {
    await _checkSummaryCollection(expense);
    try {
      return Future.wait([
        _summaryCollection(expense).then(
          (summaryDocRef) => summaryDocRef.update({
            'lastUpdate': FieldValue.serverTimestamp(),
            'total': FieldValue.increment(expense.amount),
            'count': FieldValue.increment(1)
          }),
        ),
        _expenseCollection(expense.date).then((collectionRef) {
          expense.submittedBy = user.id;
          var newExpenseData = expense.toJson();
          newExpenseData.remove('id');
          // Not sure why this property is here when undoing a delete
          // probably fine, but not looking into it now.
          newExpenseData.remove('category');
          collectionRef.add(newExpenseData);
        })
      ]);
    } catch (e) {
      return null;
    }
  }

  Future<void> removeExpense(Expense expense) async {
    await Future.wait([
      _summaryCollection(expense).then((ref) => ref.update({
            'lastUpdate': FieldValue.serverTimestamp(),
            'total': FieldValue.increment(-1 * expense.amount),
            'count': FieldValue.increment(-1),
          })),
      _expenseCollection(expense.date).then((ref) => ref.doc(expense.id!).delete()),
    ]);
  }

  Future<void> updateExpense(Expense expense, Expense previousExpense) async {
    final isSameMonthBucket = expense.date.month == previousExpense.date.month &&
        expense.date.year == previousExpense.date.year;

    if (isSameMonthBucket) {
      List<Future> actions = [
        _expenseCollection(previousExpense.date)
            .then((ref) => ref.doc(previousExpense.id).set(expense.toJson())),
      ];
      // Skip updating summary if the amount hasn't changed & the category is the same
      if (expense.amount - previousExpense.amount != 0 &&
          previousExpense.categoryId == expense.categoryId) {
        actions.add(
          _summaryCollection(expense).then(
            (ref) => ref.update({
              'lastUpdate': FieldValue.serverTimestamp(),
              'total': FieldValue.increment(expense.amount - previousExpense.amount),
            }),
          ),
        );
      }

      if (previousExpense.categoryId != expense.categoryId) {
        actions.add(
          _summaryCollection(previousExpense).then(
            (ref) => ref.update({
              'lastUpdate': FieldValue.serverTimestamp(),
              'total': FieldValue.increment(-1 * previousExpense.amount),
            }),
          ),
        );

        actions.add(
          _summaryCollection(expense).then(
            (ref) => ref.update({
              'lastUpdate': FieldValue.serverTimestamp(),
              'total': FieldValue.increment(-1 * expense.amount),
            }),
          ),
        );
      }

      await Future.wait(actions);
      return;
    }

    // If the date has changed, remove the previous expense and add the new one
    await Future.wait([
      removeExpense(previousExpense),
      addExpense(expense),
    ]);
    return;
  }

  Future react(Expense expense, String reaction) {
    return _expenseCollection(expense.date).then((ref) => ref.doc(expense.id).update({
          'reactions': [...expense.reactions, reaction],
        }));
  }
}

final expenseModifierProvider =
    StateNotifierProvider<ExpenseNotifier, List<ExpenseWithCategoryData>>((ref) {
  final user = ref.watch(userProvider).value;
  final firestore = ref.read(backendProvider);
  // HOW TO HANDLE WHEN THERE'S NO USER
  return ExpenseNotifier(user: user!, firestore: firestore);
});

final expenseProvider = StreamProvider<List<ExpenseWithCategoryData>>((ref) {
  final firestore = ref.read(backendProvider);
  final user = ref.watch(userProvider).valueOrNull;
  final budgetCategories = ref.watch(budgetProvider).value ?? [];
  final expenseUsers = ref.read(linkedUserProvider);
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
            final matchingUser = expenseUsers.firstWhereOrNull((u) => u.id == expense.submittedBy);
            return ExpenseWithCategoryData.fromJson({
              ...expense.toJson(),
              'user': matchingUser?.toJson(),
              'category': category.toJson()
            });
          }).toList());
});
