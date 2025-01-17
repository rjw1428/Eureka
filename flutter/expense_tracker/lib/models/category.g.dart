// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CategoryData _$CategoryDataFromJson(Map<String, dynamic> json) => CategoryData(
      label: json['label'] as String,
      icon: json['icon'] as String,
      budget: (json['budget'] as num).toDouble(),
      deleted: json['deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$CategoryDataToJson(CategoryData instance) =>
    <String, dynamic>{
      'label': instance.label,
      'icon': instance.icon,
      'budget': instance.budget,
      'deleted': instance.deleted,
    };

CategoryDataWithId _$CategoryDataWithIdFromJson(Map<String, dynamic> json) =>
    CategoryDataWithId(
      label: json['label'] as String,
      icon: json['icon'] as String,
      budget: (json['budget'] as num).toDouble(),
      deleted: json['deleted'] as bool? ?? false,
      id: json['id'] as String,
    );

Map<String, dynamic> _$CategoryDataWithIdToJson(CategoryDataWithId instance) =>
    <String, dynamic>{
      'label': instance.label,
      'icon': instance.icon,
      'budget': instance.budget,
      'deleted': instance.deleted,
      'id': instance.id,
    };
