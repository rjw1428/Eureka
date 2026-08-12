import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/providers/rollover_provider.dart';
import 'package:expense_tracker/services/rollover_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prompts the user to carry last month's overspend into the month that just
/// started, distributing a single pool across any active budget category.
///
/// Optional by design: "I'll do it later" is a first-class action, and the
/// modal closes itself if the paired user handles the rollover first.
class RolloverModal extends ConsumerStatefulWidget {
  const RolloverModal({
    super.key,
    required this.pool,
    required this.candidates,
    this.now,
  });

  /// The net amount to carry forward.
  final double pool;
  final List<RolloverCandidate> candidates;

  /// Injectable clock, so tests do not depend on the real date.
  final DateTime? now;

  @override
  ConsumerState<RolloverModal> createState() => _RolloverModalState();
}

class _RolloverModalState extends ConsumerState<RolloverModal> {
  late Map<String, double> _allocations;
  bool _submitting = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // Starts empty: the pool is a net figure, so which budgets absorb it is
    // the user's call, not a function of which categories ran over.
    _allocations = <String, double>{};
  }

  double get _unallocated => unallocated(_allocations, widget.pool);
  double get _allocated => totalAllocated(_allocations);

  void _setAllocation(String categoryId, double value) {
    setState(() {
      _allocations = clampAllocations(
        allocations: _allocations,
        categoryId: categoryId,
        requested: value,
        pool: widget.pool,
      );
    });
  }

  /// Closes the modal and reports why.
  ///
  /// The messenger is resolved *before* popping: afterwards this widget's
  /// context is defunct and cannot be used to find one.
  void _closeWith(String message) {
    if (_closing || !mounted) return;
    _closing = true;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _deferForNow() {
    HapticFeedback.selectionClick();
    ref.read(rolloverDeferredProvider.notifier).state =
        currentMonthKey(widget.now);
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    HapticFeedback.selectionClick();
    setState(() => _submitting = true);

    final result = await ref
        .read(rolloverNotifierProvider.notifier)
        .submitRollover(_allocations, now: widget.now);

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case RolloverSubmitResult.completed:
        _closeWith(_allocated > 0
            ? 'Rolled over ${currency.format(_allocated)} into this month'
            : 'Nothing carried over this month');
      case RolloverSubmitResult.lostClaim:
        _closeWith('Someone else is already handling the rollover');
      case RolloverSubmitResult.failed:
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text("Couldn't save the rollover — please try again"),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If the paired user claims or completes the month while this modal is
    // open, close it rather than let a doomed submit proceed. A record written
    // by this user is our own claim landing and must not close anything.
    ref.listen(rolloverStatusProvider, (previous, next) {
      final record = next.valueOrNull;
      if (record == null) return;
      if (record['claimedBy'] == ref.read(currentUserIdProvider)) return;

      _closeWith(
        record['status'] == kRolloverComplete
            ? 'Your partner just completed the rollover'
            : 'Your partner is handling the rollover',
      );
    });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(theme),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final candidate in widget.candidates)
                      _categoryRow(theme, candidate),
                  ],
                ),
              ),
            ),
            const Divider(),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Carry over ${sourceMonthLabel(widget.now)}',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'You spent ${currency.format(widget.pool)} more than budgeted last '
          'month. Choose which budgets give it back this month.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total ${currency.format(widget.pool)}',
                style: theme.textTheme.titleMedium),
            Text(
              'Unallocated ${currency.format(_unallocated)}',
              key: const Key('rollover-unallocated'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _unallocated > 0 ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _categoryRow(ThemeData theme, RolloverCandidate candidate) {
    final allocation = _allocations[candidate.id] ?? 0;
    final reduced = effectiveBudget(
      configuredBudget: candidate.budget,
      allocation: allocation,
    );
    final left = leftToSpend(
      budget: candidate.budget,
      committed: candidate.committed,
      allocation: allocation,
    );
    // Fixed to this category's own budget, so the thumb never moves because a
    // different row changed. Going further is blocked by the pool, not by the
    // track shrinking underneath the user.
    final max = sliderMaxFor(candidate.budget);
    final atPoolLimit = _unallocated <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(candidate.category.iconData, size: 24),
              ),
              Expanded(
                child: Text(
                  candidate.category.label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (allocation > 0) ...[
                Text(
                  currency.format(candidate.budget),
                  key: Key('rollover-original-${candidate.id}'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                currency.format(reduced),
                key: Key('rollover-budget-${candidate.id}'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: reduced < 0 ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
          Slider(
            key: Key('rollover-slider-${candidate.id}'),
            value: allocation.clamp(0, max == 0 ? 1 : max),
            max: max == 0 ? 1 : max,
            divisions: max >= 1 ? max.round() : null,
            onChanged: max == 0 || _submitting
                ? null
                : (value) => _setAllocation(candidate.id, value),
          ),
          Text(
            allocation > 0
                ? 'Adding ${currency.format(allocation)} rollover'
                : atPoolLimit
                    ? 'Nothing left to allocate'
                    : 'No rollover added',
            key: Key('rollover-allocation-${candidate.id}'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: allocation > 0 ? theme.colorScheme.primary : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Spent ${currency.format(candidate.committed)}  ·  '
            '${left >= 0 ? 'Remaining' : 'Over'} ${currency.format(left.abs())}',
            key: Key('rollover-left-${candidate.id}'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: left < 0 ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _submitting ? null : _deferForNow,
          child: const Text("I'll do it later", style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
