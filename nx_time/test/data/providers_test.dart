import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/goals/kgql_goal_repository.dart';
import 'package:nx_time/data/projects/kgql_project_repository.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/data/tasks/kgql_task_repository.dart';
import 'package:nx_time/domain/action/week_actions.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/today/today_view_model.dart';

import '../_support/fake_action_repository.dart';
import '../_support/mock_graphql_client.dart';
import '../_support/riverpod_helpers.dart';

void main() {
  test('taskRepositoryProvider and projectRepositoryProvider use KGQL impl', () {
    final mock = MockGraphQLClient();
    final container = makeContainer(
      overrides: [
        graphqlClientProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(taskRepositoryProvider), isA<KgqlTaskRepository>());
    expect(container.read(projectRepositoryProvider), isA<KgqlProjectRepository>());
    expect(container.read(goalRepositoryProvider), isA<KgqlGoalRepository>());
    expect(container.read(personRepositoryProvider), isA<KgqlPersonRepository>());
  });

  test('todaySnapshotProvider uses overridden repository', () async {
    final container = makeContainer(
      overrides: [
        authenticatedUserProvider.overrideWith(
          (ref) async => User(userId: '1', preset: BackendPreset.localhost),
        ),
        actionRepositoryProvider.overrideWith(
          (ref) => FakeActionRepository(initial: const []),
        ),
        modelTypeColorsProvider.overrideWith(
          (ref) async => ModelTypeColors.fallback,
        ),
      ],
    );
    addTearDown(container.dispose);

    final mon = container.read(todayMondayProvider);
    final weekKeepAlive = container.listen<AsyncValue<WeekActions>>(
      weekActionsProvider(mon),
      (_, __) {},
    );
    addTearDown(weekKeepAlive.close);
    await container.read(weekActionsProvider(mon).future);
    final snap = container.read(todaySnapshotProvider).requireValue;
    expect(snap.sourceActions, isEmpty);
  });
}
