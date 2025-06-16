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

final collectionExists = FutureProvider<bool>((ref) async {
  final firestore = ref.read(backendProvider);
  final uid = ref.watch(userIdProvider).valueOrNull;
  if (uid == null) {
    return false;
  }
  final doc = await firestore.collection('expenseUsers').doc(uid).get();
  return doc.exists;
});

final userProvider = StreamProvider<ExpenseUser?>((ref) {
  final firestore = ref.read(backendProvider);
  final uid = ref.watch(userIdProvider).valueOrNull;
  print("UID: $uid");
  if (uid == null) {
    return Stream.value(null);
  }

  // final x = ref.watch(collectionExists).valueOrNull;
  // if (x == null || x == false) {
  //   print('Collection does not exist');
  //   return Stream.value(null);
  // }

  return firestore
      .collection('expenseUsers')
      .doc(uid)
      .snapshots()
      .map<ExpenseUser?>(
        (event) => ExpenseUser.fromJson({
          'id': event.id,
          ...event.data()!,
        }),
      )
      .handleError((err) => print('WARN: expenseUserFetch stream errored ${err.toString()}'))
      .onErrorReturn(null)
      .doOnDone(() => print('CLOSED: expenseUserFetch stream'));
});
