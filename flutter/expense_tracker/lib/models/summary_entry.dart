import 'package:json_annotation/json_annotation.dart';

part 'summary_entry.g.dart';

@JsonSerializable()
class SummaryEntry {
  final String id;
  final int count;
  final double total;
  final DateTime lastUpdate;
  final DateTime startDate;
  final String categoryId;

  SummaryEntry({
    required this.id,
    required this.count,
    required this.total,
    required this.lastUpdate,
    required this.startDate,
    required this.categoryId,
  });

  factory SummaryEntry.fromJson(Map<String, dynamic> json) => _$SummaryEntryFromJson(json);

  Map<String, dynamic> toJson() => _$SummaryEntryToJson(this);
}
