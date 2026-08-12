import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Builders for the documents the rollover flow reads and writes, so tests can
/// state the situation they care about instead of assembling raw maps.
///
/// The shapes here mirror production exactly: budget categories live in a
/// `budgetConfig` map on `ledger/{ledgerId}`, per-category-per-month roll-ups
/// live in `ledger/{ledgerId}/summaries/{YYYY_MON}_{categoryId}`, and the
/// rollover record lives under `rolloverStatus.{YYYY_MON}` on the ledger doc.
const String testLedgerId = 'ledger-1';
const String testUserId = 'user-1';
const String testPartnerId = 'user-2';

CategoryDataWithId category(
  String id, {
  required double budget,
  String? label,
  String icon = 'shopping',
  bool deleted = false,
}) {
  return CategoryDataWithId(
    id: id,
    label: label ?? id,
    icon: icon,
    budget: budget,
    deleted: deleted,
  );
}

SummaryEntry summary(
  String categoryId, {
  required double total,
  required DateTime month,
  int count = 1,
}) {
  return SummaryEntry(
    id: '${monthKeyFor(month)}_$categoryId',
    categoryId: categoryId,
    total: total,
    count: count,
    startDate: DateTime(month.year, month.month),
    lastUpdate: DateTime(month.year, month.month, 2),
  );
}

/// Mirrors `formatMonth` in lib/providers/expense_provider.dart without
/// importing it, so a change there is caught by a failing test rather than
/// silently tracked by the fixtures.
String monthKeyFor(DateTime date) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${date.year}_${months[date.month - 1]}';
}

/// A rollover status record as stored on the ledger document.
Map<String, dynamic> rolloverRecord({
  required String status,
  String claimedBy = testUserId,
  DateTime? claimedAt,
  DateTime? completedAt,
  double? total,
  String? sourceMonth,
}) {
  return {
    'status': status,
    'claimedBy': claimedBy,
    'claimedAt': Timestamp.fromDate(claimedAt ?? DateTime(2026, 9, 1, 8)),
    if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt),
    if (total != null) 'total': total,
    if (sourceMonth != null) 'sourceMonth': sourceMonth,
  };
}

/// Seeds a fake Firestore with a ledger, its budget config, and any summaries.
///
/// [summaries] is keyed by the month each entry belongs to, so a test can set
/// up "last month overspent, this month has an amortized charge already" in one
/// call.
Future<FakeFirebaseFirestore> seedLedger({
  FakeFirebaseFirestore? firestore,
  String ledgerId = testLedgerId,
  List<CategoryDataWithId> categories = const [],
  List<SummaryEntry> summaries = const [],
  Map<String, dynamic> rolloverStatus = const {},
}) async {
  final db = firestore ?? FakeFirebaseFirestore();

  await db.collection('ledger').doc(ledgerId).set({
    'budgetConfig': {
      for (final c in categories)
        c.id: {
          'label': c.label,
          'icon': c.icon,
          'budget': c.budget,
          'deleted': c.deleted,
        },
    },
    if (rolloverStatus.isNotEmpty) 'rolloverStatus': rolloverStatus,
  });

  for (final entry in summaries) {
    await db
        .collection('ledger')
        .doc(ledgerId)
        .collection('summaries')
        .doc(entry.id)
        .set({
      'categoryId': entry.categoryId,
      'total': entry.total,
      'count': entry.count,
      'startDate': Timestamp.fromDate(entry.startDate),
      'lastUpdate': Timestamp.fromDate(entry.lastUpdate),
    });
  }

  return db;
}

/// Seeds an `expenseUsers` document for the signed-in user.
Future<void> seedUser(
  FakeFirebaseFirestore db, {
  String userId = testUserId,
  String ledgerId = testLedgerId,
  DateTime? initialized,
  List<String> linkedAccountIds = const [],
}) async {
  await db.collection('expenseUsers').doc(userId).set({
    'firstName': 'Test',
    'lastName': 'User',
    'email': 'test@example.com',
    'ledgerId': ledgerId,
    'role': 'primary',
    'initialized': Timestamp.fromDate(initialized ?? DateTime(2025, 1, 1)),
    'userSettings': <String, String>{},
    'noteSuggestions': <String, List<String>>{},
    'linkedAccounts': [
      for (final id in linkedAccountIds)
        {'id': id, 'firstName': 'Partner', 'email': '$id@example.com'},
    ],
  });
}
