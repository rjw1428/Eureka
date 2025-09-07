// ignore: constant_identifier_names
import 'package:intl/intl.dart';

const APP_TITLE = 'SpendWatch';
const reactionsOptions = ['👍', '❤️', '😂', '😮', '😢', '🍻', '🎉', '💩'];
const kDefaultColorString = "255, 60, 75, 175";

// Formatters
final currency =
    NumberFormat.currency(locale: "en_US", symbol: "\$", decimalDigits: 2);
final thousandsCurrency =
    NumberFormat.currency(locale: "en_US", symbol: "\$", decimalDigits: 0);

const profileWelcomeText = '''
We're excited to have you on board. ${APP_TITLE} is your personal expense tracker designed to help you manage your finances effortlessly.

For starters, let's set up your account. Please create your profile to help us personalize your experience.
''';
