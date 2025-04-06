import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/home/expenses_screen.dart';
import 'package:expense_tracker/screens/login/login.dart';
import 'package:expense_tracker/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ExpenseUser?> user$ = ref.watch(userProvider);
    return user$.when(
      data: (user) {
        return user == null ? const LoginScreen() : ExpenseScreen(user: user);
      },
      error: (error, stackTrace) => Column(children: [
        const Text('ERROR'),
        Text(
          error.toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]),
      loading: () => const Loading(),
    );
  }
}
