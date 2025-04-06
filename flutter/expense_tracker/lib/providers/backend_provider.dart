import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kCacheSize = 10485760; // 10MB

final backendProvider = Provider((ref) {
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true, cacheSizeBytes: kCacheSize);

  return FirebaseFirestore.instance;
});

final authProvider = Provider((ref) {
  return FirebaseAuth.instance;
});
