import 'package:expense_tracker/models/expense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense buildExpense({String? receiptId, String? imageUrl}) {
    return Expense(
      amount: 42.50,
      date: DateTime(2026, 3, 14),
      categoryId: 'groceries',
      submittedBy: 'user-1',
      note: 'weekly shop',
      id: 'expense-1',
      receiptId: receiptId,
      imageUrl: imageUrl,
    );
  }

  group('Expense receipt serialization', () {
    test('round-trips receiptId and imageUrl through toJson/fromJson', () {
      final original = buildExpense(
        receiptId: 'receipt-abc',
        imageUrl: 'https://example.com/receipt-abc.jpg',
      );

      final restored = Expense.fromJson(original.toJson());

      expect(restored.receiptId, 'receipt-abc');
      expect(restored.imageUrl, 'https://example.com/receipt-abc.jpg');
    });

    test('an expense without a receipt round-trips as null, not absent-as-empty', () {
      final restored = Expense.fromJson(buildExpense().toJson());

      expect(restored.receiptId, isNull);
      expect(restored.imageUrl, isNull);
    });

    test('ExpenseWithCategoryData carries the receipt fields', () {
      final json = buildExpense(
        receiptId: 'receipt-xyz',
        imageUrl: 'https://example.com/receipt-xyz.jpg',
      ).toJson();
      json['category'] = {
        'id': 'groceries',
        'label': 'Groceries',
        'icon': 'attach_money_outlined',
        'budget': 400.0,
        'deleted': false,
      };

      final restored = ExpenseWithCategoryData.fromJson(json);

      expect(restored.receiptId, 'receipt-xyz');
      expect(restored.imageUrl, 'https://example.com/receipt-xyz.jpg');
      expect(restored.toJson()['receiptId'], 'receipt-xyz');
    });
  });

  group('Expense.copyWith receipt handling', () {
    test('carries the receipt through a copy that changes unrelated fields', () {
      // Regression guard: the amortization path copies the template for every
      // installment, so a field missing from copyWith is silently dropped.
      final original = buildExpense(
        receiptId: 'receipt-abc',
        imageUrl: 'https://example.com/receipt-abc.jpg',
      );

      final copy = original.copyWith(amount: 10.0, categoryId: 'dining');

      expect(copy.amount, 10.0);
      expect(copy.categoryId, 'dining');
      expect(copy.receiptId, 'receipt-abc');
      expect(copy.imageUrl, 'https://example.com/receipt-abc.jpg');
    });

    test('replaces the receipt when new values are supplied', () {
      final original = buildExpense(
        receiptId: 'receipt-old',
        imageUrl: 'https://example.com/receipt-old.jpg',
      );

      final copy = original.copyWith(
        receiptId: 'receipt-new',
        imageUrl: 'https://example.com/receipt-new.jpg',
      );

      expect(copy.receiptId, 'receipt-new');
      expect(copy.imageUrl, 'https://example.com/receipt-new.jpg');
    });

    test('clearReceipt removes both fields, which passing null cannot do', () {
      final original = buildExpense(
        receiptId: 'receipt-abc',
        imageUrl: 'https://example.com/receipt-abc.jpg',
      );

      // Passing null relies on `?? this.x` and therefore carries forward.
      final notCleared = original.copyWith(receiptId: null, imageUrl: null);
      expect(notCleared.receiptId, 'receipt-abc');

      final cleared = original.copyWith(clearReceipt: true);
      expect(cleared.receiptId, isNull);
      expect(cleared.imageUrl, isNull);
      // Clearing the receipt must not disturb anything else.
      expect(cleared.amount, original.amount);
      expect(cleared.categoryId, original.categoryId);
    });

    test('clearReceipt on an expense with no receipt is a no-op', () {
      final cleared = buildExpense().copyWith(clearReceipt: true);

      expect(cleared.receiptId, isNull);
      expect(cleared.imageUrl, isNull);
    });
  });
}
