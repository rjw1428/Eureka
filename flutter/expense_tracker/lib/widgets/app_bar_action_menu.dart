import 'package:expense_tracker/constants/help_text.dart';
import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/screens/budgetConfig/budget_config.dart';
import 'package:expense_tracker/screens/settings.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppBarActionMenu extends ConsumerWidget {
  const AppBarActionMenu({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProvider).value!;
    return FutureBuilder(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final appVersion = snapshot.data?.version ?? '';
          return PopupMenuButton(
            tooltip: 'Menu',
            position: PopupMenuPosition.under,
            onSelected: (value) {
              HapticFeedback.selectionClick();
              if (value == "SETTINGS") {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (ctx) => const SettingsScreen()));
                return;
              }
              if (value == "BUDGET") {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (ctx) => const BudgetConfigScreen()));
                return;
              }
              if (value == "HELP") {
                showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Center(
                              child: Text(
                            'About $APP_TITLE',
                            style: Theme.of(context).textTheme.headlineMedium,
                          )),
                          const SizedBox(height: 15),
                          ...helpText.expand((section) {
                            return [
                              Text(section.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(section.info,
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 15),
                            ];
                          }),
                          Text('App Version: $appVersion'),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(context);
                              },
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                return;
              }
              if (value == "LOGOUT") {
                AuthService().logOut(ref);
                ref.read(userCreationStateProvider.notifier).loggedOut();
                return;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Center(
                  child: Text(
                    user.firstName,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ),
              // PopupMenuItem(
              //   value: "REPORT",
              //   child: Row(
              //     children: [
              //       Icon(
              //         Icons.line_axis_outlined,
              //         color: Theme.of(context).textTheme.headlineLarge?.color,
              //       ),
              //       const Padding(padding: EdgeInsets.only(left: 8), child: Text('Report'))
              //     ],
              //   ),
              // ),
              PopupMenuItem(
                value: "BUDGET",
                child: Row(
                  children: [
                    Icon(
                      Icons.monetization_on,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                    ),
                    const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('Budget'))
                  ],
                ),
              ),
              PopupMenuItem(
                value: "SETTINGS",
                child: Row(
                  children: [
                    Icon(
                      Icons.settings,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                    ),
                    const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('Settings'))
                  ],
                ),
              ),
              PopupMenuItem(
                value: "HELP",
                child: Row(
                  children: [
                    Icon(
                      Icons.help,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                    ),
                    const Padding(
                        padding: EdgeInsets.only(left: 8), child: Text('Help'))
                  ],
                ),
              ),
              PopupMenuItem(
                value: "LOGOUT",
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                    ),
                    const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('Log Out'))
                  ],
                ),
              ),
            ],
          );
        });
  }
}
