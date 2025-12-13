import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Initialize FCM service
  Future<void> initialize(String userId) async {
    // Request permission for notifications
    await _fcm.requestPermission();

    // Get the initial FCM token
    String? token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(userId, token);
    }

    // Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) async {
      await _saveTokenToFirestore(userId, newToken);
    });
  }

  // Save the FCM token to Firestore
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    await _firestore.collection('expenseUsers').doc(userId).update({
      'fcmToken': token,
    });
  }
}
