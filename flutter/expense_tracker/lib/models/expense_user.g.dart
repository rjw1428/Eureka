// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExpenseUser _$ExpenseUserFromJson(Map<String, dynamic> json) => ExpenseUser(
      id: json['id'] as String,
      email: json['email'] as String,
      ledgerId: json['ledgerId'] as String,
      role: json['role'] as String,
      linkedAccounts: (json['linkedAccounts'] as List<dynamic>?)
          ?.map((e) => Map<String, String>.from(e as Map))
          .toList(),
      userSettings: (json['userSettings'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$ExpenseUserToJson(ExpenseUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'ledgerId': instance.ledgerId,
      'role': instance.role,
      'linkedAccounts': instance.linkedAccounts,
      'userSettings': instance.userSettings,
    };
