import 'package:expense_tracker/models/linked_user.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final linkedUserProvider = Provider<List<LinkedUser>>((ref) {
  final user = ref.watch(userProvider).valueOrNull;

  if (user == null) {
    return [];
  }

  final currentAccounts = user.linkedAccounts;
  final currentAccountIds = currentAccounts.map((account) => account.id);
  final oldAccounts = user.archivedLinkedAccounts.where(
    (account) => !currentAccountIds.contains(account.id), // Remove Dupes
  );
  final self = LinkedUser.fromUser(user);
  return [...oldAccounts, ...currentAccounts, self];
});
