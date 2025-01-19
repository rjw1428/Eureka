import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeColorService {
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

  void selectColor(Color color) {
    currentColor = color;
    _colorStreamController.sink.add(color);
  }

  void dispose() {
    _colorStreamController.close();
  }
}
