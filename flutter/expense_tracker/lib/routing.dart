import 'package:expense_tracker/screens/create_account/create_account_screen.dart';
import 'package:expense_tracker/screens/home/home.dart';
import 'package:expense_tracker/screens/loading.dart';

var appRoutes = {
  '/': (context) => const HomeScreen(),
  '/welcome': (context) => const CreateAccountScreen(),
  '/loading': (context) => const LoadingScreen(),
};
