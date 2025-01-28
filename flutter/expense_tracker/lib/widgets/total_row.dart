import 'package:flutter/material.dart';

class TotalRow extends StatelessWidget {
  const TotalRow({super.key, required this.sum, this.totalBudget})
      : delta = totalBudget == null ? null : totalBudget - sum;
  final double sum;
  final double? totalBudget;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '\$${sum.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 24, color: Theme.of(context).textTheme.titleLarge?.color),
          textAlign: TextAlign.center,
        ),
        if (delta != null)
          Text(
            '${delta! >= 0 ? '+' : '-'} \$${delta!.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 16, color: delta! >= 0 ? Colors.green : Colors.red),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
