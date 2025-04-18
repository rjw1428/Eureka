import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/summary/summary_item.dart';
import 'package:expense_tracker/screens/summary/summary_chart.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value!;
    final summary$ = ref.watch(
        expenseSummaryProvider((categoryId: categoryId, start: user.initialized, end: null)));
    final budgetConfig = ref.watch(budgetProvider
        .select((configs) => configs.value!.firstWhere((config) => config.id == categoryId)));
    return summary$.when(
        error: (error, stack) => Text(error.toString()),
        loading: () => const Loading(),
        data: (summary) {
          final totalDelta =
              summary.fold(0.0, (sum, data) => sum + (budgetConfig.budget - data.total));
          final totalSpend = summary.fold(0.0, (sum, data) => sum + data.total);

          return SafeArea(
            child: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${budgetConfig.label} Spending Report',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Total ${totalDelta >= 0 ? 'Saved' : 'Over'}'),
                      const SizedBox(
                        width: 8,
                      ),
                      Text(
                        currency.format(totalDelta.abs()),
                        style: TextStyle(
                          color: totalDelta >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height *
                          (MediaQuery.of(context).size.width > 800 ? 0.5 : .3),
                      child: ReportChart(
                        data: summary,
                        budgetData: budgetConfig,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          children: [
                            const Text('Budget:'),
                            const SizedBox(
                              width: 8,
                            ),
                            Text('${currency.format(budgetConfig.budget)} per month'),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Total Spend:'),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(currency.format(totalSpend)),
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: summary.map((data) {
                          return SummaryItem(reportData: data, budgetAmount: budgetConfig.budget);
                        }).toList(),
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
