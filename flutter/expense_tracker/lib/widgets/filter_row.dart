import 'package:expense_tracker/constants/categories.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:flutter/material.dart';
import 'package:multi_dropdown/multi_dropdown.dart';

class FilterRow extends StatefulWidget {
  const FilterRow({
    super.key,
    required this.options,
    required this.selectedFilters,
    required this.onFilter,
  });

  final List<CategoryDataWithId> options;
  final List<Category> selectedFilters;
  final void Function(List<Category>) onFilter;

  @override
  State<StatefulWidget> createState() {
    return _FilterState();
  }
}

class _FilterState extends State<FilterRow> {
  @override
  Widget build(BuildContext context) {
    final controller = MultiSelectController<Category>();
    final defaultOptions = widget.options
        .map(
          (el) => DropdownItem(
            label: el.label,
            value: el.id,
            selected: widget.selectedFilters.contains(el.id),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: MultiDropdown<Category>(
              items: defaultOptions,
              controller: controller,
              enabled: true,
              searchEnabled: false,
              chipDecoration: ChipDecoration(
                backgroundColor: Theme.of(context).cardTheme.color,
                wrap: true,
                runSpacing: 2,
                spacing: 10,
              ),
              fieldDecoration: FieldDecoration(
                hintText: 'Categories',
                hintStyle: const TextStyle(color: Colors.black87),
                prefixIcon: const Icon(Icons.filter_list_alt),
                showClearIcon: false,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.black87,
                  ),
                ),
              ),
              dropdownDecoration: DropdownDecoration(
                backgroundColor: Theme.of(context).cardTheme.color!,
              ),
              dropdownItemDecoration: DropdownItemDecoration(
                selectedBackgroundColor: Theme.of(context).cardTheme.color,
                selectedIcon:
                    Icon(Icons.check_box, color: Theme.of(context).appBarTheme.backgroundColor),
                disabledIcon: Icon(Icons.lock, color: Colors.grey.shade300),
              ),
              onSelectionChange: (selection) {
                widget.onFilter(selection);
                controller.closeDropdown();
              },
            ),
          ),
          TextButton(onPressed: controller.selectAll, child: const Text('SelectAll')),
          TextButton(onPressed: controller.clearAll, child: const Text('Clear All')),
        ],
      ),
      // Padding(
      //   padding: const EdgeInsets.symmetric(vertical: 8),
      //   child:
      // ),
    );
  }
}
