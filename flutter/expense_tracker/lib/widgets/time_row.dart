import 'package:expense_tracker/models/time_filter_option.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class TimeRow extends ConsumerStatefulWidget {
  const TimeRow({
    super.key,
    required this.initialTime,
  });

  final DateTime initialTime;

  @override
  ConsumerState<TimeRow> createState() {
    return _TimeRowState();
  }
}

class _TimeRowState extends ConsumerState<TimeRow> {
  final now = DateTime.now();
  List<TimeFilterOption> timeFilterOptions = [];
  final TextEditingController timeController = TextEditingController();

  @override
  void initState() {
    // Make the available time options.
    final lastYear = DateTime(now.year - 1, now.month);
    final count = widget.initialTime.isBefore(lastYear)
        ? 13 // Go back only for the last year
        : monthsBetween(widget.initialTime, now) + 1; // go back as far back as the user started
    timeFilterOptions = List<TimeFilterOption>.generate(count, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return TimeFilterOption(id: d, label: '${d.year} ${DateFormat('MMMM').format(d)}');
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTime = ref.read(selectedTimeProvider);
    return DropdownMenu<TimeFilterOption>(
      width: double.infinity,
      initialSelection: timeFilterOptions.firstWhere(
          (opt) => opt.id.month == selectedTime.month && opt.id.year == selectedTime.year),
      controller: timeController,
      requestFocusOnTap: false,
      label: const Text('Select Month'),
      onSelected: (selectedDate) {
        // shouldn't ever be null, but just in case
        if (selectedDate != null) {
          ref.read(selectedTimeProvider.notifier).setSelectedTime(selectedDate.id);
        }
      },
      menuHeight: 200,
      dropdownMenuEntries: timeFilterOptions
          .map(
            (opt) => DropdownMenuEntry(label: opt.label, value: opt),
          )
          .toList(),
    );
  }
}
