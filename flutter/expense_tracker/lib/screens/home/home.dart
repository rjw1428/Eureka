import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/create_account/create_account_screen.dart';
import 'package:expense_tracker/screens/home/expense_list/expenses_screen.dart';
import 'package:expense_tracker/screens/login/login.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAccountState = ref.watch(userCreationStateProvider);
    if (userAccountState == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(APP_TITLE),
        ),
        body: const Loading(),
      );
    }
    if (!userAccountState.isAuthenticated) {
      return const LoginScreen();
    }
    if (!userAccountState.isCreated) {
      final appleShit = ref.read(appleBullshitStateProvider);
      return CreateAccountScreen(
        appleProfile: appleShit,
      );
    }
    final user = ref.read(userProvider).valueOrNull!;
    return ExpenseScreen(user: user);
  }
}
