import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart';

/// Short-lived [ProviderContainer] for pure Dart notifier tests.
ProviderContainer createTestContainer(List<Override> overrides) {
  return ProviderContainer(overrides: overrides);
}
