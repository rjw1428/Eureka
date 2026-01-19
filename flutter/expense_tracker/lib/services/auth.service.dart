import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/constants/utils.dart' as my_utils;
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/response.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/local_storage.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore: non_constant_identifier_names
final WEB_CLIENT_ID = dotenv.env['WEB_CLIENT_ID'];

class AuthService {
  AuthService._internal();
  FirebaseFunctions functions = FirebaseFunctions.instance;
  static final _instance = AuthService._internal();
  factory AuthService() {
    return _instance;
  }

  String? get currentUserId => FirebaseAuth.instance.currentUser!.uid;
  User? get currentUser => FirebaseAuth.instance.currentUser;
  Future<Response> createUser(String email, String password) async {
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return Response(success: true, message: userCredential.user?.uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return const Response(
          success: false,
          message: 'The password provided is too weak.',
        );
      } else if (e.code == 'email-already-in-use') {
        return const Response(
          success: false,
          message: 'The account already exists for that email.',
        );
      }
    } catch (e) {
      return const Response(
        success: false,
        message: 'Something went wrong, unable to create an account, please try again.',
      );
    }
    return const Response(success: false, message: 'Unknown error occurred.');
  }

  Future<void> createUserProfile(ExpenseUser userProfile) async {
    try {
      final id = userProfile.toJson()['id'];
      final docRef = FirebaseFirestore.instance.collection('expenseUsers').doc(id);
      final profile = userProfile.toJson();
      profile.remove('id');
      await docRef.set(profile);
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      rethrow;
    }
  }

  Future<bool> googleLogin() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider
            .addScope('https://www.googleapis.com/auth/contacts.readonly')
            .setCustomParameters({"prompt": "select_account"});
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
        return await _userProfileExists();
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

        if (googleAuth != null) {
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
        return await _userProfileExists();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('googleLogin exception: $e');
      rethrow;
    }
  }

  Future<AppleUserProfile?> appleLogin() async {
    try {
      final rawNonce = my_utils.generateNonce();
      final nonce = my_utils.sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        nonce: Platform.isIOS ? nonce : null,
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create a Firebase credential from the Apple credential
      final firebaseCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: Platform.isIOS ? rawNonce : null,
      );

      // Sign in with Firebase
      await FirebaseAuth.instance.signInWithCredential(firebaseCredential);

      //If it's the first time, return the apple user profile
      if (appleCredential.givenName != null && appleCredential.familyName != null) {
        return AppleUserProfile(
          givenName: appleCredential.givenName!,
          familyName: appleCredential.familyName!,
        );
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error signing in with Apple: $e');
      rethrow;
    }
  }

  Future<Response> emailLogin(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      return const Response(success: true);
    } on FirebaseAuthException catch (e) {
      debugPrint('Login error: ${e.code}: ${e.message}');
      return const Response(
        success: false,
        message: 'Incorrect username or password.',
      );
    } catch (e) {
      return const Response(
        success: false,
        message: 'Unknown error occurred, please try again.',
      );
    }
  }

  Future<Response> forgotPassword(String email) async {
    const successMessage =
        "An email has been sent to the provided address. If an account exists, you will be provided a link to reset your password.";
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return const Response(success: true, message: successMessage);
      // ignore: unused_catch_clause
    } on FirebaseAuthException catch (e) {
      return const Response(success: true, message: successMessage);
    } catch (e) {
      return Response(
        success: false,
        message: "An unexpected error occurred: ${e.toString()}",
      );
    }
  }

  Future<void> logOut(WidgetRef ref) async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService().onLogout(ref);
  }

  Future<bool> _userProfileExists() async {
    if (currentUserId == null) return false;

    final doc = await FirebaseFirestore.instance.collection('expenseUsers').doc(currentUserId).get();
    return doc.exists;
  }
}
