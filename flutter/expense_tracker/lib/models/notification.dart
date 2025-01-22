import 'package:json_annotation/json_annotation.dart';
part 'notification.g.dart';

@JsonSerializable()
class Notification {
  const Notification({
    required this.type,
    this.data,
  });

  final String type; //pendingRequest, primaryUnlink, secondaryUnlink
  final Map<String, dynamic>? data;

  factory Notification.fromJson(Map<String, dynamic> json) => _$NotificationFromJson(json);
}
