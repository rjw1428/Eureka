import 'package:dotted_border/dotted_border.dart';
import 'package:expense_tracker/constants/categories.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';

final CategoryConfig categoryConfig = CategoriesService().getCategories();

class Chart extends StatelessWidget {
  const Chart({super.key, required this.expenses, required this.selectedFilters});

  final List<Expense> expenses;
  final List<Category> selectedFilters;

  List<ExpenseBucket> get buckets {
    return categoryConfig.keys
        .where((key) => selectedFilters.contains(key))
        .map((key) => ExpenseBucket.forCategory(expenses, key))
        .toList();
  }

  double get maxTotalExpense {
    return buckets.fold(
      0,
      (total, bucket) => bucket.totalExpenses > total ? bucket.totalExpenses : total,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
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
          const SizedBox(height: 12),
          Row(
            children: buckets
                .map(
                  (bucket) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Text(categoryConfig[bucket.category]!.label,
                              style: Theme.of(context).textTheme.labelSmall),
                          Icon(
                            categoryConfig[bucket.category]!.icon,
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.primary.withOpacity(0.7),
                          ),
                        ],
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
                child: Text(
                  amount > 0 ? '\$${amount.toStringAsFixed(2)}' : '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
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
