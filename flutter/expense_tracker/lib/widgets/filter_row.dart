import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_dropdown/multi_dropdown.dart';

class FilterRow extends ConsumerStatefulWidget {
  const FilterRow({
    super.key,
    required this.options,
  });

  final List<CategoryDataWithId> options;

  @override
  ConsumerState<FilterRow> createState() {
    return _FilterState();
  }
}

class _FilterState extends ConsumerState<FilterRow> {
  bool _showFilter = false;

  @override
  Widget build(BuildContext context) {
    final selectedFilters = ref.watch(selectedFiltersProvider);
    final controller = MultiSelectController<String>();
    final defaultOptions = widget.options
        .map(
          (el) => DropdownItem(
            label: el.label,
            value: el.id,
            selected: selectedFilters.contains(el.id),
          ),
        )
        .toList();

    Widget filterWidget = Column(
      children: [
        MultiDropdown<String>(
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
            hintStyle: TextStyle(color: Theme.of(context).textTheme.labelSmall?.color),
            prefixIcon: const Icon(Icons.filter_list_alt),
            showClearIcon: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  BorderSide(color: Theme.of(context).buttonTheme.colorScheme!.secondaryContainer),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: Colors.black87,
              ),
            ),
          ),
          dropdownDecoration: DropdownDecoration(
            borderRadius: BorderRadius.circular(4),
            backgroundColor: Theme.of(context).cardTheme.color!,
          ),
          dropdownItemDecoration: DropdownItemDecoration(
            selectedBackgroundColor: Theme.of(context).cardTheme.color,
            selectedIcon:
                Icon(Icons.check_box, color: Theme.of(context).appBarTheme.backgroundColor),
            disabledIcon: Icon(Icons.lock, color: Colors.grey.shade300),
          ),
          onSelectionChange: (selection) {
            ref.read(selectedFiltersProvider.notifier).setSelectedFilters(selection);
            controller.closeDropdown();
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton(onPressed: controller.selectAll, child: const Text('SelectAll')),
            TextButton(onPressed: controller.clearAll, child: const Text('Clear All')),
          ],
        )
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ExpansionPanelList(
        elevation: 0,
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _showFilter = isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (ctx, isOpen) => isOpen
                ? filterWidget
                : Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Filter by category',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
            body: const SizedBox(),
            canTapOnHeader: false,
            isExpanded: _showFilter,
          )
        ],
      ),
    );
  }
}
