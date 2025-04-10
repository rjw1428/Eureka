import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final noteSuggestionProvider = FutureProvider<List<String>>((ref) async {
  final firestore = ref.read(backendProvider);
  final user = ref.watch(userProvider).valueOrNull;

  if (user == null) {
    return Future.value([]);
  }

  final doc = await firestore.collection('ledger').doc(user.ledgerId).get();
  final data = doc.data()!;
  if (data.containsKey('noteSuggestions')) {
    return List<String>.from(data['noteSuggestions'] ?? []);
  }
  return [];
});
