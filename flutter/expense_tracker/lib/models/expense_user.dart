import 'package:expense_tracker/models/notification.dart';
import 'package:json_annotation/json_annotation.dart';
part 'expense_user.g.dart';

@JsonSerializable()
class ExpenseUser {
  final String id;
  final String email;
  final String ledgerId;
  final String role;
  final List<Map<String, String>>? linkedAccounts;
  final Map<String, String>? userSettings;
  final Notification? notification;
  final String? backupLedgerId;

  ExpenseUser({
    required this.id,
    required this.email,
    required this.ledgerId,
    required this.role,
    this.linkedAccounts,
    this.userSettings,
    this.notification,
    this.backupLedgerId,
  });

  factory ExpenseUser.fromJson(Map<String, dynamic> json) => _$ExpenseUserFromJson(json);
}
