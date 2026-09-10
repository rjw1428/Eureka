import 'dart:async';

import 'package:expense_tracker/services/fcm_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMessaging extends Mock implements FirebaseMessaging {}

class MockSettings extends Mock implements NotificationSettings {}

const userId = 'user-1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late MockMessaging messaging;
  late StreamController<String> refreshes;

  setUp(() async {
    db = FakeFirebaseFirestore();
    messaging = MockMessaging();
    refreshes = StreamController<String>.broadcast();
    addTearDown(refreshes.close);

    await db.collection('expenseUsers').doc(userId).set({'firstName': 'Test'});

    when(() => messaging.requestPermission()).thenAnswer((_) async => MockSettings());
    when(() => messaging.getToken()).thenAnswer((_) async => 'token-1');
    when(() => messaging.onTokenRefresh).thenAnswer((_) => refreshes.stream);
  });

  FCMService build() => FCMService(firestore: db, messaging: messaging);

  Future<Object?> storedToken() async {
    final doc = await db.collection('expenseUsers').doc(userId).get();
    return doc.data()?['fcmToken'];
  }

  test('initialize asks for permission and stores the token', () async {
    await build().initialize(userId);

    verify(() => messaging.requestPermission()).called(1);
    expect(await storedToken(), 'token-1');
  });

  test('a null token writes nothing rather than a null field', () async {
    when(() => messaging.getToken()).thenAnswer((_) async => null);

    await build().initialize(userId);

    expect(await storedToken(), isNull);
    final doc = await db.collection('expenseUsers').doc(userId).get();
    expect(doc.data()!.containsKey('fcmToken'), isFalse);
  });

  test('a refreshed token replaces the stored one', () async {
    await build().initialize(userId);

    refreshes.add('token-2');
    await pumpEventQueue();

    expect(await storedToken(), 'token-2');
  });

  test('the existing user document is merged into, not replaced', () async {
    await build().initialize(userId);

    final doc = await db.collection('expenseUsers').doc(userId).get();
    expect(doc.data()!['firstName'], 'Test');
  });

  test('a failed write is swallowed so sign-in still completes', () async {
    // initialize() is awaited on the sign-in path, so a missing user document
    // must not turn into an unhandled error that strands the session.
    await db.collection('expenseUsers').doc('ghost').delete();

    await expectLater(build().initialize('ghost'), completes);
  });
}
