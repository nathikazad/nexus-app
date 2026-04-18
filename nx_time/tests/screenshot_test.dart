// iOS simulator integration test.
//
// Pumps the app, asks the iOS integration_test plugin to capture a screenshot,
// and the companion [driver.dart] writes the PNG to `tests/screenshots/` on the host.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nx_time/app.dart';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today tab — capture screenshot', (tester) async {
    await tester.pumpWidget(const NxTimeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final bytes = await binding.takeScreenshot('today_tab');
    expect(bytes, isNotEmpty);
  });

  testWidgets('Tasks tab — capture screenshot', (tester) async {
    await tester.pumpWidget(const NxTimeApp(initialTabIndex: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final bytes = await binding.takeScreenshot('tasks_tab');
    expect(bytes, isNotEmpty);
  });

  testWidgets('Goals tab — capture screenshot', (tester) async {
    await tester.pumpWidget(const NxTimeApp(initialTabIndex: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final bytes = await binding.takeScreenshot('goals_tab');
    expect(bytes, isNotEmpty);
  });

  testWidgets('Calendar tab — capture screenshot', (tester) async {
    await tester.pumpWidget(const NxTimeApp(initialTabIndex: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final bytes = await binding.takeScreenshot('calendar_tab');
    expect(bytes, isNotEmpty);
  });
}
