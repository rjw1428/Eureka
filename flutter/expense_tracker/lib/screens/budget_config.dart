import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:expense_tracker/services/categories.service.dart';
import 'package:expense_tracker/services/category_form.provider.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class BudgetConfigScreen extends StatefulWidget {
  const BudgetConfigScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _BudgetConfigScreenState();
  }
}

class _BudgetConfigScreenState extends State<BudgetConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;

    return StreamBuilder(
        stream: AuthService().expenseUser$.switchMap(
              (account) => CategoriesService().categoryStream$.map((configs) {
                return {
                  'configs': configs.where((config) => !config.deleted).toList(),
                  'user': account
                };
              }),
            ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Loading();
          }

          final List<CategoryDataWithId> configs =
              !snapshot.hasData ? [] : snapshot.data!['configs'];
          final ExpenseUser? user = !snapshot.hasData ? null : snapshot.data!['user'];
          final double totalBudget = configs.fold(0, (sum, val) => sum + val.budget);

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
                        editable: user?.role == 'primary',
                        onEdit: (id) => openAddCategoryOverlay(context, id),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: () => openAddCategoryOverlay(context),
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

class CategoryList extends StatelessWidget {
  const CategoryList({
    super.key,
    required this.categoryList,
    required this.onEdit,
    required this.editable,
  });

  final List<CategoryDataWithId> categoryList;
  final void Function(CategoryDataWithId) onEdit;
  final bool editable;

  @override
  Widget build(Object context) {
    return SingleChildScrollView(
      child: Column(
          children: categoryList
              .map((category) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Icon(category.iconData),
                                ),
                                Text(category.label),
                              ],
                            ),
                          ),
                          Text(
                            'Budget: ${currency.format(category.budget)}',
                            textAlign: TextAlign.end,
                          ),
                          if (editable)
                            Row(
                              children: [
                                TextButton(
                                    onPressed: () => onEdit(category),
                                    child: const Icon(Icons.edit)),
                              ],
                            )
                        ],
                      ),
                    ),
                  ))
              .toList()),
    );
  }
}
