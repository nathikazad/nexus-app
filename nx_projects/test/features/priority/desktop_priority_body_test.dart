import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/features/priority/desktop_priority_body.dart';

void main() {
  testWidgets('DesktopPriorityBody builds', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DesktopPriorityBody(
              onOpenTaskMenu: (c, r, t) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Planner'), findsNothing); // title is in parent; body has bucket labels
    expect(find.textContaining('NOW'), findsWidgets);
  });
}
