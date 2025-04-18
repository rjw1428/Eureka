import 'package:expense_tracker/models/linked_user.dart';
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
  final List<LinkedUser> linkedAccounts;
  final List<LinkedUser> archivedLinkedAccounts;
  final Map<String, String> userSettings;
  final List<String> noteSuggestions;
  final AccountNotification? notification;
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
    required this.userSettings,
    this.noteSuggestions = const [],
    this.linkedAccounts = const [],
    this.archivedLinkedAccounts = const [],
    this.notification,
    this.backupLedgerId,
  });

  factory ExpenseUser.fromJson(Map<String, dynamic> json) {
    return _$ExpenseUserFromJson(json);
  }
}
