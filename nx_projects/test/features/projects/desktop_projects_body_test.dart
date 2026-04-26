import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/features/projects/desktop_projects_body.dart';
import '../../_support/seed_test_overrides.dart';

void main() {
  testWidgets('DesktopProjectsBody builds', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: nxProjectsTestSeedOverrides,
        child: MaterialApp(
          home: Scaffold(
            body: DesktopProjectsBody(
              onOpenTaskMenu: (c, r, t) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Nexus'), findsWidgets);
  });
}
