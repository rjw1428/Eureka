import 'package:json_annotation/json_annotation.dart';

part 'pending_request.g.dart';

@JsonSerializable()
class PendingRequest {
  final String id;
  final String requestingUser;
  final String targetEmail;
  final String? requestingUserEmail;
  final String? targetUserId;
  final String? targetCurrentLedgerId;
  final String? requestingUserLedgerId;

  PendingRequest({
    required this.id,
    required this.requestingUser,
    required this.targetEmail,
    this.targetUserId,
    this.requestingUserEmail,
    this.targetCurrentLedgerId,
    this.requestingUserLedgerId,
  });

  factory PendingRequest.fromJson(Map<String, dynamic> json) => _$PendingRequestFromJson(json);
}
