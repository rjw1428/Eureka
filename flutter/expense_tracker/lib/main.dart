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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:expense_tracker/widgets/show_dialog.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

late GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _setupForegroundMessageHandler() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Handling a foreground message: ${message.messageId}');
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}, ${message.notification?.body}');

    final context = navigatorKey.currentContext;
    if (context != null) {
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? '';
      showDialogNotification(
        title,
        Text(body),
        context,
      );
    }
  });
}

void main() async {
  // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((fn) {
  //   // Run App Function
  // });
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  _setupForegroundMessageHandler();

  await LocalStorageService().initialize();
  WidgetsFlutterBinding.ensureInitialized();

  // if (kDebugMode) {
  //   try {
  //     FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  //     await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  //   } catch (e) {
  //     print(e);
  //   }
  // }

  runApp(
    ProviderScope(
      child: Consumer(builder: (context, ref, child) {
        final seedColor = ref.watch(settingsProvider.select((settings) => settings.color));
        final theme = ref.watch(settingsProvider.select((settings) => settings.theme));
        final colorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
        );

        final darkColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        );

        final ThemeMode themeMode;
        switch (theme) {
          case 'light':
            themeMode = ThemeMode.light;
            break;
          case 'dark':
            themeMode = ThemeMode.dark;
            break;
          default:
            themeMode = ThemeMode.system;
            break;
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: ThemeData().copyWith(
            colorScheme: colorScheme,
            appBarTheme: const AppBarTheme().copyWith(
              backgroundColor: colorScheme.onPrimaryContainer,
              foregroundColor: Colors.white,
            ),
            cardTheme: const CardThemeData().copyWith(
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
            cardTheme: const CardThemeData().copyWith(
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
          themeMode: themeMode,
        );
      }),
    ),
  );
}
