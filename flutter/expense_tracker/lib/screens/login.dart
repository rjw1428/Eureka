import 'package:expense_tracker/services/auth.service.dart';
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
  final _emailControl = TextEditingController();
  final _passwordControl = TextEditingController();

  @override
  void dispose() {
    _emailControl.dispose();
    _passwordControl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
      ),
      body: Center(
          child: Container(
        padding: const EdgeInsets.all(30),
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
                  'assets/images/money.jpg',
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(
                FontAwesomeIcons.apple,
                size: 20,
              ),
              onPressed: () async => await AuthService().appleLogin(),
              label: const Text("Login with Apple", textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            if (_showLoginForm)
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
                  ],
                ),
              ),
            ElevatedButton.icon(
              icon: const Icon(
                FontAwesomeIcons.envelope,
                size: 20,
              ),
              onPressed: () {
                if (!_showLoginForm) {
                  setState(() => _showLoginForm = true);
                } else {
                  AuthService().emailLogin(_emailControl.text.trim(), _passwordControl.text);
                }
              },
              label: Text(
                _showLoginForm ? "Login" : "Login with Email",
                textAlign: TextAlign.center,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('or'),
            ),
            TextButton(
              onPressed: () => {},
              child: const Text("Click here to create an account"),
            ),
          ],
        ),
      )),
    );
  }
}
