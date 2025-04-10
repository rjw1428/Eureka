import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:expense_tracker/constants/utils.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

final format = DateFormat('MMM', 'en_US');

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
          final newExpenseData = expense.toJson();
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
    expense.submittedBy = user.id;

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
  final user = ref.read(userProvider).value;
  final firestore = ref.read(backendProvider);
  // HOW TO HANDLE WHEN THERE'S NO USER
  return ExpenseNotifier(user: user!, firestore: firestore);
});

final expenseProvider = StreamProvider<List<ExpenseWithCategoryData>>((ref) {
  final firestore = ref.read(backendProvider);
  final user = ref.watch(userProvider).valueOrNull;
  final budgetCategories = ref.watch(budgetProvider).value ?? [];
  final selectedDate = ref.watch(selectedTimeProvider);

  if (user == null) {
    return Stream.value([]);
  }

  final month = formatMonth(selectedDate);

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

typedef SummaryQueryParams = ({String categoryId, DateTime start, DateTime? end});

final expenseSummaryProvider =
    StreamProvider.autoDispose.family<List<SummaryEntry>, SummaryQueryParams>((ref, query) {
  final user = ref.watch(userProvider).valueOrNull;
  final firestore = ref.read(backendProvider);
  final DateTime queryEnd = query.end ?? DateTime.now();

  if (user == null) {
    return Stream.value([]);
  }

  return firestore
      .collection('ledger')
      .doc(user.ledgerId)
      .collection('summaries')
      .where('startDate', isGreaterThanOrEqualTo: query.start)
      .where('startDate', isLessThanOrEqualTo: queryEnd)
      .where('categoryId', isEqualTo: query.categoryId)
      .snapshots()
      .doOnError((e, s) => print(e))
      .map((snapshot) => snapshot.docs.fold(
            {},
            (agg, doc) {
              final data = doc.data();
              final startDate = data['startDate'].toDate() as DateTime;
              final lastUpdate = data['lastUpdate'].toDate() as DateTime;
              final summaryPoint = SummaryEntry.fromJson({
                'id': doc.id,
                ...data,
                'startDate': startDate.toIso8601String(),
                'lastUpdate': lastUpdate.toIso8601String(),
              });
              // as Map<DateTime, SummaryEntry>
              return {...agg, DateTime(startDate.year, startDate.month): summaryPoint};
            },
          ))
      .map((points) {
    // We need to fill any of the in between time with 0's
    final DateTime? dataStartData = points.keys.reduce(
      (minDate, date) => minDate.isBefore(date) ? minDate : date,
    );

    if (dataStartData == null) {
      return [];
    }

    final slotSize = monthsBetween(dataStartData, queryEnd) + 1;
    final now = DateTime.now();
    final pointsWithZeroFills = List<SummaryEntry>.generate(slotSize, (i) {
      final expectedTime = DateTime(dataStartData.year, dataStartData.month + i);
      final SummaryEntry? dataPoint = points[expectedTime];
      return dataPoint ??
          SummaryEntry(
              id: 'zeroPoint',
              count: 0,
              total: 0,
              lastUpdate: now,
              startDate: expectedTime,
              categoryId: query.categoryId);
    });
    return pointsWithZeroFills.sorted((a, b) => b.startDate.compareTo(a.startDate));
  });
});
