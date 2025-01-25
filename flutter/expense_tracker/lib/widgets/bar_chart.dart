import 'package:dotted_border/dotted_border.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';

class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.expenses,
    required this.selectedFilters,
    required this.budgetConfigs,
  });

  final List<Expense> expenses;
  final List<String> selectedFilters;
  final List<CategoryDataWithId> budgetConfigs;

  List<ExpenseBucket> getBuckets(List<CategoryDataWithId> data) {
    return data
        .where((config) => selectedFilters.contains(config.id))
        .map((config) => ExpenseBucket.forCategory(expenses, data, config.id))
        .toList();
  }

  double getMaxTotalExpense(List<ExpenseBucket> buckets) {
    return buckets.fold(
        0, (total, bucket) => bucket.totalExpenses > total ? bucket.totalExpenses : total);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;

    final buckets = getBuckets(budgetConfigs);
    final maxTotalExpense = getMaxTotalExpense(buckets);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: width < 600 ? 16 : 0),
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 8,
      ),
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardTheme.color!.withOpacity(.7),
            Theme.of(context).cardTheme.color!.withOpacity(0)
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((bucket) {
                final size = bucket.totalExpenses == 0 ? 0 : bucket.totalExpenses / maxTotalExpense;
                final threshold = bucket.budgetLimit < maxTotalExpense
                    ? bucket.budgetLimit / maxTotalExpense
                    : null;
                return ChartBar(
                  amount: bucket.totalExpenses,
                  size: size.toDouble(),
                  threshold: threshold,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: buckets
                .map(
                  (bucket) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        height: 80,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bucket.totalExpenses > 0
                                  ? '\$${bucket.totalExpenses.toStringAsFixed(2)}'
                                  : '',
                              textAlign: TextAlign.center,
                              style: ThemeData().textTheme.labelMedium,
                              softWrap: false,
                            ),
                            SelectableText(
                                budgetConfigs
                                    .firstWhere((config) => config.id == bucket.category)
                                    .label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: Theme.of(context).textTheme.labelSmall),
                            Icon(
                              budgetConfigs
                                  .firstWhere((config) => config.id == bucket.category)
                                  .iconData,
                              color: isDarkMode
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          )
        ],
      ),
    );
  }
}

class ChartBar extends StatelessWidget {
  const ChartBar({super.key, required this.size, required this.amount, this.threshold});

  final double size;
  final double amount;
  final double? threshold;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            FractionallySizedBox(
              heightFactor: size,
              widthFactor: .9,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  color: isDarkMode
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary.withOpacity(0.65),
                ),
              ),
            ),
            if (threshold != null)
              DottedBorder(
                borderType: BorderType.RRect,
                color: Colors.red[800]!,
                dashPattern: const [4, 6],
                strokeWidth: 2,
                customPath: (size) {
                  return Path()
                    ..moveTo(0, 0)
                    ..lineTo(size.width, 0)
                    ..close();
                },
                child: FractionallySizedBox(
                  heightFactor: threshold,
                  widthFactor: 100,
                ),
              )
          ],
        ),
      ),
    );
  }
}
