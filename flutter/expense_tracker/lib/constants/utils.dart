import 'package:flutter/material.dart';

Color stringToColor(String str) {
  final List<int> seedColorParts = str.split(',').map((e) => int.parse(e)).toList();
  return Color.fromARGB(
    seedColorParts[0],
    seedColorParts[1],
    seedColorParts[2],
    seedColorParts[3],
  );
}
