import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

Color stringToColor(String str) {
  final List<int> seedColorParts =
      str.split(',').map((e) => int.parse(e)).toList();
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

String sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

String generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}
