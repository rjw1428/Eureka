import 'package:flutter/material.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      "Login",
      style: Theme.of(context).textTheme.headlineLarge,
    );
  }
}
