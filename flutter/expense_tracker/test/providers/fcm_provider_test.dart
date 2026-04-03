import 'package:expense_tracker/providers/fcm_provider.dart';
import 'package:expense_tracker/services/fcm_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

class MockFCMService extends Mock implements FCMService {}

void main() {
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('FCM Provider', () {
    test('fcmServiceProvider returns an instance of FCMService', () {
      final container = ProviderContainer(
        overrides: [
          fcmServiceProvider.overrideWithValue(MockFCMService()),
        ],
      );
      final fcmService = container.read(fcmServiceProvider);

      expect(fcmService, isA<MockFCMService>());
    });
  });
}
