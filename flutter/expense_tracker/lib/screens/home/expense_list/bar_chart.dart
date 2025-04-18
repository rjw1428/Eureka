import 'dart:ui';

import 'package:dotted_border/dotted_border.dart';
import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/providers/bar_chart_provider.dart';
import 'package:expense_tracker/screens/home/summary/summary.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BarChart extends ConsumerStatefulWidget {
  const BarChart({
    super.key,
    required this.screenWidth,
  });

  final double screenWidth;

  @override
  ConsumerState<BarChart> createState() => _BarChartState();
}

class _BarChartState extends ConsumerState<BarChart> with SingleTickerProviderStateMixin {
  final double _barColumnWidth = 64.0;
  final ScrollController _scrollController = ScrollController();

  double getMaxTotalExpense(List<ExpenseBucket> buckets) {
    return buckets.fold(
        0, (total, bucket) => bucket.totalExpenses > total ? bucket.totalExpenses : total);
  }

  void _openAnnualReport(ExpenseBucket bucket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ReportScreen(
          categoryId: bucket.category.id,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;

    final buckets$ = ref.watch(barColumnProvider);

    return buckets$.when(
        loading: () => const Loading(),
        error: (error, stack) => Text(error.toString()),
        data: (buckets) {
          final maxTotalExpense = getMaxTotalExpense(buckets);
          final chartWidth = buckets.length * _barColumnWidth;

          return Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
                platform: TargetPlatform.linux, // This enables mouse drag scrolling
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: kIsWeb,
                thickness: kIsWeb ? 8.0 : 2.0,
                radius: const Radius.circular(4),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: widget.screenWidth > chartWidth ? widget.screenWidth - 32 : chartWidth,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 25, 8, 16),
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: buckets.map((bucket) {
                                return ChartBar(
                                  amount: bucket.totalExpenses,
                                  max: maxTotalExpense,
                                  limit: bucket.category.budget,
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
                                      child: GestureDetector(
                                        onTap: () => _openAnnualReport(bucket),
                                        child: SizedBox(
                                          height: 80,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                currency.format(bucket.totalExpenses).length > 7
                                                    ? thousandsCurrency.format(bucket.totalExpenses)
                                                    : currency.format(bucket.totalExpenses),
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(bucket.category.label,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  style: Theme.of(context).textTheme.labelSmall),
                                              Icon(
                                                bucket.category.iconData,
                                                color: isDarkMode
                                                    ? Theme.of(context).colorScheme.secondary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.7),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
  }
}

class ChartBar extends StatelessWidget {
  const ChartBar({
    super.key,
    required this.max,
    required this.amount,
    required this.limit,
  }) : limitedAmount = amount < 0 ? 0 : amount;

  final double max;
  final double amount;
  final double limit;
  final double limitedAmount;

  final double overspendIndicatorPadding = 2;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final size = max == 0 ? 0 : limitedAmount / max;
    final threshold = limit > 0 && limit <= max ? limit / max : null;
    final remaining = limit - amount;
    return Expanded(
      child: LayoutBuilder(builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  heightFactor: size.toDouble(),
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
              ),
              if (threshold != null)
                DottedBorder(
                  borderType: BorderType.RRect,
                  color: Colors.red[800]!,
                  dashPattern: const [4, 6],
                  strokeWidth: 2,
                  customPath: (size) {
                    return Path()
                      ..moveTo(overspendIndicatorPadding, 1)
                      ..lineTo(constraints.maxWidth - overspendIndicatorPadding, 1)
                      ..close();
                  },
                  child: FractionallySizedBox(
                    alignment: Alignment.topRight,
                    heightFactor: threshold,
                    widthFactor: 1,
                  ),
                ),
              Positioned(
                bottom: size.toDouble() * constraints.maxHeight,
                left: 0,
                width: constraints.maxWidth,
                child: Text(
                  currency.format(remaining.abs()).length > 6
                      ? thousandsCurrency.format(remaining.abs())
                      : currency.format(remaining.abs()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: remaining >= 0 ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      shadows: const [
                        Shadow(
                          offset: Offset(1.0, 1.0),
                          blurRadius: 1.0,
                          color: Colors.black,
                        ),
                      ]),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
