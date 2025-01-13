import 'package:flutter/material.dart';

class TotalRow extends StatelessWidget {
  const TotalRow({super.key, required this.sum});
  final double sum;

  @override
  Widget build(BuildContext context) {
    return Text(
      '\$${sum.toStringAsFixed(2)}',
      style: TextStyle(fontSize: 24, color: Theme.of(context).textTheme.titleLarge?.color),
      textAlign: TextAlign.center,
    );
  }
}
