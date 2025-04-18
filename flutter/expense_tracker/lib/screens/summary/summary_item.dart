import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:expense_tracker/providers/expand_filter_row_provider.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final formatter = DateFormat('MM/yy');

class SummaryItem extends ConsumerWidget {
  SummaryItem({super.key, required this.reportData, required this.budgetAmount})
      : delta = budgetAmount - reportData.total;

  final SummaryEntry reportData;
  final double budgetAmount;
  final double delta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(selectedTimeProvider.notifier).setSelectedTime(reportData.startDate);
        ref.read(selectedFiltersProvider.notifier).setSelectedFilters([reportData.categoryId]);
        ref.read(filterRowStateProvider.notifier).openRow();
        Navigator.pop(context);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(formatter.format(reportData.startDate)),
                  const SizedBox(
                    width: 16,
                  ),
                  Text('Total transactions: ${reportData.count}')
                ],
              ),
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
      ),
    );
  }
}
