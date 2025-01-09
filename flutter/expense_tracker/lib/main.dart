import 'package:expense_tracker/expenses.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Expense Tracker'),
          backgroundColor: const Color.fromARGB(255, 17, 67, 19),
          foregroundColor: Colors.white,
        ),
        body: const Expenses(),
      ),
    ),
  );
}
