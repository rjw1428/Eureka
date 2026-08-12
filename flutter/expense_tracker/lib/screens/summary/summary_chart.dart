import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:expense_tracker/models/settings.dart';
import 'package:expense_tracker/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final formatter = DateFormat('MMM');

class ReportChart extends ConsumerWidget {
  const ReportChart({
    super.key,
    required this.data,
    required this.budgetData,
    this.budgetByMonth = const {},
  });
  final List<SummaryEntry> data;
  final CategoryDataWithId budgetData;

  /// Effective budget per month, keyed by the first of the month. Months
  /// absent from the map fall back to the configured budget.
  final Map<DateTime, double> budgetByMonth;

  /// The budget that applied in a given month, after any rollover allocation.
  double budgetFor(SummaryEntry entry) {
    final month = DateTime(entry.startDate.year, entry.startDate.month);
    return budgetByMonth[month] ?? budgetData.budget;
  }

  List<LineChartBarData> lineChartBarData1(
      List<SummaryEntry> chartData, Color themeColor) {
    chartData.sort((a, b) => a.startDate.compareTo(b.startDate));

    if (chartData.isEmpty) {
      return [];
    }
    final offset = chartData.first.startDate.month;

    final filteredData =
        chartData.asMap().entries.map((entry) => entry.value).toList();

    final selectedCategoryData = filteredData
        .asMap()
        .entries
        .map((entry) =>
            FlSpot((offset + entry.key).toDouble(), entry.value.total))
        .toList();

    // The budget is no longer a constant: a month carrying a rollover
    // allocation has a lower budget than its configured value, so this is
    // drawn as a stepped series rather than a single horizontal line.
    final budgetSpots = filteredData
        .asMap()
        .entries
        .map((entry) =>
            FlSpot((offset + entry.key).toDouble(), budgetFor(entry.value)))
        .toList();

    return [
      LineChartBarData(
        show: true,
        color: themeColor.withAlpha(150),
        barWidth: 2,
        isStepLineChart: true,
        dotData: const FlDotData(show: false),
        dashArray: [20, 10],
        spots: budgetSpots,
      ),
      LineChartBarData(
        isCurved: true,
        show: true,
        color: themeColor,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        preventCurveOverShooting: true,
        curveSmoothness: .50,
        // belowBarData: BarAreaData(show: true),
        spots: selectedCategoryData,
      )
    ];
  }

  int getChartInterval(int delta) {
    const totalSteps = 8;
    const intervals = [
      5,
      10,
      25,
      50,
      100,
      200,
      250,
      300,
      500,
      1000,
      1250,
      1500,
      1750,
      2000,
      2250,
      2500,
      2750,
      3000
    ];
    final baseStep = (delta / totalSteps).floor();
    for (final interval in intervals) {
      if (baseStep < interval) {
        return interval;
      }
    }
    return intervals.last;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor =
        ref.watch(settingsProvider.select((settings) => settings.color));
    final width = MediaQuery.of(context).size.width;
    final int dataMax = data.fold(
        0, (max, entry) => max > entry.total ? max : entry.total.toInt());
    final int dataMin = data.fold(
        0, (min, entry) => min < entry.total ? min : entry.total.toInt());
    final double maxBudget = data.isEmpty
        ? budgetData.budget
        : data.map(budgetFor).reduce((a, b) => a > b ? a : b);
    final int yMax = dataMax > maxBudget ? dataMax : maxBudget.ceil();
    final int yInterval = getChartInterval(yMax - dataMin);

    return Container(
      margin:
          EdgeInsets.symmetric(horizontal: 8, vertical: width < 600 ? 16 : 0),
      // padding: const EdgeInsets.symmetric(
      //   vertical: 16,
      //   horizontal: 8,
      // ),
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
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (touchedSpot) =>
                  Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (data) => data.map((spot) {
                // print(spot.toString());
                return LineTooltipItem(
                  '\$${spot.y.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.black),
                );
              }).toList(),
            ),
          ),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) =>
                      SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                              formatter.format(DateTime(2025, value.toInt())),
                              style: Theme.of(context).textTheme.labelSmall))),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              drawBelowEverything: true,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: yMax > 1000 ? 32 : 22,
                interval: yInterval.toDouble(),
                getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              // bottom: BorderSide(color: Colors.black, width: 2),
              bottom: BorderSide(color: Colors.transparent),
              left: BorderSide(color: Colors.transparent),
              right: BorderSide(color: Colors.transparent),
              top: BorderSide(color: Colors.transparent),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: Colors.black,
                strokeWidth: 2,
              ),
            ],
          ),
          lineBarsData: lineChartBarData1(data, themeColor),
          maxY: yMax.toDouble(),
          minY: dataMin.toDouble(),
        ),
      ),
    );
  }
}
