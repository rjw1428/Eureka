import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/receipt.service.dart';
import 'package:expense_tracker/widgets/expense_form.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/expense_fixtures.dart';

/// The form decides what an expense *is* before any provider sees it, so a
/// field it silently drops cannot be recovered downstream. These tests assert
/// the submitted payload rather than the pixels.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final groceries = CategoryDataWithIdAndDelta(
    id: 'groceries',
    label: 'Groceries',
    icon: 'shopping',
    budget: 500,
    delta: 500,
  );

  late List<Expense> submitted;
  late List<ReceiptIntent> intents;
  late FakeFunctions functions;

  setUp(() {
    submitted = [];
    intents = [];
    functions = FakeFunctions();
  });

  /// Pushes the form onto a real route, because submitting ends in a
  /// `Navigator.pop` that needs something to pop.
  Future<void> pumpForm(
    WidgetTester tester, {
    ExpenseWithCategoryData? initialExpense,
    List<CategoryDataWithIdAndDelta>? categories,
  }) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendProvider.overrideWithValue(db),
          functionsProvider.overrideWithValue(functions),
          receiptServiceProvider.overrideWithValue(buildReceiptService()),
          userProvider.overrideWith((ref) => Stream.value(buildUser())),
          activeBudgetCategoriesWithSpend.overrideWithValue(AsyncData(categories ?? [groceries])),
        ],
        child: MaterialApp(
          // The user stream is watched from the host page so it has resolved
          // before the form is pushed, mirroring the app, where the form only
          // opens from a screen that already has a user.
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(userProvider);
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: ExpenseForm(
                          initialExpense: initialExpense,
                          onRemove: (_) {},
                          onSubmit: (expense, receipt) {
                            submitted.add(expense);
                            intents.add(receipt);
                          },
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  ExpenseWithCategoryData existing({
    double amount = 90,
    AmortizationDetails? amortized,
  }) =>
      ExpenseWithCategoryData.fromJson({
        'id': 'expense-1',
        'amount': amount,
        'date': DateTime(2026, 3, 10).toIso8601String(),
        'categoryId': 'groceries',
        'submittedBy': testUserId,
        'reactions': <String>[],
        'amortized': amortized?.toJson(),
        'category': {
          'id': 'groceries',
          'label': 'Groceries',
          'icon': 'shopping',
          'budget': 500,
        },
      });

  Future<void> setAmount(WidgetTester tester, String value) async {
    await tester.ensureVisible(find.widgetWithText(TextField, 'Amount'));
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), value);
    await tester.pump();
  }

  /// The amortization controls live behind the collapsed "Advanced" section,
  /// so every test that touches them has to open it first.
  Future<void> openAdvanced(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Advanced'));
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
  }

  Future<void> toggleAmortize(WidgetTester tester) async {
    await openAdvanced(tester);
    await tester.ensureVisible(find.text('Amortize expense'));
    await tester.tap(find.text('Amortize expense'));
    await tester.pumpAndSettle();
  }

  Future<void> setMonths(WidgetTester tester, String value) async {
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Number of Months (2-24)'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Number of Months (2-24)'),
      value,
    );
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester, {String label = 'Save'}) async {
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, label));
    await tester.tap(find.widgetWithText(ElevatedButton, label));
    await tester.pumpAndSettle();
  }

  Future<void> pickCategory(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries').last);
    await tester.pumpAndSettle();
  }


  group('turning amortization on while editing', () {
    testWidgets('the submitted expense carries the amortization details', (tester) async {
      // Regression: the edit path built the expense without ever reading the
      // toggle, so the update looked ordinary — the month kept its full amount
      // and no later month was ever created.
      await pumpForm(tester, initialExpense: existing(amount: 90));

      await toggleAmortize(tester);
      await setMonths(tester, '3');
      await submit(tester, label: 'Update');

      expect(submitted, hasLength(1));
      expect(submitted.single.amortized, isNotNull,
          reason: 'without this the provider takes the plain-update path');
      expect(submitted.single.amortized!.over, 3);
      expect(submitted.single.id, 'expense-1');
    });

    testWidgets('the entered amount is submitted as the total to divide', (tester) async {
      await pumpForm(tester, initialExpense: existing(amount: 90));

      await toggleAmortize(tester);
      await setMonths(tester, '3');
      await setAmount(tester, '90');
      await submit(tester, label: 'Update');

      expect(submitted.single.amount, 90,
          reason: 'the provider divides; pre-dividing here would double-split');
    });

    testWidgets('an out-of-range month count is rejected and nothing submits', (tester) async {
      await pumpForm(tester, initialExpense: existing());

      await toggleAmortize(tester);
      await setMonths(tester, '1');
      await submit(tester, label: 'Update');

      expect(find.text('Invalid Amortization Months'), findsOneWidget);
      expect(submitted, isEmpty);
    });

    testWidgets('a month count above the cap is rejected too', (tester) async {
      await pumpForm(tester, initialExpense: existing());

      await toggleAmortize(tester);
      await setMonths(tester, '25');
      await submit(tester, label: 'Update');

      expect(find.text('Invalid Amortization Months'), findsOneWidget);
      expect(submitted, isEmpty);
    });

    testWidgets('leaving the toggle off submits a plain expense', (tester) async {
      await pumpForm(tester, initialExpense: existing());

      await submit(tester, label: 'Update');

      expect(submitted.single.amortized, isNull);
    });
  });

  group('an expense already in a series', () {
    final details = AmortizationDetails(groupId: 'group-1', index: 1, over: 4);

    testWidgets('opens with the toggle on and locked', (tester) async {
      await pumpForm(
        tester,
        initialExpense: existing(amount: 25, amortized: details),
      );

      await openAdvanced(tester);

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Amortize expense'),
      );
      expect(toggle.value, isTrue);
      expect(toggle.onChanged, isNull, reason: 'a series cannot be un-amortized from the form');
    });

    testWidgets('shows its month count, which cannot be edited', (tester) async {
      await pumpForm(
        tester,
        initialExpense: existing(amount: 25, amortized: details),
      );

      await openAdvanced(tester);

      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Number of Months (2-24)'),
      );
      expect(field.controller!.text, '4');
      expect(field.enabled, isFalse);
    });

    testWidgets('submits the series it already belongs to', (tester) async {
      // Regression: an edit used to submit a plain expense, which sent the
      // update down the de-amortize path and left a duplicate document behind.
      await pumpForm(
        tester,
        initialExpense: existing(amount: 25, amortized: details),
      );

      await submit(tester, label: 'Update');

      expect(submitted.single.amortized, isNotNull);
      expect(submitted.single.amortized!.over, 4);
      expect(submitted.single.amortized!.groupId, 'group-1',
          reason: 'the series keeps its identity across an edit');
    });

    testWidgets('scales the per-month amount back up to the series total',
        (tester) async {
      await pumpForm(
        tester,
        initialExpense: existing(amount: 25, amortized: details),
      );

      await setAmount(tester, '30');
      await submit(tester, label: 'Update');

      expect(submitted.single.amount, 120,
          reason: '30 a month over 4 months; the provider divides it again');
    });

    testWidgets('opens showing the per-month amount, not the total', (tester) async {
      await pumpForm(
        tester,
        initialExpense: existing(amount: 25, amortized: details),
      );

      final amount = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Amount'),
      );
      expect(amount.controller!.text, '25.00');
    });
  });

  group('adding a new expense', () {
    testWidgets('an amortized add submits the total and the month count', (tester) async {
      await pumpForm(tester);

      await pickCategory(tester);
      await setAmount(tester, '300');
      await toggleAmortize(tester);
      await setMonths(tester, '3');
      await submit(tester);

      expect(submitted.single.amount, 300);
      expect(submitted.single.amortized!.over, 3);
      expect(submitted.single.id, isNull);
    });

    testWidgets('a plain add submits no amortization', (tester) async {
      await pumpForm(tester);

      await pickCategory(tester);
      await setAmount(tester, '42');
      await submit(tester);

      expect(submitted.single.amount, 42);
      expect(submitted.single.amortized, isNull);
    });

    testWidgets('a zero amount is rejected', (tester) async {
      await pumpForm(tester);

      await pickCategory(tester);
      await setAmount(tester, '0');
      await submit(tester);

      expect(find.text('Invalid Amount'), findsOneWidget);
      expect(submitted, isEmpty);
    });

    testWidgets('a non-numeric amount is rejected', (tester) async {
      await pumpForm(tester);

      await pickCategory(tester);
      await setAmount(tester, 'abc');
      await submit(tester);

      expect(find.text('Invalid Amount'), findsOneWidget);
      expect(submitted, isEmpty);
    });

    testWidgets('an expense with no category is rejected', (tester) async {
      await pumpForm(tester);

      await setAmount(tester, '42');
      await submit(tester);

      expect(find.text('Invalid Category'), findsOneWidget);
      expect(submitted, isEmpty);
    });

    testWidgets('a subtraction in the amount field is evaluated on submit', (tester) async {
      await pumpForm(tester);

      await pickCategory(tester);
      await setAmount(tester, '50-12.50');
      await submit(tester);

      expect(submitted.single.amount, 37.5);
    });
  });

  group('the overspend notification', () {
    final nearlySpent = CategoryDataWithIdAndDelta(
      id: 'groceries',
      label: 'Groceries',
      icon: 'shopping',
      budget: 500,
      delta: 60,
    );

    testWidgets('fires when a plain expense pushes the category over', (tester) async {
      await pumpForm(tester, categories: [nearlySpent]);

      await pickCategory(tester);
      await setAmount(tester, '90');
      await submit(tester);

      final call = functions.lastCallTo('sendBudgetNotification');
      expect(call, isNotNull);
      expect(call!.payload['amount'], 90);
    });

    testWidgets('does not fire when only this month\'s installment is charged', (tester) async {
      // 90 over three months is 30 against a 60 remaining budget: the total
      // would overspend, the installment does not.
      await pumpForm(tester, categories: [nearlySpent]);

      await pickCategory(tester);
      await setAmount(tester, '90');
      await toggleAmortize(tester);
      await setMonths(tester, '3');
      await submit(tester);

      expect(functions.callsTo('sendBudgetNotification'), isEmpty);
    });

    testWidgets(
        'fires on the installment when the installment itself is too '
        'large', (tester) async {
      await pumpForm(tester, categories: [nearlySpent]);

      await pickCategory(tester);
      await setAmount(tester, '300');
      await toggleAmortize(tester);
      await setMonths(tester, '3');
      await submit(tester);

      final call = functions.lastCallTo('sendBudgetNotification');
      expect(call, isNotNull);
      expect(call!.payload['amount'], 100,
          reason: 'the notification reports the monthly charge, not the total');
    });

    testWidgets('charges an existing series\' amount as-is', (tester) async {
      // An expense already in a series stores the per-month figure, so it must
      // not be divided a second time.
      await pumpForm(
        tester,
        initialExpense: existing(
          amount: 90,
          amortized: AmortizationDetails(groupId: 'g', index: 1, over: 3),
        ),
        categories: [nearlySpent],
      );

      await submit(tester, label: 'Update');

      final call = functions.lastCallTo('sendBudgetNotification');
      expect(call, isNotNull);
      expect(call!.payload['amount'], 90);
    });
  });
}
