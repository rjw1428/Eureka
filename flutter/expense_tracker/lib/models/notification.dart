import 'package:json_annotation/json_annotation.dart';
part 'notification.g.dart';

@JsonSerializable()
class AccountNotification {
  const AccountNotification({
    required this.type,
    this.data,
  });

  final String type; //pendingRequest, primaryUnlink, secondaryUnlink
  final Map<String, dynamic>? data;

  factory AccountNotification.fromJson(Map<String, dynamic> json) =>
      _$AccountNotificationFromJson(json);
}
