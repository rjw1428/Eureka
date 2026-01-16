import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart' hide Settings;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/constants/utils.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/models/pending_request.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_tracker/models/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsNotifier extends StateNotifier<Settings> {
  final ExpenseUser? user;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  SettingsNotifier(this.user, this.firestore, this.functions)
      : super(
          Settings.fromMap(user?.userSettings ?? {}),
        ) {
    // initialize();
  }

  // void initialize() {
  //  // GET LINKED ACCOUNTS
  //   const user firestore.collection('expenseUsers').doc(userId).get()
  // }

  void setTheme(String theme) async {
    state = Settings(
        theme: theme,
        color: state.color,
        notificationSettings: state.notificationSettings);
    final validatedUser = user!;

    await firestore.collection('expenseUsers').doc(validatedUser.id).update({
      FieldPath(['userSettings', 'theme']): theme,
    });
  }

  void setColor(Color color) async {
    state = Settings(
        theme: state.theme,
        color: color,
        notificationSettings: state.notificationSettings);

    final colorStr =
        "${color.alpha},${color.red},${color.green},${color.blue}";
    // LocalStorageService().setThemeColor(result);

    final validatedUser = user!;

    // Update backend
    await firestore.collection('expenseUsers').doc(validatedUser.id).update({
      FieldPath(['userSettings', 'color']): colorStr,
    });

    // trigger cloud function to update linked accounts
    if (validatedUser.linkedAccounts.isNotEmpty) {
      await functions.httpsCallable("updateLinkedAccounts").call({
        'ids':
            validatedUser.linkedAccounts.map((account) => account.id).toList(),
        'self': validatedUser.id,
        'color': colorStr,
      });
    }
  }

  void toggleOverspendingIndividualBudget(bool value) async {
    final newNotificationSettings = NotificationSettings(
      overspendingIndividualBudget: value,
      overspendingTotalBudget:
          state.notificationSettings.overspendingTotalBudget,
    );
    state = Settings(
      theme: state.theme,
      color: state.color,
      notificationSettings: newNotificationSettings,
    );

    final validatedUser = user!;

    await firestore.collection('expenseUsers').doc(validatedUser.id).update({
      FieldPath([
        'userSettings',
        'notification.overspendingIndividualBudget'
      ]): value.toString(),
    });
  }

  void toggleOverspendingTotalBudget(bool value) async {
    final newNotificationSettings = NotificationSettings(
      overspendingIndividualBudget:
          state.notificationSettings.overspendingIndividualBudget,
      overspendingTotalBudget: value,
    );
    state = Settings(
      theme: state.theme,
      color: state.color,
      notificationSettings: newNotificationSettings,
    );

    final validatedUser = user!;

    await firestore.collection('expenseUsers').doc(validatedUser.id).update({
      FieldPath(['userSettings', 'notification.overspendingTotalBudget']):
          value.toString(),
    });
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  final user = ref.watch(userProvider).asData?.value;
  final firestore = ref.read(backendProvider);
  final functions = ref.read(functionsProvider);

  return SettingsNotifier(user, firestore, functions);
});
