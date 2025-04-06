import 'package:expense_tracker/screens/login/login.forgot_password.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginWithEmailForm extends StatefulWidget {
  const LoginWithEmailForm({super.key});
  @override
  State<LoginWithEmailForm> createState() => _LoginWithEmailState();
}

class _LoginWithEmailState extends State<LoginWithEmailForm> {
  final _emailControl = TextEditingController();
  final _passwordControl = TextEditingController();

  bool validateInput() {
    if (_emailControl.text.isEmpty) {
      showDialogNotification(
        'Email missing',
        const Text('Enter your email address and try again.'),
        context,
      );
      return false;
    }

    if (_passwordControl.text.isEmpty) {
      showDialogNotification(
        'Password missing',
        const Text('Enter your password and try again.'),
        context,
      );
      return false;
    }
    return true;
  }

  void login() async {
    final response = await AuthService().emailLogin(
      _emailControl.text.trim(),
      _passwordControl.text,
    );

    if (!response.success && mounted) {
      showDialogNotification(
        'Login Unsuccessful',
        Text(response.message!),
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          TextField(
            controller: _emailControl,
            decoration: const InputDecoration(
              label: Text('Email'),
            ),
          ),
          TextField(
            controller: _passwordControl,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              label: Text('Password'),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(
              FontAwesomeIcons.envelope,
              size: 18,
            ),
            onPressed: () async {
              if (validateInput()) {
                login();
              }
            },
            label: const Text(
              "Login",
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ForgotPassword(emailAddress: _emailControl),
        ],
      ),
    );
  }
}
