import 'package:expense_tracker/constants/help_text.dart';
import 'package:expense_tracker/screens/settings.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:flutter/material.dart';

class AppBarActionMenu extends StatelessWidget {
  const AppBarActionMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      tooltip: 'Menu',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == "SETTINGS") {
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SettingsScreen()));
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
                        child: Text('About Expense Tracker',
                            style: Theme.of(context).textTheme.headlineMedium)),
                    const SizedBox(height: 15),
                    ...helpText.expand((section) {
                      return [
                        Text(section.title, style: Theme.of(context).textTheme.titleMedium),
                        Text(section.info, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 15),
                      ];
                    }),
                    Center(
                      child: TextButton(
                        onPressed: () {
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
          AuthService().logOut();
          return;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: "SETTINGS",
          child: Row(
            children: [
              Icon(Icons.settings, color: Theme.of(context).textTheme.headlineLarge?.color),
              const Padding(padding: EdgeInsets.only(left: 8), child: Text('Settings'))
            ],
          ),
        ),
        PopupMenuItem(
          value: "HELP",
          child: Row(
            children: [
              Icon(Icons.help, color: Theme.of(context).textTheme.headlineLarge?.color),
              const Padding(padding: EdgeInsets.only(left: 8), child: Text('Help'))
            ],
          ),
        ),
        PopupMenuItem(
          value: "LOGOUT",
          child: Row(
            children: [
              Icon(Icons.logout, color: Theme.of(context).textTheme.headlineLarge?.color),
              const Padding(padding: EdgeInsets.only(left: 8), child: Text('Log Out'))
            ],
          ),
        ),
      ],
    );
  }
}
