import 'package:expense_tracker/constants/icons.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:json_annotation/json_annotation.dart';
part 'expense.g.dart';

final dateFormatter = DateFormat.yMd();

@JsonSerializable()
class AmortizationDetails {
  AmortizationDetails({
    required this.groupId,
    this.nextId,
    required this.index,
    required this.over,
  });

  final String groupId;
  final String? nextId;
  final int index;
  final int over;

  factory AmortizationDetails.fromJson(Map<String, dynamic> json) =>
      _$AmortizationDetailsFromJson(json);
  Map<String, dynamic> toJson() => _$AmortizationDetailsToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Expense {
  Expense({
    required this.amount,
    required this.date,
    required this.categoryId,
    this.submittedBy,
    this.note,
    this.id,
    this.reactions = const [],
    this.hideUntil,
    this.amortized,
  });

  String categoryId;
  String? id;
  String? note;
  String? submittedBy;
  double amount;
  DateTime date;
  List<String> reactions;
  DateTime? hideUntil;
  AmortizationDetails? amortized;

  factory Expense.fromJson(Map<String, dynamic> json) => _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);

  String get formattedDate {
    return dateFormatter.format(date);
  }

  updateId(String oldId) {
    id = oldId;
  }
}

@JsonSerializable()
class ExpenseWithCategoryData extends Expense {
  CategoryDataWithId category;

  ExpenseWithCategoryData({
    required super.amount,
    required super.date,
    required super.categoryId,
    required super.submittedBy,
    required this.category,
    super.amortized,
  });

  factory ExpenseWithCategoryData.fromJson(Map<String, dynamic> json) =>
      _$ExpenseWithCategoryDataFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ExpenseWithCategoryDataToJson(this);

  String get title {
    return '${category.label}${note == null ? '' : ':'} ${note ?? ''}';
  }

  IconData get icon {
    return categoryIcons[category.icon]!;
  }

  Map<String, int>? get reactionData {
    if (reactions.isEmpty) {
      return null;
    }
    return reactions.fold({}, (prev, cur) {
      if (prev!.containsKey(cur)) {
        prev[cur] = prev[cur]! + 1;
      } else {
        prev[cur] = 1;
      }
      return prev;
    });
  }
}

class ExpenseBucket {
  ExpenseBucket({
    required this.expenses,
    required this.category,
  });

  final CategoryDataWithId category;
  final List<Expense> expenses;

  double get totalExpenses {
    return expenses.fold(0, (sum, val) => sum + val.amount);
  }
}
