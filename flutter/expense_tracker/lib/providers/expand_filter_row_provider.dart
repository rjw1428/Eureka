import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilterRowStateNotifier extends StateNotifier<bool> {
  FilterRowStateNotifier() : super(false);

  toggleRow() {
    state = !state;
  }

  openRow() {
    state = true;
  }
}

final filterRowStateProvider = StateNotifierProvider<FilterRowStateNotifier, bool>((ref) {
  return FilterRowStateNotifier();
});
