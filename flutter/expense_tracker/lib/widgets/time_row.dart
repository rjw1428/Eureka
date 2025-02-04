import 'package:expense_tracker/models/time_filter_option.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

int monthsBetween(DateTime startDate, DateTime endDate) {
  int years = endDate.year - startDate.year;
  int months = endDate.month - startDate.month;

  if (years > 0 && months < 0) {
    years--;
    months += 12;
  }

  return years * 12 + months;
}

class TimeRow extends StatefulWidget {
  const TimeRow({
    super.key,
    required this.onTimeSelect,
    required this.initialTime,
  });

  final void Function(DateTime) onTimeSelect;
  final DateTime initialTime;

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
    final lastYear = DateTime(now.year - 1, now.month);
    if (widget.initialTime.isBefore(lastYear)) {
      timeFilterOptions = List<TimeFilterOption>.generate(13, (i) {
        final d = DateTime(now.year, now.month - i, 1);
        return TimeFilterOption(id: d, label: '${d.year} ${DateFormat('MMMM').format(d)}');
      });
    } else {
      final count = monthsBetween(widget.initialTime, now) + 1;
      timeFilterOptions = List<TimeFilterOption>.generate(count, (i) {
        final d = DateTime(now.year, now.month - i, 1);
        return TimeFilterOption(id: d, label: '${d.year} ${DateFormat('MMMM').format(d)}');
      });
    }

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
