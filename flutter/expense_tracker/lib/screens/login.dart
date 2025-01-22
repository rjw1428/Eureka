import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showLoginForm = false;
  bool _showCreateAccountForm = false;
  final _emailControl = TextEditingController();
  final _passwordControl = TextEditingController();
  final _confirmPasswordControl = TextEditingController();

  @override
  void dispose() {
    _emailControl.dispose();
    _passwordControl.dispose();
    _confirmPasswordControl.dispose();
    super.dispose();
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
                Text(
                  "Login",
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(200.0),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 300,
                      width: 300,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(
                    FontAwesomeIcons.google,
                    size: 20,
                  ),
                  onPressed: () async => await AuthService().googleLogin(),
                  label: const Text("Login with Google", textAlign: TextAlign.center),
                ),
                // const SizedBox(height: 16),
                // ElevatedButton.icon(
                //   icon: const Icon(
                //     FontAwesomeIcons.apple,
                //     size: 20,
                //   ),
                //   onPressed: () async => await AuthService().appleLogin(),
                //   label: const Text("Login with Apple", textAlign: TextAlign.center),
                // ),
                const SizedBox(height: 16),
                if (_showLoginForm && !_showCreateAccountForm)
                  SizedBox(
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
                        TextButton(
                          onPressed: () async {
                            if (_emailControl.text.isEmpty) {
                              showDialogNotification(
                                'Email missing',
                                const Text('Enter your email address and try again.'),
                                context,
                              );
                              return;
                            }
                            final response = await AuthService().forgotPassword(_emailControl.text);
                            showDialogNotification(
                              response.success
                                  ? 'Password Reset Email Sent'
                                  : 'An error has occurred',
                              Text(response.message!),
                              context,
                            );
                          },
                          child: Text(
                            'Forgot Password',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                ElevatedButton.icon(
                    icon: const Icon(
                      FontAwesomeIcons.envelope,
                      size: 20,
                    ),
                    onPressed: () async {
                      if (!_showLoginForm) {
                        setState(() {
                          _showLoginForm = true;
                          _showCreateAccountForm = false;
                        });
                      } else {
                        if (_emailControl.text.isEmpty) {
                          showDialogNotification(
                            'Email missing',
                            const Text('Enter your email address and try again.'),
                            context,
                          );
                          return;
                        }

                        if (_passwordControl.text.isEmpty) {
                          showDialogNotification(
                            'Password missing',
                            const Text('Enter your password and try again.'),
                            context,
                          );
                          return;
                        }

                        final response = await AuthService().emailLogin(
                          _emailControl.text.trim(),
                          _passwordControl.text,
                        );

                        if (!response.success) {
                          showDialogNotification(
                            'Login Unsuccessful',
                            Text(response.message!),
                            context,
                          );
                        }
                      }
                    },
                    label: Text(
                      _showLoginForm ? "Login" : "Login with Email",
                      textAlign: TextAlign.center,
                    )),

                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('or'),
                ),
                if (_showCreateAccountForm && !_showLoginForm)
                  SizedBox(
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
                      ],
                    ),
                  ),
                TextButton(
                  onPressed: () async {
                    if (!_showCreateAccountForm) {
                      setState(() {
                        _showCreateAccountForm = true;
                        _showLoginForm = false;
                      });
                    } else {
                      if (_passwordControl.text.length < 6) {
                        showDialogNotification(
                          'Password too short',
                          const Text('Password must be 6 characters or greater. Try again.'),
                          context,
                        );
                        return;
                      }

                      if (_passwordControl.text != _confirmPasswordControl.text) {
                        showDialogNotification(
                          'Invalid Password',
                          const Text('Confirmation password did not match. Try again.'),
                          context,
                        );
                        return;
                      }

                      final success = await AuthService()
                          .createUser(_emailControl.text.trim(), _passwordControl.text);
                      if (!success) {
                        showDialogNotification(
                          'An Error Occurred',
                          const Text(
                              'Something went wrong, unable to create an account, please try again.'),
                          context,
                        );
                        return;
                      }
                    }
                  },
                  child: Text(_showCreateAccountForm
                      ? "Create Account"
                      : "Click here to create an account"),
                ),
              ],
            ),
          )),
        ),
      ),
    );
  }
}
