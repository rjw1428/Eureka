// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SummaryEntry _$SummaryEntryFromJson(Map<String, dynamic> json) => SummaryEntry(
      id: json['id'] as String,
      count: (json['count'] as num).toInt(),
      total: (json['total'] as num).toDouble(),
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
      startDate: DateTime.parse(json['startDate'] as String),
      categoryId: json['categoryId'] as String,
    );

Map<String, dynamic> _$SummaryEntryToJson(SummaryEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'count': instance.count,
      'total': instance.total,
      'lastUpdate': instance.lastUpdate.toIso8601String(),
      'startDate': instance.startDate.toIso8601String(),
      'categoryId': instance.categoryId,
    };
