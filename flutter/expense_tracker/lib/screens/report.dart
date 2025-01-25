import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/summary_entry.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/services/expense.service.dart';
import 'package:expense_tracker/widgets/report_chart.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: CombineLatestStream.combine2(
            ExpenseService().getSummary(DateTime(2024), null), CategoriesService().categoryStream$,
            (summary, budgetConfig) {
          return {
            'summary': summary,
            'budgetConfig': budgetConfig,
          };
        }),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
            return const Loading();
          }

          final _budgetConfig = snapshot.data!['budgetConfig'] as List<CategoryDataWithId>;
          final _summaryData = snapshot.data!['summary'] as List<SummaryEntry>;

          return SafeArea(
            child: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Spending Report',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: 500,
                      child: ReportChart(
                        data: _summaryData,
                        budgetData: _budgetConfig,
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        });
  }
}
