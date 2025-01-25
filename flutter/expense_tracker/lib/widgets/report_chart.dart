import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

final formatter = DateFormat('MMM');

class ReportChart extends StatelessWidget {
  const ReportChart({super.key, required this.data, required this.budgetData});
  final List<SummaryEntry> data;
  final List<CategoryDataWithId> budgetData;

  List<LineChartBarData> lineChartBarData1(List<SummaryEntry> chartData) {
    chartData.sort((a, b) => a.startDate.compareTo(b.startDate));
    final offset = chartData.first.startDate.month;

    final filteredData = chartData
        .asMap()
        .entries
        .where((entry) => entry.value.categoryId == 'COFFEE')
        .map((entry) => entry.value)
        .toList();

    final coffeeData = filteredData
        .asMap()
        .entries
        .map((entry) => FlSpot((offset + entry.key).toDouble(), entry.value.total))
        .toList();
    return [
      LineChartBarData(
        isCurved: true,
        show: true,
        color: Colors.red,
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
    final int yMax = budgetData.fold(
        dataMax, (max, category) => max > category.budget ? max : category.budget.toInt());

    final coffeeBudget = budgetData.firstWhere((config) => config.id == 'COFFEE');

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
                return LineTooltipItem(spot.y.toString(), const TextStyle(color: Colors.red));
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
              sideTitles: SideTitles(
                  getTitlesWidget: (value, meta) =>
                      Text(value.toString(), style: Theme.of(context).textTheme.labelSmall),
                  showTitles: true,
                  interval: (yMax ~/ 10).toDouble()),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              bottom: BorderSide(color: Colors.black, width: 3),
              left: BorderSide(color: Colors.transparent),
              right: BorderSide(color: Colors.transparent),
              top: BorderSide(color: Colors.transparent),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: coffeeBudget.budget,
                color: Colors.red.withAlpha(150),
                strokeWidth: 2,
                dashArray: [20, 10],
              ),
            ],
          ),
          lineBarsData: lineChartBarData1(data),
          // lineChartBarData1_2,
          // lineChartBarData1_3,
          maxY: yMax + 10,
          minY: 0,
        ),
      ),
    );
  }
}
