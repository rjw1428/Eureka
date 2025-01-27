import 'package:dotted_border/dotted_border.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';

class BarChart extends StatefulWidget {
  const BarChart({
    super.key,
    required this.expenses,
    required this.selectedFilters,
    required this.budgetConfigs,
    required this.screenWidth,
  });

  final List<Expense> expenses;
  final List<String> selectedFilters;
  final List<CategoryDataWithId> budgetConfigs;
  final double screenWidth;

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> with SingleTickerProviderStateMixin {
  bool _showLeftGradient = false;
  bool _showRightGradient = false;
  final double _scrollGradientWidth = 50.0;
  final double _scrollGradientOpacity = 0.8;
  final double _barColumnWidth = 64.0;
  final ScrollController _scrollController = ScrollController();

  List<ExpenseBucket> getBuckets(List<CategoryDataWithId> data) {
    return data
        .where((config) => widget.selectedFilters.contains(config.id))
        .map((config) => ExpenseBucket.forCategory(widget.expenses, data, config.id))
        .toList();
  }

  double getMaxTotalExpense(List<ExpenseBucket> buckets) {
    return buckets.fold(
        0, (total, bucket) => bucket.totalExpenses > total ? bucket.totalExpenses : total);
  }

  void _checkGradients() {
    // we are setting the _showGradient values in the build method (so
    //that they are updated as category selections change). I think the
    // only thing all this does is trigger a new "build" call from setState
    // on scroll, thus recalculating the visibility
    final newLeftGradientState = _scrollController.hasClients && _scrollController.offset > 0;
    final newRightGradientState = _scrollController.hasClients &&
        (_scrollController.offset == 0 || !_scrollController.position.atEdge);

    if (newRightGradientState != _showRightGradient || newLeftGradientState != _showLeftGradient) {
      setState(() {
        _showLeftGradient = newLeftGradientState;
        _showRightGradient = newRightGradientState;
      });
    }
  }

  @override
  void initState() {
    final chartWidth =
        widget.budgetConfigs.where((config) => widget.selectedFilters.contains(config.id)).length *
            _barColumnWidth;
    _showRightGradient = chartWidth > widget.screenWidth;

    _scrollController.addListener(_checkGradients);
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;

    final buckets = getBuckets(widget.budgetConfigs);
    final maxTotalExpense = getMaxTotalExpense(buckets);
    final chartWidth = buckets.length * _barColumnWidth;

    if (_scrollController.hasClients) {
      _showRightGradient = (_scrollController.offset == 0 && widget.screenWidth < chartWidth) ||
          (!_scrollController.position.atEdge && widget.screenWidth < chartWidth);

      _showLeftGradient = (_scrollController.offset > 0 && widget.screenWidth < chartWidth) ||
          (!_scrollController.position.atEdge && widget.screenWidth < chartWidth);
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: widget.screenWidth < 600 ? 8 : 0),
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
      child: Stack(
        children: [
          // LEFT GRADIENT TO INDICATE SCROLL
          AnimatedOpacity(
            opacity: _showLeftGradient ? _scrollGradientOpacity : 0,
            duration: const Duration(milliseconds: 500),
            child: Container(
              width: _scrollGradientWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).cardTheme.color!.withOpacity(.7),
                    Theme.of(context).cardTheme.color!.withOpacity(0)
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),

          // RIGHT GRADIENT TO INDICATE SCROLL
          AnimatedOpacity(
            opacity: _showRightGradient ? _scrollGradientOpacity : 0,
            duration: const Duration(milliseconds: 500),
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                width: _scrollGradientWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).cardTheme.color!.withOpacity(.7),
                      Theme.of(context).cardTheme.color!.withOpacity(0)
                    ],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                ),
              ),
            ),
          ),
          // SCROLLABLE CONTENT
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: widget.screenWidth > chartWidth ? widget.screenWidth - 32 : chartWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: buckets.map((bucket) {
                          final size = bucket.totalExpenses == 0
                              ? 0
                              : bucket.totalExpenses / maxTotalExpense;
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
                                        style: isDarkMode
                                            ? ThemeData.dark().textTheme.labelMedium
                                            : ThemeData().textTheme.labelMedium,
                                        softWrap: false,
                                      ),
                                      SelectableText(
                                          widget.budgetConfigs
                                              .firstWhere((config) => config.id == bucket.category)
                                              .label,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          style: Theme.of(context).textTheme.labelSmall),
                                      Icon(
                                        widget.budgetConfigs
                                            .firstWhere((config) => config.id == bucket.category)
                                            .iconData,
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
                          )
                          .toList(),
                    )
                  ],
                ),
              ),
            ),
          ),
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
                  heightFactor:
                      threshold != null && threshold! >= 2.0 ? threshold! - 2.0 : threshold,
                  widthFactor: 100,
                ),
              )
          ],
        ),
      ),
    );
  }
}
