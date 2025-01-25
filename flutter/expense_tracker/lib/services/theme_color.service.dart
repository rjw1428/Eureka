import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/services/auth.service.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeColorService {
  final _db = FirebaseFirestore.instance;
  final _colorStreamController = StreamController<Color>();
  ThemeColorService._internal();
  Color currentColor = Colors.red;

  static final ThemeColorService _instance = ThemeColorService._internal();
  factory ThemeColorService() {
    return _instance;
  }
  Stream<Color> get colorStream {
    return _colorStreamController.stream.shareReplay(maxSize: 1);
  }

  Future<Color> init() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    String themeColor = preferences.getString('theme_color') ?? "255,163,3,3";
    final List<int> seedColorParts = themeColor.split(',').map((e) => int.parse(e)).toList();
    final initialColor = Color.fromARGB(
      seedColorParts[0],
      seedColorParts[1],
      seedColorParts[2],
      seedColorParts[3],
    );
    selectColor(initialColor);
    return initialColor;
  }

  void selectColor(Color color) async {
    currentColor = color;
    _colorStreamController.sink.add(color);
  }

  Future<void> updateColor(String color) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString('theme_color', color);

    final uid = await AuthService().userId$.first;
    await _db.collection('expenseUsers').doc(uid).update({
      'userSettings': {
        'color': color,
      }
    });
  }

  void dispose() {
    _colorStreamController.close();
  }
}
