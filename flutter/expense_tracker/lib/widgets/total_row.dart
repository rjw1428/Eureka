import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/services/local_storage.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TotalRow extends StatefulWidget {
  const TotalRow({super.key, required this.sum, this.totalBudget})
      : delta = totalBudget == null ? null : totalBudget - sum;
  final double sum;
  final double? totalBudget;
  final double? delta;

  @override
  State<TotalRow> createState() => _TotalRowState();
}

class _TotalRowState extends State<TotalRow> {
  bool showValues = LocalStorageService().showTotal;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => setState(() {
        final nextState = !showValues;
        showValues = nextState;
        LocalStorageService().setShowTotal(nextState);
        HapticFeedback.mediumImpact();
      }),
      child: Column(
        children: [
          Text(
            showValues
                ? currency.format(widget.sum)
                : currency.format(widget.sum).replaceAll(RegExp(r'[0-9]'), '-'),
            style: TextStyle(fontSize: 24, color: Theme.of(context).textTheme.titleLarge?.color),
            textAlign: TextAlign.center,
          ),
          if (widget.delta != null)
            Text(
              '${widget.delta! >= 0 ? '+' : '-'} ${showValues ? currency.format(widget.delta!) : currency.format(widget.delta!).replaceAll(RegExp(r'[0-9]'), '-')}',
              style: TextStyle(fontSize: 16, color: widget.delta! >= 0 ? Colors.green : Colors.red),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
