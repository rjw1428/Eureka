import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:expense_tracker/services/auth.service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

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

  Future<void> addAmortizedExpense(Expense templateExpense, int months) async {
    final groupId = const Uuid().v4();
    final monthlyAmount = templateExpense.amount / months;

    final firstExpense = Expense(
      amount: monthlyAmount,
      date: templateExpense.date,
      categoryId: templateExpense.categoryId,
      note: templateExpense.note,
      submittedBy: user.id,
      amortized: AmortizationDetails(
        groupId: groupId,
        index: 1,
        over: months,
      ),
    );

    try {
      final collectionRef = await _expenseCollection(firstExpense.date);
      final docRef = await collectionRef.add(firstExpense.toJson());

      // Also update the summary for the first expense
      final summaryRef = await _summaryCollection(firstExpense);
      final summaryDoc = await summaryRef.get();
      if (!summaryDoc.exists) {
        await summaryRef.set({
          'startDate': DateTime(firstExpense.date.year, firstExpense.date.month),
          'categoryId': firstExpense.categoryId
        });
      }

      await Future.wait([
        summaryRef.update({
          'lastUpdate': FieldValue.serverTimestamp(),
          'total': FieldValue.increment(firstExpense.amount),
          'count': FieldValue.increment(1)
        }),
        FirebaseFunctions.instance.httpsCallable('createAmortizedExpenses').call({
          'template': templateExpense.toJson(),
          'firstExpenseId': docRef.id,
          'groupId': groupId,
          'months': months,
          'ledgerId': user.ledgerId,
        }),
      ]);
    } catch (e) {
      print('Error adding amortized expense: $e');
      // Optionally rethrow or handle the error in the UI
    }
  }

  Future addExpense(Expense expense) async {
    final docId = _summaryId(expense);
    final collectionRef = firestore.collection('ledger').doc(user.ledgerId).collection('summaries');
    final summaryDoc = await collectionRef.doc(docId).get();

    // If the summary document does not exist, create it with initial values
    if (!summaryDoc.exists) {
      await collectionRef
          .doc(docId)
          .set({'startDate': DateTime(expense.date.year, expense.date.month), 'categoryId': expense.categoryId});
    }
    try {
      return Future.wait([
        collectionRef.doc(docId).update({
          'lastUpdate': FieldValue.serverTimestamp(),
          'total': FieldValue.increment(expense.amount),
          'count': FieldValue.increment(1)
        }),
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
    if (expense.amortized != null) {
      try {
        await FirebaseFunctions.instance.httpsCallable('deleteAmortizedSeries').call({
          'groupId': expense.amortized!.groupId,
          'ledgerId': user.ledgerId,
        });
      } catch (e) {
        print('Error deleting amortized expense series: $e');
        // Optionally rethrow or handle the error in the UI
      }
    } else {
      await Future.wait([
        _summaryCollection(expense).then((ref) => ref.update({
              'lastUpdate': FieldValue.serverTimestamp(),
              'total': FieldValue.increment(-1 * expense.amount),
              'count': FieldValue.increment(-1),
            })),
        _expenseCollection(expense.date).then((ref) => ref.doc(expense.id!).delete()),
      ]);
    }
  }

  Future<void> updateExpense(Expense expense, Expense previousExpense) async {
    final isSameMonthBucket =
        expense.date.month == previousExpense.date.month && expense.date.year == previousExpense.date.year;
    expense.submittedBy = user.id;

    if (isSameMonthBucket) {
      List<Future> actions = [
        _expenseCollection(previousExpense.date).then((ref) => ref.doc(previousExpense.id).set(expense.toJson())),
      ];
      // Skip updating summary if the amount hasn't changed & the category is the same
      if (expense.amount - previousExpense.amount != 0 && previousExpense.categoryId == expense.categoryId) {
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
    final self = AuthService().currentUser!.uid;
    List<Future<void>> futures = [
      _expenseCollection(expense.date).then((ref) => ref.doc(expense.id).update({
            'reactions': [...expense.reactions, reaction],
          }))
    ];
    if (self != expense.submittedBy) {
      futures.add(FirebaseFunctions.instance.httpsCallable("triggerLinkedAccount").call({
        'id': expense.submittedBy,
      }));
    }
    return Future.wait(futures);
  }
}

final expenseModifierProvider = StateNotifierProvider<ExpenseNotifier, List<ExpenseWithCategoryData>>((ref) {
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
      .map((snapshot) => snapshot.docs.map((doc) => Expense.fromJson({...doc.data(), "id": doc.id})).toList())
      .doOnData((d) => print('-- Returning expense data: ${d.length}'))
      .handleError((err) => print('Expense Stream: ${err.toString()}'))
      .shareReplay(maxSize: 1)
      .map((expenses) => expenses.map((expense) {
            final CategoryDataWithId category = budgetCategories.firstWhere((cat) => cat.id == expense.categoryId);
            return ExpenseWithCategoryData.fromJson({...expense.toJson(), 'category': category.toJson()});
          }).toList());
});

typedef SummaryQueryParams = ({String categoryId, DateTime start, DateTime? end});

final expenseSummaryProvider = StreamProvider.autoDispose.family<List<SummaryEntry>, SummaryQueryParams>((ref, query) {
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
    if (points.entries.isEmpty) {
      return [];
    }
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

final currentSummaryProvider = StreamProvider<List<SummaryEntry>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final firestore = ref.read(backendProvider);
  final now = DateTime.now();
  final DateTime start = DateTime(now.year, now.month).subtract(const Duration(seconds: 1));

  if (user == null) {
    return Stream.value([]);
  }

  return firestore
      .collection('ledger')
      .doc(user.ledgerId)
      .collection('summaries')
      .where('startDate', isGreaterThanOrEqualTo: start)
      .snapshots()
      .doOnError((e, s) => print(e))
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            final startDate = data['startDate'].toDate() as DateTime;
            final lastUpdate = data['lastUpdate'].toDate() as DateTime;
            return SummaryEntry.fromJson({
              'id': doc.id,
              ...data,
              'startDate': startDate.toIso8601String(),
              'lastUpdate': lastUpdate.toIso8601String(),
            });
          }).toList());
});
