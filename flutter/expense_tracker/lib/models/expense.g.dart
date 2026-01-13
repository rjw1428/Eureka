// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AmortizationDetails _$AmortizationDetailsFromJson(Map<String, dynamic> json) =>
    AmortizationDetails(
      groupId: json['groupId'] as String,
      nextId: json['nextId'] as String?,
      index: (json['index'] as num).toInt(),
      over: (json['over'] as num).toInt(),
    );

Map<String, dynamic> _$AmortizationDetailsToJson(
        AmortizationDetails instance) =>
    <String, dynamic>{
      'groupId': instance.groupId,
      'nextId': instance.nextId,
      'index': instance.index,
      'over': instance.over,
    };

Expense _$ExpenseFromJson(Map<String, dynamic> json) => Expense(
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      categoryId: json['categoryId'] as String,
      submittedBy: json['submittedBy'] as String?,
      note: json['note'] as String?,
      id: json['id'] as String?,
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      hideUntil: json['hideUntil'] == null
          ? null
          : DateTime.parse(json['hideUntil'] as String),
      amortized: json['amortized'] == null
          ? null
          : AmortizationDetails.fromJson(
              json['amortized'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ExpenseToJson(Expense instance) => <String, dynamic>{
      'categoryId': instance.categoryId,
      'id': instance.id,
      'note': instance.note,
      'submittedBy': instance.submittedBy,
      'amount': instance.amount,
      'date': instance.date.toIso8601String(),
      'reactions': instance.reactions,
      'hideUntil': instance.hideUntil?.toIso8601String(),
      'amortized': instance.amortized?.toJson(),
    };

ExpenseWithCategoryData _$ExpenseWithCategoryDataFromJson(
        Map<String, dynamic> json) =>
    ExpenseWithCategoryData(
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      categoryId: json['categoryId'] as String,
      submittedBy: json['submittedBy'] as String?,
      category:
          CategoryDataWithId.fromJson(json['category'] as Map<String, dynamic>),
      amortized: json['amortized'] == null
          ? null
          : AmortizationDetails.fromJson(
              json['amortized'] as Map<String, dynamic>),
    )
      ..id = json['id'] as String?
      ..note = json['note'] as String?
      ..reactions =
          (json['reactions'] as List<dynamic>).map((e) => e as String).toList()
      ..hideUntil = json['hideUntil'] == null
          ? null
          : DateTime.parse(json['hideUntil'] as String);

Map<String, dynamic> _$ExpenseWithCategoryDataToJson(
        ExpenseWithCategoryData instance) =>
    <String, dynamic>{
      'categoryId': instance.categoryId,
      'id': instance.id,
      'note': instance.note,
      'submittedBy': instance.submittedBy,
      'amount': instance.amount,
      'date': instance.date.toIso8601String(),
      'reactions': instance.reactions,
      'hideUntil': instance.hideUntil?.toIso8601String(),
      'amortized': instance.amortized,
      'category': instance.category,
    };
