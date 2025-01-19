// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PendingRequest _$PendingRequestFromJson(Map<String, dynamic> json) =>
    PendingRequest(
      id: json['id'] as String,
      requestingUser: json['requestingUser'] as String,
      targetEmail: json['targetEmail'] as String,
      targetUserId: json['targetUserId'] as String?,
      requestingUserEmail: json['requestingUserEmail'] as String?,
      targetCurrentLedgerId: json['targetCurrentLedgerId'] as String?,
      requestingUserLedgerId: json['requestingUserLedgerId'] as String?,
    );

Map<String, dynamic> _$PendingRequestToJson(PendingRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'requestingUser': instance.requestingUser,
      'targetEmail': instance.targetEmail,
      'requestingUserEmail': instance.requestingUserEmail,
      'targetUserId': instance.targetUserId,
      'targetCurrentLedgerId': instance.targetCurrentLedgerId,
      'requestingUserLedgerId': instance.requestingUserLedgerId,
    };
