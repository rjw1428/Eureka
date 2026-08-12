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
import 'package:expense_tracker/services/receipt.service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

final format = DateFormat('MMM', 'en_US');

class ExpenseNotifier extends Notifier<List<ExpenseWithCategoryData>> {
  late final ExpenseUser user;
  late final FirebaseFirestore firestore;
  late final ReceiptService receipts;

  @override
  List<ExpenseWithCategoryData> build() {
    user = ref.read(userProvider).value!;
    firestore = ref.read(backendProvider);
    receipts = ref.read(receiptServiceProvider);
    return const [];
  }

  String _formatMonth(DateTime date) {
    return "${date.year}_${formatter.format(date).toUpperCase()}";
  }

  DocumentReference<Map<String, dynamic>> _summaryRefFor(String categoryId, DateTime date) {
    final docId = "${_formatMonth(date)}_$categoryId";
    return firestore.collection('ledger').doc(user.ledgerId).collection('summaries').doc(docId);
  }

  /// Atomically creates-or-increments a category-month summary in a single
  /// write. Using `set(merge: true)` with `FieldValue.increment` means the doc
  /// is created if missing, concurrent increments never overwrite each other,
  /// and a decrement against a missing summary does not throw.
  Future<void> _applySummaryDelta({
    required String categoryId,
    required DateTime date,
    int countDelta = 0,
    double totalDelta = 0,
  }) {
    final startDate = DateTime(date.year, date.month);
    return _summaryRefFor(categoryId, date).set({
      'startDate': startDate,
      'categoryId': categoryId,
      'lastUpdate': FieldValue.serverTimestamp(),
      'total': FieldValue.increment(totalDelta),
      'count': FieldValue.increment(countDelta),
    }, SetOptions(merge: true));
  }

  Future<CollectionReference<Map<String, dynamic>>> _expenseCollection(DateTime date) async {
    final month = formatMonth(date);
    return firestore.collection('ledger').doc(user.ledgerId).collection(month);
  }

  /// Creates an amortized series. A receipt attached here belongs to the whole
  /// series: every installment references the same object, and it is released
  /// only when the series is deleted. `createAmortizedExpenses` builds each
  /// installment by spreading the template, so the fields propagate to months
  /// 2..N without any change on the function side.
  Future<String?> addAmortizedExpense(
    Expense templateExpense,
    int months, [
    String? updateId,
    Uint8List? receiptBytes,
  ]) async {
    final groupId = const Uuid().v4();
    final monthlyAmount = templateExpense.amount / months;
    final amortizedData = AmortizationDetails(
      groupId: groupId,
      index: 1,
      over: months,
    );

    UploadedReceipt? uploaded;
    if (receiptBytes != null) {
      uploaded = await receipts.upload(
        ledgerId: user.ledgerId,
        bytes: receiptBytes,
      );
      templateExpense.receiptId = uploaded.receiptId;
      templateExpense.imageUrl = uploaded.imageUrl;
    } else if (templateExpense.receiptId != null) {
      await receipts.clearMarker(templateExpense.receiptId!);
    }

    final firstExpense =
        templateExpense.copyWith(amount: monthlyAmount, amortized: amortizedData, submittedBy: user.id);

    try {
      String? id = updateId;
      final collectionRef = await _expenseCollection(firstExpense.date);
      if (updateId == null) {
        final docRef = await collectionRef.add(firstExpense.toJson());
        id = docRef.id;
      } else {
        await collectionRef.doc(updateId).set(firstExpense.toJson());
      }
      // Also update the summary for the first expense (months 2..N are handled
      // by the createAmortizedExpenses Cloud Function). Atomic create-or-increment.
      await Future.wait([
        _applySummaryDelta(
          categoryId: firstExpense.categoryId,
          date: firstExpense.date,
          countDelta: 1,
          totalDelta: firstExpense.amount,
        ),
        FirebaseFunctions.instance.httpsCallable('createAmortizedExpenses').call({
          'template': templateExpense.toJson(),
          'firstExpenseId': id,
          'groupId': groupId,
          'months': months,
          'ledgerId': user.ledgerId,
        }),
      ]);
      return id;
    } catch (e) {
      debugPrint('Error adding amortized expense: $e');
      await _releaseUpload(uploaded);
      return null;
    }
  }

  /// Creates an expense, optionally attaching a receipt from [receiptBytes].
  ///
  /// Returns the new document id, or null if the expense could not be saved.
  /// Throws [ReceiptException] when the failure is receipt-specific, so the UI
  /// can distinguish a permission problem from a generic save failure.
  ///
  /// The receipt is uploaded *before* the document write, and released again if
  /// that write or the summary update fails: a document must never reference an
  /// object that does not exist, whereas an unreferenced object is invisible and
  /// merely costs storage until the sweep collects it.
  Future<String?> addExpense(Expense expense, {Uint8List? receiptBytes}) async {
    if (expense.amortized != null) {
      return addAmortizedExpense(
        expense,
        expense.amortized!.over,
        null,
        receiptBytes,
      );
    }

    UploadedReceipt? uploaded;
    if (receiptBytes != null) {
      // Propagates ReceiptException; no document is written on upload failure.
      uploaded = await receipts.upload(
        ledgerId: user.ledgerId,
        bytes: receiptBytes,
      );
      expense.receiptId = uploaded.receiptId;
      expense.imageUrl = uploaded.imageUrl;
    } else if (expense.receiptId != null) {
      // Re-adding an expense that already carries a receipt is the undo-restore
      // path. Nothing to upload; just cancel the pending deletion so the object
      // survives the sweep.
      await receipts.clearMarker(expense.receiptId!);
    }

    expense.submittedBy = user.id;
    final newExpenseData = expense.toJson();
    newExpenseData.remove('id');
    // Not sure why this property is here when undoing a delete
    // probably fine, but not looking into it now.
    newExpenseData.remove('category');

    DocumentReference<Map<String, dynamic>> docRef;
    try {
      final collectionRef = await _expenseCollection(expense.date);
      // Awaited, unlike the previous implementation which discarded this future
      // and so reported success even when the write failed.
      docRef = await collectionRef.add(newExpenseData);
    } catch (e) {
      debugPrint('Failed to write expense: $e');
      await _releaseUpload(uploaded);
      return null;
    }

    try {
      // Atomic create-or-increment: no read-then-write, so concurrent adds
      // to a brand-new bucket can no longer overwrite each other.
      await _applySummaryDelta(
        categoryId: expense.categoryId,
        date: expense.date,
        countDelta: 1,
        totalDelta: expense.amount,
      );
    } catch (e) {
      debugPrint('Failed to update summary; rolling back the expense: $e');
      try {
        await docRef.delete();
      } catch (deleteError) {
        debugPrint('Could not roll back expense ${docRef.id}: $deleteError');
      }
      await _releaseUpload(uploaded);
      return null;
    }

    return docRef.id;
  }

  /// Reclaims an object that was uploaded but never ended up referenced.
  Future<void> _releaseUpload(UploadedReceipt? uploaded) async {
    if (uploaded == null) return;
    await receipts.deleteUnreferenced(
      ledgerId: user.ledgerId,
      receiptId: uploaded.receiptId,
    );
  }

  /// Deletes an expense and *releases* its receipt — marks the object for
  /// deletion rather than deleting it, so the undo affordance can still restore
  /// a working receipt. The caller commits or cancels that deletion once the
  /// undo window closes (see `commitReceiptDeletion` / `ReceiptService`).
  ///
  /// Pass [releaseReceipt] as false when the expense document is being moved
  /// rather than genuinely deleted, as on a cross-month date change: the new
  /// document carries the same `receiptId`, so the object must not be touched.
  Future<void> removeExpense(
    Expense expense, [
    String? updateId,
    bool releaseReceipt = true,
  ]) async {
    final now = DateTime.now();
    if (expense.hideUntil != null && expense.hideUntil!.isAfter(now) && expense.submittedBy != user.id) {
      debugPrint('Attempted to delete a hidden expense not submitted by current user. Deletion prevented.');
      // Optionally throw an exception or return a specific error code
      return;
    }

    if (releaseReceipt && expense.receiptId != null) {
      try {
        await receipts.release(
          ledgerId: user.ledgerId,
          receiptId: expense.receiptId!,
        );
      } catch (e) {
        // The expense deletion must not be blocked by cleanup bookkeeping.
        debugPrint('Could not mark receipt ${expense.receiptId} for deletion; '
            'the object will be orphaned: $e');
      }
    }

    if (expense.amortized != null) {
      // Immediately delete the selected expense to update the UI
      if (updateId == null) {
        final ref = await _expenseCollection(expense.date);
        await ref.doc(expense.id).delete();
      }
      // Then, in the background, delete the rest of the series
      FirebaseFunctions.instance.httpsCallable('deleteAmortizedSeries').call({
        'groupId': expense.amortized!.groupId,
        'ledgerId': user.ledgerId,
        'updateId': updateId,
      });
    } else {
      await Future.wait([
        // Merge-increment tolerates a missing summary: the raw doc is still
        // deleted and no error aborts the operation.
        _applySummaryDelta(
          categoryId: expense.categoryId,
          date: expense.date,
          countDelta: -1,
          totalDelta: -expense.amount,
        ),
        _expenseCollection(expense.date).then((ref) => ref.doc(expense.id!).delete()),
      ]);
    }
  }

  /// Applies [receipt] to [expense], returning the id of any object the update
  /// supersedes. The superseded object is released only after the write lands.
  ///
  /// Throws [ReceiptException] if a replacement cannot be uploaded, leaving the
  /// existing receipt untouched.
  Future<({String? superseded, UploadedReceipt? uploaded})> _applyReceiptIntent(
    Expense expense,
    Expense previousExpense,
    ReceiptIntent receipt,
  ) async {
    switch (receipt) {
      case ReceiptUnchanged():
        // Carry the existing receipt forward. Note this happens for every edit,
        // which is why replacement must never be gated on `imageUrl == null`.
        expense.receiptId = previousExpense.receiptId;
        expense.imageUrl = previousExpense.imageUrl;
        return (superseded: null, uploaded: null);

      case ReceiptRemoved():
        expense.receiptId = null;
        expense.imageUrl = null;
        return (superseded: previousExpense.receiptId, uploaded: null);

      case ReceiptReplaced(:final bytes):
        final uploaded = await receipts.upload(
          ledgerId: user.ledgerId,
          bytes: bytes,
        );
        expense.receiptId = uploaded.receiptId;
        expense.imageUrl = uploaded.imageUrl;
        return (superseded: previousExpense.receiptId, uploaded: uploaded);
    }
  }

  /// Updates an expense, applying [receipt] to whatever it had before.
  ///
  /// Returns false if the update could not be saved. Throws [ReceiptException]
  /// for receipt-specific failures.
  Future<bool> updateExpense(
    Expense expense,
    Expense previousExpense, {
    ReceiptIntent receipt = const ReceiptUnchanged(),
  }) async {
    final now = DateTime.now();
    if (previousExpense.hideUntil != null && previousExpense.hideUntil!.isAfter(now) && previousExpense.submittedBy != user.id) {
      debugPrint('Attempted to update a hidden expense not submitted by current user. Update prevented.');
      // Optionally throw an exception or return a specific error code
      return false;
    }
    final wasAmortized = previousExpense.amortized != null;
    final isAmortized = expense.amortized != null;

    final applied = await _applyReceiptIntent(expense, previousExpense, receipt);
    final superseded = applied.superseded;

    /// Releases the superseded object once the write has landed. Kept to the
    /// tail of each branch so a failed write leaves the original receipt intact.
    Future<void> releaseSuperseded() async {
      if (superseded == null || superseded == expense.receiptId) return;
      try {
        await receipts.release(
          ledgerId: user.ledgerId,
          receiptId: superseded,
        );
      } catch (e) {
        debugPrint('Update saved, but the superseded receipt $superseded could '
            'not be marked for deletion: $e');
      }
    }

    /// Undoes a replacement upload when the write fails.
    Future<void> rollbackReplacement() => _releaseUpload(applied.uploaded);

    // Transitioning from amortized to non-amortized. The receipt fields are
    // already resolved on `expense`, so the re-add carries them without
    // re-uploading.
    if (wasAmortized && !isAmortized) {
      await removeExpense(previousExpense, null, false);
      final id = await addExpense(expense);
      if (id == null) {
        await rollbackReplacement();
        return false;
      }
      await releaseSuperseded();
      return true;
    }

    // UPDATING an amortized expense
    if (wasAmortized && isAmortized) {
      await removeExpense(previousExpense, previousExpense.id, false);
      await addAmortizedExpense(expense, expense.amortized!.over, previousExpense.id);
      await releaseSuperseded();
      return true;
    }

    // Transitioning from non-amortized to amortized
    if (!wasAmortized && isAmortized) {
      await removeExpense(previousExpense, null, false);
      await addAmortizedExpense(expense, expense.amortized!.over, previousExpense.id);
      await releaseSuperseded();
      return true;
    }

    final isSameMonthBucket =
        expense.date.month == previousExpense.date.month && expense.date.year == previousExpense.date.year;
    expense.submittedBy = user.id;

    if (isSameMonthBucket) {
      List<Future> actions = [
        _expenseCollection(previousExpense.date).then((ref) => ref.doc(previousExpense.id).set(expense.toJson())),
      ];
      if (previousExpense.categoryId == expense.categoryId) {
        // Same category: adjust the bucket total by the amount delta only.
        // The count is unchanged (still one transaction in the same bucket).
        final totalDelta = expense.amount - previousExpense.amount;
        if (totalDelta != 0) {
          actions.add(_applySummaryDelta(
            categoryId: expense.categoryId,
            date: expense.date,
            totalDelta: totalDelta,
          ));
        }
      } else {
        // Category changed within the month: move the transaction between
        // buckets. Decrement the old category and increment the new one,
        // both in count and total. The new bucket is created if missing.
        actions.add(_applySummaryDelta(
          categoryId: previousExpense.categoryId,
          date: previousExpense.date,
          countDelta: -1,
          totalDelta: -previousExpense.amount,
        ));
        actions.add(_applySummaryDelta(
          categoryId: expense.categoryId,
          date: expense.date,
          countDelta: 1,
          totalDelta: expense.amount,
        ));
      }

      try {
        await Future.wait(actions);
      } catch (e) {
        debugPrint('Failed to update expense: $e');
        await rollbackReplacement();
        return false;
      }
      await releaseSuperseded();
      return true;
    }

    // The date moved to another month. Under the month-sharded layout that is a
    // delete plus an add, so the document id changes — but `receiptId` does
    // not, and Storage is deliberately left alone. Passing releaseReceipt=false
    // is what stops the old document's deletion from marking an object the new
    // document still points at.
    //
    // Sequenced rather than run through Future.wait: the add must not race the
    // remove, and a failed add must not leave the expense deleted.
    await removeExpense(previousExpense, null, false);
    final movedId = await addExpense(expense);
    if (movedId == null) {
      await rollbackReplacement();
      return false;
    }
    await releaseSuperseded();
    return true;
  }

  Future react(Expense expense, String reaction) {
    final self = AuthService().currentUser!.uid;
    List<Future<void>> futures = [
      _expenseCollection(expense.date).then((ref) => ref.doc(expense.id).update({
            'reactions': [...expense.reactions, reaction],
          }))
    ];
    if (self != expense.submittedBy) {
      futures.add(FirebaseFunctions.instance.httpsCallable("sendReactionNotification").call({
        'id': expense.submittedBy,
        'reactionEmoji': reaction,
      }));
    }
    return Future.wait(futures);
  }
}

final expenseModifierProvider = NotifierProvider<ExpenseNotifier, List<ExpenseWithCategoryData>>(ExpenseNotifier.new);

final expenseProvider = StreamProvider<List<ExpenseWithCategoryData>>((ref) {
  final firestore = ref.read(backendProvider);
  final user = ref.watch(userProvider).value;
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
  final user = ref.watch(userProvider).value;
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
      .map((snapshot) => snapshot.docs.fold<Map<DateTime, SummaryEntry>>(
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
      return <SummaryEntry>[];
    }
    // We need to fill any of the in between time with 0's
    final DateTime? dataStartData = points.keys.reduce(
      (minDate, date) => minDate.isBefore(date) ? minDate : date,
    );

    if (dataStartData == null) {
      return <SummaryEntry>[];
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
  }).doOnError((e, s) => print(e));
});

final latestSummaryDateProvider = StreamProvider<DateTime?>((ref) {
  final user = ref.watch(userProvider).value;
  final firestore = ref.read(backendProvider);

  if (user == null) {
    return Stream.value(null);
  }

  return firestore
      .collection('ledger')
      .doc(user.ledgerId)
      .collection('summaries')
      .orderBy('startDate', descending: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    return (data['startDate'] as Timestamp).toDate();
  });
});

/// Summaries for a single calendar month, keyed by the first instant of that
/// month (only the year and month components are significant).
///
/// Bounds the query to the requested month only. The 24h buffer on each side
/// absorbs the timezone skew in how `startDate` is written (local midnight of
/// the 1st, stored as a UTC instant). Without the upper bound, other months'
/// summaries (e.g. amortized expenses spread across months) leak in and the
/// form's per-category "Remaining" reflects an arbitrary month's total.
final monthSummaryProvider =
    StreamProvider.family<List<SummaryEntry>, DateTime>((ref, month) {
  final user = ref.watch(userProvider).value;
  final firestore = ref.read(backendProvider);
  final DateTime start = DateTime(month.year, month.month).subtract(const Duration(hours: 24));
  final DateTime end = DateTime(month.year, month.month + 1).subtract(const Duration(hours: 24));

  if (user == null) {
    return Stream.value([]);
  }

  return firestore
      .collection('ledger')
      .doc(user.ledgerId)
      .collection('summaries')
      .where('startDate', isGreaterThanOrEqualTo: start)
      .where('startDate', isLessThan: end)
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

/// Summaries for the month in progress.
final currentSummaryProvider = Provider<AsyncValue<List<SummaryEntry>>>((ref) {
  final now = DateTime.now();
  return ref.watch(monthSummaryProvider(DateTime(now.year, now.month)));
});

/// Summaries for the month that just closed. `DateTime` normalises month 0 to
/// December of the prior year, so no year-boundary special case is needed.
final previousMonthSummaryProvider =
    Provider<AsyncValue<List<SummaryEntry>>>((ref) {
  final now = DateTime.now();
  return ref.watch(monthSummaryProvider(DateTime(now.year, now.month - 1)));
});
