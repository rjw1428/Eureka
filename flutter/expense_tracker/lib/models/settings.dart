import 'package:flutter/material.dart';

class Settings {
  final String theme;
  final Color color;
  final NotificationSettings notificationSettings;

  Settings({
    required this.theme,
    required this.color,
    required this.notificationSettings,
  });

  factory Settings.fromMap(Map<String, String> map) {
    return Settings(
      theme: map['theme'] ?? 'auto',
      color: _colorFromString(map['color']),
      notificationSettings: NotificationSettings.fromMap(map),
    );
  }

  Map<String, String> toMap() {
    return {
      'theme': theme,
      'color': '${color.alpha},${color.red},${color.green},${color.blue}',
      ...notificationSettings.toMap(),
    };
  }
}

Color _colorFromString(String? colorString) {
  if (colorString == null) {
    return Colors.blue;
  }
  try {
    if (colorString.contains(',')) {
      final parts = colorString.split(',');
      return Color.fromARGB(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        int.parse(parts[3]),
      );
    } else {
      return Color(int.parse(colorString));
    }
  } catch (e) {
    return Colors.blue;
  }
}

class NotificationSettings {
  final bool overspendingIndividualBudget;
  final bool overspendingTotalBudget;

  NotificationSettings({
    required this.overspendingIndividualBudget,
    required this.overspendingTotalBudget,
  });

  factory NotificationSettings.fromMap(Map<String, String> map) {
    return NotificationSettings(
      overspendingIndividualBudget:
          map['notification.overspendingIndividualBudget'] == 'true',
      overspendingTotalBudget:
          map['notification.overspendingTotalBudget'] == 'true',
    );
  }

  Map<String, String> toMap() {
    return {
      'notification.overspendingIndividualBudget':
          overspendingIndividualBudget.toString(),
      'notification.overspendingTotalBudget':
          overspendingTotalBudget.toString(),
    };
  }
}
