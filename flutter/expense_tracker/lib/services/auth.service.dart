import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rxdart/rxdart.dart';

// ignore: non_constant_identifier_names
final WEB_CLIENT_ID = dotenv.env['WEB_CLIENT_ID'];

class AuthService {
  AuthService._internal();
  static final _instance = AuthService._internal();
  factory AuthService() {
    return _instance;
  }

  final userStream = FirebaseAuth.instance.authStateChanges().shareReplay(maxSize: 1);
  User? user = FirebaseAuth.instance.currentUser;

  Future<void> createUser(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = await userStream.first;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
      }
    } catch (e) {
      print(e);
    }
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
    // if (bool.parse(dotenv.env['DEV_MODE'] ?? 'true')) {
    //   try {
    //     final googleProvider = GoogleAuthProvider();
    //     googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
    //     await FirebaseAuth.instance.signInWithPopup(googleProvider);
    //     user = FirebaseAuth.instance.currentUser;
    //   } on FirebaseAuthException catch (e) {
    //     print('googleLogin exception: $e');
    //   }
    // } else {

    // }
  }

  Future<void> appleLogin() async {
    try {
      final appleProvider = AppleAuthProvider();
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(appleProvider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(appleProvider);
      }
    } catch (e) {
      print('Apple Login Error');
    }
  }

  Future<void> emailLogin(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      // user = await userStream.first;
      user = FirebaseAuth.instance.currentUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
      }
    }
  }

  Future<void> logOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
