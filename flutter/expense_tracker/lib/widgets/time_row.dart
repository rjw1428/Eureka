import 'package:expense_tracker/constants/utils.dart';
import 'package:expense_tracker/models/time_filter_option.dart';
import 'package:expense_tracker/providers/expense_stream_provider.dart';
import 'package:expense_tracker/providers/filter_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  final TextEditingController timeController = TextEditingController();

  List<TimeFilterOption> _buildTimeFilterOptions(DateTime? latestDate) {
    final now = DateTime.now();
    // Use the later of now or latestDate as the upper bound
    final upperBound = latestDate != null && latestDate.isAfter(now)
        ? latestDate
        : now;

    final lastYear = DateTime(now.year - 1, now.month);
    final pastCount = widget.initialTime.isBefore(lastYear)
        ? 13
        : monthsBetween(widget.initialTime, now) + 1;

    final futureCount = monthsBetween(now, upperBound);

    // Generate future months (excluding current month) + past months
    final futureOptions = List<TimeFilterOption>.generate(futureCount, (i) {
      final d = DateTime(now.year, now.month + i + 1, 1);
      return TimeFilterOption(
          id: d, label: '${d.year} ${DateFormat('MMMM').format(d)}');
    });

    final pastOptions = List<TimeFilterOption>.generate(pastCount, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return TimeFilterOption(
          id: d, label: '${d.year} ${DateFormat('MMMM').format(d)}');
    });

    return [...futureOptions, ...pastOptions];
  }

  @override
  Widget build(BuildContext context) {
    final selectedTime = ref.read(selectedTimeProvider);
    final latestDate = ref.watch(latestSummaryDateProvider).value;
    final timeFilterOptions = _buildTimeFilterOptions(latestDate);

    return DropdownMenu<TimeFilterOption>(
      width: double.infinity,
      initialSelection: timeFilterOptions.firstWhere((opt) =>
          opt.id.month == selectedTime.month &&
          opt.id.year == selectedTime.year),
      controller: timeController,
      requestFocusOnTap: false,
      label: const Text('Select Month'),
      onSelected: (selectedDate) {
        // shouldn't ever be null, but just in case
        if (selectedDate != null) {
          ref
              .read(selectedTimeProvider.notifier)
              .setSelectedTime(selectedDate.id);
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
