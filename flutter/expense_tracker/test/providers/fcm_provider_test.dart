import 'package:expense_tracker/providers/fcm_provider.dart';
import 'package:expense_tracker/services/fcm_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockFCMService extends FCMService {
  bool initialized = false;

  @override
  Future<void> initialize(String userId) async {
    initialized = true;
  }
}

void main() {
  group('FCM Provider', () {
    test('resolves to the overridden service', () {
      final container = ProviderContainer(
        overrides: [fcmServiceProvider.overrideWithValue(MockFCMService())],
      );
      addTearDown(container.dispose);

      expect(container.read(fcmServiceProvider), isA<MockFCMService>());
    });

    test('a double may be constructed without a live Firebase app', () {
      // Regression: FCMService used to resolve FirebaseFirestore.instance in a
      // field initializer, so building any subclass threw [core/no-app].
      expect(MockFCMService.new, returnsNormally);
    });

    test('the provider hands back the same instance on repeated reads', () {
      final container = ProviderContainer(
        overrides: [fcmServiceProvider.overrideWithValue(MockFCMService())],
      );
      addTearDown(container.dispose);

      expect(
        identical(
          container.read(fcmServiceProvider),
          container.read(fcmServiceProvider),
        ),
        isTrue,
      );
    });
  });
}
