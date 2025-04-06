import 'package:expense_tracker/models/expense_user.dart';
import 'package:expense_tracker/providers/backend_provider.dart';
import 'package:expense_tracker/services/account_link.service.dart';
import 'package:expense_tracker/services/theme_color.service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

// Used on home screen to determine if user is logged in or not
final userIdProvider = StreamProvider<String?>((ref) {
  final auth = ref.read(authProvider);
  return auth
      .authStateChanges()
      .map((user) => user?.uid)
      .distinct((prev, cur) => prev == cur)
      .doOnData((id) => print(id))
      .shareReplay(maxSize: 1);
});

final userProvider = StreamProvider<ExpenseUser?>((ref) {
  final uid = ref.watch(userIdProvider).valueOrNull;
  final firestore = ref.read(backendProvider);

  if (uid == null) {
    return Stream.value(null);
  }

  return firestore
      .collection('expenseUsers')
      .doc(uid)
      .snapshots()
      .where((event) => event.data() != null)
      .map(
        (event) => ExpenseUser.fromJson({
          'id': event.id,
          ...event.data()!,
        }),
      )
      .doOnDone(() => print('CLOSED: expenseUserFetch stream'))
      .handleError((err) => print('WARN: expenseUserFetch stream errored ${err.toString()}'));
});

final userSettingsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = ref.read(userProvider).valueOrNull;
  return CombineLatestStream.combine2(
      AccountLinkService().pendingLinkRequestList(user!.id),
      ThemeColorService().colorStream$,
      (pendingRequestList, color) =>
          {'pendingRequestList': pendingRequestList, 'user': user, 'color': color});
});
