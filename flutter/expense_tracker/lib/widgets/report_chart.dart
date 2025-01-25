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
    final coffeeBudget = budgetData.firstWhere((config) => config.id == 'COFFEE');
    final dataMax = data
        .asMap()
        .entries
        .where((entry) => entry.value.categoryId == 'COFFEE')
        .map((entry) => entry.value)
        .fold(coffeeBudget.budget, (max, cur) => max > cur.total ? max : cur.total);

    return LineChart(
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
                interval: 2
                // reservedSize: 40,
                ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: Colors.black, width: 4),
            left: BorderSide(color: Colors.transparent),
            right: BorderSide(color: Colors.transparent),
            top: BorderSide(color: Colors.transparent),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: coffeeBudget.budget,
              color: Colors.green,
              strokeWidth: 3,
              dashArray: [20, 10],
            ),
          ],
        ),
        lineBarsData: lineChartBarData1(data),
        // lineChartBarData1_2,
        // lineChartBarData1_3,

        // minX: 0,
        // maxX: chartData.length + 1,
        // minX: chartData.length.toDouble(),
        // maxX: -1,
        maxY: dataMax + 10,
        minY: 0,
      ),
    );
  }
}
