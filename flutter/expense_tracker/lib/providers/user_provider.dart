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
      .handleError((err) =>
          print('WARN: expenseUserFetch stream errored ${err.toString()}'))
      .onErrorReturn(null)
      .doOnDone(() => print('CLOSED: expenseUserFetch stream'));
});

class UserCreationState extends StateNotifier<bool?> {
  UserCreationState(this.ref) : super(null) {
    _initialize();
  }

  final Ref ref;

  Future<void> _initialize() async {
    final uid = ref.read(userIdProvider).valueOrNull;
    if (uid == null) {
      state = null;
      return;
    }
    final firestore = ref.read(backendProvider);
    final doc = await firestore.collection('expenseUsers').doc(uid).get();
    state = doc.exists;
  }

  void loggedIn() {
    _initialize();
  }

  void loggedOut() {
    state = null;
  }

  void setCreated() {
    state = true;
  }
}

final userCreationStateProvider =
    StateNotifierProvider<UserCreationState, bool?>((ref) {
  return UserCreationState(ref);
});
