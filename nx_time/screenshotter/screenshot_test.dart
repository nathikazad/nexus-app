// iOS simulator integration test.
//
// Captures PNGs for main tabs and key pushed screens; `tests/driver.dart`
// writes files to `tests/screenshots/` on the host.
//
// After capture, optionally compare tab shots to design references (same folder):
//   python3 tests/compare_tab_refs.py
//
// Activity detail / add time block / edit activity (HTML refs in tests/ref_capture/):
//   python3 tests/compare_activity_refs.py
//
// Run driver:
//   flutter drive --driver=tests/driver.dart --target=tests/screenshot_test.dart -d <simulator_id>

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nx_time/app.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../test/_support/screenshot_auth.dart';

/// Extra settle time after [Navigator.push] so screenshots are not mid-transition.
const _kAfterNav = Duration(milliseconds: 1100);

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Main tabs', () {
    testWidgets('today_tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      final bytes = await binding.takeScreenshot('today_tab');
      expect(bytes, isNotEmpty);
    });

    testWidgets('tasks_tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(initialTabIndex: 1),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      final bytes = await binding.takeScreenshot('tasks_tab');
      expect(bytes, isNotEmpty);
    });

    testWidgets('goals_tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(initialTabIndex: 2),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      final bytes = await binding.takeScreenshot('goals_tab');
      expect(bytes, isNotEmpty);
    });

    testWidgets('calendar_tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(initialTabIndex: 3),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      final bytes = await binding.takeScreenshot('calendar_tab');
      expect(bytes, isNotEmpty);
    });
  });

  group('Stacked screens', () {
    testWidgets('activity_detail', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.text('Deep sleep'));
      await tester.pump();
      await tester.pump(_kAfterNav);

      final bytes = await binding.takeScreenshot('activity_detail');
      expect(bytes, isNotEmpty);
    });

    testWidgets('add_time_block', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.text('Add time block manually'));
      await tester.pump();
      await tester.pump(_kAfterNav);

      final bytes = await binding.takeScreenshot('add_time_block');
      expect(bytes, isNotEmpty);
    });

    testWidgets('edit_activity', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.text('Platform › Sprint review'));
      await tester.pump();
      await tester.pump(_kAfterNav);

      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.pump(_kAfterNav);

      final bytes = await binding.takeScreenshot('edit_activity');
      expect(bytes, isNotEmpty);
    });

    testWidgets('task_picker', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(initialTabIndex: 1),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.byTooltip('Pick tasks'));
      await tester.pump();
      await tester.pump(_kAfterNav);

      final bytes = await binding.takeScreenshot('task_picker');
      expect(bytes, isNotEmpty);
    });

    testWidgets('task_detail', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(initialTabIndex: 1),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.text('Draft weekly newsletter'));
      await tester.pump();
      await tester.pump(_kAfterNav);

      final bytes = await binding.takeScreenshot('task_detail');
      expect(bytes, isNotEmpty);
    });

    testWidgets('ai_chat', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.byIcon(SolarLinearIcons.stars));
      await tester.pump();
      await tester.pump(_kAfterNav);

      final bytes = await binding.takeScreenshot('ai_chat');
      expect(bytes, isNotEmpty);
    });

    testWidgets('voice_overlay', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: screenshotAuthOverrides,
          child: const NexusTimeApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.longPress(find.byIcon(SolarLinearIcons.stars));
      await tester.pump();
      await tester.pump(_kAfterNav);

      final bytes = await binding.takeScreenshot('voice_overlay');
      expect(bytes, isNotEmpty);
    });
  });
}
