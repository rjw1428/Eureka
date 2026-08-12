import 'dart:typed_data';

import 'package:expense_tracker/services/receipt.service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final first = Uint8List.fromList([1, 2, 3]);
  final second = Uint8List.fromList([4, 5, 6]);

  group('editing an expense that already has a receipt', () {
    ReceiptSelection build() => ReceiptSelection(hadExistingReceipt: true);

    test('untouched resolves to unchanged', () {
      final selection = build();

      expect(selection.intent, isA<ReceiptUnchanged>());
      expect(selection.hasReceipt, isTrue);
    });

    test('picking resolves to a replacement', () {
      final selection = build()..pick(first);

      expect(selection.intent, isA<ReceiptReplaced>());
      expect((selection.intent as ReceiptReplaced).bytes, first);
    });

    test('removing resolves to a removal', () {
      final selection = build()..remove();

      expect(selection.intent, isA<ReceiptRemoved>());
      expect(selection.hasReceipt, isFalse);
    });

    test('remove then pick resolves as a replacement, not a removal', () {
      final selection = build()
        ..remove()
        ..pick(first);

      expect(selection.intent, isA<ReceiptReplaced>());
      expect(selection.hasReceipt, isTrue);
    });

    test('pick then remove resolves as a removal', () {
      final selection = build()
        ..pick(first)
        ..remove();

      expect(selection.intent, isA<ReceiptRemoved>());
      expect(selection.pickedBytes, isNull);
    });

    test('picking twice keeps only the most recent image', () {
      final selection = build()
        ..pick(first)
        ..pick(second);

      expect((selection.intent as ReceiptReplaced).bytes, second);
    });
  });

  group('creating an expense with no existing receipt', () {
    ReceiptSelection build() => ReceiptSelection(hadExistingReceipt: false);

    test('untouched resolves to unchanged and shows no receipt', () {
      final selection = build();

      expect(selection.intent, isA<ReceiptUnchanged>());
      expect(selection.hasReceipt, isFalse);
    });

    test('picking resolves to a replacement', () {
      final selection = build()..pick(first);

      expect(selection.intent, isA<ReceiptReplaced>());
      expect(selection.hasReceipt, isTrue);
    });

    test('removing when there was never a receipt is a no-op, not a removal',
        () {
      final selection = build()..remove();

      // Emitting ReceiptRemoved here would ask the data layer to release an
      // object that never existed.
      expect(selection.intent, isA<ReceiptUnchanged>());
      expect(selection.hasReceipt, isFalse);
    });
  });

  test('abandoning an edit leaves the stored expense untouched', () {
    // The form owns this object, so dismissing without submitting simply
    // discards it — the intent is never delivered.
    final selection = ReceiptSelection(hadExistingReceipt: true)..remove();

    expect(selection.intent, isA<ReceiptRemoved>());
    // A fresh selection for the same expense is back to unchanged.
    expect(
      ReceiptSelection(hadExistingReceipt: true).intent,
      isA<ReceiptUnchanged>(),
    );
  });
}
