import 'package:flutter/material.dart';

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Loading...',
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
