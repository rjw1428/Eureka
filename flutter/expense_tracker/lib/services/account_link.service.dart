import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/pending_request.dart';
import 'package:expense_tracker/models/response.dart';
import 'package:rxdart/transformers.dart';

class AccountLinkService {
  AccountLinkService._internal();
  FirebaseFunctions functions = FirebaseFunctions.instance;
  static final _instance = AccountLinkService._internal();
  factory AccountLinkService() {
    return _instance;
  }
  final _db = FirebaseFirestore.instance;

  Future<Response> sendLinkRequest(String email, String requestingUser) async {
    try {
      await _db.collection('pendingShareRequests').add(
        {
          'targetEmail': email,
          'requestingUser': requestingUser,
        },
      );
      return const Response(success: true);
    } catch (e) {
      return Response(success: false, message: e.toString());
    }
  }

  Stream<List<PendingRequest>> pendingLinkRequestList(String userId) {
    return _db
        .collection('pendingShareRequests')
        .where('requestingUser', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PendingRequest.fromJson({...doc.data(), 'id': doc.id});
      }).toList();
    }).startWith([]);
  }

  Future acceptLinkRequest(PendingRequest request, String userId) async {
    await _db.collection('expenseUsers').doc(userId).update({
      'notification': null,
      'role': 'secondary',
      'ledgerId': request.requestingUserLedgerId,
      'backupLedgerId': request.targetCurrentLedgerId,
      'linkedAccounts': FieldValue.arrayUnion([
        {
          'id': request.requestingUser,
          'email': request.requestingUserEmail,
        },
      ])
    });

    return functions.httpsCallable("triggerLinkedAccount").call({
      'requestId': request.id,
    });
  }

  Future<void> clearNotification(String userId) {
    return _db.collection('expenseUsers').doc(userId).update({
      'notification': null,
    });
  }

  // When a user rejects, they can clear they're own pending request
  Future rejectLinRequest(PendingRequest request) async {
    await clearNotification(request.targetUserId!);
    return _db.collection('pendingShareRequests').doc(request.id).delete();
  }

  // When a user deletes the request, they need a cloud function to remove the target's pending request
  Future<void> removeRequest(PendingRequest request) {
    return Future.wait([
      _db.collection('pendingShareRequests').doc(request.id).delete(),
      functions.httpsCallable("clearLinkRequest").call({
        'targetId': request.targetUserId,
      })
    ]);
  }

  Future onUnlink(Map<String, String> linkedAccount, ExpenseUser user) async {
    // Linked account {id, email }

    final initiatorUpdate = user.role == 'primary'
        ? {
            'linkedAccounts': FieldValue.arrayRemove([linkedAccount]),
            'archivedLinkedAccounts': FieldValue.arrayUnion([linkedAccount])
          }
        : {
            'linkedAccounts': FieldValue.arrayRemove([linkedAccount]),
            'archivedLinkedAccounts': FieldValue.arrayUnion([linkedAccount]),
            'role': 'primary',
            'backupLedgerId': null,
            'ledgerId': user.backupLedgerId,
          };
    // Update to initiator's account
    await _db.collection('expenseUsers').doc(user.id).update(initiatorUpdate);

    // Update to target's account
    return functions.httpsCallable("unlinkRequest").call({
      'targetId': linkedAccount['id'],
      'initiatorId': user.id,
    });
  }

  Future<PendingRequest> getPendingRequest(String requestId) {
    return _db.collection('pendingShareRequests').doc(requestId).get().then(
          (request) => PendingRequest.fromJson({...request.data()!, 'id': requestId}),
        );
  }
}
