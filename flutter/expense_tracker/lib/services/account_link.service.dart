import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/linked_user.dart';
import 'package:expense_tracker/models/pending_request.dart';
import 'package:expense_tracker/models/response.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/transformers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

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

  Future onUnlink(LinkedUser linkedAccount, ExpenseUser user) async {
    // Linked account {id, email }

    final initiatorUpdate = user.role == 'primary'
        ? {
            'linkedAccounts': FieldValue.arrayRemove([linkedAccount.toJson()]),
            'archivedLinkedAccounts': FieldValue.arrayUnion([linkedAccount.toJson()])
          }
        : {
            'linkedAccounts': FieldValue.arrayRemove([linkedAccount.toJson()]),
            'archivedLinkedAccounts': FieldValue.arrayUnion([linkedAccount.toJson()]),
            'role': 'primary',
            'backupLedgerId': null,
            'ledgerId': user.backupLedgerId,
          };
    // Update to initiator's account
    await _db.collection('expenseUsers').doc(user.id).update(initiatorUpdate);

    // Update to target's account
    return functions.httpsCallable("unlinkRequest").call({
      'targetId': linkedAccount.id,
      'initiatorId': user.id,
    });
  }

  Future<PendingRequest> getPendingRequest(String requestId) {
    return _db.collection('pendingShareRequests').doc(requestId).get().then(
          (request) => PendingRequest.fromJson({...request.data()!, 'id': requestId}),
        );
  }

  Future<String> onDeleteAccount(ExpenseUser user, WidgetRef ref) async {
    final isPrepared = await _prepareAccountForDeletion(user);
    if (!isPrepared) {
      return 'Something went wrong, unable to handle linked accounts. Try again later.';
    }

    return await deleteFirebaseAccount(ref);
  }

  Future<bool> _prepareAccountForDeletion(ExpenseUser user) async {
    try {
      // Delete all pending requests
      final pendingRequests =
          await _db.collection('pendingShareRequests').where('requestingUser', isEqualTo: user.id).get();

      for (final request in pendingRequests.docs) {
        await _db.collection('pendingShareRequests').doc(request.id).delete();
      }

      // Delete all linked accounts
      for (final linkedAccount in user.linkedAccounts) {
        if (user.role == 'primary') {
          // Upgrade secondary accounts to primary
          functions.httpsCallable("promoteAccount").call({
            'id': linkedAccount.id,
            'removeId': user.id,
          });
        } else {
          await onUnlink(linkedAccount, user);
        }
      }
    } catch (e) {
      debugPrint('Error preparing account for deletion: $e');
      return false;
    }
    return true;
  }

  Future<String> deleteFirebaseAccount(WidgetRef ref) async {
    final firebaseUser = FirebaseAuth.instance.currentUser!;
    try {
      await firebaseUser.delete();
      debugPrint('User deleted');
      AuthService().logOut(ref);
      return 'success';
    } on FirebaseAuthException catch (error) {
      debugPrint('Error deleting user: ${error.code}');
      if (error.code != 'requires-recent-login') {
        return error.message ?? 'An error occurred while deleting your account. Please try again later.';
      }
      final provider = firebaseUser.providerData.first;

      if (provider.providerId == 'google.com') {
        try {
          await AuthService().googleLogin();
          await firebaseUser.delete();
          return 'success';
        } catch (e) {
          debugPrint('Error re-authenticating with Google: $e');
          return 'You need to re-authenticate with Google before deleting your account.';
        }
      } else if (provider.providerId == 'apple.com') {
        try {
          await AuthService().appleLogin();
          await firebaseUser.delete();
          return 'success';
        } catch (e) {
          debugPrint('Error re-authenticating with Apple: $e');
          return 'You need to re-authenticate with Apple before deleting your account.';
        }
      } else if (provider.providerId == 'password') {
        debugPrint('Re-authentication with email and password is required.');
        return 'You need to re-authenticate with email and password before deleting your account. Try logging out and back in and then try deleting your account again.';
      }

      return 'Something went wrong, please try again later.';
    }
  }
}
