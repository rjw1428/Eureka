import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'test_provider.g.dart';

@riverpod
String test(Ref ref) {
  return 'test';
}
