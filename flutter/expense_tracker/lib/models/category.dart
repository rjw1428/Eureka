import 'package:expense_tracker/constants/icons.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
part 'category.g.dart';

@JsonSerializable()
class CategoryData {
  final String label;
  final String icon;
  final double budget;

  CategoryData({
    required this.label,
    required this.icon,
    required this.budget,
    this.deleted = false,
  });

  bool deleted;

  Map<String, dynamic> toJson() => _$CategoryDataToJson(this);
}

@JsonSerializable()
class CategoryDataWithId extends CategoryData {
  CategoryDataWithId({
    required super.label,
    required super.icon,
    required super.budget,
    super.deleted = false,
    required this.id,
  });

  String id;

  factory CategoryDataWithId.fromJson(Map<String, dynamic> json) =>
      _$CategoryDataWithIdFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CategoryDataWithIdToJson(this);

  IconData get iconData {
    return categoryIcons[icon] ?? Icons.abc;
  }

  updateId(String oldId) {
    id = oldId;
  }
}

class CategoryDataWithIdAndDelta extends CategoryDataWithId {
  CategoryDataWithIdAndDelta({
    required this.delta,
    required super.id,
    required super.label,
    required super.icon,
    required super.budget,
    super.deleted = false,
  });

  final double delta;
}
