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
          print(value);
          return;
        }
        if (value == "HELP") {
          print(value);
          return;
        }
        if (value == "LOGOUT") {
          print(value);
          return;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: "SETTINGS",
          child: Row(
            children: [
              Icon(Icons.settings, color: Theme.of(context).appBarTheme.backgroundColor),
              const Padding(padding: EdgeInsets.only(left: 8), child: Text('Settings'))
            ],
          ),
        ),
        PopupMenuItem(
          value: "HELP",
          child: Row(
            children: [
              Icon(Icons.help, color: Theme.of(context).appBarTheme.backgroundColor),
              const Padding(padding: EdgeInsets.only(left: 8), child: Text('Help'))
            ],
          ),
        ),
        PopupMenuItem(
          value: "LOGOUT",
          child: Row(
            children: [
              Icon(Icons.logout, color: Theme.of(context).appBarTheme.backgroundColor),
              const Padding(padding: EdgeInsets.only(left: 8), child: Text('Log Out'))
            ],
          ),
        ),
      ],
    );
  }
}
