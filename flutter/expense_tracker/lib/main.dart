import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/providers/settings_provider.dart';
import 'package:expense_tracker/routing.dart';
import 'package:expense_tracker/services/local_storage.service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:expense_tracker/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((fn) {
  //   // Run App Function
  // });
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalStorageService().initialize();
  WidgetsFlutterBinding.ensureInitialized();

  // try {
  //   FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  //   await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  // } catch (e) {
  //   print(e);
  // }

  runApp(
    ProviderScope(
      child: Consumer(builder: (context, ref, child) {
        final seedColor =
            ref.watch(settingsProvider.select((settings) => settings.color));
        final colorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
        );

        final darkColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        );
        return MaterialApp(
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
                // Reaction text
                labelMedium: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                )),
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
          themeMode: ThemeMode.dark,
        );
      }),
    ),
  );
}
