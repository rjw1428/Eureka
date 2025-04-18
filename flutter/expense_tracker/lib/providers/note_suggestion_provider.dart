import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// FOR ADD AND EDIT, THIS WILL BECOME A STATE NOTIFIER
final noteSuggestionProvider = Provider<List<String>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;

  if (user == null) {
    return [];
  }

  return user.noteSuggestions;
});
