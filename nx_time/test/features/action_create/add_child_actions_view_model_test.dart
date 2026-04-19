import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/action_create/add_child_actions_view_model.dart';

import '../../_support/fake_action_repository.dart';
import '../../_support/riverpod_helpers.dart';

void main() {
  test('parentActionForChildrenProvider loads parent with graph from fake repo', () async {
    final p = Action(
      id: 1,
      name: 'Parent',
      modelTypeId: 2,
      modelTypeName: 'Goto',
      startTime: DateTime(2026, 4, 18, 8, 0),
      endTime: DateTime(2026, 4, 18, 18, 0),
    );
    final c = Action(
      id: 2,
      name: 'Child',
      modelTypeId: 3,
      modelTypeName: 'Meet',
      startTime: DateTime(2026, 4, 18, 9, 0),
      endTime: DateTime(2026, 4, 18, 10, 0),
    );
    final fake = FakeActionRepository(initial: [p, c]);
    await fake.linkChildAction(parentId: 1, childId: 2);

    final container = makeContainer(
      overrides: [
        actionRepositoryProvider.overrideWith((ref) => fake),
      ],
    );
    addTearDown(container.dispose);

    final key = (id: 1, modelTypeName: 'Goto');
    final loaded = await container.read(parentActionForChildrenProvider(key).future);
    expect(loaded, isNotNull);
    expect(loaded!.childActionIds, [2]);
    expect(loaded.relationIdByChildId[2], isNotNull);
  });
}
