import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final formatter = DateFormat('MM/yy');

class SummaryItem extends StatelessWidget {
  SummaryItem({super.key, required this.reportData, required this.budgetAmount})
      : delta = budgetAmount - reportData.total;

  final SummaryEntry reportData;
  final double budgetAmount;
  final double delta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatter.format(reportData.startDate)),
            Row(
              children: [
                Text(
                  '${delta >= 0 ? "+" : ""}${currency.format(delta)}',
                  style: TextStyle(color: delta >= 0 ? Colors.green : Colors.red),
                ),
                const SizedBox(
                  width: 16,
                ),
                Text(currency.format(reportData.total))
              ],
            )
          ],
        ),
      ),
    );
  }
}
