// ignore: constant_identifier_names
import 'package:intl/intl.dart';

const APP_TITLE = 'SpendWatch';

// Formatters
final currency = NumberFormat.currency(locale: "en_US", symbol: "\$", decimalDigits: 2);
final thousandsCurrency = NumberFormat.currency(locale: "en_US", symbol: "\$", decimalDigits: 0);
