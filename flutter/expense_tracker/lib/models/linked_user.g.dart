// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LinkedUser _$LinkedUserFromJson(Map<String, dynamic> json) => LinkedUser(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      color: json['color'] as String,
    );

Map<String, dynamic> _$LinkedUserToJson(LinkedUser instance) =>
    <String, dynamic>{
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'id': instance.id,
      'email': instance.email,
      'color': instance.color,
    };
