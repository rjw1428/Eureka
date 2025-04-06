// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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
    )..user = json['user'] == null
        ? null
        : LinkedUser.fromJson(json['user'] as Map<String, dynamic>);

Map<String, dynamic> _$ExpenseToJson(Expense instance) => <String, dynamic>{
      'categoryId': instance.categoryId,
      'id': instance.id,
      'note': instance.note,
      'submittedBy': instance.submittedBy,
      'user': instance.user,
      'amount': instance.amount,
      'date': instance.date.toIso8601String(),
      'reactions': instance.reactions,
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
    )
      ..id = json['id'] as String?
      ..note = json['note'] as String?
      ..user = json['user'] == null
          ? null
          : LinkedUser.fromJson(json['user'] as Map<String, dynamic>)
      ..reactions =
          (json['reactions'] as List<dynamic>).map((e) => e as String).toList();

Map<String, dynamic> _$ExpenseWithCategoryDataToJson(
        ExpenseWithCategoryData instance) =>
    <String, dynamic>{
      'categoryId': instance.categoryId,
      'id': instance.id,
      'note': instance.note,
      'submittedBy': instance.submittedBy,
      'user': instance.user,
      'amount': instance.amount,
      'date': instance.date.toIso8601String(),
      'reactions': instance.reactions,
      'category': instance.category,
    };
