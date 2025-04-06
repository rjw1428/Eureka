import 'package:expense_tracker/constants/strings.dart';
import 'package:expense_tracker/models/expense_user.dart';
import 'package:json_annotation/json_annotation.dart';
part 'linked_user.g.dart';

@JsonSerializable()
class LinkedUser {
  final String firstName;
  final String lastName;
  final String id;
  final String email;
  final String color;

  LinkedUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.color,
  });

  factory LinkedUser.fromJson(Map<String, dynamic> json) {
    return _$LinkedUserFromJson(json);
  }
  Map<String, dynamic> toJson() => _$LinkedUserToJson(this);

  factory LinkedUser.fromUser(ExpenseUser user) {
    return LinkedUser(
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      color: user.userSettings['color'] ?? kDefaultColorString,
    );
  }
}
