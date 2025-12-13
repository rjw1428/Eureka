import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/providers/fcm_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

class UserState {
  bool isAuthenticated;
  bool isCreated;

  UserState({
    required this.isAuthenticated,
    required this.isCreated,
  });

  copyWith({
    bool? isAuthenticated,
    bool? isCreated,
  }) {
    return UserState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isCreated: isCreated ?? this.isCreated,
    );
  }
}

// Used on home screen to determine if user is logged in or not
final userIdProvider = StreamProvider<String?>((ref) {
  final auth = ref.read(authProvider);
  return auth
      .authStateChanges()
      .map((user) => user?.uid)
      .startWith(auth.currentUser?.uid)
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

class UserCreationState extends StateNotifier<UserState?> {
  UserCreationState(this.ref) : super(null) {
    _initialize();
  }

  final Ref ref;

  Future<void> _initialize() async {
    ref.watch(userIdProvider).when(data: (uid) async {
      if (uid == null) {
        state = UserState(isAuthenticated: false, isCreated: false);
        return;
      }

      final firestore = ref.read(backendProvider);
      final doc = await firestore.collection('expenseUsers').doc(uid).get();
      state = UserState(isAuthenticated: true, isCreated: doc.exists);

      // Initialize FCM Service
      if (doc.exists) {
        final fcmService = ref.read(fcmServiceProvider);
        await fcmService.initialize(uid);
      }
    }, error: (error, stack) {
      print('Error fetching user ID: $error');
      state = null;
      return;
    }, loading: () {
      print('Loading user ID...');
      state = null;
      return;
    });
  }

  void loggedIn() {
    _initialize();
  }

  void loggedOut() {
    state = UserState(isAuthenticated: false, isCreated: false);
  }

  void setCreated() {
    state = state!.copyWith(isCreated: true);
  }
}

final userCreationStateProvider =
    StateNotifierProvider<UserCreationState, UserState?>((ref) {
  return UserCreationState(ref);
});

class AppleUserProfile {
  String givenName;
  String familyName;

  AppleUserProfile({
    required this.givenName,
    required this.familyName,
  });
}

class AppleBullshitState extends StateNotifier<AppleUserProfile?> {
  AppleBullshitState(this.ref) : super(null) {
    state = null;
  }

  final Ref ref;

  setAppleBullshit(String given, String family) {
    state = AppleUserProfile(givenName: given, familyName: family);
  }
}

final appleBullshitStateProvider =
    StateNotifierProvider<AppleBullshitState, AppleUserProfile?>((ref) {
  return AppleBullshitState(ref);
});
