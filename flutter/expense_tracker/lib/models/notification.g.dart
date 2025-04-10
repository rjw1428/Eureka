// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountNotification _$AccountNotificationFromJson(Map<String, dynamic> json) =>
    AccountNotification(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AccountNotificationToJson(
        AccountNotification instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data,
    };
