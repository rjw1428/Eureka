import 'package:expense_tracker/services/auth.service.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:flutter/material.dart';

class CreateAccountForm extends StatefulWidget {
  const CreateAccountForm({super.key});

  @override
  State<CreateAccountForm> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccountForm> {
  final _emailControl = TextEditingController();
  final _passwordControl = TextEditingController();
  final _confirmPasswordControl = TextEditingController();

  bool validateInput() {
    if (_passwordControl.text.length < 6) {
      showDialogNotification(
        'Password too short',
        const Text('Password must be 6 characters or greater. Try again.'),
        context,
      );
      return false;
    }

    if (_passwordControl.text != _confirmPasswordControl.text) {
      showDialogNotification(
        'Invalid Password',
        const Text('Confirmation password did not match. Try again.'),
        context,
      );
      return false;
    }
    return true;
  }

  void createAccount() async {
    final response = await AuthService().createUser(
      _emailControl.text.trim(),
      _passwordControl.text,
    );

    if (!response.success && mounted) {
      showDialogNotification(
        'An Error Occurred',
        Text(response.message!),
        context,
      );
      return;
    }

    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/welcome', (route) => false);
    }
  }

  @override
  void dispose() {
    _emailControl.dispose();
    _passwordControl.dispose();
    _confirmPasswordControl.dispose();
    super.dispose();
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
          TextField(
            controller: _confirmPasswordControl,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              label: Text('Re-enter Password'),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
              onPressed: () async {
                if (validateInput()) {
                  createAccount();
                }
              },
              child: const Text('Create Account'))
        ],
      ),
    );
  }
}
