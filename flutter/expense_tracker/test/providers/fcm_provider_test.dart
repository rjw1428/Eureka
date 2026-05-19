import 'package:expense_tracker/providers/fcm_provider.dart';
import 'package:expense_tracker/services/fcm_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockFCMService extends FCMService {
  @override
  Future<void> initialize(String userId) async {}
}

void main() {
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
