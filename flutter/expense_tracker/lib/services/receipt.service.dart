import 'dart:async' show Timer;
import 'dart:typed_data' show Uint8List;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Where a receipt image comes from. Web only ever offers [gallery], which the
/// picker surfaces as a file-upload dialog.
enum ReceiptSource { camera, gallery }

/// Why a receipt operation could not be completed. The UI maps these to
/// distinct messages — a permission problem and a network problem are not the
/// same thing to a user.
enum ReceiptFailure { notAnImage, tooLarge, permissionDenied, network, unknown }

class ReceiptException implements Exception {
  ReceiptException(this.failure, [this.cause]);

  final ReceiptFailure failure;
  final Object? cause;

  @override
  String toString() => 'ReceiptException($failure, $cause)';
}

/// What the user did to an expense's receipt while editing it.
///
/// Modelled explicitly rather than inferred from whether `imageUrl` is null.
/// The proof-of-concept inferred it, which made "kept the existing receipt" and
/// "chose a new one" indistinguishable and silently discarded replacements.
sealed class ReceiptIntent {
  const ReceiptIntent();
}

/// Leave whatever receipt the expense already had.
class ReceiptUnchanged extends ReceiptIntent {
  const ReceiptUnchanged();
}

/// Attach these bytes, superseding any existing receipt.
class ReceiptReplaced extends ReceiptIntent {
  const ReceiptReplaced(this.bytes);

  final Uint8List bytes;
}

/// Detach the existing receipt, leaving the expense without one.
class ReceiptRemoved extends ReceiptIntent {
  const ReceiptRemoved();
}

/// The form's pending receipt state, as a small state machine.
///
/// Extracted from the widget so the transitions are testable directly: the
/// interesting cases (remove-then-pick, pick-then-pick, abandoning an edit) are
/// exactly where inferring intent from a nullable URL went wrong before.
class ReceiptSelection {
  ReceiptSelection({this.hadExistingReceipt = false});

  /// Whether the expense being edited already carried a receipt.
  final bool hadExistingReceipt;

  Uint8List? _picked;
  bool _removed = false;

  Uint8List? get pickedBytes => _picked;
  bool get isRemoved => _removed;

  /// True when submitting now would leave the expense with a receipt.
  bool get hasReceipt => _picked != null || (hadExistingReceipt && !_removed);

  /// Choosing an image always supersedes a pending removal — remove-then-pick
  /// is a replacement, not a removal.
  void pick(Uint8List bytes) {
    _picked = bytes;
    _removed = false;
  }

  /// Dropping the receipt discards any pending pick as well.
  void remove() {
    _picked = null;
    _removed = true;
  }

  ReceiptIntent get intent {
    if (_picked != null) return ReceiptReplaced(_picked!);
    // Removing an expense that never had a receipt is a no-op, not a removal.
    if (_removed && hadExistingReceipt) return const ReceiptRemoved();
    return const ReceiptUnchanged();
  }
}

/// A receipt that has been uploaded and is ready to be referenced by an
/// expense. Both fields are written to the expense document together.
class UploadedReceipt {
  const UploadedReceipt({required this.receiptId, required this.imageUrl});

  final String receiptId;
  final String imageUrl;
}

/// Argument bundle for [_compressInIsolate]; must be sendable across isolates.
class _CompressRequest {
  const _CompressRequest(this.bytes, this.maxDimension, this.quality);

  final Uint8List bytes;
  final int maxDimension;
  final int quality;
}

/// Decodes, downscales and re-encodes as JPEG. Returns null when the bytes are
/// not a decodable image, which doubles as our content-type check — a file
/// renamed to `.jpg` fails here rather than reaching Storage.
///
/// Top-level so it can run under [compute].
Uint8List? _compressInIsolate(_CompressRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return null;

  final longestSide =
      decoded.width > decoded.height ? decoded.width : decoded.height;

  // Only ever downscale. An image already under the cap keeps its dimensions
  // rather than being blown up to meet it.
  final resized = longestSide > request.maxDimension
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? request.maxDimension : null,
          height: decoded.height > decoded.width ? request.maxDimension : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;

  return img.encodeJpg(resized, quality: request.quality);
}

/// Owns everything that touches receipt bytes or Storage: picking, validating,
/// compressing, uploading, and the deferred-deletion bookkeeping.
///
/// Deliberately bytes-only (`Uint8List`) with no `dart:io` anywhere, so one
/// code path serves iOS, Android and web. Constructing a `File` from a picked
/// image throws on web, which is the trap this interface exists to avoid.
class ReceiptService {
  ReceiptService({
    required FirebaseStorage storage,
    required FirebaseFirestore firestore,
    ImagePicker? picker,
    Uuid? uuid,
    Duration? undoWindow,
  })  : _storage = storage,
        _firestore = firestore,
        _picker = picker ?? ImagePicker(),
        _uuid = uuid ?? const Uuid(),
        undoWindow = undoWindow ?? defaultUndoWindow;

  /// Injectable so tests can collapse the wait instead of sleeping through it.
  final Duration undoWindow;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final ImagePicker _picker;
  final Uuid _uuid;

  /// Client-side ceiling, enforced before any bytes move so the user gets an
  /// actionable message instead of an opaque Storage rejection. The rules carry
  /// a higher (10 MB) ceiling purely as an abuse backstop.
  static const int maxUploadBytes = 4 * 1024 * 1024;
  static const int maxDimension = 1600;
  static const int jpegQuality = 70;

  /// How long a released object survives before the nightly sweep may reclaim
  /// it. Far longer than the undo snackbar, so the sweep can never race a live
  /// undo or an in-flight commit.
  static const Duration backstop = Duration(hours: 24);

  static const String markerCollection = 'receipt_deletions';
  static const String _contentType = 'image/jpeg';

  CollectionReference<Map<String, dynamic>> get _markers =>
      _firestore.collection(markerCollection);

  Reference _objectRef(String ledgerId, String receiptId) =>
      _storage.ref().child('receipts').child(ledgerId).child(receiptId);

  /// Picks an image and returns it compressed and ready to upload, or null if
  /// the user dismissed the picker.
  ///
  /// Throws [ReceiptException] for a non-image selection or for bytes that are
  /// still over [maxUploadBytes] after compression.
  Future<Uint8List?> pickAndPrepare(ReceiptSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source == ReceiptSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // Passing the picker's own hints is harmless where honoured and ignored
      // where not; the compression below is what we actually rely on.
      maxWidth: maxDimension.toDouble(),
      maxHeight: maxDimension.toDouble(),
      imageQuality: jpegQuality,
    );

    if (picked == null) return null;

    final raw = await picked.readAsBytes();
    return prepare(raw);
  }

  /// Compresses and validates raw image bytes. Split out from [pickAndPrepare]
  /// so it is testable without a picker.
  Future<Uint8List> prepare(Uint8List raw) async {
    final compressed = await compute(
      _compressInIsolate,
      _CompressRequest(raw, maxDimension, jpegQuality),
    );

    if (compressed == null) {
      throw ReceiptException(ReceiptFailure.notAnImage);
    }
    if (compressed.lengthInBytes > maxUploadBytes) {
      throw ReceiptException(ReceiptFailure.tooLarge);
    }
    return compressed;
  }

  /// Uploads bytes under a freshly generated receipt id and resolves the
  /// download URL.
  ///
  /// A new id every time: replacement never overwrites in place, so the
  /// existing receipt stays intact until the expense document has durably moved
  /// to the new one.
  Future<UploadedReceipt> upload({
    required String ledgerId,
    required Uint8List bytes,
  }) async {
    try {
      return await _attemptUpload(ledgerId, bytes);
    } on ReceiptException catch (e) {
      // A permission denial most often means the token predates the user's
      // current `ledgerId` claim — for instance right after linking accounts.
      // Refresh once and retry before telling them they lack access.
      if (e.failure != ReceiptFailure.permissionDenied ||
          onPermissionDenied == null) {
        rethrow;
      }
      await onPermissionDenied!();
      return _attemptUpload(ledgerId, bytes);
    }
  }

  /// Invoked once when Storage reports a permission failure, to give the app a
  /// chance to refresh the ID token before the operation is retried.
  Future<void> Function()? onPermissionDenied;

  Future<UploadedReceipt> _attemptUpload(
    String ledgerId,
    Uint8List bytes,
  ) async {
    final receiptId = _uuid.v4();
    final ref = _objectRef(ledgerId, receiptId);

    try {
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _contentType),
      );
      final url = await ref.getDownloadURL();
      return UploadedReceipt(receiptId: receiptId, imageUrl: url);
    } on FirebaseException catch (e) {
      throw ReceiptException(_classify(e), e);
    }
  }

  /// Marks an object for deletion without removing it, so an undo can still
  /// restore a working receipt, and schedules the deletion for once the undo
  /// window has passed.
  ///
  /// Scheduling here rather than at the call site means no caller can release
  /// an object and forget to commit it — the previous arrangement, where the
  /// UI was responsible for committing, left objects stranded whenever that
  /// path did not complete.
  ///
  /// Idempotent: releasing an already-released object neither duplicates the
  /// marker nor pushes its backstop further out.
  ///
  /// Pass [scheduleCommitAfter] as false only when the caller genuinely wants
  /// the object left to the nightly sweep.
  Future<void> release({
    required String ledgerId,
    required String receiptId,
    DateTime? now,
    bool scheduleCommitAfter = true,
  }) async {
    final doc = _markers.doc(receiptId);
    final deleteAfter = (now ?? DateTime.now()).add(backstop);

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(doc);
      if (existing.exists) return;
      tx.set(doc, {
        'ledgerId': ledgerId,
        'receiptId': receiptId,
        'deleteAfter': Timestamp.fromDate(deleteAfter),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    if (scheduleCommitAfter) {
      scheduleCommit(ledgerId: ledgerId, receiptId: receiptId);
    }
  }

  /// How long a released object is held before its deletion is committed.
  /// Comfortably longer than the undo snackbar, so an undo always wins the
  /// race, and short enough that storage tracks what is actually referenced.
  static const Duration defaultUndoWindow = Duration(seconds: 6);

  /// Pending commits, keyed by receipt id, so an undo can cancel one.
  final Map<String, Timer> _pendingCommits = {};

  /// Schedules the deletion of a released object once the undo window closes.
  ///
  /// Deliberately driven by a timer owned by this service rather than by
  /// awaiting the undo snackbar's `closed` future. Cleanup must not depend on a
  /// widget staying mounted, a route surviving, or a UI future resolving — an
  /// earlier version tied it to the snackbar and cleanup silently never ran.
  ///
  /// Best effort by design: if the app dies before the timer fires, the marker
  /// remains and the nightly sweep reclaims the object.
  void scheduleCommit({
    required String ledgerId,
    required String receiptId,
  }) {
    _pendingCommits.remove(receiptId)?.cancel();
    _pendingCommits[receiptId] = Timer(undoWindow, () {
      _pendingCommits.remove(receiptId);
      commitDeletion(ledgerId: ledgerId, receiptId: receiptId);
    });
  }

  /// Commits a released object's deletion: removes the object, then its marker.
  ///
  /// Never throws — a background cleanup failure is not the user's problem, and
  /// the marker surviving means the sweep will retry. But it is recorded on the
  /// marker so the failure is diagnosable from Firestore without a device
  /// attached, which an earlier log-only version was not.
  Future<void> commitDeletion({
    required String ledgerId,
    required String receiptId,
  }) async {
    try {
      await _deleteObject(ledgerId, receiptId);
      await _markers.doc(receiptId).delete();
    } catch (e) {
      debugPrint(
        'Receipt deletion not committed for $receiptId; '
        'marker retained for the sweep: $e',
      );
      await _recordCommitFailure(receiptId, e);
    }
  }

  /// Annotates a marker with why its commit failed, so the next failure can be
  /// diagnosed by reading Firestore rather than by reproducing on a device.
  ///
  /// The marker's `update` rule denies client writes, so this is attempted and
  /// allowed to fail; it is diagnostics, not correctness.
  Future<void> _recordCommitFailure(String receiptId, Object error) async {
    try {
      await _markers.doc(receiptId).set({
        'lastCommitAttempt': FieldValue.serverTimestamp(),
        'lastCommitError': error.toString(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not record commit failure for $receiptId: $e');
    }
  }

  /// Cancels a pending deletion, returning the object to active use. Called on
  /// undo.
  Future<void> clearMarker(String receiptId) async {
    // Cancel the scheduled commit first: an undo that only removed the marker
    // would still lose the object when the timer fired.
    _pendingCommits.remove(receiptId)?.cancel();
    try {
      await _markers.doc(receiptId).delete();
    } catch (e) {
      // The restore itself already succeeded; the object is now at risk of
      // backstop reclamation, which is worth a log but not a rollback.
      debugPrint('Failed to clear deletion marker for $receiptId: $e');
    }
  }

  /// Immediately deletes an object that was never referenced by a saved
  /// expense — the compensating path when a write fails after an upload.
  ///
  /// If the delete fails, a marker is written instead so the object still gets
  /// reclaimed rather than orphaned indefinitely.
  Future<void> deleteUnreferenced({
    required String ledgerId,
    required String receiptId,
  }) async {
    try {
      await _deleteObject(ledgerId, receiptId);
    } catch (e) {
      debugPrint('Inline delete of $receiptId failed, falling back to a '
          'deletion marker: $e');
      try {
        await release(ledgerId: ledgerId, receiptId: receiptId);
      } catch (markerError) {
        debugPrint('Could not mark $receiptId for deletion either. The object '
            'is orphaned: $markerError');
      }
    }
  }

  /// Deletes the stored object, treating an already-absent object as success.
  Future<void> _deleteObject(String ledgerId, String receiptId) async {
    try {
      await _objectRef(ledgerId, receiptId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }

  ReceiptFailure _classify(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'permission-denied':
        return ReceiptFailure.permissionDenied;
      case 'retry-limit-exceeded':
      case 'canceled':
        return ReceiptFailure.network;
      default:
        return ReceiptFailure.unknown;
    }
  }
}

final receiptServiceLabels = <ReceiptFailure, String>{
  ReceiptFailure.notAnImage: 'That file is not an image.',
  ReceiptFailure.tooLarge:
      'That image is too large to attach, even after compression.',
  ReceiptFailure.permissionDenied:
      'You do not have permission to save receipts for this ledger.',
  ReceiptFailure.network:
      'Could not reach the server. Check your connection and try again.',
  ReceiptFailure.unknown: 'Something went wrong attaching that receipt.',
};
