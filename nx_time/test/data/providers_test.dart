import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/today/today_view_model.dart';

import '../_support/fake_action_repository.dart';
import '../_support/riverpod_helpers.dart';

void main() {
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
