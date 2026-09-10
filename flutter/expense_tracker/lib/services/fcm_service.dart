import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  /// Both dependencies are injectable so the service can be exercised without
  /// a live Firebase app. Resolving `.instance` in a field initializer made
  /// merely constructing an FCMService — even a test double extending it —
  /// throw `[core/no-app]`.
  FCMService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _injectedFirestore = firestore,
        _injectedMessaging = messaging;

  final FirebaseFirestore? _injectedFirestore;
  final FirebaseMessaging? _injectedMessaging;

  // Resolved lazily: a subclass that overrides `initialize` never touches
  // Firebase at all, which is what makes it usable as a test double.
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;
  FirebaseMessaging get _fcm => _injectedMessaging ?? FirebaseMessaging.instance;

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
    try {
      await _firestore.collection('expenseUsers').doc(userId).update({
        'fcmToken': token,
      });
    } catch (e) {
      // A token that cannot be stored costs this device its notifications; it
      // must not take down sign-in, which is what awaits initialize().
      debugPrint('Could not persist the FCM token for $userId: $e');
    }
  }
}
