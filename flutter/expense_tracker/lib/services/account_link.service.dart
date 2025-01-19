import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/models/pending_request.dart';
import 'package:expense_tracker/models/response.dart';
import 'package:rxdart/rxdart.dart';

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
    });
  }

  Stream<PendingRequest> subscribeToLinkMessage(String userId) {
    return _db
        .collection('expenseUsers')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()!['pendingRequest'] as String?)
        .where((requestId) => requestId != null)
        .map((requestId) => requestId as String)
        .switchMap(
          (requestId) => Stream.fromFuture(_db
              .collection('pendingShareRequests')
              .doc(requestId)
              .get()
              .then((request) => PendingRequest.fromJson({...request.data()!, 'id': requestId}))),
        );
  }

  Future acceptLinkRequest(PendingRequest request, String userId) {
    return Future.wait([
      _db.collection('expenseUsers').doc(userId).update({
        'pendingRequest': null,
        'role': 'secondary',
        'ledgerId': request.requestingUserLedgerId,
        'backupLedgerId': request.targetCurrentLedgerId,
        'linkedAccounts': FieldValue.arrayUnion([
          {
            'id': request.requestingUser,
            'email': request.requestingUserEmail,
          },
        ])
      }),
      functions.httpsCallable("triggerLinkedAccount").call({
        'requestId': request.id,
      })
    ]);
  }

  // When a user rejects, they can clear they're own pending request
  Future rejectLinRequest(PendingRequest request) {
    return Future.wait([
      _db.collection('expenseUsers').doc(request.targetUserId).update({
        'pendingRequest': null,
      }),
      _db.collection('pendingShareRequests').doc(request.id).delete(),
    ]);
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
}
