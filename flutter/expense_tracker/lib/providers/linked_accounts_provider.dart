import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final something = Provider((ref) {
  final user = ref.watch(userProvider).valueOrNull;

  if (user == null) {
    return [];
  }

  final oldAccounts = user.archivedLinkedAccounts ?? [];
  final currentAccounts = user.linkedAccounts ?? [];
  return [...oldAccounts, currentAccounts];
});
