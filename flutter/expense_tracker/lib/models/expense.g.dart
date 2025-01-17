// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Expense _$ExpenseFromJson(Map<String, dynamic> json) => Expense(
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      categoryId: json['categoryId'] as String,
      note: json['note'] as String?,
      id: json['id'] as String?,
    );

Map<String, dynamic> _$ExpenseToJson(Expense instance) => <String, dynamic>{
      'categoryId': instance.categoryId,
      'id': instance.id,
      'note': instance.note,
      'amount': instance.amount,
      'date': instance.date.toIso8601String(),
    };

ExpenseWithCategoryData _$ExpenseWithCategoryDataFromJson(
        Map<String, dynamic> json) =>
    ExpenseWithCategoryData(
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      categoryId: json['categoryId'] as String,
      category:
          CategoryDataWithId.fromJson(json['category'] as Map<String, dynamic>),
    )
      ..id = json['id'] as String?
      ..note = json['note'] as String?;

Map<String, dynamic> _$ExpenseWithCategoryDataToJson(
        ExpenseWithCategoryData instance) =>
    <String, dynamic>{
      'categoryId': instance.categoryId,
      'id': instance.id,
      'note': instance.note,
      'amount': instance.amount,
      'date': instance.date.toIso8601String(),
      'category': instance.category,
    };
