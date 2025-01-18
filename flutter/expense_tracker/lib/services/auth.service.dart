import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/models/response.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rxdart/rxdart.dart';

// ignore: non_constant_identifier_names
final WEB_CLIENT_ID = dotenv.env['WEB_CLIENT_ID'];
FirebaseFunctions functions = FirebaseFunctions.instance;

class AuthService {
  AuthService._internal();
  static final _instance = AuthService._internal();
  factory AuthService() {
    return _instance;
  }
  final _db = FirebaseFirestore.instance;
  final userStream = FirebaseAuth.instance.authStateChanges().shareReplay(maxSize: 1);
  User? user = FirebaseAuth.instance.currentUser;

  Stream<String?> getCurrentUserLedgerId() {
    if (user == null) return const Stream.empty();
    return _getUserLedgerId(user!.uid);
  }

  Stream<String> _getUserLedgerId(String uid) {
    return _db
        .collection('expenseUsers')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.get('ledgerId') as String);
  }

  Future<bool> createUser(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = await userStream.first;

      return await initializeAccount(email, user!.uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
      }
    } catch (e) {
      print(e);
    }
    return false;
  }

  Future<void> googleLogin() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      user = FirebaseAuth.instance.currentUser;
    } on FirebaseAuthException catch (e) {
      print('googleLogin exception: $e');
    }
  }

  // Future<void> appleLogin() async {
  //   try {
  //     final appleProvider = AppleAuthProvider();
  //     if (kIsWeb) {
  //       await FirebaseAuth.instance.signInWithPopup(appleProvider);
  //     } else {
  //       await FirebaseAuth.instance.signInWithProvider(appleProvider);
  //     }
  //   } catch (e) {
  //     print('Apple Login Error');
  //   }
  // }

  Future<Response> emailLogin(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      user = FirebaseAuth.instance.currentUser;
      return const Response(success: true);
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.code}: ${e.message}');
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

  Future<bool> initializeAccount(String email, String userId) async {
    Completer<bool> completer = Completer();
    try {
      final resp = await functions.httpsCallable("initializeExpenseTrackerAccount").call({
        'userId': userId,
        'email': email,
      });
      print(resp.data);
    } catch (e) {
      print(e);
      completer.complete(false);
    }
    return completer.future;
  }

  Stream getAccount() {
    return userStream.switchMap((user) {
      if (user == null) {
        return const Stream.empty().startWith(null);
      }
      print("LOGGED IN AS: ${user.uid}");
      return _db
          .collection('expenseUsers')
          .doc(user!.uid)
          .snapshots()
          .map((event) => event.data())
          .where((data) => data != null)
          .map((d) => user!.uid);
    });
  }

  Future<void> logOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
