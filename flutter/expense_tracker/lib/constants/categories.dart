import 'package:expense_tracker/models/category.dart';
import 'package:flutter/material.dart';

// ignore: constant_identifier_names
enum Category { EATING_OUT, SNACKS, GAS, SHOPPING, HOME_RENO }

const Map<Category, CategoryData> categories = {
  Category.EATING_OUT: CategoryData(
    label: 'Eating Out',
    icon: Icons.lunch_dining_outlined,
    budget: 500.0,
  ),
  Category.SNACKS: CategoryData(
    label: 'Snacks',
    icon: Icons.icecream_outlined,
    budget: 100.0,
  ),
  Category.GAS: CategoryData(
    label: 'Gas',
    icon: Icons.local_gas_station_outlined,
    budget: 200.0,
  ),
  Category.SHOPPING: CategoryData(
    label: 'Shopping',
    icon: Icons.shopping_basket_outlined,
    budget: 100.0,
  ),
  Category.HOME_RENO: CategoryData(
    label: 'Home Reno',
    icon: Icons.construction_outlined,
    budget: 100.0,
  ),
};
