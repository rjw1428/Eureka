import 'dart:io';

import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/login/login.create_account.dart';
import 'package:expense_tracker/screens/login/login.email.dart';
import 'package:expense_tracker/screens/login/login.header.dart';
import 'package:expense_tracker/screens/login/login.logo.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _showLoginForm = false;
  bool _showCreateAccountForm = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(APP_TITLE),
        ),
        body: SingleChildScrollView(
          child: Center(
              child: Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardSpace + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LoginHeader(),
                const LoginLogo(),
                ElevatedButton.icon(
                  icon: const Icon(
                    FontAwesomeIcons.google,
                    size: 20,
                  ),
                  onPressed: () async {
                    setState(() {
                      _showCreateAccountForm = false;
                      _showLoginForm = false;
                    });
                    try {
                      await AuthService().googleLogin();
                      ref.read(userCreationStateProvider.notifier).loggedIn();
                    } catch (e) {
                      // Handle error
                      print("Error during Google login: $e");
                    }
                  },
                  label: const Text("Login with Google",
                      textAlign: TextAlign.center),
                ),
                if (!kIsWeb && Platform.isIOS) const SizedBox(height: 16),
                if (!kIsWeb && Platform.isIOS)
                  ElevatedButton.icon(
                    icon: const Icon(
                      FontAwesomeIcons.apple,
                      size: 20,
                    ),
                    onPressed: () async {
                      setState(() {
                        _showCreateAccountForm = false;
                        _showLoginForm = false;
                      });
                      try {
                        await AuthService().appleLogin();
                        ref.read(userCreationStateProvider.notifier).loggedIn();
                      } catch (e) {
                        // Handle error
                        print("Error during Apple login: $e");
                      }
                    },
                    label: const Text("Login with Apple",
                        textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 16),
                if (!_showLoginForm)
                  ElevatedButton.icon(
                    icon: const Icon(
                      FontAwesomeIcons.envelope,
                      size: 18,
                    ),
                    onPressed: () => setState(() {
                      _showLoginForm = true;
                      _showCreateAccountForm = false;
                    }),
                    label: const Text(
                      "Login with Email",
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_showLoginForm && !_showCreateAccountForm)
                  const LoginWithEmailForm(),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('or'),
                ),
                if (!_showCreateAccountForm)
                  TextButton(
                    onPressed: () async {
                      if (!_showCreateAccountForm) {
                        setState(() {
                          _showCreateAccountForm = true;
                          _showLoginForm = false;
                        });
                      }
                    },
                    child: const Text("Click here to create an account"),
                  ),
                if (_showCreateAccountForm && !_showLoginForm)
                  const CreateAccountForm(),
              ],
            ),
          )),
        ),
      ),
    );
  }
}
