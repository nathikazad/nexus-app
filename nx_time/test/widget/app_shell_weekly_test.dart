@Tags(['widget'])
library;

import 'package:nx_time/data/subscriptions/kgql_model_subscription.dart';
import 'package:nx_time/features/calendar/calendar_page.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';
import '../_support/fake_task_repository.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';
import '../_support/fake_goal_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/shell/app_shell.dart';
import 'package:nx_time/features/today/today_view_model.dart';

import '../_support/fake_action_repository.dart';
import '../_support/fake_log_repository.dart';
import '../_support/pump_app.dart';

class _AuthLoggedIn extends AuthController {
  _AuthLoggedIn() : super(initialDelay: Duration.zero, skipBackendPing: true);

  @override
  Future<User?> build() async =>
      User(userId: '1', preset: BackendPreset.localhost);
}

void main() {
  testWidgets('shell labels the planning Calendar tab', (tester) async {
    await pumpAppWith(
      tester,
      child: const AppShell(initialTabIndex: 3),
      overrides: [
        workspaceChangesProvider.overrideWith((ref) => const Stream.empty()),
        planningFeedProvider.overrideWith(
          (ref) async => const CalendarFeed(entries: []),
        ),
        taskRepositoryProvider.overrideWithValue(
          const FakeEmptyTaskRepository(),
        ),
        allProjectsProvider.overrideWith((ref) async => []),
        goalRepositoryProvider.overrideWithValue(FakeGoalRepository()),
        authProvider.overrideWith(_AuthLoggedIn.new),
        authenticatedUserProvider.overrideWith(
          (ref) async => User(userId: '1', preset: BackendPreset.localhost),
        ),
        actionRepositoryProvider.overrideWith(
          (ref) => FakeActionRepository(initial: const []),
        ),
        logRepositoryProvider.overrideWith(
          (ref) => FakeLogRepository(initial: const []),
        ),
        modelTypeColorsProvider.overrideWith(
          (ref) async => ModelTypeColors.fallback,
        ),
        todaySnapshotProvider.overrideWith(
          (ref) =>
              AsyncValue.data(buildTodaySnapshot(const [], DateTime.now())),
        ),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Calendar'), findsAtLeastNWidgets(1));
    expect(find.text('Weekly'), findsNothing);
  });
}
