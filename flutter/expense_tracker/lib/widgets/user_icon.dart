import 'package:expense_tracker/constants/utils.dart';
import 'package:expense_tracker/models/linked_user.dart';
import 'package:flutter/material.dart';

class UserIcon extends StatelessWidget {
  const UserIcon({super.key, required this.user, required this.size});

  final LinkedUser user;
  final int size;

  @override
  Widget build(Object context) {
    return Container(
      width: size.toDouble(),
      height: size.toDouble(),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: stringToColor(user.color),
        border: Border.all(
          color: ThemeData().cardColor,
          width: 4.0,
        ),
      ),
      child: Center(
        child: Text(
          "${user.firstName[0].toUpperCase()}${user.lastName[0].toUpperCase()}",
          style: TextStyle(fontSize: size / 2),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
