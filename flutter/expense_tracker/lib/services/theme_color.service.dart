import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/constants/utils.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:expense_tracker/services/local_storage.service.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class ThemeColorService {
  static final ThemeColorService _instance = ThemeColorService._internal();

  final _db = FirebaseFirestore.instance;
  final _colorStreamController = StreamController<Color?>();
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  ThemeColorService._internal();
  Color currentColor = Colors.red;

  factory ThemeColorService() {
    return _instance;
  }

  get defaultColor => stringToColor(kDefaultColorString);

  Stream<Color> get colorStream$ {
    return Stream.value(defaultColor);
    // final userColor$ = AuthService().expenseUser$.map((user) {
    //   if (user == null) {
    //     return null;
    //   }

    //   // If there is a user, check local storage first
    //   if (LocalStorageService().themeColor != null) {
    //     final initialColor = _stringToColor(LocalStorageService().themeColor!);
    //     return initialColor;
    //   }

    //   // Return user's color
    //   final userColor = user.userSettings['color'] as String;
    //   final initialUserColor = _stringToColor(userColor);
    //   return initialUserColor;
    // });

    // final selectionColor$ = _colorStreamController.stream.asBroadcastStream();

    // return userColor$
    //     .switchMap(
    //       (userColor) => selectionColor$.startWith(userColor).map((selectedColor) {
    //         if (userColor == null) {
    //           return DEFAULT_COLOR;
    //         }
    //         return selectedColor ?? userColor;
    //       }),
    //     )
    //     .startWith(DEFAULT_COLOR);
  }

  Future<void> updateColor(Color color, ExpenseUser user) async {
    // Update local
    _selectColor(color);

    // Write to local
    final result = "${color.alpha},${color.red},${color.green},${color.blue}";
    LocalStorageService().setThemeColor(result);

    // Update backend
    await _db.collection('expenseUsers').doc(user.id).update({
      'userSettings': {
        'color': result,
      }
    });

    // trigger cloud function to update linked accounts
    if (user.linkedAccounts.isNotEmpty) {
      await functions.httpsCallable("updateLinkedAccounts").call({
        'ids': user.linkedAccounts.map((account) => account.id).toList(),
        'self': user.id,
        'color': result,
      });
    }
  }

  void reset() {
    _colorStreamController.sink.add(defaultColor);
  }

  void dispose() {
    _colorStreamController.close();
  }

  void _selectColor(Color color) async {
    currentColor = color;
    _colorStreamController.sink.add(color);
  }
}
