import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteSuggestionNotifier extends StateNotifier<List<String>> {
  NoteSuggestionNotifier({required this.user, required this.firestore})
      : super(user?.noteSuggestions ?? []);

  final ExpenseUser? user;
  final FirebaseFirestore firestore;

  addSuggestion(String newSuggestion) {
    if (user == null) {
      return;
    }

    return firestore.collection('expenseUsers').doc(user!.id).update({
      'noteSuggestions': FieldValue.arrayUnion([newSuggestion])
    });
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

final noteSuggestionProvider = StateNotifierProvider<NoteSuggestionNotifier, List<String>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final firestore = ref.read(backendProvider);
  return NoteSuggestionNotifier(user: user, firestore: firestore);
});
