import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/projects/kgql_project_repository.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/data/tasks/kgql_task_repository.dart';
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
      ],
    );
    addTearDown(container.dispose);

    final snap = await container.read(todaySnapshotProvider.future);
    expect(snap.sourceActions, isEmpty);
  });
}
