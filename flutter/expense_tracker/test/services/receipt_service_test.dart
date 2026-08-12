import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/services/receipt.service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

class MockReference extends Mock implements Reference {}

const ledgerId = 'ledger-1';
const receiptId = 'receipt-1';

/// A JPEG larger than the compression cap, used to prove downscaling happens.
Uint8List buildLargeJpeg({int width = 3000, int height = 2000}) {
  final image = img.Image(width: width, height: height);
  // A gradient rather than flat colour, so the encoder cannot trivially
  // collapse it and the size reduction being measured is real.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;
  late MockReference rootRef;
  late MockReference objectRef;
  late ReceiptService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
    rootRef = MockReference();
    objectRef = MockReference();

    // ref().child('receipts').child(ledgerId).child(receiptId)
    when(() => storage.ref()).thenReturn(rootRef);
    when(() => rootRef.child(any())).thenReturn(objectRef);
    when(() => objectRef.child(any())).thenReturn(objectRef);
    when(() => objectRef.delete()).thenAnswer((_) async {});

    service = ReceiptService(storage: storage, firestore: firestore);
  });

  Future<Map<String, dynamic>?> readMarker(String id) async {
    final doc = await firestore
        .collection(ReceiptService.markerCollection)
        .doc(id)
        .get();
    return doc.exists ? doc.data() : null;
  }

  group('prepare', () {
    test('downscales and re-encodes a large image', () async {
      final original = buildLargeJpeg();

      final compressed = await service.prepare(original);

      expect(compressed.lengthInBytes, lessThan(original.lengthInBytes));

      final decoded = img.decodeImage(compressed)!;
      final longestSide = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      expect(longestSide, ReceiptService.maxDimension);
      // 3000x2000 is 3:2; downscaling must preserve that.
      expect(decoded.height, closeTo(decoded.width * 2 / 3, 2));
    });

    test('does not upscale an image already under the cap', () async {
      final small = buildLargeJpeg(width: 400, height: 300);

      final decoded = img.decodeImage(await service.prepare(small))!;

      expect(decoded.width, 400);
      expect(decoded.height, 300);
    });

    test('rejects bytes that are not a decodable image', () async {
      final notAnImage = Uint8List.fromList(
        List<int>.generate(2048, (i) => i % 256),
      );

      expect(
        () => service.prepare(notAnImage),
        throwsA(isA<ReceiptException>().having(
          (e) => e.failure,
          'failure',
          ReceiptFailure.notAnImage,
        )),
      );
    });
  });

  group('release', () {
    test('writes a marker without deleting the object', () async {
      await service.release(ledgerId: ledgerId, receiptId: receiptId);

      final marker = await readMarker(receiptId);
      expect(marker, isNotNull);
      expect(marker!['ledgerId'], ledgerId);
      expect(marker['receiptId'], receiptId);
      verifyNever(() => objectRef.delete());
    });

    test('sets deleteAfter one backstop into the future', () async {
      final now = DateTime(2026, 5, 1, 12);

      await service.release(
        ledgerId: ledgerId,
        receiptId: receiptId,
        now: now,
      );

      final deleteAfter =
          (await readMarker(receiptId))!['deleteAfter'] as Timestamp;
      expect(deleteAfter.toDate(), now.add(ReceiptService.backstop));
    });

    test('releasing twice neither duplicates nor extends the backstop',
        () async {
      final first = DateTime(2026, 5, 1, 12);
      await service.release(
        ledgerId: ledgerId,
        receiptId: receiptId,
        now: first,
      );

      // A later release must not push the original eligibility out.
      await service.release(
        ledgerId: ledgerId,
        receiptId: receiptId,
        now: first.add(const Duration(hours: 6)),
      );

      final all = await firestore
          .collection(ReceiptService.markerCollection)
          .get();
      expect(all.docs, hasLength(1));

      final deleteAfter = all.docs.single.data()['deleteAfter'] as Timestamp;
      expect(deleteAfter.toDate(), first.add(ReceiptService.backstop));
    });
  });

  group('commitDeletion', () {
    test('deletes the object and then the marker', () async {
      await service.release(ledgerId: ledgerId, receiptId: receiptId);

      await service.commitDeletion(ledgerId: ledgerId, receiptId: receiptId);

      verify(() => objectRef.delete()).called(1);
      expect(await readMarker(receiptId), isNull);
    });

    test('treats an already-missing object as success', () async {
      when(() => objectRef.delete()).thenThrow(
        FirebaseException(plugin: 'storage', code: 'object-not-found'),
      );
      await service.release(ledgerId: ledgerId, receiptId: receiptId);

      await service.commitDeletion(ledgerId: ledgerId, receiptId: receiptId);

      expect(await readMarker(receiptId), isNull);
    });

    test('retains the marker when the object delete fails', () async {
      when(() => objectRef.delete()).thenThrow(
        FirebaseException(plugin: 'storage', code: 'retry-limit-exceeded'),
      );
      await service.release(ledgerId: ledgerId, receiptId: receiptId);

      await service.commitDeletion(ledgerId: ledgerId, receiptId: receiptId);

      // Marker survives so the nightly sweep retries.
      expect(await readMarker(receiptId), isNotNull);
    });
  });

  group('clearMarker', () {
    test('removes the marker and leaves the object alone', () async {
      await service.release(ledgerId: ledgerId, receiptId: receiptId);

      await service.clearMarker(receiptId);

      expect(await readMarker(receiptId), isNull);
      verifyNever(() => objectRef.delete());
    });

    test('is a no-op when no marker exists', () async {
      await service.clearMarker(receiptId);

      expect(await readMarker(receiptId), isNull);
    });
  });

  group('deleteUnreferenced', () {
    test('deletes inline without writing a marker', () async {
      await service.deleteUnreferenced(
        ledgerId: ledgerId,
        receiptId: receiptId,
      );

      verify(() => objectRef.delete()).called(1);
      expect(await readMarker(receiptId), isNull);
    });

    test('falls back to a marker when the inline delete fails', () async {
      when(() => objectRef.delete()).thenThrow(
        FirebaseException(plugin: 'storage', code: 'retry-limit-exceeded'),
      );

      await service.deleteUnreferenced(
        ledgerId: ledgerId,
        receiptId: receiptId,
      );

      // Never orphaned: the sweep will reclaim it.
      expect(await readMarker(receiptId), isNotNull);
    });
  });
}
