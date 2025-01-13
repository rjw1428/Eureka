import 'package:flutter/material.dart';

class CategoryData {
  final String label;
  final IconData icon;
  final double budget;

  CategoryData({
    required this.label,
    required this.icon,
    required this.budget,
    this.deleted = false,
  });

  bool deleted;
}

class CategoryDataWithId extends CategoryData {
  CategoryDataWithId({
    required super.label,
    required super.icon,
    required super.budget,
    super.deleted = false,
    required this.id,
  });

  String id;

  updateId(String oldId) {
    id = oldId;
  }
}
