import 'package:expense_tracker/services/fcm_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fcmServiceProvider = Provider((ref) => FCMService());
