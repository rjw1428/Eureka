import 'package:expense_tracker/constants/categories.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeRow extends StatefulWidget {
  const TimeRow({
    super.key,
    required this.onTimeSelect,
  });

  final void Function(DateTime) onTimeSelect;

  @override
  State<StatefulWidget> createState() {
    return _TimeRowState();
  }
}

class _TimeRowState extends State<TimeRow> {
  final now = DateTime.now();
  List<TimeFilterOption> timeFilterOptions = [];
  final TextEditingController timeController = TextEditingController();

  @override
  void initState() {
    timeFilterOptions = List<TimeFilterOption>.generate(13, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return TimeFilterOption(id: d, label: '${d.year} ${DateFormat('MMMM').format(d)}');
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<TimeFilterOption>(
      width: double.infinity,
      initialSelection: timeFilterOptions
          .firstWhere((opt) => opt.id.month == now.month && opt.id.year == now.year),
      controller: timeController,
      requestFocusOnTap: false,
      label: const Text('Select Month'),
      onSelected: (selectedDate) {
        widget.onTimeSelect(selectedDate!.id);
      },
      menuHeight: 200,
      dropdownMenuEntries:
          timeFilterOptions.map((opt) => DropdownMenuEntry(label: opt.label, value: opt)).toList(),
    );
  }
}
