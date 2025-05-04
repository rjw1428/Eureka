import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

// Used on home screen to determine if user is logged in or not
final userIdProvider = StreamProvider<String?>((ref) {
  final auth = ref.read(authProvider);
  return auth
      .authStateChanges()
      .map((user) => user?.uid)
      .distinct((prev, cur) => prev == cur)
      .shareReplay(maxSize: 1);
});

final userProvider = StreamProvider<ExpenseUser?>((ref) {
  final firestore = ref.read(backendProvider);
  final uid = ref.watch(userIdProvider).valueOrNull;
  print("UID: $uid");
  if (uid == null) {
    // ref.invalidateSelf();
    return Stream.value(null);
  }

  return firestore
      .collection('expenseUsers')
      .doc(uid)
      .snapshots()
      .map(
        (event) => ExpenseUser.fromJson({
          'id': event.id,
          ...event.data()!,
        }),
      )
      .doOnDone(() => print('CLOSED: expenseUserFetch stream'))
      .handleError((err) => print('WARN: expenseUserFetch stream errored ${err.toString()}'));
});
