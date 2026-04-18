// iOS simulator integration test.
//
// Pumps the app, asks the iOS integration_test plugin to capture a screenshot,
// and the companion [driver.dart] writes the PNG to `tests/screenshots/` on the host.

import 'package:flutter/material.dart';
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
}
