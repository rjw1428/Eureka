import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteSuggestionNotifier extends StateNotifier<Map<String, List<String>>> {
  NoteSuggestionNotifier({required this.user, required this.firestore}) : super(user?.noteSuggestions ?? {});

  final ExpenseUser? user;
  final FirebaseFirestore firestore;

  addSuggestion(String newSuggestion, String categoryId) {
    if (user == null) {
      return;
    }

    final suggestions = List<String>.from(user!.noteSuggestions[categoryId] ?? []);
    if (!suggestions.contains(newSuggestion)) {
      suggestions.add(newSuggestion);
    }
    final updatedSuggestions = Map<String, List<String>>.from(user!.noteSuggestions);
    updatedSuggestions[categoryId] = suggestions;

    return firestore.collection('expenseUsers').doc(user!.id).update({'noteSuggestions': updatedSuggestions});
  }

  removeSuggestion(String toRemove) {
    if (user == null) {
      return;
    }

    return firestore.collection('expenseUsers').doc(user!.id).update({
      'noteSuggestions': FieldValue.arrayRemove([toRemove])
    });
  }
}

final noteSuggestionProvider = StateNotifierProvider<NoteSuggestionNotifier, Map<String, List<String>>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final firestore = ref.read(backendProvider);
  return NoteSuggestionNotifier(user: user, firestore: firestore);
});
