import 'package:dice_roll/constants.dart';
import 'package:dice_roll/gradient_container.dart';
import 'package:flutter/material.dart';

void main() {
  // Requires Widget Tree
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: GradientContainer(colors: gradient, title: title),
      ),
    ),
  );

  // Ctrl + Shift + R => Refactor to wrap widget in layout widget
  // adding commas will cause formatter to break lines
}

// Just a demo of defaulting values for position arguments
int add(int a, [int b = 10]) {
  return a + b;
}
