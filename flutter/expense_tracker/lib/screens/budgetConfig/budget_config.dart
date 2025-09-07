import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/budgetConfig/category_list.dart';
import 'package:expense_tracker/services/category_form.provider.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BudgetConfigScreen extends ConsumerStatefulWidget {
  const BudgetConfigScreen({super.key});

  @override
  ConsumerState<BudgetConfigScreen> createState() {
    return _BudgetConfigScreenState();
  }
}

class _BudgetConfigScreenState extends ConsumerState<BudgetConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final AsyncValue<List<CategoryDataWithId>> budgetConfig$ =
        ref.watch(activeBudgetCategoryProvider);
    final user = ref.read(userProvider).valueOrNull!;

    return budgetConfig$.when(
        error: (error, stack) => Text(error.toString()),
        loading: () => const Loading(),
        data: (configs) {
          final double totalBudget =
              configs.fold(0, (sum, val) => sum + val.budget);
          return Scaffold(
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardSpace + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Budget Config',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spending Categories:',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.start,
                        ),
                        SelectableText(
                          'Total: ${currency.format(totalBudget)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        )
                      ],
                    ),
                    Expanded(
                      child: CategoryList(
                        categoryList: configs,
                        onEdit: (id) =>
                            openAddCategoryOverlay(context, user.ledgerId, id),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              openAddCategoryOverlay(context, user.ledgerId),
                          label: const Text('Add a spending category'),
                          icon: const Icon(Icons.playlist_add),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20)
                  ],
                ),
              ),
            ),
          );
        });
  }
}
