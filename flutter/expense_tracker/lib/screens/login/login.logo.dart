import 'package:flutter/material.dart';

class LoginLogo extends StatelessWidget {
  const LoginLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}
