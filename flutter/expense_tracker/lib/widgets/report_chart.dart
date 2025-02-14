import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:expense_tracker/services/theme_color.service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

final formatter = DateFormat('MMM');

class ReportChart extends StatelessWidget {
  const ReportChart({super.key, required this.data, required this.budgetData});
  final List<SummaryEntry> data;
  final CategoryDataWithId budgetData;

  List<LineChartBarData> lineChartBarData1(List<SummaryEntry> chartData) {
    chartData.sort((a, b) => a.startDate.compareTo(b.startDate));
    final offset = chartData.first.startDate.month;

    final filteredData = chartData.asMap().entries.map((entry) => entry.value).toList();

    final coffeeData = filteredData
        .asMap()
        .entries
        .map((entry) => FlSpot((offset + entry.key).toDouble(), entry.value.total))
        .toList();
    return [
      LineChartBarData(
        isCurved: true,
        show: true,
        color: ThemeColorService().currentColor,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        // belowBarData: BarAreaData(show: true),
        spots: coffeeData,
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final int dataMax = data.fold(0, (max, entry) => max > entry.total ? max : entry.total.toInt());
    final int dataMin = data.fold(0, (min, entry) => min < entry.total ? min : entry.total.toInt());
    final int yMax = dataMax > budgetData.budget ? dataMax : budgetData.budget.toInt();
    final int yInterval = yMax < 100
        ? 10
        : yMax < 500
            ? 50
            : yMax < 1000
                ? 100
                : 300;
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
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
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
                  getTitlesWidget: (double value, TitleMeta meta) => SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(formatter.format(DateTime(2025, value.toInt())),
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
                getTitlesWidget: (value, meta) =>
                    Text(value.toStringAsFixed(0), style: Theme.of(context).textTheme.labelSmall),
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
                y: budgetData.budget,
                color: ThemeColorService().currentColor.withAlpha(150),
                strokeWidth: 2,
                dashArray: [20, 10],
              ),
              HorizontalLine(
                y: 0,
                color: Colors.black,
                strokeWidth: 2,
              ),
            ],
          ),
          lineBarsData: lineChartBarData1(data),
          maxY: yMax.toDouble(),
          minY: dataMin.toDouble(),
        ),
      ),
    );
  }
}
