import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope, Override;
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] under [ProviderScope] with optional [overrides].
Future<void> pumpAppWith(
  WidgetTester tester, {
  required Widget child,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
}
