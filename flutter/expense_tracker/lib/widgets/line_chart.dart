import 'package:expense_tracker/models/summary_entry.dart';
import 'package:flutter/material.dart';

class LineChart extends StatelessWidget {
  const LineChart({super.key, required this.data});

  final List<SummaryEntry> data;

  @override
  Widget build(BuildContext context) {
    return const Text('summary');
  }
}
