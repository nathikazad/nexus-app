import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/app.dart';

void main() {
  testWidgets('Nexus projects app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NexusProjectsApp()),
    );
    await tester.pump();
    expect(find.textContaining('Nexus'), findsWidgets);
  });
}
