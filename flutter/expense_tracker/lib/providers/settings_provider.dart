import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/constants/utils.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/pending_request.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Settings {
  Settings({
    required this.color,
    this.pendingRequestList = const [],
  });

  final Color color;
  final List<PendingRequest> pendingRequestList;

  Settings copyWith({
    Color? color,
    List<PendingRequest>? pendingRequestList,
  }) {
    return Settings(
        color: color ?? this.color,
        pendingRequestList: pendingRequestList ?? this.pendingRequestList);
  }
}

class SettingsNotifier extends StateNotifier<Settings> {
  final ExpenseUser? user;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  SettingsNotifier(this.user, this.firestore, this.functions)
      : super(Settings(color: stringToColor(user?.userSettings['color'] ?? kDefaultColorString))) {
    // initialize();
  }

  // void initialize() {
  //  // GET LINKED ACCOUNTS
  //   const user firestore.collection('expenseUsers').doc(userId).get()
  // }

  void setColor(Color color) async {
    state = state.copyWith(color: color);

    final colorStr = "${color.alpha},${color.red},${color.green},${color.blue}";
    // LocalStorageService().setThemeColor(result);

    final validatedUser = user!;

    // Update backend
    await firestore.collection('expenseUsers').doc(validatedUser.id).update({
      'userSettings': {
        'color': colorStr,
      }
    });

    // trigger cloud function to update linked accounts
    if (validatedUser.linkedAccounts.isNotEmpty) {
      await functions.httpsCallable("updateLinkedAccounts").call({
        'ids': validatedUser.linkedAccounts.map((account) => account.id).toList(),
        'self': validatedUser.id,
        'color': colorStr,
      });
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  final user = ref.watch(userProvider).asData?.value;
  final firestore = ref.read(backendProvider);
  final functions = ref.read(functionsProvider);

  return SettingsNotifier(user, firestore, functions);
});
