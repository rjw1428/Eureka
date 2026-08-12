import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/receipt.service.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

final functionsProvider = Provider((ref) {
  return FirebaseFunctions.instance;
});

final storageProvider = Provider((ref) {
  return FirebaseStorage.instance;
});

final receiptServiceProvider = Provider((ref) {
  return ReceiptService(
    storage: ref.read(storageProvider),
    firestore: ref.read(backendProvider),
  )..onPermissionDenied = () => refreshAuthClaims(ref);
});
