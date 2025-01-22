import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/response.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rxdart/rxdart.dart';

// ignore: non_constant_identifier_names
final WEB_CLIENT_ID = dotenv.env['WEB_CLIENT_ID'];

class AuthService {
  AuthService._internal();
  FirebaseFunctions functions = FirebaseFunctions.instance;
  static final _instance = AuthService._internal();
  factory AuthService() {
    return _instance;
  }
  // final _db = FirebaseFirestore.instance;
  final userStream = FirebaseAuth.instance.authStateChanges().shareReplay(maxSize: 1);
  User? user = FirebaseAuth.instance.currentUser;

  final Stream<DocumentSnapshot<Map<String, dynamic>>> user$ = FirebaseAuth.instance
      .authStateChanges()
      .where((user) => user != null)
      .switchMap((user) => FirebaseFirestore.instance
          .collection('expenseUsers')
          .doc(user!.uid)
          .snapshots()
          .shareReplay(maxSize: 1))
      .shareReplay(maxSize: 1);
  Stream<String?> getCurrentUserLedgerId() {
    return userStream.take(1).switchMap((user) {
      if (user == null) return const Stream.empty();
      return _getUserLedgerId();
    });
  }

  Stream<String> _getUserLedgerId() {
    return user$.map((doc) => doc.get('ledgerId') as String).shareReplay(maxSize: 1);
  }

  Stream getAccountOrNull() {
    return userStream.switchMap((user) {
      if (user == null) {
        return const Stream.empty().startWith(null);
      }
      print("LOGGED IN AS: ${user.uid}");
      return getAccount(user);
    });
  }

  Stream<ExpenseUser> getAccount(User user) {
    return user$
        .map((event) => event.data())
        .where((data) => data != null)
        .map((d) => ExpenseUser.fromJson({'id': user.uid, ...d!}));
  }

  Future<Response> createUser(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = await userStream.first;
      await initializeAccount(email, user!.uid);
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
    return const Response(success: true);
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
    // Completer here is just used to trigger an error message
    Completer<bool> completer = Completer();
    try {
      final resp = await functions.httpsCallable("initializeExpenseTrackerAccount").call({
        'userId': userId,
        'email': email,
      });
      print(resp.data);
      completer.complete(true);
    } catch (e) {
      print(e);
      completer.complete(false);
    }
    return completer.future;
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

  Future<void> logOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
