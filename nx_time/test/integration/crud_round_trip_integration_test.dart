import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart';

import '../_support/integration_auth.dart';

void main() {
  test(
    'Action CRUD via repository',
    () async {
      final container = ProviderContainer(overrides: timeIntegrationOverrides);
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final repo = container.read(actionRepositoryProvider);

      final day = DateTime.now();
      final cal = DateTime(day.year, day.month, day.day);
      final start = DateTime(cal.year, cal.month, cal.day, 23, 15);
      final end = start.add(const Duration(hours: 1));

      final newId = await repo.create(
        Action(
          id: 0,
          name: 'nx_time integration CRUD',
          modelTypeId: 0,
          startTime: start,
          endTime: end,
        ),
        'Meet',
      );

      final loaded = await repo.getById(id: newId, modelTypeName: 'Meet');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'nx_time integration CRUD');

      await repo.update(
        Action(
          id: newId,
          name: 'nx_time integration CRUD updated',
          description: 'tmp',
          modelTypeId: loaded.modelTypeId,
          modelTypeName: loaded.modelTypeName,
          startTime: loaded.startTime,
          endTime: loaded.endTime,
        ),
      );

      final after = await repo.getById(id: newId, modelTypeName: 'Meet');
      expect(after!.name, 'nx_time integration CRUD updated');

      await repo.delete(newId);

      final gone = await repo.getById(id: newId, modelTypeName: 'Meet');
      expect(gone, isNull);
    },
    skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    tags: ['integration'],
  );
}
