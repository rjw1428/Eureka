import 'package:expense_tracker/constants/categories.dart';
import 'package:flutter/material.dart';

class CategoryData {
  final String label;
  final IconData icon;
  final double budget;

  const CategoryData({required this.label, required this.icon, required this.budget});
}

class CategoryDataWithId extends CategoryData {
  final Category id;
  const CategoryDataWithId(
      {required super.label, required super.icon, required super.budget, required this.id});
}
