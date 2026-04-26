import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/app.dart';
import '_support/seed_test_overrides.dart';

void main() {
  testWidgets('Nexus projects app smoke test', (WidgetTester tester) async {
    // Mobile width: avoid desktop planner layout in tests (wide Row + cart).
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: nxProjectsTestSeedOverrides,
        child: const NexusProjectsApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Nexus'), findsWidgets);
  });
}
