import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

ProviderContainer makeContainer({List<Override> overrides = const []}) {
  return ProviderContainer(overrides: overrides);
}
