import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedTimeNotifier extends StateNotifier<DateTime> {
  SelectedTimeNotifier() : super(DateTime.now());

  void setSelectedTime(DateTime month) {
    state = month;
  }
}

final selectedTimeProvider =
    StateNotifierProvider<SelectedTimeNotifier, DateTime>((ref) => SelectedTimeNotifier());
