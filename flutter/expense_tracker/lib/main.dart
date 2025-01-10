import 'package:expense_tracker/widgets/expenses.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const seedColor = Color.fromARGB(255, 163, 3, 3);
final colorScheme = ColorScheme.fromSeed(
  seedColor: seedColor,
);

final darkColorScheme = ColorScheme.fromSeed(
  seedColor: seedColor,
  brightness: Brightness.dark,
);
void main() {
  // WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((fn) {
  //   // Run App Function
  // });
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData().copyWith(
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme().copyWith(
          backgroundColor: colorScheme.onPrimaryContainer,
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardTheme().copyWith(
          color: colorScheme.primaryFixed,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primaryContainer,
          ),
        ),
        textTheme: ThemeData().textTheme.copyWith(
              titleLarge: TextStyle(
                fontWeight: FontWeight.normal,
                color: colorScheme.onSecondaryContainer,
              ),
              titleSmall: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface,
                fontStyle: FontStyle.italic,
              ),
            ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: darkColorScheme,
        appBarTheme: const AppBarTheme().copyWith(
          backgroundColor: colorScheme.onPrimaryContainer,
        ),
        cardTheme: const CardTheme().copyWith(
          color: darkColorScheme.primaryContainer,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkColorScheme.primaryContainer,
          ),
        ),
      ),
      home: const Expenses(),
      themeMode: ThemeMode.system,
    ),
  );
}
