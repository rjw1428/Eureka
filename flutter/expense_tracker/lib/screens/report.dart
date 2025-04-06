import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/services/expense.service.dart';
import 'package:expense_tracker/widgets/report_chart.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

final formatter = DateFormat('MM/yy');

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    return const Text('TO DO');
    //   return StreamBuilder(
    //       stream: CombineLatestStream.combine2(
    //           // THIS START TIME SHOULD BE THE USERS INITIALIZED TIME
    //           ExpenseService().getSummary(DateTime(2024), null, categoryId),
    //           CategoriesService().categoryStream$, (summary, budgetConfig) {
    //         return {
    //           'summary': summary,
    //           'budgetConfig': budgetConfig.firstWhere((config) => config.id == categoryId),
    //         };
    //       }),
    //       builder: (context, snapshot) {
    //         if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
    //           return const Loading();
    //         }

    //         final budgetConfig = snapshot.data!['budgetConfig'] as CategoryDataWithId;
    //         final summaryData = snapshot.data!['summary'] as List<SummaryEntry>;
    //         summaryData.sort((a, b) => b.startDate.compareTo(a.startDate));

    //         final totalSpend = summaryData.fold(0.0, (sum, data) => sum + data.total);
    //         final totalDelta =
    //             summaryData.fold(0.0, (sum, data) => sum + (budgetConfig.budget - data.total));
    //         return SafeArea(
    //           child: Scaffold(
    //             body: Column(
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               children: [
    //                 Stack(
    //                   children: [
    //                     Center(
    //                       child: Padding(
    //                         padding: const EdgeInsets.only(top: 8.0),
    //                         child: Text(
    //                           '${budgetConfig.label} Spending Report',
    //                           style: Theme.of(context).textTheme.titleLarge,
    //                         ),
    //                       ),
    //                     ),
    //                     Row(
    //                       mainAxisAlignment: MainAxisAlignment.end,
    //                       children: [
    //                         IconButton(
    //                           onPressed: () => Navigator.pop(context),
    //                           icon: const Icon(Icons.close),
    //                         ),
    //                       ],
    //                     ),
    //                   ],
    //                 ),
    //                 Row(
    //                   mainAxisAlignment: MainAxisAlignment.center,
    //                   children: [
    //                     Text('Total ${totalDelta >= 0 ? 'Saved' : 'Over'}'),
    //                     const SizedBox(
    //                       width: 8,
    //                     ),
    //                     Text(
    //                       currency.format(totalDelta.abs()),
    //                       style: TextStyle(
    //                         color: totalDelta >= 0 ? Colors.green : Colors.red,
    //                       ),
    //                     ),
    //                   ],
    //                 ),
    //                 Center(
    //                   child: SizedBox(
    //                     width: MediaQuery.of(context).size.width * 0.9,
    //                     height: MediaQuery.of(context).size.height *
    //                         (MediaQuery.of(context).size.width > 800 ? 0.5 : .3),
    //                     child: ReportChart(
    //                       data: summaryData,
    //                       budgetData: budgetConfig,
    //                     ),
    //                   ),
    //                 ),
    //                 Padding(
    //                   padding: const EdgeInsets.all(8.0),
    //                   child: Row(
    //                     mainAxisAlignment: MainAxisAlignment.spaceAround,
    //                     children: [
    //                       Row(
    //                         children: [
    //                           const Text('Budget:'),
    //                           const SizedBox(
    //                             width: 8,
    //                           ),
    //                           Text('${currency.format(budgetConfig.budget)} per month'),
    //                         ],
    //                       ),
    //                       Row(
    //                         children: [
    //                           const Text('Total Spend:'),
    //                           const SizedBox(
    //                             width: 8,
    //                           ),
    //                           Text(currency.format(totalSpend)),
    //                         ],
    //                       )
    //                     ],
    //                   ),
    //                 ),
    //                 Expanded(
    //                   child: SingleChildScrollView(
    //                     child: Column(
    //                       children: summaryData.map((data) {
    //                         return ReportRow(reportData: data, budgetAmount: budgetConfig.budget);
    //                       }).toList(),
    //                     ),
    //                   ),
    //                 )
    //               ],
    //             ),
    //           ),
    //         );
    //       });
  }
}

class ReportRow extends StatelessWidget {
  ReportRow({super.key, required this.reportData, required this.budgetAmount})
      : delta = budgetAmount - reportData.total;

  final SummaryEntry reportData;
  final double budgetAmount;
  final double delta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatter.format(reportData.startDate)),
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
    );
  }
}
