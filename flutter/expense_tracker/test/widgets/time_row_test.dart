import 'package:expense_tracker/models/time_filter_option.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:expense_tracker/widgets/time_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// The month picker is a single list covering both future and past months, so
/// its order is the only thing telling a reader how the months relate. Anything
/// other than one continuous reverse-chronological run puts a month far from
/// the months it neighbours in time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();

  String labelFor(int monthsFromNow) {
    final d = DateTime(now.year, now.month + monthsFromNow, 1);
    return '${d.year} ${DateFormat('MMMM').format(d)}';
  }

  /// [initialTime] is the account's creation date in production, and it sets
  /// how far back the menu reaches. Six months by default, so a test that is
  /// about ordering is not also about a brand-new account.
  Future<List<String>> optionLabels(
    WidgetTester tester, {
    DateTime? latestSummary,
    DateTime? initialTime,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          latestSummaryDateProvider
              .overrideWith((ref) => Stream.value(latestSummary)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TimeRow(
              initialTime:
                  initialTime ?? DateTime(now.year, now.month - 6, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final menu = tester.widget<DropdownMenu<TimeFilterOption>>(
      find.byType(DropdownMenu<TimeFilterOption>),
    );
    return menu.dropdownMenuEntries.map((e) => e.label).toList();
  }

  testWidgets('next month sits directly above the current month',
      (tester) async {
    // The reported problem: with several months of future spend, next month
    // was generated first and so appeared at the very top of the menu, far
    // from the current month it actually neighbours.
    final labels = await optionLabels(
      tester,
      latestSummary: DateTime(now.year, now.month + 3, 1),
    );

    final current = labels.indexOf(labelFor(0));
    expect(labels[current - 1], labelFor(1));
  });

  testWidgets('the whole list runs from the furthest future backwards',
      (tester) async {
    final labels = await optionLabels(
      tester,
      latestSummary: DateTime(now.year, now.month + 3, 1),
    );

    expect(labels.take(5).toList(), [
      labelFor(3),
      labelFor(2),
      labelFor(1),
      labelFor(0),
      labelFor(-1),
    ]);
  });

  testWidgets('every step down the list is exactly one month earlier',
      (tester) async {
    final labels = await optionLabels(
      tester,
      latestSummary: DateTime(now.year, now.month + 2, 1),
    );

    final expected = List.generate(
      labels.length,
      (i) => labelFor(2 - i),
    );
    expect(labels, expected);
  });

  testWidgets('the current month leads when there is no future spend',
      (tester) async {
    final labels = await optionLabels(tester);

    expect(labels.first, labelFor(0));
    expect(labels[1], labelFor(-1));
  });

  testWidgets('a brand-new account is offered only the month it opened in',
      (tester) async {
    final labels = await optionLabels(tester, initialTime: now);

    expect(labels, [labelFor(0)]);
  });

  testWidgets('a summary in the past adds no future months', (tester) async {
    final labels = await optionLabels(
      tester,
      latestSummary: DateTime(now.year, now.month - 2, 1),
    );

    expect(labels.first, labelFor(0));
  });

  testWidgets('the months are unique and none is skipped', (tester) async {
    final labels = await optionLabels(
      tester,
      latestSummary: DateTime(now.year, now.month + 4, 1),
    );

    expect(labels.toSet(), hasLength(labels.length));
  });

  testWidgets('the history reaches back a year and stops', (tester) async {
    // An initialTime older than a year is capped at 13 entries, so the menu
    // stays navigable no matter how old the ledger is.
    final labels = await optionLabels(
      tester,
      initialTime: DateTime(now.year - 5, now.month, 1),
    );

    expect(labels, hasLength(13));
    expect(labels.first, labelFor(0));
    expect(labels.last, labelFor(-12));
  });
}
