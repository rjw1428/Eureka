// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExpenseUser _$ExpenseUserFromJson(Map<String, dynamic> json) => ExpenseUser(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      ledgerId: json['ledgerId'] as String,
      role: json['role'] as String,
      initialized: DateTime.parse(json['initialized'] as String),
      userSettings: Map<String, String>.from(json['userSettings'] as Map),
      linkedAccounts: (json['linkedAccounts'] as List<dynamic>? ?? [])
          .map((e) => LinkedUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      archivedLinkedAccounts: (json['archivedLinkedAccounts'] as List<dynamic>? ?? [])
          .map((e) => LinkedUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      notification: json['notification'] == null
          ? null
          : AccountNotification.fromJson(json['notification'] as Map<String, dynamic>),
      backupLedgerId: json['backupLedgerId'] as String?,
    );

Map<String, dynamic> _$ExpenseUserToJson(ExpenseUser instance) => <String, dynamic>{
      'id': instance.id,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'email': instance.email,
      'ledgerId': instance.ledgerId,
      'role': instance.role,
      'linkedAccounts': instance.linkedAccounts,
      'archivedLinkedAccounts': instance.archivedLinkedAccounts,
      'userSettings': instance.userSettings,
      'notification': instance.notification,
      'backupLedgerId': instance.backupLedgerId,
      'initialized': instance.initialized.toIso8601String(),
    };
