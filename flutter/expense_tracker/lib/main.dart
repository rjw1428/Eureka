import 'package:expense_tracker/routing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:expense_tracker/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((fn) {
  //   // Run App Function
  // });
  SharedPreferences preferences = await SharedPreferences.getInstance();
  String themeColor = preferences.getString('theme_color') ?? "255,163,3,3";
  final List<int> seedColorParts = themeColor.split(',').map((e) => int.parse(e)).toList();
  final seedColor = Color.fromARGB(
    seedColorParts[0],
    seedColorParts[1],
    seedColorParts[2],
    seedColorParts[3],
  );
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
  );

  final darkColorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
              labelSmall: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface,
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
        textTheme: ThemeData.dark().textTheme.copyWith(
              titleSmall: TextStyle(
                fontSize: 10,
                color: colorScheme.primaryContainer,
                fontStyle: FontStyle.italic,
              ),
            ),
      ),
      routes: appRoutes,
      initialRoute: '/',
      themeMode: ThemeMode.system,
    ),
  );
}
