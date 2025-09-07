import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/create_account/create_account_screen.dart';
import 'package:expense_tracker/screens/home/expense_list/expenses_screen.dart';
import 'package:expense_tracker/screens/login/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCreated = ref.watch(userCreationStateProvider);
    if (isCreated == null) {
      return const LoginScreen();
    }
    if (!isCreated) {
      return const CreateAccountScreen();
    }
    final user = ref.read(userProvider).valueOrNull!;
    return ExpenseScreen(user: user);
  }
}
