import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _onLogin(ctx) {
    //  AuthService().googleLogin
    Navigator.pushNamedAndRemoveUntil(ctx, '/', (route) => false);
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
                  height: 400,
                  width: 400,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(
                FontAwesomeIcons.google,
                size: 20,
              ),
              onPressed: () => _onLogin(context),
              label: const Text("Login with Google", textAlign: TextAlign.center),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('or'),
            ),
            TextButton(
              onPressed: () {},
              child: const Text("Click here to create an account"),
            )
          ],
        ),
      )),
    );
  }
}
