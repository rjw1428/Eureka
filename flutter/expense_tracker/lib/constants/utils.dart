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

int monthsBetween(DateTime startDate, DateTime endDate) {
  int years = endDate.year - startDate.year;
  int months = endDate.month - startDate.month;

  if (years > 0 && months < 0) {
    years--;
    months += 12;
  }

  return years * 12 + months;
}
