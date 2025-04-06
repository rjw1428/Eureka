import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

final formatter = DateFormat('MMM');

class ExpenseService {
  ExpenseService._internal();

  final _db = FirebaseFirestore.instance;
  static final ExpenseService _instance = ExpenseService._internal();

  factory ExpenseService() {
    return _instance;
  }

  // Stream<List<Expense>> getExpenseStream(
  //   String ledgerId,
  //   DateTime date,
  // ) {
  //   final month = formatMonth(date);

  //   return _db
  //       .collection('ledger')
  //       .doc(ledgerId)
  //       .collection(month)
  //       // .startAfter(lastVisible)
  //       // .limit(10)
  //       .orderBy('date', descending: true)
  //       .snapshots()
  //       .map((snapshot) =>
  //           snapshot.docs.map((doc) => Expense.fromJson({...doc.data(), "id": doc.id})).toList())
  //       .handleError((err) => print('Expense Stream: ${err.toString()}'))
  //       .shareReplay(maxSize: 1);
  // }

  // Stream<List<SummaryEntry>> getSummary(DateTime start, DateTime? end, String categoryId) {
  //   DateTime queryEnd = end ?? DateTime.now();
  //   return _db
  //       .collection('ledger')
  //       .doc(ledgerId)
  //       .collection('summaries')
  //       .where('startDate', isGreaterThanOrEqualTo: start)
  //       .where('startDate', isLessThanOrEqualTo: queryEnd)
  //       .where('categoryId', isEqualTo: categoryId)
  //       .snapshots()
  //       .doOnError((e, s) => print(e))
  //       .map(
  //         (snapshot) => snapshot.docs.map((doc) {
  //           final data = doc.data();
  //           final startDate = data['startDate'].toDate() as DateTime;
  //           final lastUpdate = data['lastUpdate'].toDate() as DateTime;
  //           final summaryPoint = SummaryEntry.fromJson({
  //             'id': doc.id,
  //             ...data,
  //             'startDate': startDate.toIso8601String(),
  //             'lastUpdate': lastUpdate.toIso8601String(),
  //           });
  //           return summaryPoint;
  //         }).toList(),
  //       );
  // }
}
