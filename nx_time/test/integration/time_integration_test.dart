import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/action/action_attr_keys.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/today/today_view_model.dart';

import '../_support/integration_auth.dart';

/// Calendar day for demo Actions from `seed_nx_time_calendar_demo` (Postgres `CURRENT_DATE` when you ran load_data).
/// Run integration tests the same day you seed, or re-run load_data first.
DateTime get kNxTimeDemoDay {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

Map<String, dynamic> _startTimeDayFilter(String modelTypeName, DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final end = start.add(const Duration(days: 1));
  return {
    'model_type': modelTypeName,
    'filters': [
      {'key': 'start_time', 'op': '>=', 'value': start.toIso8601String()},
      {'key': 'start_time', 'op': '<', 'value': end.toIso8601String()},
    ],
  };
}

void main() {
  group('nx_time integration (live GraphQL)', () {
    test(
      'Action schema loads',
      () async {
        final container = ProviderContainer(
          overrides: timeIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final mt = await container.read(actionSchemaProvider.future);
        expect(mt.name, kActionModelTypeName);
        expect(mt.attributes, isNotNull);
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'KGQL today snapshot returns without throw (seeded day may be empty)',
      () async {
        final container = ProviderContainer(
          overrides: timeIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final snapshot = await container.read(todaySnapshotProvider.future);
        final day = kNxTimeDemoDay;
        expect(
          snapshot.titleLine,
          'Today — ${DateFormat('EEE, MMM d').format(day)}',
        );
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'seeded demo day: Today snapshot lists multiple Action descendants',
      () async {
        final container = ProviderContainer(
          overrides: timeIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final snapshot = await container.read(todaySnapshotProvider.future);
        expect(
          snapshot.activityBlockCount,
          greaterThanOrEqualTo(6),
          reason:
              'seed_nx_time_calendar_demo should place Sleep, Meet, Workout, Goto, Consumption, … on this day',
        );
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'get_kgql_models: Action + start_time window (same as Today repository)',
      () async {
        final container = ProviderContainer(
          overrides: timeIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final client = container.read(graphqlClientProvider);
        final schema = await container.read(actionSchemaProvider.future);
        final struct = buildKgqlStructFromSchema(schema);

        final models = await fetchKgqlModels(
          client,
          filter: _startTimeDayFilter(kActionModelTypeName, kNxTimeDemoDay),
          struct: struct,
        );
        expect(models.length, greaterThanOrEqualTo(6));
        final names = models.map((m) => m.name).join(' ');
        expect(
          names,
          anyOf(contains('Platform'), contains('Sprint'), contains('Sarah')),
          reason: 'demo seed includes named Meet rows',
        );
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'get_kgql_models: Meet-only + same day window',
      () async {
        final container = ProviderContainer(
          overrides: timeIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final client = container.read(graphqlClientProvider);
        final meetType = await fetchKgqlModelTypeByName(client, 'Meet');
        final struct = buildKgqlStructFromSchema(meetType);

        final meets = await fetchKgqlModels(
          client,
          filter: _startTimeDayFilter('Meet', kNxTimeDemoDay),
          struct: struct,
        );
        expect(meets.length, greaterThanOrEqualTo(2));
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'get_kgql_models: fetch Meet by id round-trip',
      () async {
        final container = ProviderContainer(
          overrides: timeIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final client = container.read(graphqlClientProvider);
        final meetType = await fetchKgqlModelTypeByName(client, 'Meet');
        final struct = buildKgqlStructFromSchema(meetType);

        final meets = await fetchKgqlModels(
          client,
          filter: _startTimeDayFilter('Meet', kNxTimeDemoDay),
          struct: struct,
        );
        expect(meets, isNotEmpty);
        final id = meets.first.id;

        final one = await fetchKgqlModelById(
          client,
          modelTypeName: 'Meet',
          id: id,
          struct: struct,
        );
        expect(one, isNotNull);
        expect(one!.id, id);
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'get_kgql_model_type: Sleep inherits Action interval + duration',
      () async {
        final container = ProviderContainer(
          overrides: timeIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final client = container.read(graphqlClientProvider);
        final sleep = await fetchKgqlModelTypeByName(client, 'Sleep');
        final keys = {
          for (final a in sleep.attributes ?? const <AttributeDefinition>[])
            if (a.key != null && a.key!.isNotEmpty) a.key!,
        };
        expect(keys, containsAll(['start_time', 'end_time', 'duration']));
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );

    test(
      'get_kgql_models: Task relation picker lists seeded tasks',
      () async {
        final container = ProviderContainer(
          overrides: timeIntegrationOverrides,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        final client = container.read(graphqlClientProvider);
        final tasks = await fetchKgqlModelsForRelationPicker(client, 'Task');
        expect(tasks, isNotEmpty);
        final blob = tasks.map((t) => t.name).join(' ');
        expect(
          blob,
          anyOf(contains('Refactor'), contains('calendar')),
          reason: 'seed_nx_time_calendar_demo adds Refactor token validation / Ship calendar v1',
        );
      },
      tags: ['integration'],
      skip: runTimeIntegration ? null : kTimeIntegrationSkipReason,
    );
  });
}
