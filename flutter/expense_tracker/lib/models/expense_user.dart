import 'package:expense_tracker/models/notification.dart';
import 'package:json_annotation/json_annotation.dart';
part 'expense_user.g.dart';

@JsonSerializable()
class ExpenseUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String ledgerId;
  final String role;
  final List<Map<String, String>>? linkedAccounts;
  final List<Map<String, String>>? archivedLinkedAccounts;
  final Map<String, String>? userSettings;
  final Notification? notification;
  final String? backupLedgerId;
  final DateTime initialized;

  ExpenseUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.ledgerId,
    required this.role,
    required this.initialized,
    this.linkedAccounts,
    this.archivedLinkedAccounts,
    this.userSettings,
    this.notification,
    this.backupLedgerId,
  });

  factory ExpenseUser.fromJson(Map<String, dynamic> json) {
    return _$ExpenseUserFromJson(json);
  }
}
