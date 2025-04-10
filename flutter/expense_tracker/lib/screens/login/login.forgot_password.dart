import 'package:expense_tracker/services/auth.service.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:flutter/material.dart';

class ForgotPassword extends StatelessWidget {
  const ForgotPassword({super.key, required this.emailAddress});

  final TextEditingController emailAddress;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        if (emailAddress.text.isEmpty) {
          showDialogNotification(
            'Email missing',
            const Text('Enter your email address and try again.'),
            context,
          );
          return;
        }
        final response = await AuthService().forgotPassword(emailAddress.text);

        showDialogNotification(
          response.success ? 'Password Reset Email Sent' : 'An error has occurred',
          Text(response.message!),
          context,
        );
      },
      child: Text(
        'Forgot Password',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
