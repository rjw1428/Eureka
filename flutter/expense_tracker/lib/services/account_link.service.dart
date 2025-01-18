import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/response.dart';

class AccountLinkService {
  AccountLinkService._internal();
  static final _instance = AccountLinkService._internal();
  factory AccountLinkService() {
    return _instance;
  }
  final _db = FirebaseFirestore.instance;

  Future<Response> sendLinkRequest(String email, String requestingUser) async {
    // THIS NEEDS TO BE A CLOUD FUNCTION AS WELL
    // Client will write the target email address to the pendingShareRequests colloection
    // ON WRITE, CLOUD FUNCTION WILL LOOK IT UP AND ADD THE
    // final user = await _db.collection('expenseUsers').where('email', isEqualTo: email).get();

    // if (!user.docs.first.exists) {
    //   return false;
    // }

    // user.docs.first.id;
    // return true;
    try {
      await _db.collection('pendingShareRequests').add(
        {'targetEmail': email, 'requestingUser': requestingUser},
      );
      return const Response(success: true);
    } catch (e) {
      return Response(success: false, message: e.toString());
    }
  }

  void subscribeToLinkMessage() {}
}
