import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:expense_tracker/providers/filtered_expenses_provider.dart';
import 'package:expense_tracker/screens/home/expense_list/expense_item.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:expense_tracker/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';

class ExpenseList extends ConsumerStatefulWidget {
  const ExpenseList({
    super.key,
    required this.onRemove,
    required this.onEdit,
    this.reactions = reactionsOptions,
  });

  final void Function(ExpenseWithCategoryData) onRemove;
  final void Function(ExpenseWithCategoryData) onEdit;
  final List<String> reactions;

  @override
  ConsumerState<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends ConsumerState<ExpenseList> {
  final List<OverlayEntry> _overlayEntry = [];

  void _showReactionMenu(ExpenseWithCategoryData expense, double dy, int index) {
    _removeOverlay();

    final OverlayEntry backgroundOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _removeOverlay,
          onLongPressStart: (d) => _removeOverlay(),
          child: Container(
            color: Colors.transparent,
          ),
        ),
      ),
    );

    final OverlayEntry menuOverlay = OverlayEntry(
      builder: (context) => Positioned(
        right: 50,
        top: dy + 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.reactions.map((reaction) {
                return InkWell(
                  onTap: () {
                    ref.read(expenseModifierProvider.notifier).react(expense, reaction);
                    _removeOverlay();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You reacted with $reaction'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Text(
                    reaction,
                    style: const TextStyle(fontSize: 18),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    final OverlayState overlay = Overlay.of(context);
    overlay.insert(backgroundOverlay);
    overlay.insert(menuOverlay);

    _overlayEntry.add(backgroundOverlay);
    _overlayEntry.add(menuOverlay);
  }

  void _removeOverlay() {
    if (_overlayEntry.isNotEmpty) {
      _overlayEntry.forEach((overlay) => overlay.remove());
    }
    _overlayEntry.clear();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(selectedFiltersProvider);
    final expenses$ = ref.watch(filteredExpensesProvider);

    return expenses$.when(
        error: (error, stackTrace) => Text(error.toString()),
        loading: () => const Loading(),
        data: (expenses) {
          final List<ExpenseWithCategoryData> filteredList = filters == null
              ? expenses
              : expenses.where((expense) => filters.contains(expense.category.id)).toList();

          if (filteredList.isEmpty) {
            if (filters != null && filters.isEmpty) {
              return const Center(child: Text('No filters selected 🫢'));
            }

            return const Center(child: Text('No expenses found 💩'));
          }

          return LazyLoadScrollView(
              onEndOfPage: () => {},
              child: ListView.builder(
                clipBehavior: Clip.hardEdge,
                itemCount: filteredList.length,
                itemBuilder: (ctx, i) {
                  return kIsWeb
                      ? ExpenseItem(
                          expense: filteredList[i],
                          onEdit: widget.onEdit,
                          onRemove: widget.onRemove,
                          onReact: (el, ctx) {
                            final box = ctx.findRenderObject() as RenderBox;
                            final offset = box.localToGlobal(Offset.zero);
                            return _showReactionMenu(el, offset.dy, i);
                          },
                        )
                      : GestureDetector(
                          key: ValueKey(expenses[i].id),
                          onLongPressStart: (details) {
                            HapticFeedback.lightImpact();
                            _showReactionMenu(filteredList[i], details.globalPosition.dy, i);
                          },
                          child: ExpenseItem(
                            expense: filteredList[i],
                            onEdit: (e) => widget.onEdit(e),
                            onRemove: widget.onRemove,
                          ),
                        );
                  // return Dismissible(
                  //   key: ValueKey(list[i].id),
                  //   onDismissed: (direction) => onRemove(list[i]),
                  //   child: ExpenseItem(expense: list[i]),
                  // );
                },
              ));
        });
  }
}
